#!/bin/bash
###################################################################
#Script Name	: power-stats.sh
#Description	: Gets power metrics from sonof s31 plugs and then
#               adds it into influxDB                                                                                
#Args           :                                                                                           
#Author       	:Pete Sagat                                                
#Email         	:petesagat@gmail.com                                           
###################################################################

# Define the values and locations arrays
values=("Today" "Power")
locations=("Lab-Server" "Lab-Rack" "Office-PC" "Lab-Freezer" "Dehumidifer")

# Set array
responses=()

# Define password
password="alphaomega"

# Define curl request for each plug
labserver=$(curl -s "http://192.168.1.143/cm?user=admin&password=${password}&cmnd=Status0") # tied to Lab-server
labrack=$(curl -s "http://192.168.1.200/cm?user=admin&password=${password}&cmnd=Status0") # tied to Lab-rack
officepc=$(curl -s "http://192.168.1.201/cm?user=admin&password=${password}&cmnd=Status0") # tied to Office-pc
labfreezer=$(curl -s "http://192.168.1.209/cm?user=admin&password=${password}&cmnd=Status0") # tied to Lab-freezer
dehumidifier=$(curl -s "http://192.168.1.208/cm?user=admin&password=${password}&cmnd=Status0") # tied to Dehumidifer

# Add curl requests to the array
responses+=("$labserver")
responses+=("$labrack")
responses+=("$officepc")
responses+=("$labfreezer")
responses+=("$dehumidifier")

x=0

# Nested for loop to go through all locations and for each location get the two values. Then writes to influxdb
    for location in "${locations[@]}"; do
        for value in "${values[@]}"; do
         output=$(echo "${responses[$x]}" | jq -r ".StatusSNS.ENERGY.$value")
            if [ $value = "Today" ]; then
            measurement=DailyUsage
            else
            measurement=Watts
            fi
            curl -i -XPOST 'http://localhost:8086/write?db=power' --data-binary "Power,location=$location,measurement=$measurement value=$output"
        done
        (( x++ ))
    done
