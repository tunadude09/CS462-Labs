ruleset track_trips {
  meta {

  }

  global {

  }




  rule process_trips {
    select when car new_trip
    pre {
  		mileage_value = event:attr("mileage")
    }
    send_directive("trip") with trip_length = mileage_value
  }
}

