ruleset vehicle_profile {
  meta {
    //use module track_trips alias track_trips
    provides get_vin, get_long_trip_threshold
    shares get_vin, get_long_trip_threshold

  }

  global {
    clear_vin = "1N4AL3AP1FC130990"
    clear_threshold = 100

    get_vin = function() {
      ent:vin.defaultsTo(clear_vin)
    };
    get_long_trip_threshold = function() {
      ent:threshold.defaultsTo(clear_threshold)
    };
  }

  rule get_vehicle_profile {
    select when car profile
    pre {
      vin = get_vin()
      long_trip_threshold = get_long_trip_threshold()
    }
    send_directive("car_profile") with vin = vin long_trip_threshold = long_trip_threshold
  }







  rule update_vehicle_profile {
    select when car profile_updated
    pre {
      vin = event:attr("vin")
      long_trip_threshold = event:attr("long_trip_threshold")
        
    }

    always {
      ent:vin := vin;
      ent:threshold := long_trip_threshold
    }
  }
 




  rule all_rulesets_added {
    //  TODO:  need to avoid race conditions and only run this after rules are installed
    select when pico ruleset_added where rid == "vehicle_profile"
    pre {
      vin  =  event:attr("vin")
      long = event:attr("long_threshold")
    }
    
    fired {
      //  TODO:  I need to fire this on the new child pico
      //event:send(
      //  { "eci": the_vehicle.eci , "eid": "update-profile",
      //  "domain": "car", "type": "profile_updated",
      //  "attrs": { "vin": vin, "threshold" : long_trip_threshold } } );

      raise car event "profile_updated"
        attributes { "vin": vin, "long_trip_threshold" : long};
    
    }
  }










  rule clear_profile {
    select when car trip_reset
    pre {
      //  TODO: resets the all profile variables
    }
    send_directive("profile_reset_confired") 
    always {
      ent:vin := clear_vin;
      ent:threshold := clear_threshold;
    }
  }
}


