ruleset sub_fleets {
  meta {
    use module track_trips
    use module trip_store
    use module vehicle_profile
    provides vehicles, __testing, long_trip_threshold
    shares vehicles, __testing, long_trip_threshold
  }
  global {
    clear_vehicles = {}

    vehicles = function() {
      ent:vehicles.defaultsTo(clear_vehicles)
    }

  rule new_sub_fleet {
    select when sub_fleet new
    pre {
      sf_name = event:attr("vehicle_id")
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
