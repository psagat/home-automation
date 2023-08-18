#!/bin/bash
################################################################################
#Script Name	: thermostat-stats.sh
#Description	: Gets temp and humidity readings from Ecobee thermostats and 
#               logs information back to influxdb                                                                                
#Args           :                                                                                           
#Author       	: Pete Sagat                                                
#Email         	: petesagat@gmail.com                                           
################################################################################

# Thermostat data file
thermostat_data_file=/root/grafana-scripts/ecobee/thermostat_data.txt

# Get this from your Ecobee account under my apps. 
APIKEY='LvgiinTDjPjVkMZc2S4eK98FQd6D2kca'

# Filename where refreshkey needs to be stored (need to create it first time)
refresh_token=/root/grafana-scripts/ecobee/refreshkey.txt 

# Read the current refresh token from the file. This is what allows us to get a new access token. 
{
  read REFRESH 
} < $refresh_token

# Get a new access token
response=`curl -s --request POST --data "grant_type=refresh_token&code=$REFRESH&client_id=$APIKEY" "https://api.ecobee.com/token"`
TOKEN=`echo $response | grep access_token | awk -F '"' '{print $4}'`

# Get data from ecobee
curl -s -H 'Content-Type: text/json' -H 'Authorization: Bearer '$TOKEN'' 'https://api.ecobee.com/1/thermostat?format=json&body=\{"selection":\{"selectionType":"registered","selectionMatch":"","includeSensors":true\}\}' > $thermostat_data_file

# Get temp and humidity readings from data file
MainTemp=$(jq -r '.thermostatList[0].remoteSensors[2].capability[0].value | tonumber * 0.10' "$thermostat_data_file")
MainHum=$(jq -r '.thermostatList[0].remoteSensors[2].capability[1].value' "$thermostat_data_file")
MasterTemp=$(jq -r '.thermostatList[1].remoteSensors[0].capability[0].value | tonumber * 0.10' "$thermostat_data_file")
MasterHum=$(jq -r '.thermostatList[1].remoteSensors[0].capability[1].value' "$thermostat_data_file")
BasementTemp=$(jq -r '.thermostatList[2].remoteSensors[1].capability[0].value | tonumber * 0.10' "$thermostat_data_file")
BasementHum=$(jq -r '.thermostatList[2].remoteSensors[1].capability[1].value' "$thermostat_data_file")
ConnorsTemp=$(jq -r '.thermostatList[0].remoteSensors[0].capability[0].value | tonumber * 0.10' "$thermostat_data_file")
JacobsTemp=$(jq -r '.thermostatList[0].remoteSensors[1].capability[0].value | tonumber * 0.10' "$thermostat_data_file")
NataliesTemp=$(jq -r '.thermostatList[2].remoteSensors[0].capability[0].value | tonumber * 0.10' "$thermostat_data_file")

#Write the data to the influx database
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Temperature,location=Main,measurement=temp value=$MainTemp"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Humidity,location=Main,measurement=humidity value=$MainHum"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Temperature,location=Master,measurement=temp value=$MasterTemp"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Humidity,location=Master,measurement=humidity value=$MasterHum"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Temperature,location=Basement,measurement=temp value=$BasementTemp"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Humidity,location=Basement,measurement=humidity value=$BasementHum"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Temperature,location=ConnorsRM,measurement=temp value=$ConnorsTemp"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Temperature,location=NataliesRM,measurement=temp value=$NataliesTemp"
curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "Temperature,location=JacobsRM,measurement=temp value=$JacobsTemp"

#clean up
rm -rf $thermostat_data_file
