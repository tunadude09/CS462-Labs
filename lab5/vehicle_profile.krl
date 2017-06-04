ruleset vehicle_profile {
  meta {
    use module track_trips alias track_trips
    provides get_vin, get_long_trip_threshold
    shares get_vin, get_long_trip_threshold

  }

  global {
    clear_vin = -1
    clear_threshold = -1

    get_vin = function() {
      ent:vin
    };
    get_long_trip_threshold = function() {
      ent:threshold
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
    if vin.length() == 0 then noop()

    fired {
      ent:vin := vin
      ent:threshold := long_trip_threshold
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

