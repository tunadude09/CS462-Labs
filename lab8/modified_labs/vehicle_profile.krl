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
 




  rule v_prof_ruleset_added {
    //  TODO:  need to avoid race conditions and only run this after rules are installed
    select when pico ruleset_added where rid == "vehicle_profile"
    pre {
      vin  =  event:attr("vin")
      long = event:attr("long_threshold")
      vehicle_id = event:attr("vehicle_id")
      parent_eci = event:attr("parent_eci")

    }
      //event:send(
      //  { "eci": the_vehicle.eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "Subscriptions", "vehicle_id": vehicle_id } } );
      //event:send(
      //  { "eci": the_vehicle.eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "vehicle_profile", "vehicle_id": vehicle_id, "vin" : vin, "long_threshold" : long_trip_threshold, "parent_eci" : meta:eci } } );
      //event:send(
      //  { "eci": the_vehicle.eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "track_trips", "vehicle_id": vehicle_id } } );
      //event:send(
      //  { "eci": the_vehicle.eci, "eid": "install-ruleset",
      //  "domain": "pico", "type": "new_ruleset",
      //  "attrs": { "rid": "trip_store", "vehicle_id": vehicle_id } } );

    fired {
      //  set the vehicle_id, this will never be changed until the vehicle is deleted
      ent:vehicle_id := vehicle_id;

      raise car event "profile_updated"
        attributes { "vin": vin, "long_trip_threshold" : long};
      raise pico event "new_ruleset"
        attributes { "rid": "Subscriptions", "vehicle_id": vehicle_id, "parent_eci" : parent_eci };
    
    }
  }



  rule sub_ruleset_added {
    select when pico ruleset_added where rid == "Subscriptions"
    pre {
      parent_eci = event:attr("parent_eci")
    }
    fired {
      raise pico event "new_ruleset"
        attributes { "rid": "track_trips", "vehicle_id": vehicle_id, "parent_eci" : parent_eci };
    }
  }

  rule track_ruleset_added {
    select when pico ruleset_added where rid == "track_trips"
    pre {
      parent_eci = event:attr("parent_eci")
    }
    fired {
      raise pico event "new_ruleset"
        attributes { "rid": "trip_store", "vehicle_id": vehicle_id, "parent_eci" : parent_eci };
    }
  }

  rule all_rulesets_added {
    select when pico ruleset_added where rid == "trip_store"
    pre {
      parent_eci = event:attr("parent_eci")
    }
    //  this will ask for a subscription now that all rules are installed
    event:send(
      { "eci": parent_eci , "eid": "asking_for_subscription",
      "domain": "pico", "type": "child_ready_for_subscription",
      "attrs": { "child_eci": meta:eci, "vehicle_id" : vehicle_id } } )
    fired {
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


