ruleset manage_fleet {
  meta {
    use module track_trips
    use module trip_store
    use module vehicle_profile
    provides vehicles, __testing, long_trip_threshold
    shares vehicles, __testing, long_trip_threshold
  }
  global {
    clear_vehicles = {}

    long_trip_threshold = 80

    vehicles = function() {
      ent:vehicles.defaultsTo(clear_vehicles)
    }

    vins = function() {
      ent:vehicle_vins.defaultsTo(clear_vehicles)
    }

    nameFromID = function(vehicle_id) {
      "Vehicle " + vehicle_id + " Pico"
    }

    childFromID = function(vehicle_id) {
      ent:vehicles[vehicle_id]
    }






/*
      skyQuery is used to programmatically call function inside of other picos from inside a rule.
      parameters;
         eci - The eci of the pico which contains the function to be called
         mod - The ruleset ID or alias of the module  
         func - The name of the function in the module 
         params - The parameters to be passed to function being called
         optional parameters 
         _host - The host of the pico engine being queried. 
                 Note this must include protocol (http:// or https://) being used and port number if not 80.
                 For example "http://localhost:8080", which also is the default.
         _path - The sub path of the url which does not include mod or func.
                 For example "/sky/cloud/", which also is the default.
         _root_url - The entire url except eci, mod , func.
                 For example, dependent on _host and _path is 
                 "http://localhost:8080/sky/cloud/", which also is the default.  
      skyQuery on success (if status code of request is 200) returns results of the called function. 
      skyQuery on failure (if status code of request is not 200) returns a Map of error information which contains;
              error - general error message.
              httpStatus - status code returned from http get command.
              skyQueryError - The value of the "error key", if it exist, of the function results.   
              skyQueryErrorMsg - The value of the "error_str", if it exist, of the function results.
              skyQueryReturnValue - The function call results.
    */
    skyQuery = function(eci, mod, func, params,_host,_path,_root_url) { // path must start with "/"", _host must include protocol(http:// or https://)
      //.../sky/cloud/<eci>/<rid>/<name>?name0=value0&...&namen=valuen
      createRootUrl = function (_host,_path){
        host = _host || meta:host;
        path = _path || "/sky/cloud/";
        root_url = host+path;
        root_url
      };
      root_url = _root_url || createRootUrl(_host,_path);
      web_hook = root_url + eci + "/"+mod+"/" + func;

      response = http:get(web_hook.klog("URL"), {}.put(params)).klog("response ");
      status = response{"status_code"};// pass along the status 
      error_info = {
        "error": "sky query request was unsuccesful.",
        "httpStatus": {
            "code": status,
            "message": response{"status_line"}
        }
      };
      // clean up http return
      response_content = response{"content"}.decode();
      response_error = (response_content.typeof() == "Map" && (not response_content{"error"}.isnull())) => response_content{"error"} | 0;
      response_error_str = (response_content.typeof() == "Map" && (not response_content{"error_str"}.isnull())) => response_content{"error_str"} | 0;
      error = error_info.put({"skyQueryError": response_error,
                              "skyQueryErrorMsg": response_error_str, 
                              "skyQueryReturnValue": response_content});
      is_bad_response = (response_content.isnull() || (response_content == "null") || response_error || response_error_str);
      // if HTTP status was OK & the response was not null and there were no errors...
      (status == 200 && not is_bad_response ) => response_content | error
    }





   collect_all_fleet_trips = function() {
     //  TODO:  now I need to #1 run through all call this method on every vehicle in vehicles()
     vehicles_meta = ent:vehicles.values();
     vehicles_meta_ecis = vehicles_meta.map(function(x) {x["eci"]});
     vehicles_meta_trips = vehicles_meta_ecis.map(function(x) {skyQuery(x, "trip_store", "trips")});
     //  TODO:  then #2 I need to aggregate these all together and return
     // {"0":{"timestamp":"1497155028","mileage":"170","vin":"88888"},"1":{"timestamp":"1497155034","mileage":"5684","vin":"88888"}},{}]}
     //  how to combine an array of these into a single json file?
     //  this might be ok for now FIXME as needed in future labs
     vehicles_meta_trips.map(function(x) {x.values()});

   }








    __testing = { "events":  [ { "domain": "vehicle", "type": "needed", "attrs": [ "vehicle_id" ] } ] }
  }


  rule collect_all_trips {
  select when car collect_all_trips
  pre {
    all_trips = collect_all_fleet_trips()
  }
    send_directive("all_trips") with trips = all_trips
  }


  rule get_vehicles {
    select when car get_vehicles
    pre {
      vehicles_value = vehicles()
      vins_value = vins()
    }
    send_directive("vehicles_info") with vehicles = vehicles_value vins = vins_value
  }






  rule create_new_vehicle {
    select when car new_vehicle

    //creating a new pico to represent the vehicle
    //installing the trip_store, track_trips, and vehicle_profile rulesets in the new vehicle
    //storing the new vehicle pico's ECI and an event attribute with the vehicle's name in an entity variable called vehicles that maps its name to the ECI

    pre {
      vehicle_id = event:attr("vehicle_id")
      vehicle_vin = event:attr("vin")
      exists = ent:vehicles.defaultsTo(clear_vehicles) >< vehicle_id
      vin_exists = ent:vehicle_vins.defaultsTo(clear_vehicles).values() >< vehicle_vin

      eci = meta:eci
      vin = event:attr("vin")

      //vehicle_values = vehicles()
    }

    if exists || vin_exists then
      send_directive("vehicle_ready")
        with vehicle_id = vehicle_id vin = vehicle_vin
    fired {
    } else {
      //  TODO:  could potentially create race condition if not included
      //ent:vehicles := ent:vehicles.defaultsTo(clear_vehicles).union(vehicle_id);
      ent:vehicle_vins := ent:vehicle_vins.defaultsTo(clear_vehicles).put([vehicle_id], vehicle_vin);
      raise pico event "new_child_request"
        attributes { "dname": nameFromID(vehicle_id), "color": "#FF69B4", "vehicle_id": vehicle_id, "vin" : vin };
    }
  }





  rule pico_child_initialized {
    select when pico child_initialized
    pre {
      the_vehicle = event:attr("new_child")
      vehicle_id = event:attr("rs_attrs"){"vehicle_id"}
      vin = event:attr("rs_attrs"){"vin"}

      vehicle_values = vehicles()

      //vehicle_map = {vehicle_id : the_vehicle}

    }
    if vehicle_id.klog("found vehicle_id")
    then {
      event:send(
        { "eci": the_vehicle.eci, "eid": "install-ruleset",
        "domain": "pico", "type": "new_ruleset",
        "attrs": { "rid": "vehicle_profile", "vehicle_id": vehicle_id, "vin" : vin, "long_threshold" : long_trip_threshold } } );
      event:send(
        { "eci": the_vehicle.eci, "eid": "install-ruleset",
        "domain": "pico", "type": "new_ruleset",
        "attrs": { "rid": "track_trips", "vehicle_id": vehicle_id } } );
      event:send(
        { "eci": the_vehicle.eci, "eid": "install-ruleset",
        "domain": "pico", "type": "new_ruleset",
        "attrs": { "rid": "trip_store", "vehicle_id": vehicle_id } } );

      

    } fired {

      //  TODO:  save thee eci ids etc properly here
      ent:vehicles := ent:vehicles.defaultsTo(clear_vehicles);
      ent:vehicles := ent:vehicles.put([vehicle_id], the_vehicle);
      //ent:vehicles{[vehicle_id]} := the_vehicle;
  
    }
  }



  rule car_offline {
    select when car unneeded_vehicle
    pre {
      vehicle_id = event:attr("vehicle_id")
      exists = ent:vehicles.defaultsTo(clear_vehicles) >< vehicle_id
      //eci = meta:eci
      child_to_delete = childFromID(vehicle_id)
    }
    if exists then
      send_directive("car_deleted")
        with vehicle_id_num = vehicle_id
    fired {
      raise pico event "delete_child_request"
        attributes child_to_delete;
      ent:vehicles{[vehicle_id]} := null
    }
  }







  rule clear_vehicles {
    select when car vehicles_reset
    pre {
    }
    send_directive("fleet_reset_confirmed")
    always {
      ent:vehicles := clear_vehicles;
    }
  }

}