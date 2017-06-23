ruleset flower_delivery_network_vehicle {
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

    get_seen_body = function() {
      ent:last_seq_seen.defaultsTo({});
    }
    
    get_random_message_body = function() {
      messages = ent:job_directory.defaultsTo({});
      index = random:integer(0, messages.length() - 1);
      message_id = messages.keys()[index];
      message = messages[message_id];
      message = message.put("job_id", message_id);
      message.defaultsTo({});
    }

    prepare_message = function (message_type_int) {
      message = (message_type_int == 0) => get_seen_body() | get_random_message_body();
      (message.isnull() || message == {}) => "" | message
    }

    get_stored_job_keys = function() {
      //other_seen_body = {"3hdieh3dkwwww":"2","2erwer555yt6":"2","2erw3333er555yt6":"2","333r333r333r3":"1"};
      //  TODO:  make sure I have provided all the info necessary to choose seen messages easily
      jobs = ent:job_directory;
      job_keys_info = jobs.map(function(v, k) {{"job_id" : k, "origin_id" : k.split(re#:#)[0], "number" : k.split(re#:#)[1], "driver_id": v["delivery"]["driver_id"], "last_update_timestamp":v["last_update_timestamp"], "driver_x":v["delivery"]["driver_x"], "driver_y":v["delivery"]["driver_y"], "pickup_x":v["pickup_x"], "pickup_y":v["pickup_y"]}});
     job_keys_info;
    }

    get_distance = function(x1, y1, x2, y2){
      //  this is currently the manhatten distance
      //math:sqrt(math:power(x1.as("Number") - x2.as("Number"),2) + math:power(y1.as("Number") - y2.as("Number"),2))
      part_1 = x1-x2;
      part_2 = y1-y2;
      part_1 = (part_1 >= 0) => part_1 | -1 * part_1;
      part_2 = (part_2 >= 0) => part_2 | -1 * part_2;
      part_1 + part_2;
    }
 
    get_profile = function() {
      profile = {};
      profile = profile.put("driver_id", ent:profile_driver_id.defaultsTo(meta:eci));
      profile = profile.put("current_x", ent:profile_current_x.defaultsTo(-1));
      profile = profile.put("current_y", ent:profile_current_y.defaultsTo(-1));
      profile = profile.put("mpg", ent:profile_mpg.defaultsTo(-1));
      profile = profile.put("experience", ent:profile_experience.defaultsTo(-1));
      profile = profile.put("job", ent:profile_job.defaultsTo(-1));
      profile;
    }

    assigned_job = function() {
      currently_assigned_job = ((not ent:profile_job.isnull()) && (ent:profile_job != -1)) => true | false;
      job_still_assigned = (ent:job_directory[ent:profile_job]["delivery"]["driver_id"] == ent:profile_driver_id) => true | false;
      (currently_assigned_job && job_still_assigned) => true | false
    }

    calc_finish_timestamp = function() {
      //  TODO:  fill this out later, for now every job takes 100 seconds
      //  TODO:  need a much better estimation here
      time:strftime(time:now(), "%s").as("Number") + 30
    }


    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
  }

  rule stuff {
    select when stuff stuff
    pre {
      stuff = get_stored_job_keys()
    }
    send_directive("stuff") with stuff = stuff
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
      //  this fires every second
      schedule notification event "heartbeat" repeat "*/1  *  * * * *"
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
      subscriber = get_peer();
      message_type_int = random:integer(0,1);
      message = prepare_message(message_type_int).klog(subscriber);
      message_type = (message_type_int == 0) => "seen" | "rumor"; 
    }
    //send_directive("heartbeat") with message = message type = message_type subscriber = subscriber
    event:send(
      { "eci": subscriber, "eid": "message_passed",
      "domain": "flower", "type": "new_message",
      "attrs": { "message_type": message_type, "body": message, "sender_eci" : meta:eci, "random" : true } } )      
    fired {
      raise vehicle event "manage_jobs"
        attributes event:attrs();
    }
  }

  rule pass_heartbeat_message {
    select when heartbeat ready_to_pass_messages
    pre {
      subscriber = get_peer();
      message_type_int = random:integer(0,1);
      message = prepare_message(message_type_int).klog(subscriber);
      message_type = (message_type_int == 0) => "seen" | "rumor"; 
    }
    //send_directive("heartbeat") with message = message type = message_type subscriber = subscriber;
    event:send(
      { "eci": subscriber, "eid": "message_passed",
      "domain": "flower", "type": "new_message",
      "attrs": { "message_type": message_type, "body": message, "sender_eci" : meta:eci, "random" : true } } )      
  }

   

  //  TODO:  this isn't a problem for a single pico.... it's race conditions when multiple picos are involved
  //  I think the solution is to put extra checks on incoming rumors to make sure delivered, claimed, or pickup 
  //  conditions are not needlesly quashed

  rule manage_jobs {
    select when vehicle manage_jobs
    pre {
      is_assigned_job = assigned_job()
      job_action = (is_assigned_job) => "execute_job" | "find_job"
    }
    send_directive("manage") with is=is_assigned_job action=job_action
    fired {
      raise vehicle event "manage_jobs_sub"
        with job_action = job_action
    }
  }

  rule find_job {
    select when vehicle manage_jobs_sub where job_action == "find_job"
    pre {
      jobs = ent:job_directory.filter(function(x) {x["delivery"]["status"] == "available"})
      //  TODO; probably need to add additional eligibility requirements
      eligible_jobs = jobs.filter(function(x) {x["min_experience"] <= ent:profile_experience})
      eligible_jobs = jobs.filter(function(x) {x["min_mpg"] <= ent:profile_mpg})
      eligible_jobs = jobs.filter(function(x) {x["max_distance"] >= get_distance(x["pickup_x"],x["pickup_y"], ent:profile_current_x, ent:profile_current_y)})

      //  TODO: could make this more intelligent in the future, maybe make it search out closest
      claimed_job_id = eligible_jobs.keys()[0]
      updated_job = ent:job_directory[claimed_job_id].defaultsTo({})
      delivery = {}
      delivery["driver_id"] = ent:profile_driver_id
      delivery["status"] = "claimed"
      delivery["driver_x"] = ent:profile_current_x
      delivery["driver_y"] = ent:profile_current_y
      updated_job["delivery"] = delivery
      updated_job["last_update_timestamp"] = time:strftime(time:now(), "%s").as("Number")
      new_directory = (claimed_job_id.isnull()) => ent:job_directory | ent:job_directory.put([claimed_job_id], updated_job)      
    }
    send_directive("find_job") with jobs=jobs eligible=eligible_jobs claimed_job=claimed_job updated_job=updated_job
    fired {
      //  this either leaves the directory the same, as no jobs were found, or it updates it
      //  with the new job claim made by this driver
      //  claimed_job_id will be null unless it found and claimed a job
      ent:job_directory := new_directory;
      ent:profile_job := claimed_job_id;

      //  raise this after the local jobs database has been updated
      //raise heartbeat event "ready_to_pass_messages"
      //  attributes event:attrs();
    }
  }


  rule execute_job {
    select when vehicle manage_jobs_sub where job_action == "execute_job"
    pre {
      finish_timestamp = (ent:profile_finish_timestamp.defaultsTo(-1) == -1) => calc_finish_timestamp() | ent:profile_finish_timestamp
        
      //  TODO:  more advanced simulation required
      //  simulation_results = simulate_time_step()
      current_timestamp = time:strftime(time:now(), "%s").as("Number")       
      sim_finished = (current_timestamp >= finish_timestamp) => true | false
      //  if sim has finished all these things will be changed
      new_experience = (sim_finished) => ent:profile_experience + 1 | ent:profile_experience
      new_job = (sim_finished) => -1 | ent:profile_job
      //  then update job directory
      finished_job = ent:job_directory[ent:profile_job].defaultsTo({})
      delivery = {}
      delivery["driver_id"] = -2  //  I'm just changing the values so that these will always win over others and never be replaced
      delivery["status"] = "delivered"
      delivery["driver_x"] = finished_job["pickup_x"]
      delivery["driver_y"] = finished_job["pickup_y"]
      finished_job["delivery"] = delivery
      finished_job["last_update_timestamp"] = time:strftime(time:now(), "%s").as("Number")
      new_job = (sim_finished) => finished_job | ent:job_directory[ent:profile_job]
      new_job_id = (sim_finished) => -1 | ent:profile_job

      new_finish_timestamp = (sim_finished) => -1 | finish_timestamp
    }
    send_directive("execute_job") with sim_finished=sim_finished finish_t=finish_timestamp finished_job=finished_job 

    fired {
      //  updates these if the sim is finished, they left alone if unfinished
      ent:job_directory := ent:job_directory.put([ent:profile_job], new_job);
      ent:profile_experience := new_experience;
      ent:profile_job := new_job_id;
      ent:profile_finish_timestamp := new_finish_timestamp;

      //  raise this after the local jobs database has been updated
      //raise heartbeat event "ready_to_pass_messages"
      //  attributes event:attrs();
    }
  }






  rule update_vehicle_profile {
    select when vehicle update_profile
    pre {
      driver_id = ent:profile_driver_id.defaultsTo(meta:eci)
      current_x = event:attr("current_x")
      current_x = (current_x.isnull()) => ent:profile_current_x | current_x
      current_y = event:attr("current_y")
      current_y = (current_y.isnull()) => ent:profile_current_y | current_y
      mpg = event:attr("mpg")
      mpg = (mpg.isnull()) => ent:profile_mpg | mpg
      experience = event:attr("experience")
      experience = (experience.isnull()) => ent:profile_experience | experience
      job = event:attr("job")
      job = (job.isnull()) => ent:profile_job | job
    }
    always {
      ent:profile_driver_id := driver_id;
      ent:profile_current_x := current_x;
      ent:profile_current_y := current_y;
      ent:profile_mpg := mpg;
      ent:profile_experience := experience;
      ent:profile_job := job;
    }
  }


  rule get_vehicle_profile {
    select when vehicle get_profile
    pre {
      profile = get_profile()
    }
    send_directive("vehicle_profile") with profile = profile
  }



         
  rule add_peer {
    select when flower add_peer
    pre {
      other_eci = event:attr("other_eci") 
    }
    always { 
      //  TODO:  probably want this as a sent event so it can pass from engine to engine
      raise wrangler event "subscription"
        with name = vehicle_id
          name_space = "flower_relationships"
          my_role = "pico_1"
          subscriber_role = "pico_2"
          channel_type = "subscription"
          subscriber_eci = other_eci
    }    
  }


  rule new_seen_message {
    select when flower new_message where message_type == "seen"
    pre {
      sender_eci = event:attr("sender_eci")

      other_seen_body = event:attr("body")
      other_seen_body = (other_seen_body.typeof() == "String") => other_seen_body.decode() | other_seen_body
      local_seen_body = get_seen_body()

      //  TODO:  this will probably need to be altered and debugged further
      // {"job_id" :, "origin_id" : , "number" : , "driver_id": , "last_update_timestamp":, "driver_x":, "driver_y":, "pickup_x/y"}
      job_keys_info = get_stored_job_keys()
        
      /*
        if any of these is true, the job_id should be added
        if other's job_id doesn't exist, add
        elif driver_id is missing from other and local has driver_id , add
        elif both driver_ids are equal and exist and local timestamp is greater, then add
        elif local is closer, then add
        elif both are same distance, but local has lower driver_id, then add

        use nested () => true | false to create elif
      */

      //  I'm comparing 2 seperate objects... a seen dictionary and job keys above
      other_job_not_completed_boolean_filter = job_keys_info.map(function(x) {((other_seen_body[x["job_id"]]["delivery"]["status"] == "delivered") || (other_seen_body[x["job_id"]]["delivery"]["status"] == "picked_up")) => false | true}).values()

      missing_job_boolean_filter = job_keys_info.map(function(x) {(other_seen_body[x["job_id"]].isnull()) => true | false}).values()
      driver_id_found_boolean_filter = job_keys_info.map(function(x) {( ((other_seen_body[x["job_id"]]["driver_id"].isnull() || other_seen_body[x["job_id"]]["driver_id"] == "")    && ((not x["job_id"]["driver_id"].isnull()) && (x["job_id"]["driver_id"] != ""))) ) => true | false}).values()
      newer_driver_update_found_boolean_filter = job_keys_info.map(function(x) {( (other_seen_body[x["job_id"]]["driver_id"] == x["driver_id"])    && (other_seen_body[x["job_id"]]["last_update_timestamp"] < x["last_update_timestamp"]) ) => true | false}).values()
      local_is_closer_filter = job_keys_info.map(function(x) {(get_distance(x["driver_x"], x["driver_y"], x["pickup_x"], x["pickup_y"]) < get_distance(other_seen_body[x["job_id"]]["driver_x"], other_seen_body[x["job_id"]]["driver_y"], x["pickup_x"], x["pickup_y"])) => true | false}).values()
      driver_id_is_smaller_filter = job_keys_info.map(function(x) { (x["driver_id"] < other_seen_body[x["job_id"]]["driver_id"]) => true | false }).values()
      indexes = 0.range(missing_job_boolean_filter.length() - 1)
      

      //local_distance = math:power(3,2)
      //local_distance = math:sqrt(math:power(x["driver_x"].as("Number") - x["pickup_x"].as("Number"),2) + math:power(x["driver_y"].as("Number") - x["pickup_y"].as("Number"),2))
      //temp_temp = job_keys_info.map(function(x) {get_distance(x["driver_x"], x["driver_y"], x["pickup_x"], x["pickup_y"])})

      //  use range to generate a range of values then map out these values to combine the two lists
      missing_job_ids_filter_1 = indexes.map(function(i) {(missing_job_boolean_filter[i] || ((not missing_job_boolean_filter[i]) && driver_id_found_boolean_filter[i])) => true | false})
      missing_job_ids_filter_2 = indexes.map(function(i) {(missing_job_ids_filter_1[i] || ((not missing_job_ids_filter_1[i]) && newer_driver_update_found_boolean_filter[i])) => true | false})
      missing_job_ids_filter_3 = indexes.map(function(i) {(missing_job_ids_filter_2[i] || ((not missing_job_ids_filter_2[i]) && local_is_closer_filter[i])) => true | false})
      missing_job_ids_filter_4 = indexes.map(function(i) {(missing_job_ids_filter_3[i] || ((not missing_job_ids_filter_3[i]) && driver_id_is_smaller_filter[i])) => true | false})
      missing_job_ids_filter_5 = indexes.map(function(i) {(missing_job_ids_filter_4[i] && other_job_not_completed_boolean_filter[i]) => true | false})
      
      missing_job_ids_filter = missing_job_ids_filter_5

      job_keys_ids = job_keys_info.keys()
      missing_job_ids_pre = indexes.map(function(i) {(missing_job_ids_filter[i]) => job_keys_ids[i] | -1})
      missing_job_ids_to_be_added = missing_job_ids_pre.filter(function(x) {x != -1})

      passed_attributes = {}
      passed_attributes = passed_attributes.put("sender_eci", sender_eci)
      passed_attributes = passed_attributes.put("job_ids_tba", missing_job_ids_to_be_added)
    }
    //send_directive("seen_message") with passed_attrs = passed_attributes local = local_seen_body other = other_seen_body first=missing_job_boolean_filter  second=driver_id_found_boolean_filter third=newer_driver_update_found_boolean_filter fourth=local_is_closer_filter  fifth=driver_id_is_smaller_filter missing1=missing_job_ids_filter_1  missing2=missing_job_ids_filter_2  missing3=missing_job_ids_filter_3 missing4=missing_job_ids_filter_4
    fired {
      raise flower event "missing_seen_messages"
          attributes passed_attributes;  
    }
  }


  rule seen_message_response {
    select when flower missing_seen_messages
    foreach event:attr("job_ids_tba") setting (missing_job_id)
    pre {
      sender_eci = event:attr("sender_eci")
      message = ent:job_directory[missing_job_id];
      message = message.put("job_id", missing_job_id);
    }
    //send_directive("misssing_message") with message = message
    event:send(
      { "eci": sender_eci, "eid": "message_passed",
      "domain": "flower", "type": "new_message",
      "attrs": { "message_type": "rumor", "body": message } } )
    
  }


  rule new_rumor_message {
    select when flower new_message where message_type == "rumor"
    pre {
      rumor_body = event:attr("body")
      rumor_body = (rumor_body.typeof() == "String") => rumor_body.decode() | rumor_body
      job_id = rumor_body["job_id"].klog(rumor_body)
      job_id_array = job_id.split(re#:#)
      origin_id = job_id_array[0]
      origin_sequence_number = job_id_array[1]

      //  test job_id if random flag is set to true
      random_flag = event:attr("random")
      need_to_check_id = random_flag
      job_id_not_yet_added = (need_to_check_id && ent:job_directory.keys() >< job_id) => false | true


      //  keep largest seq number for last_seq_seen map
      //last_seq_num = ent:last_seq_seen[origin_id].defaultsTo(-1).klog(meta:eci);
      //last_seq_num = (last_seq_num > origin_sequence_number) => last_seq_num | origin_sequence_number


      pickup_x = rumor_body["pickup_x"].as("Number")
      pickup_y = rumor_body["pickup_y"].as("Number")
      dropoff_x = rumor_body["dropoff_x"].as("Number")
      dropoff_y = rumor_body["dropoff_y"].as("Number")
      min_mpg = rumor_body["min_mpg"].as("Number")
      min_experience = rumor_body["min_experience"].as("Number")
      max_distance = rumor_body["max_distance"].as("Number")
      delivery_time = rumor_body["delivery_time"].as("Number")

      status = rumor_body["delivery"]["status"]
      driver_id = rumor_body["delivery"]["driver_id"]
      driver_x = rumor_body["delivery"]["driver_x"].as("Number")
      driver_y = rumor_body["delivery"]["driver_y"].as("Number")
      last_update_timestamp = rumor_body["delivery"]["last_update_timestamp"].as("Number")


      delivery_completed = ((not ent:job_directory[job_id].isnull()) && ((ent:job_directory[job_id]["delivery"]["status"] == "picked_up") || (ent:job_directory[job_id]["delivery"]["status"] == "delivered") || ((ent:job_directory[job_id]["delivery"]["status"] == "claimed") && (status == "available"))))

      job = {"pickup_x":pickup_x, "pickup_y":pickup_y, "dropoff_x":dropoff_x, "dropoff_y":dropoff_y, "min_mpg":min_mpg, "min_experience":min_experience, "max_distance":max_distance, "delivery_time":delivery_time, "delivery" : {"status":status, "driver_id":driver_id, "driver_x":driver_x, "driver_y":driver_y}, "last_update_timestamp":last_update_timestamp}
      last_seq_seen = {"driver_id":job["delivery"]["driver_id"], "last_update_timestamp":job["last_update_timestamp"] , "driver_x":job["delivery"]["driver_x"], "driver_y":job["delivery"]["driver_y"]}
    }
    
    
    //send_directive("stored_messages") with messages = ent:job_directory.defaultsTo({}) number = ent:origin_sequence_number.defaultsTo(-1) last_seq = ent:last_seq_seen.defaultsTo({})
    //  only add random if job_id not found, otherwise add all non-random regardless as it's already been vetted
    //if job_id_not_yet_added && (not delivery_completed) then
    if job_id_not_yet_added then

      send_directive("TEEST RUMOR") with rumor = rumor_body
    fired {
      ent:job_directory := ent:job_directory.defaultsTo({}).put([job_id], job).klog();

      //  save last seen as new messages are added
      ent:last_seq_seen := ent:last_seq_seen.defaultsTo({});
      ent:last_seq_seen := ent:last_seq_seen.put([job_id], last_seq_seen);
    }
  }



  rule add_new_delivery_job {
    select when flower new_delivery_job
    pre {
      origin_sequence_number = ent:origin_sequence_number.defaultsTo(-1)
      origin_sequence_number = (origin_sequence_number.typeof() == "Number") => origin_sequence_number | origin_sequence_number.as("Number")
      origin_sequence_number = origin_sequence_number + 1
      origin_id = meta:picoId
      job_id = origin_id + ":" + origin_sequence_number.as("String")

      //  keep largest seq number for last_seq_seen map
      //last_seq_num = ent:last_seq_seen[origin_id].defaultsTo(-1)
      //last_seq_num = (last_seq_num > origin_sequence_number) => last_seq_num | origin_sequence_number



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
    

    send_directive("stored_jobs") with jobs = ent:job_directory number = ent:origin_sequence_number last_seq = ent:last_seq_seen
    always {
      ent:job_directory := ent:job_directory.defaultsTo({}).put([job_id], job);
      ent:origin_sequence_number := origin_sequence_number;

      //  save last seen as new job are added
      ent:last_seq_seen := ent:last_seq_seen.defaultsTo({});
      ent:last_seq_seen := ent:last_seq_seen.put([job_id], last_seq_seen);
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

  rule get_messages {
    select when flower get_jobs
    pre {

    }
    send_directive("stored_jobs") with stored_messages = ent:job_directory.defaultsTo({}) last_seen = ent:last_seq_seen.defaultsTo({})
  }

  rule reset_messages {
    select when flower reset_jobs
    pre {
    }
    always {
      ent:job_directory := {};
      ent:origin_sequence_number := -1;
      ent:last_seq_seen := {};
    }
  }
}
