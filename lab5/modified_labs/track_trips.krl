ruleset track_trips {
  meta {
    use module io.picolabs.use_edmund_api alias api
    provides long_trips
  }

  global {
    long_trips = 100
    clear_id = -1

  }


  rule process_trips {
    select when car new_trip where mileage > 0
    pre {
      mileage_value = event:attr("mileage")

      //  increment last_id, then pass this on as an event attribute
      next_id = ent:trips_last_id + 1
      event_attr_map = event:attrs()
      next_id_map = {"next_id": next_id}
      timestamp_map = {"timestamp": time:strftime(time:now(), "%s")}
      //timestamp_map = {"timestamp": "123456867"}
      event_attr_map = event_attr_map.put(next_id_map)
      event_attr_map = event_attr_map.put(timestamp_map)
    }
    send_directive("trip") with trip_length = mileage_value

    fired{
      raise explicit event "trip_processed"
         attributes event_attr_map;
      ent:trips_last_id := next_id;

    }
  }


  rule find_long_trips {
    select when explicit trip_processed
    pre {
      mileage_value = event:attr("mileage")
    }

    if mileage_value <= long_trips then
       noop()
    fired {
    } else {
      raise explicit event "found_long_trip"
         attributes event:attrs()
    }
  }


  rule trip_fuel_usage {
    select when explicit trip_processed
    pre {
      mileage_value = event:attr("mileage")
      vin = event:attr("vin")
      //resp = api:decode_vin(vin)
      //mpg = resp[0]["content"]["MPG"]["highway"]
      mpg = 25
    }

    //send_directive("fuel_usage_filler")
    send_directive("results") with miles_driven = mileage_value gas_used_gal = mileage_value / mpg

  }




  rule clear_trip_counts {
    select when car trip_reset
    pre {
      //  TODO: resets the both the normal and long trip entity variables
    }
    always {
      ent:trips_last_id := clear_id;
    }

  }
}


