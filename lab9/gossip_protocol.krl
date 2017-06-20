ruleset gossip_protocol {
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
      messages = ent:stored_messages.defaultsTo({});
      index = random:integer(0, messages.length() - 1);
      message_id = messages.keys()[index];
      message = messages[message_id];
      message = message.put("Message_ID", message_id);
      message.defaultsTo({});
    }

    prepare_message = function (message_type_int) {
      (message_type_int == 0) => get_seen_body() | get_random_message_body();
    }

    update = function () {
      "test"
    }

    get_stored_message_keys = function() {
      //other_seen_body = {"3hdieh3dkwwww":"2","2erwer555yt6":"2","2erw3333er555yt6":"2","333r333r333r3":"1"};
      message_ids = ent:stored_messages.keys();
      message_keys_info = message_ids.map(function(x) {{"message_id" : x, "origin_id" : x.split(re#:#)[0], "number" : x.split(re#:#)[1]}});
      message_keys_info;
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


  rule start_heartbeat {
    select when heartbeat start
    pre {
      //  TODO: I need to only delete schedules on the current pico
      existing_schedule_for_pico = schedule:list().filter(function(x) {x["event"]["eci"] == meta:eci})
      id_to_delete = (existing_schedule_for_pico.length() > 0) => existing_schedule_for_pico[0]["id"] | -1
      //id_to_delete = schedule:list()[0]["id"]
      //deleted = (id_to_delete != -1) => schedule:remove(id_to_delete) | "nothing_to_delete"
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
      //  update()  //  TODO:  finish update
    }
    //send_directive("heartbeat") with message = message type = message_type subscriber = subscriber;
    event:send(
      { "eci": subscriber, "eid": "message_passed",
      "domain": "chat", "type": "new_message",
      "attrs": { "message_type": message_type, "body": message, "sender_eci" : meta:eci } } )
      
    
  }











                  






  rule add_peer {
    select when chat add_peer
    pre {
      other_eci = event:attr("other_eci") 
    }
    //event:send(
    //{ "eci": meta:eci, "eid": "subscription",
    //  "domain": "wrangler", "type": "subscription",
    //  "attrs": { "name": "fleet_vehicle",
    //             "name_space": "fleet",
    //             "my_role": "fleet_controller",
    //             "subscriber_role": "fleet_member",
    //             "channel_type": "subscription",
    //             "subscriber_eci": child_eci } } )

    always { 
      //  TODO:  probably want this as a sent event so it can pass from engine to engine
      raise wrangler event "subscription"
        with name = vehicle_id
          name_space = "chat_relationships"
          my_role = "pico_1"
          subscriber_role = "pico_2"
          channel_type = "subscription"
          subscriber_eci = other_eci      
    }    
  }

  rule on_switch_test {
    select when chat new_message
    if ent:net_status.defaultsTo("on") == "on" then 
      noop()
    fired {
      raise chat event "new_message_sub"
        attributes event:attrs()
    }
  }

  rule on_switch_test_origin {
    select when chat new_origin_message
    if ent:net_status.defaultsTo("on") == "on" then 
      noop()
    fired {
      raise chat event "new_origin_message_sub"
        attributes event:attrs()
    }
  }


  rule new_seen_message {
    select when chat new_message_sub where message_type == "seen"
    pre {
      sender_eci = event:attr("sender_eci")

      other_seen_body = event:attr("body")
      other_seen_body = (other_seen_body.typeof() == "String") => other_seen_body.decode() | other_seen_body
      local_seen_body = get_seen_body()
      known_origin_ids = local_seen_body.keys()

      message_keys_info = get_stored_message_keys()
      //  if other seen doesn't have the oid or the local messagge number is greater than other's, add
      message_keys_info_tba = message_keys_info.filter(function(x) {other_seen_body[x["origin_id"]].isnull() || x["number"] > other_seen_body[x["origin_id"]]});
      message_ids_to_be_added = message_keys_info_tba.map(function(x) {x["message_id"]});
      
      passed_attributes = {}
      passed_attributes = passed_attributes.put("sender_eci", sender_eci)
      passed_attributes = passed_attributes.put("message_ids_tba", message_ids_to_be_added)
     }

    send_directive("seen_message") with ids = passed_attributes local = local_seen_body other = other_seen_body
    fired {
      raise chat event "missing_seen_messages"
          attributes passed_attributes;  
    }
  }



  rule seen_message_response {
    select when chat missing_seen_messages
    foreach event:attr("message_ids_tba") setting (missing_message_id)
    pre {
      sender_eci = event:attr("sender_eci")
      message = ent:stored_messages[missing_message_id];
      message = message.put("Message_ID", missing_message_id);
    }
    //send_directive("misssing_message") with message = message;
    event:send(
      { "eci": sender_eci, "eid": "message_passed",
      "domain": "chat", "type": "new_message",
      "attrs": { "message_type": "rumor", "body": message } } )
    
  }



  rule new_rumor_message {
    select when chat new_message_sub where message_type == "rumor"
    pre {
      rumor_body = event:attr("body")
      //  TODO:  this seems to struggle receiving JSON??
      rumor_body = (rumor_body.typeof() == "String") => rumor_body.decode() | rumor_body
      message_id = rumor_body["Message_ID"].klog(rumor_body)
      message_id_array = message_id.split(re#:#)
      origin_id = message_id_array[0]
      origin_sequence_number = message_id_array[1]

      //  keep largest seq number for last_seq_seen map
      last_seq_num = ent:last_seq_seen[origin_id].defaultsTo(-1).klog(meta:eci);
      last_seq_num = (last_seq_num > origin_sequence_number) => last_seq_num | origin_sequence_number

      originator = rumor_body["Originator"]
      text = rumor_body["Text"]
      message = {"Originator" : originator, "Text" : text}
    }
    //  {"Message_ID" : "3hdieh3dkwwww:1" , "Originator" : "Bob", "Text" : "thisistext"}
    
    send_directive("TEEST RUMOR") with rumor = rumor_body
    //send_directive("stored_messages") with messages = ent:stored_messages.defaultsTo({}) number = ent:origin_sequence_number.defaultsTo(-1) last_seq = ent:last_seq_seen.defaultsTo({})
    always {
      ent:stored_messages := ent:stored_messages.defaultsTo({}).put([message_id], message).klog();

      //  save last seen as new messages are added
      ent:last_seq_seen := ent:last_seq_seen.defaultsTo({});
      ent:last_seq_seen := ent:last_seq_seen.put([origin_id], last_seq_num);
    }
  }


  rule add_new_chat_message {
    select when chat new_origin_message_sub
    pre {
      origin_sequence_number = ent:origin_sequence_number.defaultsTo(-1)
      origin_sequence_number = (origin_sequence_number.typeof() == "Number") => origin_sequence_number | origin_sequence_number.as("Number")
      origin_sequence_number = origin_sequence_number + 1
      origin_id = meta:picoId
      message_id = origin_id + ":" + origin_sequence_number.as("String")

      //  keep largest seq number for last_seq_seen map
      last_seq_num = ent:last_seq_seen[origin_id].defaultsTo(-1)
      last_seq_num = (last_seq_num > origin_sequence_number) => last_seq_num | origin_sequence_number

      originator = event:attr("Originator")
      text = event:attr("Text")
      message = {"Originator" : originator, "Text" : text}
    }
    

    send_directive("stored_messages") with messages = ent:stored_messages number = ent:origin_sequence_number last_seq = ent:last_seq_seen
    always {
      ent:stored_messages := ent:stored_messages.defaultsTo({}).put([message_id], message);
      ent:origin_sequence_number := origin_sequence_number;

      //  save last seen as new messages are added
      ent:last_seq_seen := ent:last_seq_seen.defaultsTo({});
      ent:last_seq_seen := ent:last_seq_seen.put([origin_id], last_seq_num);
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
    select when chat get_messages
    pre {

    }
    send_directive("stored_chat") with stored_messages = ent:stored_messages.defaultsTo({}) last_seen = ent:last_seq_seen.defaultsTo({})
  }

  rule turn_network_on {
    select when process on
    always {
      ent:net_status := "on"
    }
  }


  rule turn_network_off {
    select when process off
    always {
      ent:net_status := "off"
    }
  }

  rule reset_messages {
    select when chat reset_messages
    pre {
    }
    always {
      ent:net_status := "on";
      ent:stored_messages := {};
      ent:origin_sequence_number := -1;
      ent:last_seq_seen := {};
    }
  }
}
