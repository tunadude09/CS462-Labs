ruleset timing_tracker {
  meta {
    shares entries
  }
  global {
    entries = function() {
      ent:timings.defaultsTo([])
    }
  }
  rule timing_started {
    select when timing started number re#(n0*\d+)#i setting(number)
    pre {
      name = event:attr("name")
      ordinal = number.extract(re#n0*(\d+)#i)[0].as("Number")
      time_out = time:now()
      exists = ent:timings.defaultsTo([])
                          .filter(function(v){v{"ordinal"} == ordinal})
    }
    if exists.length() == 0 then noop()
    fired {
      ent:timings := ent:timings.defaultsTo([]).append({
        "ordinal": ordinal,
        "number": number,
        "name": name,
        "time_out": time_out })
    }
  }
  rule timing_finished {
    select when timing finished number re#n0*(\d+)#i setting(ordinal_string)
    foreach ent:timings setting(v,k)
      pre {
        ordinal = ordinal_string.as("Number")
        this_one = ordinal == v{"ordinal"}
      }
      if this_one then noop()
      fired {
        ent:timings{[k,"time_in"]} := time:now()
      }
  }
}
