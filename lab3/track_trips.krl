ruleset track_trips {
  meta {

  }

  global {

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


}

