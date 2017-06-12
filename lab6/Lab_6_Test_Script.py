
# coding: utf-8

# In[59]:

import numpy as np
import json
import urllib2
import time


# Write a script or test harness to test your set up. Ensure your test harness tests the rules and functions you defined by:
# 1)  creating vehicles and deleting at least one vehicle. 
# 2)  tests the vehicles by sending them trips. Use the trips and long_trips functions to ensure they are working. You may want to script something with curl to send vehicles a number of random trips for testing purposes. You'll need a variety of trips in the vehicles for the next two parts. 
# 3)  tests the vehicle profile to ensure it's getting set reliably.

# In[123]:

#  parameters
base_url = "http://localhost:8080/sky/event/"
eci = "cj3s12aii0002d9g5gwaymev8"


# In[124]:

check_cars = base_url + eci + "/getv/car/get_vehicles"
is_empty = urllib2.urlopen(check_cars).read()
#  TODO: check if it's empty
if json.loads(is_empty)['directives'][0]['options']['vehicles'] == {}:
    print("PASSED: empty")
else: print("FAILED: not empty")


# In[131]:

check_cars = base_url + eci + "/getv/car/get_vehicles"
is_empty = urllib2.urlopen(check_cars).read()
#  TODO: check if it's empty
if json.loads(is_empty)['directives'][0]['options']['vehicles'] == {}:
    print("PASSED: empty")
else: print("FAILED: not empty")
    

add_car = base_url + eci + "/addingnewv/car/new_vehicle?vehicle_id=111&vin=5111"
urllib2.urlopen(add_car).read()
time.sleep(0.3)
is_car_added = urllib2.urlopen(check_cars).read()
if json.loads(is_car_added)['directives'][0]['options']['vehicles']["111"]:
    print("PASSED: first car added")
else: print("FAILED: first car missing")


add_car_2 = base_url + eci + "/addingnewv/car/new_vehicle?vehicle_id=222&vin=5222"
add_car_3 = base_url + eci + "/addingnewv/car/new_vehicle?vehicle_id=333&vin=5333"
add_car_4 = base_url + eci + "/addingnewv/car/new_vehicle?vehicle_id=444&vin=5444"
add_car_5 = base_url + eci + "/addingnewv/car/new_vehicle?vehicle_id=555&vin=5555"
urllib2.urlopen(add_car_2).read()
urllib2.urlopen(add_car_3).read()
urllib2.urlopen(add_car_4).read()
urllib2.urlopen(add_car_5).read()
time.sleep(0.3)
how_many_cars = urllib2.urlopen(check_cars).read()
try:
    json.loads(how_many_cars)['directives'][0]['options']['vehicles']['111']
    json.loads(how_many_cars)['directives'][0]['options']['vehicles']['222']
    json.loads(how_many_cars)['directives'][0]['options']['vehicles']['333']
    json.loads(how_many_cars)['directives'][0]['options']['vehicles']['444']
    json.loads(how_many_cars)['directives'][0]['options']['vehicles']['555']
    print("PASSED: all cars added")
except KeyError:
    print("FAILED: a car was missing")


remove_car = base_url + eci + "/test/car/unneeded_vehicle?vehicle_id=111"
urllib2.urlopen(remove_car).read()
time.sleep(0.3)
is_car_removed = urllib2.urlopen(check_cars).read()
try:
    json.loads(is_car_removed)['directives'][0]['options']['vehicles']['111']
    print("FAILED: car wasn't deleted")
except KeyError:
    print("PASSED: car was deleted")


# In[108]:

child_picos_eci


# In[132]:

get_ecis = base_url + eci + "/findeci/car/get_vehicles"
child_picos_eci = urllib2.urlopen(get_ecis).read()

eci_1 = json.loads(child_picos_eci)['directives'][0]['options']['vehicles']['333']['eci']
eci_2 = json.loads(child_picos_eci)['directives'][0]['options']['vehicles']['444']['eci']


# In[133]:

#  test a single vehilce pico
#  first add 2 trips, long and short, test
#  then update profie, test

def test_child_picos(new_eci):
    child_eci = new_eci
    check_trips = base_url + child_eci + "/checktrips/car/return_ent"


    add_short_miles = base_url + child_eci + "/addshort/car/new_trip?mileage=10&vin=444"
    add_long_miles = base_url + child_eci + "/addlong/car/new_trip?mileage=200&vin=444"
    urllib2.urlopen(add_short_miles).read()
    urllib2.urlopen(add_long_miles).read()
    time.sleep(0.3)
    trips_added = urllib2.urlopen(check_trips).read()
    try:
        json.loads(trips_added)['directives'][0]['options']['trips_ent']['0']
        json.loads(trips_added)['directives'][0]['options']['trips_ent']['1']
        json.loads(trips_added)['directives'][0]['options']['long_ent']['1']
        json.loads(trips_added)['directives'][0]['options']['short_ent']['0']
        print("PASSED: all long and short trips added")
    except KeyError:
        print("FAILED: a trip was missing or incorrectly classified as long")



    update_threshold = base_url + child_eci + "/updateprofile/car/profile_updated?vin=777&long_trip_threshold=888"
    urllib2.urlopen(update_threshold).read()
    time.sleep(0.3)
    check_profile = base_url + child_eci + "/getprofile/car/profile"
    profile_updated = urllib2.urlopen(check_profile).read()
    if  json.loads(profile_updated)['directives'][0]['options']['vin'] == '777' and         json.loads(profile_updated)['directives'][0]['options']['long_trip_threshold'] == '888':
        print("PASSED: profile successfully updated")
    else:
        print("FAILED: profile not updated")


# In[134]:

test_child_picos(eci_1)
test_child_picos(eci_2)


# In[129]:

eci_1


# In[ ]:




# In[ ]:




# In[ ]:




# In[ ]:




# In[ ]:




# In[ ]:




# In[ ]:




# In[ ]:




# In[130]:

#  reset everything

remove_car_2 = base_url + eci + "/addingnewv/car/unneeded_vehicle?vehicle_id=222&vin=5222"
remove_car_3 = base_url + eci + "/addingnewv/car/unneeded_vehicle?vehicle_id=333&vin=5333"
remove_car_4 = base_url + eci + "/addingnewv/car/unneeded_vehicle?vehicle_id=444&vin=5444"
remove_car_5 = base_url + eci + "/addingnewv/car/unneeded_vehicle?vehicle_id=555&vin=5555"
urllib2.urlopen(remove_car_2).read()
urllib2.urlopen(remove_car_3).read()
urllib2.urlopen(remove_car_4).read()
urllib2.urlopen(remove_car_5).read()
how_many_cars = urllib2.urlopen(check_cars).read()
#  TODO: check if 5 cars have been added



reset_car = base_url + eci + "/test/car/vehicles_reset"
urllib2.urlopen(reset_car).read()
is_car_removed = urllib2.urlopen(check_cars).read()
#  TODO: check if only 4 cars remain





# In[110]:

is_car_removed


# In[ ]:



