ruleset io.picolabs.use_edmund_api {
  meta {
    use module io.picolabs.edmund_keys
      provides decode_vin

    configure using account_sid = keys:edmund("account_sid")
      provides decode_vin
  }

  global {
    decode_vin = defaction(vin, account_sid2) {

       base_url = "https://api.edmunds.com/v1/api/toolsrepository/vindecoder?vin=#{vin}&fmt=json&api_key=#{account_sid2}"

https://api.edmunds.com/v1/api/toolsrepository/vindecoder?vin=4T1BD1FKXCU056404&fmt=json&api_key=dvrzxsvabzehwqcyg8rta9pk

       http:get(base_url)
            with parseJSON = true


    }
  }




  rule test_decode_vin {
    select when test new_message
    pre {
      resp = decode_vin(event:attr("vin"), account_sid)
      vin = event:attr("vin")
    }
    
    send_directive("vin_info") with body = resp authssid = account_sid vin_info_stuff = event:attr("vin") final_url = "https://api.edmunds.com/v1/api/toolsrepository/vindecoder?vin=#{vin}&fmt=json&api_key=#{account_sid2}"
  }
}

