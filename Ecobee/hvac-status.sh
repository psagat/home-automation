#!/bin/bash

###########################################################################
#Script Name	: power-stats.sh
#Description	: Gets HVAC status from Ecobee thermostats and reports
#                 information back to influxdb                                                                                
#Args           :                                                                                           
#Author       	:Pete Sagat                                                
#Email         	:petesagat@gmail.com                                           
###########################################################################

# Thermostat data file
data_file=/root/grafana-scripts/ecobee/hvac_thermostat_data.txt
# Get this from your Ecobee account under my apps. 
APIKEY='LvgiinTDjPjVkMZc2S4eK98FQd6D2kca'

# Filename where refreshkey needs to be stored (need to create it first time)
refresh_token=/root/grafana-scripts/ecobee/refreshkey.txt 

# Pre cleanup
rm -rf $data_file

# Read the current refresh token from the file. This is what allows us to get a new access token. 
{
  read REFRESH 
} < $refresh_token

# Get a new access token
response=`curl -s --request POST --data "grant_type=refresh_token&code=$REFRESH&client_id=$APIKEY" "https://api.ecobee.com/token"`
TOKEN=`echo $response | grep access_token | awk -F '"' '{print $4}'`

# Get thermostat data and create data file
curl -s -H 'Content-Type: text/json' -H 'Authorization: Bearer '$TOKEN'' 'https://api.ecobee.com/1/thermostatSummary?format=json&body=\{"selection":\{"selectionType":"registered","selectionMatch":"311058466093","includeEquipmentStatus":true\}\}' > $data_file

# Checks to ensure the data exists and if it doesnt after 5 attempts it kicks it out with an error
for ((attempt=1; attempt<=5; attempt++)); do
    if [ -s "$data_file" ]; then
        echo "Data is present in the file. Performing action..."
        break  # Exit the loop since data is present
    else
        echo "Waiting for data in the file..."
        sleep 2  
    fi
done

if [ ! -s "$data_file" ]; then
    echo "Data was not found after $attempt attempts. Exiting..."
    exit 1
fi

# Get furnace runtime status of each thermostat 
MainOutput=`cat $data_file | jq '.statusList[1]' | grep -Ei 'Cool|Heat|Fan'`
MasterOutput=`cat $data_file | jq '.statusList[2]' | grep -Ei 'Cool|Heat|Fan'`
BasementOutput=`cat $data_file | jq '.statusList[0]' | grep -Ei 'Cool|Heat|Fan'`

# Define arrays for variables and locations
outputs=("MainOutput" "MasterOutput" "BasementOutput")
locations=("Main" "Master" "Basement")

# Loop through the array of variables
for i in "${!outputs[@]}"; do
    variable="${outputs[i]}"
    location="${locations[i]}"

    # Use indirect variable expansion to get the value of the variable with its name
    value="${!variable}"

    if [ -z "$value" ]; then
        echo "The variable for location '$location' is empty."
        curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "AC,location=$location,measurement=status value=0"
    else
        echo "The variable for location '$location' is not empty."
            if [[ "$value" =~ [Cc][Oo][Oo][Ll] ]]; then
                echo "The variable for location '$location' contains 'Cool'."
                curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "AC,location=$location,measurement=status value=1"
            elif [[ "$value" =~ [Hh][Ee][Aa][Tt] ]]; then
                echo "The variable for location '$location' contains 'Heat'."
                curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "AC,location=$location,measurement=status value=2"
            elif [[ "$value" =~ [Ff][Aa][Nn] && ! "$value" =~ [Cc][Oo][Oo][Ll] && ! "$value" =~ [Hh][Ee][Aa][Tt] ]]; then
                echo "The variable for location '$location' contains 'Fan' but not 'Cool' or 'Heat'."
                curl -i -XPOST 'http://localhost:8086/write?db=hvac' --data-binary "AC,location=$location,measurement=status value=3"
            fi
    fi
done

#clean up
rm -rf $data_file
