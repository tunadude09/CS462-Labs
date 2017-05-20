ruleset io.picolabs.use_edmund_api {
  meta {
    use module io.picolabs.edmund_keys

    configure using account_sid = keys:edmund("account_sid")
    provides decode_vin
  }




  global {
    decode_vin = defaction(vin, account_sid_2) {

       base_url = https://api.edmunds.com/api/vehicle/v2/vins/" + vin + "?fmt=json&api_key=" + account_sid_2

       http:get(base_url)
            with parseJSON = true


    }
  }







  rule test_decode_vin {
    select when test new_message
    pre {
      auth_key = keys:edmund("account_sid")
      vin = event:attr("vin")
      resp = decode_vin(vin, auth_key)
    }





    send_directive("vin_info") with body = resp authssid = auth_key vin_info_stuff = vin final_url = "https://api.edmunds.com/v1/api/toolsrepository/vindecoder?vin=#{vin}&fmt=json&api_key=#{account_sid_2}"
  }
}

