ruleset track_trips {
  meta {

  }

  global {

  }




  rule process_trips {
    select when car new_trip where mileage.as("num") > 0
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
    send_directive("trip") with trip_length = mileage_value
  }


  rule trip_fuel_usage {
    select when car trip_processed
    pre {
      mileage_value = event:attr("mileage")
    }
    send_directive("trip") with trip_length = mileage_value
  }

}

