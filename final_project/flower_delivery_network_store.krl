ruleset flower_delivery_network_store {
  meta {
    use module Subscriptions

    shares __testing
  }
  global {
    get_peer = function () {
      //  TODO:  this is only random as a test, fix
      subscriptions = Subscriptions:getSubscriptions();
      index = random:integer(0, subscriptions.length() - 1);
      sub_attrs = subscriptions[subscriptions.keys()[index]]["attributes"];
      (sub_attrs["subscriber_eci"].isnull()) => sub_attrs["outbound_eci"] | sub_attrs["subscriber_eci"];
      //subscriptions.keys();
      //sub_attrs["outbound_eci"];
    }


    get_job_directory = function() {
      ent:job_directory.defaultsTo({})
    }



    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
  }

  rule stuff {
    select when stuff stuff
    pre {
      stuff = schedule:list()
    }
    send_directive("stuff") with stuff = stuff
  }


  rule get_job_directory {
    select when store get_job_directory
    pre {
      jobs = get_job_directory()
    }
    send_directive("jobs") with jobs = jobs
  }




  rule start_heartbeat {
    select when heartbeat start
    pre {
      existing_schedule_for_pico = schedule:list().filter(function(x) {x["event"]["eci"] == meta:eci})
      id_to_delete = (existing_schedule_for_pico.length() > 0) => existing_schedule_for_pico[0]["id"] | -1
    }
    if id_to_delete != -1 then
      schedule:remove(id_to_delete);
    always {
      //  this fires every minute
      schedule notification event "heartbeat" repeat "1  *  * * * *"
        attributes event:attrs()
    }
  }

  rule stop_heartbeat {
    select when heartbeat stop_all
    foreach schedule:list() setting (heartbeat_schedule)
    pre { 
    }
    schedule:remove(heartbeat_schedule["id"])
  }

  rule heartbeat {
    select when notification heartbeat
    pre {
    }
    fired {
      raise flower event "monitor_jobs"
        attributes event:attrs();
    }
  }

  rule monitor_jobs {
    select when store monitor_jobs
    pre {
       peer_eci = get_peer()
    }
    
    always {
    }
  }


  rule collect_new_jobs_report {
    select when store collect_jobs_report
    pre {
      jobs = events:attr("jobs")
    }
    always {
      ent:jobs_directory := jobs
    }
  }







  rule add_new_delivery_job {
    select when flower new_delivery_job
    pre {
       peer_eci = get_peer()


      origin_sequence_number = ent:origin_sequence_number.defaultsTo(-1)
      origin_sequence_number = (origin_sequence_number.typeof() == "Number") => origin_sequence_number | origin_sequence_number.as("Number")
      origin_sequence_number = origin_sequence_number + 1
      origin_id = meta:picoId
      job_id = origin_id + ":" + origin_sequence_number.as("String")



      //  TODO: Probably need more job detail here!!
      pickup_x = event:attr("pickup_x").as("Number")
      pickup_y = event:attr("pickup_y").as("Number")
      dropoff_x = event:attr("dropoff_x").as("Number")
      dropoff_y = event:attr("dropoff_y").as("Number")
      min_mpg = event:attr("min_mpg").as("Number")
      min_experience = event:attr("min_experience").as("Number")

      max_distance = event:attr("max_distance").as("Number")
      delivery_time = event:attr("delivery_time").as("Number")

      timestamp_now = time:strftime(time:now(), "%s").as("Number")
      job = {"pickup_x":pickup_x, "pickup_y":pickup_y, "dropoff_x":dropoff_x, "dropoff_y":dropoff_y, "min_mpg":min_mpg, "min_experience":min_experience, "max_distance":max_distance, "delivery_time":delivery_time, "delivery" : {"status":"available", "driver_id":"", "driver_x":"", "driver_y":""}, "last_update_timestamp":timestamp_now}
      last_seq_seen = {"driver_id":job["delivery"]["driver_id"], "last_update_timestamp":job["last_update_timestamp"] , "driver_x":job["delivery"]["driver_x"], "driver_y":job["delivery"]["driver_y"]}    
}
    

    //send_directive("stored_jobs") with jobs = ent:job_directory number = ent:origin_sequence_number last_seq = ent:last_seq_seen
    event:send(
      { "eci": peer_eci, "eid": "message_passed",
      "domain": "flower", "type": "new_delivery_job",
      "attrs": event:attrs() } )
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
}
