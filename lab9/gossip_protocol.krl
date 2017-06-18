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
      subscriptions[subscriptions.keys()[index]]["eci"]
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

    prepare_message = function (message_type) {
      //message_type = random:Integer(0,1);
      body = (message_type == 0) => get_seen_body() | get_random_message_body();
      body;
    }

    update = function () {
      "test"
    }

    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
  }

  rule stuff {
    select when stuff stuff
    pre {
      stuff = get_peer()
      num_is_bigger_than_null =  null > 10
    }
    send_directive("stuff") with stuff = stuff results = num_is_bigger_than_null
  }


  rule start_heartbeat {
    select when heartbeat start
    pre {
      //  TODO:  I'll need to allow the heartbeat to be reset later
      //         I'll prob use schedule:list() and schedule:remove(id) to find and remove old
      //         schedules so I can do a clean reset
    }
    fired {
      //  TODO:  update for re-occuring event, I'll do 1 shot for easy debug for now
      schedule notification event "heartbeat" at time:add(time:now(), {"minutes": 1})
        attributes event:attrs()
    }
  }


  rule heartbeat {
    select when notification heartbeat
    pre {
      subscriber = get_peer();
      message_type_int = random:Integer(0,1);
      message = prepare_message(message_type_int);
      message_type = (message_type_int == 0) => "seen" | "rumor"; 
      //  update()  //  TODO:  finish update
    }
    //send_directive("heartbeat")
    fired {
      event:send(
        { "eci": subscriber, "eid": "message_passed",
        "domain": "chat", "type": "new_message",
        "attrs": { "message_type": message_type, "body": message, "sender_eci" : meta:eci } } );
      
    }
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
      raise wrangler event "subscription"
        with name = vehicle_id
          name_space = "chat_relationships"
          my_role = "pico_1"
          subscriber_role = "pico_2"
          channel_type = "subscription"
          subscriber_eci = other_eci      
    }    


  }


















  rule new_seen_message {
    select when chat new_message where message_type == "seen"
    pre {
      other_seen_body = event:attr("Body")
      local_seen_body = get_seen_body()
      known_origin_ids = local_seen_body.keys()

      incomplete_origin_ids_in_other = known_origin_ids.filter(function(x) { other_seen_body[x] >= local_seen_body[x] => false | true })
      
     }
     //  TODO:  I have no idea how to do this.... leave for a lot later!!



    send_directive("new_seen_message TODO: NEEDS WORK!!!")
    always {
    }
  }



  rule new_rumor_message {
    select when chat new_message where message_type == "rumor"
    pre {
      rumor_body = event:attr("Body")
      message_id = rumor_body["Message_ID"]
      message_id_array = message_id.split(re#:#)
      origin_id = message_id_array[0]
      origin_sequence_number = message_id_array[1]

      //  keep largest seq number for last_seq_seen map
      last_seq_num = ent:last_seq_seen[origin_id].defaultsTo(-1)
      last_seq_num = (last_seq_num > origin_sequence_number) => last_seq_num | origin_sequence_number

      originator = rumor_body["Originator"]
      text = rumor_body["Text"]
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


  rule add_new_chat_message {
    select when chat new_origin_message
    pre {
      origin_sequence_number = ent:origin_sequence_number.defaultsTo(-1) + 1
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



  rule reset_messages {
    select when chat reset_messages
    pre {
    }
    always {
      ent:stored_messages := {};
      ent:origin_sequence_number := -1;
      ent:last_seq_seen := {};
    }
  }
}
