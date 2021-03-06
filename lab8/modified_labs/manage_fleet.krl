ruleset manage_fleet {
  meta {
    use module track_trips
    use module trip_store
    use module vehicle_profile
    use module Subscriptions

    provides vehicles, __testing, long_trip_threshold, collect_all_fleet_trips, nameFromID
    shares vehicles, __testing, long_trip_threshold, collect_all_fleet_trips, nameFromID
  }
  global {
    clear_vehicles = {}

    long_trip_threshold = 80

    canichangethis = []

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
     vehicles_meta = ent:vehicles.values();
     vehicles_meta_ecis = vehicles_meta.map(function(x) {x["eci"]});
     vehicles_meta_trips = vehicles_meta_ecis.map(function(x) {skyQuery(x, "trip_store", "trips")});
     vehicles_meta_trips = vehicles_meta_trips.map(function(x) {x.values()});
     //test_arr = [[{"timestamp":"1497332946","mileage":"3333","vin":"1N4AL3AP1FC130990","vehicle_id":"4444"},{"timestamp":"1497332950","mileage":"77","vin":"1N4AL3AP1FC130990","vehicle_id":"4444"}], [{"timestamp":"1497332946","mileage":"1111","vin":"1N4AL3AP1FC130990","vehicle_id":"4444"},{"timestamp":"1497332950","mileage":"11","vin":"1N4AL3AP1FC130990","vehicle_id":"4444"}]];
     flatten(vehicles_meta_trips, 0)
   }

   flatten = function (arr, i) {
     i == arr.length() => []  |   arr[i].append(flatten(arr, i + 1))
   }




  get_5_latest_reports = function() {
    //  grab back 5 from array
    report_cids = ent:all_report_cids.defaultsTo([]);
    report_cids = report_cids.reverse();
    cid_duplication = ent:reports_count;

    id0 = report_cids[0];
    id1 = report_cids[1 * cid_duplication];
    id2 = report_cids[2 * cid_duplication];
    id3 = report_cids[3 * cid_duplication];
    id4 = report_cids[4 * cid_duplication];

    collect_reports = {};
    collect_reports = collect_reports.put(["0"], ent:fleet_reports[id0]);
    collect_reports = collect_reports.put(["1"], ent:fleet_reports[id1]);
    collect_reports = collect_reports.put(["2"], ent:fleet_reports[id2]);
    collect_reports = collect_reports.put(["3"], ent:fleet_reports[id3]);
    collect_reports = collect_reports.put(["4"], ent:fleet_reports[id4]);
    collect_reports;
    //report_cids;
  }

  

    __testing = { "events":  [ { "domain": "vehicle", "type": "needed", "attrs": [ "vehicle_id" ] } ] }
  }

  rule get_last_5_reports {
    select when fleet collect_latest_reports
    pre {
      stuff = get_5_latest_reports()
    }
    send_directive("stuff") with stuff = stuff
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
      //event:send(
      //  { "eci": the_vehicle.eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "Subscriptions", "vehicle_id": vehicle_id } } );
      event:send(
        { "eci": the_vehicle.eci, "eid": "install-ruleset",
        "domain": "pico", "type": "new_ruleset",
        "attrs": { "rid": "vehicle_profile", "vehicle_id": vehicle_id, "vin" : vin, "long_threshold" : long_trip_threshold, "parent_eci" : meta:eci } } );
      //event:send(
      //  { "eci": the_vehicle.eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "track_trips", "vehicle_id": vehicle_id } } );
      //event:send(
      //  { "eci": the_vehicle.eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "trip_store", "vehicle_id": vehicle_id } } );

      

    } fired {

      //  TODO:  save thee eci ids etc properly here
      ent:vehicles := ent:vehicles.defaultsTo(clear_vehicles);
      ent:vehicles := ent:vehicles.put([vehicle_id], the_vehicle);
      //ent:vehicles{[vehicle_id]} := the_vehicle;
  
    }
  }




  rule subscribe_to_child_vehicle {
    select when pico child_ready_for_subscription
    pre {
      child_eci = event:attr("child_eci")
      vehicle_id = event:attr("vehicle_id")
    }


      //event:send(
      //{ "eci": meta:eci, "eid": "subscription",
      //  "domain": "wrangler", "type": "subscription",
      //  "attrs": { "name": "fleet_vehicle",
      //             "name_space": "fleet",
      //             "my_role": "fleet_controller",
      //             "subscriber_role": "fleet_member",
      //             "channel_type": "subscription",
      //             "subscriber_eci": child_eci } } )

    always {
      
      raise wrangler event "subscription"
        with name = vehicle_id
          name_space = "fleet"
          my_role = "fleet_controller"
          subscriber_role = "fleet_member_vehicle"
          channel_type = "subscription"
          subscriber_eci = child_eci      
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









  rule request_reports_prep {
    select when fleet request_reports
    pre {
      //  generate one corr_id for the entire report
      corr_id = time:now()
      corr_id = "cid" + corr_id
    }
    fired {
      raise fleet event "request_reports_sub"
        with corr_id = corr_id;
    }
  }






  rule request_reports {
    select when fleet request_reports_sub
    foreach Subscriptions:getSubscriptions() setting (subscription)
    pre {
      subs_attrs = subscription{"attributes"}
      corr_id = event:attr("corr_id")
    }
    if subs_attrs{"subscriber_role"} == "fleet_member_vehicle" then    
      event:send(
        { "eci": subs_attrs{"subscriber_eci"}, "eid": "report_requested",
          "domain": "fleet", "type": "report_requested" ,
          "attrs": { "corr_id": corr_id, "parent_eci" : meta:eci}
        }
      )
      //event:send(
      //  { "eci": meta:eci, "eid": subs_attrs{"outbound_eci"},
      //    "domain": "fleet", "type": "report_requested" ,
      //    "attrs": { "corr_id": corr_id, "parent_eci" : meta:eci}
      // }
      //)  
    always {
      //  reset the reports received count
      ent:reports_count := 0;

      //  TODO:  remove this later, for debuggin
      //ent:fleet_reports := {}
    }
  }





  rule gather_reports {
    select when fleet report_ready
    pre {
      corr_id = event:attr("corr_id")
      report = event:attr("report")
      reports_received = ent:reports_count.defaultsTo(0) + 1
      num_vehicles = ent:vehicles.length()
    }

    always {
      ent:reports_count := reports_received;
      //  TODO:  store report


      ent:fleet_reports := ent:fleet_reports.defaultsTo({});
      report_obj = ent:fleet_reports[corr_id];
      report_obj = report_obj.defaultsTo({});
      current_report_group = report_obj["trips"];
      current_report_group = current_report_group.defaultsTo([]);
      current_report_group = current_report_group.append(report);

      report_obj["vehicles"] = num_vehicles;
      report_obj["responding"] = reports_received;
      report_obj["trips"] = current_report_group.klog(report_obj);

      ent:fleet_reports := ent:fleet_reports.put([corr_id], report_obj);

      ent:all_report_cids := ent:all_report_cids.defaultsTo([]);
      ent:all_report_cids :=  ent:all_report_cids.append(corr_id);
    }
  }




  rule get_report {
    select when fleet get_report
    pre {
       reports = ent:fleet_reports.defaultsTo({})
       //reports_count = ent:reports_count.defaultsTo(0)
    }
    send_directive("reports") with reports = reports
  }





  rule reset_report {
    select when fleet reset_report
    fired {
      ent:fleet_reports := {}
    }
  }














  rule reset_subs {
    select when car vehicles_reset
    pre {

    }
    fired {
      raise wrangler event "subscription_cancellation"
        with subscription_name = "fleet:444"
    }  
  }




  //rule reset_subscriptions {
  //  select when car vehicles_reset
  //  foreach Subscriptions:getSubscriptions() setting (subscription)
  //  pre {
  //    subs_attrs = subscription{"attributes"}
  //  }
  //  if subs_attrs{"subscriber_role"} == "fleet_member_vehicle" then
  //    noop()
  //  fired {
  //    raise wrangler event "subscription_cancellation"
  //      with subscription_name = subs_attrs{"name_space"} + ":" + subs_attrs{"subscription_name"}
  //  }  
 // }






  rule clear_vehicles {
    select when car vehicles_reset
    pre {
    }
    send_directive("fleet_reset_confirmed")
    always {
      ent:vehicles := clear_vehicles;
      ent:vehicle_vins := clear_vehicles;
    }
  }

}