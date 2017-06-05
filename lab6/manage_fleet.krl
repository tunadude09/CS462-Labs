ruleset manage_fleet {
  meta {
    use module track_trips
    use module trip_store
    use module vehicle_profile
    provides vehicles, __testing
    shares vehicles, __testing
  }
  global {
    clear_vehicles = []

    vehicles = function() {
      ent:vehicles
    }

    nameFromID = function(vehicle_id) {
      "Vehicle " + vehicle_id + " Pico"
    }
    __testing = { "events":  [ { "domain": "vehicle", "type": "needed", "attrs": [ "vehicle_id" ] } ] }
  }


  rule get_vehicles {
    select when car get_vehicles
    pre {
      vehicles_value = vehicles()
    }
    send_directive("vehicles_info") with vehicles = vehicles_value
  }






  rule create_new_vehicle {
    select when car new_vehicle

    //creating a new pico to represent the vehicle
    //installing the trip_store, track_trips, and vehicle_profile rulesets in the new vehicle
    //storing the new vehicle pico's ECI and an event attribute with the vehicle's name in an entity variable called vehicles that maps its name to the ECI

    pre {
      vehicle_id = event:attr("vehicle_id")
      exists = ent:vehicles >< vehicle_id
      eci = meta:eci
      //vehicle_values = vehicles()
    }

    if exists then
      send_directive("vehicle_ready")
        with vehicle_id = vehicle_id
    fired {
    } else {
      ent:vehicles := ent:vehicles.defaultsTo([]).union([vehicle_id]);
      raise pico event "new_child_request"
        attributes { "dname": nameFromID(vehicle_id), "color": "#FF69B4", "vehicle_id": vehicle_id };
    }
  }





  rule pico_child_initialized {
    select when pico child_initialized
    pre {
      the_vehicle = event:attr("new_child")
      //info_returned = event:attr("rs_attrs")
      vehicle_id = event:attr("rs_attrs"){"vehicle_id"}
      vehicle_values = vehicles()

    }
    if vehicle_id.klog("found vehicle_id")
    then
      noop()
    fired {
      ent:vehicles := ent:vehicles.defaultsTo({});
      ent:vehicles{[vehicle_id]} := the_vehicle;





      //event:send(
      //  { "eci": eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "track_trips", "vehicle_id": vehicle_id } } );
      //event:send(
      //  { "eci": eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "trip_store", "vehicle_id": vehicle_id } } );
      //event:send(
      //  { "eci": eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "vehicle_profile", "vehicle_id": vehicle_id } } );

    //send_directive("vehicles_info2") with vehicles = vehicle_values;

  
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
rm -r ~/.pico-engine