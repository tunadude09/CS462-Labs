ruleset io.picolabs.use_edmund_api {
  meta {
    use module io.picolabs.edmund_keys
      provides decode_vin

    configure using account_sid = keys:edmund_keys("account_sid")
      provides decode_vin
  }

  global {
    decode_vin = defaction(vin) {

       base_url = "https://api.edmunds.com/v1/api/toolsrepository/vindecoder?vin=#{vin}&fmt=json&api_key=#{account_sid}"



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

