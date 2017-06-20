ruleset flower_delivery_network_store {
  meta {
    use module Subscriptions

    shares __testing
  }
  global {
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
