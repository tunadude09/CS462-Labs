ruleset trip_store {
  meta {
    use module track_trips alias track_trips
    use module vehicle_profile
    provides trips, long_trips, short_trips
    shares trips, long_trips, short_trips
  }

  global {
    clear_trips = {}
    //clear_id = -1

    trips = function() {
         ent:trips.defaultsTo(clear_trips)
    };
    long_trips = function() {
         ent:long_trips.defaultsTo(clear_trips)
    };
    short_trips = function() {
         short_keys = ent:trips.defaultsTo(clear_trips).keys().difference(ent:long_trips.keys());
         ent:trips.defaultsTo(clear_trips).filter(function(v, k) {short_keys >< k});
    };

  }

  rule test_return_ent{
    select when car return_ent
    pre{
       trips_var = trips()
       long_trips_var = long_trips()
       short_trips_var = short_trips()
    }
    send_directive("entities") with trips_ent = trips_var long_ent = long_trips_var short_ent = short_trips_var 

  }


  rule test_return_trips{
    select when car return_trips
    pre{
       trips_var = trips()
    }
    send_directive("all_trips") with trips = trips_var 
  }




  rule collect_trips {
    select when explicit trip_processed
    pre {
      vin = event:attr("vin")
      mileage = event:attr("mileage")
      timestamp = event:attr("timestamp")
      vehicle_id = vehicle_profile:get_vehicle_id()
      //max_id = ent:trips_last_id
      //next_id = max_id + 1
      next_id = event:attr("next_id")

    }
    send_directive("trips_so_far") with trips_var = ent:trips.defaultsTo(clear_trips) long_trips_var = ent:long_trips.defaultsTo(clear_trips)

    always{
      ent:trips := ent:trips.defaultsTo(clear_trips);
      ent:trips{[next_id,"timestamp"]} := timestamp;
      ent:trips{[next_id,"mileage"]} := mileage.as("Number");
      ent:trips{[next_id,"vin"]} := vin;
      ent:trips{[next_id,"vehicle_id"]} := vehicle_id;
      //ent:trips_last_id := next_id;
    }
  }





  rule collect_long_trips {
    select when explicit found_long_trip
    pre {
      vin = event:attr("vin")
      mileage = event:attr("mileage")
      timestamp = event:attr("timestamp")
      vehicle_id = vehicle_profile:get_vehicle_id()

      //max_id = ent:long_trips_last_id
      //next_id = max_id + 1
      next_id = event:attr("next_id")
    }
    //send_directive("long_trips_so_far") with trips_var = ent:trips.defaultsTo(clear_trips) long_trips_var = ent:long_trips.defaultsTo(clear_trips)

    always{
      ent:long_trips := ent:long_trips.defaultsTo(clear_trips);
      ent:long_trips{[next_id,"timestamp"]} := timestamp;
      ent:long_trips{[next_id,"mileage"]} := mileage.as("Number");
      ent:long_trips{[next_id,"vin"]} := vin;
      ent:long_trips{[next_id,"vehicle_id"]} := vehicle_id;

      //ent:long_trips_last_id := next_id;
    }
  }











  rule generate_report {
    select when fleet report_requested
    pre {
      all_trips_for_vehicle = trips()
      parent_eci = event:attr("parent_eci")
      corr_id = event:attr("corr_id")

    }
    
    event:send(
      { "eci": parent_eci, "eid": "sending_report",
        "domain": "fleet", "type": "report_ready" ,
        "attrs": { "corr_id": corr_id, "report" : all_trips_for_vehicle}
     }
   )

  }









  rule clear_trips {
    select when car trip_reset
    pre {
      //  TODO: resets the both the normal and long trip entity variables
    }
    send_directive("reset_confired") 
    //send_directive("reset_confired") with trips_var = ent:trips.defaultsTo(clear_trips) long_trips_var = ent:long_trips.defaultsTo(clear_trips)
    always {
      //ent:trips_last_id := clear_id;
      //ent:long_trips_last_id := clear_id;
      ent:trips := clear_trips;
      ent:long_trips := clear_trips;
    }

  }
}


