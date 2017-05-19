ruleset track_trips {
  meta {
    provides long_trips
  }

  global {
    long_trips = 100
  }




  rule process_trips {
    select when car new_trip where mileage > 0
    pre {
      mileage_value = event:attr("mileage")
    }
    send_directive("trip") with trip_length = mileage_value

    fired{
      raise explicit event "trip_processed"
         attributes event:attrs()
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


}

