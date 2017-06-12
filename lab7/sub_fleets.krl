ruleset subfleet {
  meta {
    use module fleet
    use module trip_store
    shares get_subfleet_total_mileages, total_mileage_for_vehicle
provides get_subfleet_total_mileages, total_mileage_for_vehicle
}
  global {

  total_mileage_for_vehicle = function (vehicle_id) {
    all_trips = trip_store.trips();
    vehicle_trips = all_trips.filter(function(x) { x(“vehicle_id”) == vehicle_id });
    vehicle_mileages = vehicle_trips.map(function(x) { x(“mileage”) });
    total = vehicle_mileages.sum();
    total;
}


  get_subfleet_total_mileages = function(subfleet_name) {
    subfleet_mileages = {};

vehicle_ids = ent:subfleet_membership(subfleet_name);
vehicle_names = vehicle_ids.map(function(x) { fleet.nameFromID(x) });
vehicle_total_miles = vehicle_ids.map(function(x) { total_mileage_for_vehicle(x) });
subfleet_total_miles = vehicle_total_miles.sum();

 //  TODO:  combine into one JSON list in subfleet_mileages
    //  I could create a list of order numbers the len of both then…

      subfleet_mileages = numbers.map(function(x) {{vehicle_names(x) : vehicle_total_miles(x)}});

subfleet_mileages = subfleet_mileages.put([“subfleet_mileage_totals”], subfleet_total_miles)

 subfleet_mileages;  //  this is what is returned
  }



}




  rule new_subfleet {
    select when subfleet new
    pre {
      name = event:attr(“name”) 
      description = event:attr(“description”)
}
always {
  ent:subfleet_profiles := ent:subfleet_profiles.defaultsTo({}).put([name], description)
}
  }


  rule add_to_subfleet {
    select when subfleet add
    pre {
      vehicle_id = event:attr(“vehicle_id”) 
      subfleet_name = event:attr(“subfleet_name”)
}
always {
  //  TODO:  I might need to update the structure differently
  //  target structure: f_m -> {name: [vehicle1, v2, v3,…], ….}
  ent:subfleet_membership(subfleet_name) := ent:subfleet_membership(subfleet_name).append(vehicle_id)
}
  }




rule auto_ approve_subscriptions {
  select when wrangler inbound_pending_subscription_added
  pre{
    attributes = event:attrs().klog("subcription :");
    }
    noop();
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

