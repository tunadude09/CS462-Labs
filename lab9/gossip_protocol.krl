ruleset gossip_protocol {
  meta {
    use module Subscriptions

    shares __testing
  }
  global {

    get_seen_message = function() {
      seen_messages = ent:stored_messages.keys();
      seen_messages.map
    }


    get_peer = function () {
      //  TODO:  this is only random as a test, fix
      subscriptions = Subscriptions:getSubscriptions();
      index = random:integer(0, subscriptions.length() - 1);
      subscriptions[subscriptions.keys()[index]]["eci"]
    }


    prepare_message = function () {
      "test"
    }


    update = function () {
      "test"
    }


    send = function () {
      "test"
    }



    __testing = { "queries": [ { "name": "__testing" } ],
                  "events": [ ] }
  }

  rule stuff {
    select when stuff stuff
    pre {
      stuff = get_peer()
    }
    send_directive("stuff") with stuff = stuff
  }

  rule start_heartbeat {
    select when heartbeat start
    pre {
      //  TODO:  I'll need to allow the heartbeat to be reset later
      //         I'll prob use schedule:list() and schedule:remove(id) to find and remove old
      //         schedules so I can do a clean reset
    }
    fired {
      //  TODO:  update for reocuring event, I'll do 1 shot for easy debug for now
      schedule notification event "heartbeat" at time:add(time:now(), {"minutes": 1})
        attributes event:attrs()
    }
  }


  rule heartbeat {
    select when notification heartbeat
    pre {
      


    }
    //  TODO:  fill in heartbeat
    send_directive("heartbeat")
  }


  //  TODO:  add rule new_rumor_message {}

  rule add_new_chat_message {
    select when chat new_origin_message
    pre {
      origin_sequence_number = ent:origin_sequence_number.defaultsTo(-1) + 1
      origin_id = meta:picoId
      message_id = origin_id + ":" + origin_sequence_number.as("String")

      last_seq_num = ent:last_seq_seen[message_id].defaultsTo(-1)


      originator = event:attr("Originator")
      text = event:attr("Text")
      message = {"Originator" : originator, "Text" : text}
    }
    last_seq_num = last_seq_num > origin_sequence_number => last_seq_num | origin_sequence_number

    //send_directive("stored_messages") with messages = ent:stored_messages and number = ent:origin_sequence_numbe
    always {
      ent:stored_messages := ent:stored_messages.defaultsTo({}).put([message_id], message);
      ent:origin_sequence_number := origin_sequence_number;

      //  save last seen as new messages are added
      ent:last_seq_seen := ent:last_seq_seen.put([message_id], last_seq_num);
    }
  }

  rule reset_messages {
    select when chat reset_messages
    pre {
    }
    always {
      ent:stored_messages := {};
      ent:origin_sequence_number := -1
    }
  }
}
