ruleset manage_fleet {
  meta {

    use module track_trips
    use module trip_store
    use module vehicle_profile
    //provides get_vin, get_long_trip_threshold
    //shares get_vin, get_long_trip_threshold
  }
  global {
    clear_vehicles = {}


    entries = function() {
      ent:timings.defaultsTo([])
    }
  }







  rule create_new_vehicle {
    select when car new_vehicle
    pre {




      //name = event:attr("name")
      //ordinal = number.extract(re#n0*(\d+)#i)[0].as("Number")
      //time_out = time:now()
      //exists = ent:timings.defaultsTo([])
      //                    .filter(function(v){v{"ordinal"} == ordinal})
    }
    //if exists.length() == 0 then noop()
    //fired {
    //  ent:timings := ent:timings.defaultsTo([]).append({
    //    "ordinal": ordinal,
    //    "number": number,
    //    "name": name,
    //   "time_out": time_out })
    }
  }













  rule clear_vehicles {
    select when car vehicles_reset
    pre {
    }
    send_directive("fleet_reset_confired") 
    always {
      ent:vehicles := clear_vehicles;
    }
  }

}
