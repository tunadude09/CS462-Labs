ruleset io.picolabs.use_edmund_api {
  meta {
    use module io.picolabs.edmund_keys

    configure using account_sid = keys:edmund("account_sid")
    provides decode_vin
  }


  global {
    decode_vin = defaction(vin) {

       base_url = "https://api.edmunds.com/api/vehicle/v2/vins/" + vin + "?fmt=json&api_key=" + keys:edmund("account_sid")

       http:get(base_url)
            with parseJSON = true
    }
  }


  rule test_decode_vin {
    select when test new_message
    pre {
      //auth_key = keys:edmund("account_sid")
      vin = event:attr("vin")
      resp = decode_vin(vin)
    }

    send_directive("vin_info") with make = resp[0]["content"]["make"]["name"] model =  resp[0]["content"]["model"]["name"] year =    resp[0]["content"]["years"][0]["year"] city_mileage =     resp[0]["content"]["MPG"]["city"] highway_mileage =     resp[0]["content"]["MPG"]["highway"]
  }
}


