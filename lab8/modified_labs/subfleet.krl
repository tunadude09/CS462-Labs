ruleset subfleet {
  meta {
    use module manage_fleet
    use module trip_store
    shares get_subfleet_total_mileages, total_mileage_for_vehicle
    provides get_subfleet_total_mileages, total_mileage_for_vehicle
  }
  global {
    subfleet_profiles = function() {
      ent:subfleet_profiles.defaultsTo({})
    }
    subfleet_membership = function() {
      ent:subfleet_membership.defaultsTo({})
    }



    total_mileage_for_vehicle = function (vehicle_id, all_trips) {
      vehicle_trips = all_trips.filter(function(x) {x["vehicle_id"] == vehicle_id});
      vehicle_trips = vehicle_trips.values();
      vehicle_mileages = vehicle_trips.map(function(x) {x["mileage"]});
      total = vehicle_mileages.reduce(function(a,b) {a + b});
      total;
    }
 
    get_subfleet_total_mileages = function(subfleet_name) {
      all_fleet_trips = manage_fleet:collect_all_fleet_trips();

      subfleet_mileages = {};

      vehicle_ids = ent:subfleet_membership.filter(function(v, k) {v == subfleet_name}).keys();
      vehicle_names = vehicle_ids.map(function(x) { manage_fleet:nameFromID(x) });
      vehicle_total_miles = vehicle_ids.map(function(x) { total_mileage_for_vehicle(x, all_fleet_trips) });
      subfleet_total_miles = vehicle_total_miles.reduce(function(a,b) {a + b});

      //  TODO:  combine into one JSON list in subfleet_mileages
      //  I could create a list of order numbers the len of both then…
      subfleet_mileages = subfleet_mileages.put(["vehicle_names"], vehicle_names);
      subfleet_mileages = subfleet_mileages.put(["vehicle_total_miles"], vehicle_total_miles);
      subfleet_mileages = subfleet_mileages.put(["subfleet_totals"], {"subfleet_name": subfleet_name, "subfleet_total_mileage": subfleet_total_miles});
      subfleet_mileages  
  }


  }




  rule get_total_mileage {
  select when subfleet v_mileage
  pre{
    vehicle_id = event:attr("vehicle_id")
    all_fleet_trips = manage_fleet:collect_all_fleet_trips()
    miles = total_mileage_for_vehicle(vehicle_id, all_fleet_trips)
  }
    send_directive("miles") with total_mileage = miles
  }





  rule get_total_mileage {
  select when subfleet all_mileage
  pre{
    subfleet_name = event:attr("subfleet_name")
    miles = get_subfleet_total_mileages(subfleet_name)
  }
    send_directive("subfleet_miles") with total_mileage = miles
  }





  rule get_subfleets_meta {
    select when subfleet info
    pre {
      subfleet_prof_current = subfleet_profiles()
      subfleet_mem_current = subfleet_membership()      
    }
    send_directive("subfleets_profile") with profiles = subfleet_prof_current membership = subfleet_mem_current
  }


  rule new_subfleet {
    select when subfleet new
    pre {
      name = event:attr("name")
      description = event:attr("description")
    }
    always {
      raise pico event "new_child_request"
        attributes { "dname": name, "color": "#FF69B4" };
    
      ent:subfleet_profiles := ent:subfleet_profiles.defaultsTo({}).put([name], description)
    }
  }



  rule add_to_subfleet {
    select when subfleet add
    pre {
      vehicle_id = event:attr("vehicle_id")
      subfleet_name = event:attr("subfleet_name")
    }
    send_directive("yes")
    always {
      //  TODO:  I might need to update the structure differently
      //  target structure: f_m -> {name: [vehicle1, v2, v3,…], ….}
      ent:subfleet_membership := ent:subfleet_membership.defaultsTo({}).put([vehicle_id], subfleet_name)
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





  rule clear_subfleet_profiles {
    select when subfleet delete_profiles
    always {
      ent:subfleet_profiles := {}
    }
  }

  rule clear_subfleet_membership {
    select when subfleet delete_membership
    always {
      ent:subfleet_membership := {}
    }
  }
}

