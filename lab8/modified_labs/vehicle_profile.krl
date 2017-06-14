ruleset vehicle_profile {
  meta {
    //use module track_trips alias track_trips
    provides get_vin, get_long_trip_threshold, get_vehicle_id
    shares get_vin, get_long_trip_threshold, get_vehicle_id

  }

  global {
    clear_vin = "1N4AL3AP1FC130990"
    clear_threshold = 100
    empty_id = -1

    get_vin = function() {
      ent:vin.defaultsTo(clear_vin)
    };
    get_long_trip_threshold = function() {
      ent:threshold.defaultsTo(clear_threshold)
    };
    get_vehicle_id = function() {
      ent:vehicle_id.defaultsTo(empty_id)
    };
  }

  rule get_vehicle_profile {
    select when car profile
    pre {
      vin = get_vin()
      long_trip_threshold = get_long_trip_threshold()
      vehicle_id = get_vehicle_id()
    }
    send_directive("car_profile") with vin = vin long_trip_threshold = long_trip_threshold vehicle_id = vehicle_id
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
      vehicle_id = event:attr("vehicle_id")
      parent_eci = event:attr("parent_eci")

    }
      event:send(
        { "eci": parent_eci , "eid": "asking_for_subscription",
        "domain": "pico", "type": "child_ready_for_subscription",
        "attrs": { "child_eci": meta:eci, "vehicle_id" : vehicle_id } } )
    fired {
      //  TODO:  I need to fire this on the new child pico
      
      //  set the vehicle_id, this will never be changed until the vehicle is deleted
      ent:vehicle_id := vehicle_id;

      raise car event "profile_updated"
        attributes { "vin": vin, "long_trip_threshold" : long};
    
    }
  }







  rule auto_approve_subscriptions {
    select when wrangler inbound_pending_subscription_added
    pre{
      attributes = event:attrs().klog("subcription :");
    }
    noop()
    always{
      raise wrangler event "pending_subscription_approval"
          attributes attributes;       
          log("auto accepted subcription.");
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


