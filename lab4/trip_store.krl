ruleset trip_store {
  meta {
    use module track_trips alias track_trips
    provides long_trips
  }

  global {
    long_trips = 100

    //  TODO:  then add 3 functions to retrieve entity variables
  }







  rule collect_trips {
    select when explicit trip_processed
    pre {
      mileage = event:attr("mileage")
      timestamp = event:attr("timestamp")

      //  TODO: store in an entity variable (which contains all the trips which have been processed)

    }


  }


  rule collect_long_trips {
    select when explicit found_long_trip
    pre {
      mileage = event:attr("mileage")
      timestamp = event:attr("timestamp")

      //  TODO: store in an entity variable (which contains all the long trips which have been processed)

    }


  }


  rule clear_trips {
    select when car trip_reset
    pre {

      //  TODO: resets the both the normal and long trip entity variables

    }


  }
}

