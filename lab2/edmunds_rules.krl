ruleset io.picolabs.use_edmund_api {
  meta {
    use module io.picolabs.edmund_keys

    configure using account_sid = keys:edmund("account_sid")
    provides decode_vin
  }


  global {
    decode_vin = defaction(vin, account_sid_2) {

       base_url = "https://api.edmunds.com/api/vehicle/v2/vins/" + vin + "?fmt=json&api_key=" + account_sid_2

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

    send_directive("vin_info") with make = resp["content"]["make"]["name"] model =     resp["content"]["make"]["name"] year =    resp["content"]["make"]["name"] city_mileage =     resp["content"]["make"]["name"] highway_mileage =     resp["content"]["make"]["name"]
  }
}




{"directives":[{"options":
{


"body":

[{"content":{"make":{"id":200003381,"name":"Toyota","niceName":"toyota"},"model":{"id":"Toyota_Camry_Hybrid","name":"Camry Hybrid","niceName":"camry-hybrid"},"engine":{"equipmentType":"ENGINE","availability":"USED","cylinder":4,"size":2.5,"configuration":"inline","fuelType":"regular unleaded","horsepower":200,"type":"hybrid","code":"2AR-FXE","rpm":{"horsepower":5700},"valve":{"gear":"double overhead camshaft"}},"transmission":{"id":"200389867","name":"continuously variableA","equipmentType":"TRANSMISSION","availability":"STANDARD","automaticType":"Continuously variable","transmissionType":"AUTOMATIC","numberOfSpeeds":"continuously variable"},"drivenWheels":"front wheel drive","numOfDoors":"4","options":[],"colors":[{"category":"Exterior","options":[{"id":"200389845","name":"Barcelona Red Metallic","equipmentType":"COLOR","availability":"USED"}]}],"manufacturerCode":"2560","price":{"baseMSRP":27500,"baseInvoice":25300,"deliveryCharges":795,"usedTmvRetail":12525,"usedPrivateParty":10708,"usedTradeIn":8855,"estimateTmv":false,"tmvRecommendedRating":0},"categories":{"market":"Hybrid","EPAClass":"Midsize Cars","vehicleSize":"Midsize","primaryBodyType":"Car","vehicleStyle":"Sedan","vehicleType":"Car"},"vin":"4T1BD1FKXCU056404","squishVin":"4T1BD1FKCU","years":[{"id":100536569,"year":2012,"styles":[{"id":101403737,"name":"XLE 4dr Sedan (2.5L 4cyl gas/electric hybrid CVT)","submodel":{"body":"Sedan","modelName":"Camry Hybrid Sedan","niceName":"sedan"},"trim":"XLE"}]}],"matchingType":"SQUISHVIN","MPG":{"highway":"38","city":"40"}},"content_type":"application/json","content_length":1547,"headers":{"content-type":"application/json","date":"Sat, 20 May 2017 00:19:51 GMT","server":"nginx/1.8.1","x-artifact-id":"vehicle-rest-web","x-artifact-version":"1.23.14","x-mashery-responder":"prod-j-worker-us-east-1b-121.mashery.com","content-length":"1547","connection":"Close"},"status_code":200,"status_line":"OK"}]


}

,"name":"vin_info","meta":{"rid":"io.picolabs.use_edmund_api","rule_name":"test_decode_vin","txn_id":"TODO","eid":"runwithnewkey"}}]}