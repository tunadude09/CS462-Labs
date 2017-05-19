ruleset io.picolabs.use_edmund_api {
  meta {
    use module io.picolabs.edmund_keys
  	provides decode_vin
  }

  global {
    decode_vin = defaction(vin) {

       base_url = "https://www.google.com"

       http:get(base_url)
            with parseJSON = true


    }
  }




  rule test_decode_vin {
    select when test new_message
    pre {
  		resp = decode_vin(event:attr("vin"))
    }
    send_directive("vin_info") with body = resp
  }
}

