#!/bin/bash

# SNIPE-IT ADDON
# Addon takes information from macos-setup-helper and submits it to the Snipe-IT API 
# Maintained by Brendan DeBrincat <brendan[at]quacktacular.net>
#
# Please use and modify this script as you like, but share any improvements or features in 
# a GitHub issue or pull request https://github.com/quacktacular/macos-setup-helper

# Lets populate the basic hardware info
API_URL="YOUR_SNIPEIT_API_URL"
API_TOKEN="YOUR_SNIPEIT_API_TOKEN"
DEFAULT_FIELDSET_ID=3
DEFAULT_MANUFACTURER_ID=4
DEFAULT_CATEGORY_ID=2
DEFAULT_STATUS_ID=2

# This runs the Snipe-IT check, and routes flow to existingAsset or newAsset 
main () {
  # Lets check if the asset is already present
  apiRequest "GET" "hardware?search=${DEVICE_SERIAL}" ASSET_SEARCH_JSON
  checkResponse "$ASSET_SEARCH_JSON" "['total']" ASSET_SEARCH_TOTAL 

  # Lets check if the model exists yet
  apiRequest "GET" "models" MODEL_SEARCH_JSON  "search=${DEVICE_MODEL}"
  checkResponse "$MODEL_SEARCH_JSON" "['total']" MODEL_SEARCH_TOTAL 

  # If we found 1 the machine exists! None we'll ask to add. If multiple something's wrong.
  if [ $ASSET_SEARCH_TOTAL -eq 1 ]
  then
    existingAsset
  elif [ $ASSET_SEARCH_TOTAL -eq 0 ] 
  then
    addAsset
  else
    apiError "$ASSET_SEARCH_JSON"
  fi
}

# If the computer already exists in Snipe-IT
existingAsset () {
  checkResponse "$ASSET_SEARCH_JSON" "['rows'][0]['name']" ASSET_NAME  
  checkResponse "$ASSET_SEARCH_JSON" "['rows'][0]['id']" ASSET_ID  
  checkResponse "$ASSET_SEARCH_JSON" "['rows'][0]['model']['id']" ASSET_MDOEL_ID  
  checkResponse "$ASSET_SEARCH_JSON" "['rows'][0]['model']['name']" ASSET_MODEL_NAME  
  echo "Looks like you have $ASSET_NAME! The model is $ASSET_MODEL_NAME"
	# Check for name mistach
  if [ "$ASSET_NAME" != "$DEVICE_NAME" ]
  then
    echo "    Name in Snipe-IT:       $ASSET_NAME"
    echo "    Name on local machine:  $DEVICE_NAME"
    echo "(1) Want to use the one from Snipe-IT?"
    echo "(2) Or the use the local name?"
    echo "(3) Or ignore the mismatch?"
    while true; do
        read -p "Please enter one of the above options: " INPUT_NAME_CHANGE
        case $INPUT_NAME_CHANGE in
            [1]* ) echo "Updating Snipe..."; updateHostName "$ASSET_NAME"; break;;
            [2]* ) echo "Updating local name..."; updateSnipeName "$ASSET_ID" "$DEVICE_NAME"; break;; 
            [3]* ) echo "Alright! Nothing was changed."; exit;; 
            * ) echo "Please choose one of the above options.";;
        esac
    done
  fi  
	# See if we want to update asset specs
	echo "Do you want to update the specs in Snipe-IT?"
	echo "      (y) Yes update the specs to match this machine"
	echo "      (n) No leave the specs in Snipe-IT as is"
	while true; do
			read -p "Please enter yes or no: " INPUT_NAME_CHANGE
			case $INPUT_NAME_CHANGE in
					[Yy]* ) updateSnipeSpecs $ASSET_ID; break;;
					[Nn]* ) echo "Alright. Nothing was updated."; exit;; 
					* ) echo "Please answer yes or no.";;
			esac
	done
}

# If the computer does not yet exist in Snipe-IT
addAsset () { 
	echo "Couldn't find $DEVICE_SERIAL [$DEVICE_MODEL] in the database. Should I add it? "
	echo "      (y) Yes add the asset to Snipe-IT"
	echo "      (n) No do not add anything"
	while true; do
			read -p "Please answer yes or no: " INPUT_ADD_ASSET
			case $INPUT_ADD_ASSET in
					[Yy]* ) echo "Alright we'll try to add it."; break;;
					[Nn]* ) echo "We won't add anything."; exit;;
					* ) echo "Please answer yes or no.";;
			esac
	done

	modelManagment # Hand-off to the function
  ASSET_ADD_DATA="{\"name\":\"${DEVICE_NAME}\",\"asset_tag\":\"${DEVICE_SERIAL}\",\"status_id\":${DEFAULT_STATUS_ID},\"model_id\":${MODEL_ID},\"serial\":\"${DEVICE_SERIAL}\",\"_snipeit_ram_3\":\"${DEVICE_RAM}\",\"_snipeit_cpu_4\":\"${DEVICE_CPU_SPEED} ${DEVICE_CPU_BRAND}\",\"_snipeit_storage_5\":\"${DEVICE_STORAGE_CAPACITY}\",\"_snipeit_mac_10\":\"${DEVICE_MAC}\",\"_snipeit_year_8\":\"${DEVICE_YEAR}\",\"_snipeit_battery_health_11\":\"${DEVICE_BATTERY_HEALTH}\",\"_snipeit_battery_cycles_12\":\"${DEVICE_BATTERY_CYCLES}\"}"
  apiRequest "POST" "hardware" ASSET_ADD_JSON  "${ASSET_ADD_DATA}"
  checkResponse "$ASSET_ADD_JSON" "['payload']['id']" ASSET_ID    
  echo "Added ${DEVICE_NAME}! Its new asset_id is ${ASSET_ID}." 
}

# Handle model check and creation if necessary
modelManagment () {
  if [ $MODEL_SEARCH_TOTAL -eq 1 ]
  then
    checkResponse "$MODEL_SEARCH_JSON" "['rows'][0]['id']" MODEL_ID    
    echo "The model already exists and its model_id is ${MODEL_ID}..."
  elif [ $MODEL_SEARCH_TOTAL -eq 0 ] 
  then
    echo "Couldn't find $DEVICE_MODEL in the database, so we'll try to create it..."
    MODEL_ADD_DATA="{\"name\":\"${DEVICE_MODEL}\",\"category_id\":${DEFAULT_CATEGORY_ID},\"fieldset_id\":${DEFAULT_FIELDSET_ID},\"manufacturer_id\":${DEFAULT_MANUFACTURER_ID}}"
    apiRequest "POST" "models" MODEL_ADD_JSON  "${MODEL_ADD_DATA}"
    checkResponse "$MODEL_ADD_JSON" "['payload']['id']" MODEL_ID    
		echo "Added the model. Its new model_id is ${MODEL_ID}!"
  else
    apiError "$MODEL_SEARCH_JSON"
  fi
}

# Functions to handle computer name mismatch 
updateSnipeName () {
  echo "Let's try to update name in Snipe! Should be $2..."
  NAME_CHANGE_DATA="{\"name\":\"${2}\"}"
  apiRequest "PATCH" "hardware/${1}" NAME_CHANGE_JSON  "${NAME_CHANGE_DATA}"
  checkResponse "$NAME_CHANGE_JSON" "['payload']['name']" NAME_CHANGE_RESULT  
  if [ "$NAME_CHANGE_RESULT" ==  "$2" ]
  then
    echo "The name in Snipe-IT was updated successfully!"
  else
    apiError "$NAME_CHANGE_JSON"
  fi
}

updateSnipeSpecs () {
  echo "Updating Snipe-IT..."
	modelManagment # Hand-off to the function
  ASSET_UPDATE_DATA="{\"asset_tag\":\"${DEVICE_SERIAL}\",\"model_id\":${MODEL_ID},\"serial\":\"${DEVICE_SERIAL}\",\"_snipeit_ram_3\":\"${DEVICE_RAM}\",\"_snipeit_cpu_4\":\"${DEVICE_CPU_SPEED} ${DEVICE_CPU_BRAND}\",\"_snipeit_storage_5\":\"${DEVICE_STORAGE_CAPACITY}\",\"_snipeit_mac_10\":\"${DEVICE_MAC}\",\"_snipeit_year_8\":\"${DEVICE_YEAR}\",\"_snipeit_battery_health_11\":\"${DEVICE_BATTERY_HEALTH}\",\"_snipeit_battery_cycles_12\":\"${DEVICE_BATTERY_CYCLES}\"}"
  apiRequest "PATCH" "hardware/${1}" ASSET_UPDATE_JSON  "${ASSET_UPDATE_DATA}"
  checkResponse "$ASSET_UPDATE_JSON" "['status']" ASSET_UPDATE_STATUS    
  if [ ${ASSET_UPDATE_STATUS} == "success" ]
  then
    echo "Updated ${DEVICE_SERIAL} successfully!" 
  else
    apiError "$ASSET_UPDATE_JSON"
  fi
}

updateHostName () {
  echo "Let's try to update the host name! Should be $1..."
  # Make the hostname valid by removing dumb chars
	NEW_HOSTNAME=$( echo "{$1}" | tr -d -c '[:alnum:]-' )
	# Append .local (this is just for display, scutil adds it for LocalHostName automatically)
	NEW_LOCAL_HOSTNAME=$( echo ${NEW_HOSTNAME}.local )
	# Alright lets start!
	echo "Setting the computer name to ${1}..."
  sudo scutil --set ComputerName "${1}"
	echo "Setting mDNS name to ${NEW_LOCAL_HOSTNAME}..."
  sudo scutil --set LocalHostName "${NEW_HOSTNAME}"
	echo "Setting hostname to ${NEW_HOSTNAME}..."
  sudo scutil --set HostName "${NEW_HOSTNAME}"
}

# Make an API request
apiRequest () {
  # $1 is the curl method (like POST)
  # $2 is the API endpoint
  # $3 is the variable to set
  # $4 is the data to send
  if [ "${1}" == "GET" ]
  then
    export "${3}"="$( curl -s -G \
      "${API_URL}${2}" \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --data-urlencode "${4}" )"    
  elif [ "${1}" == "PATCH" ]
  then
    export "${3}"="$( curl -s --request PATCH \
      "${API_URL}${2}" \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --data "${4}" )"    
  else
    export "${3}"="$( curl -s --request POST \
      "${API_URL}${2}" \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -H "Accept: application/json" \
      -H "Content-Type: application/json" \
      --data "${4}" )"
  fi
}

# This function makes sure the API response $1 is valid JSON, and if so sets the specified 
# bash variable $3 to the value of the specified key $2
checkResponse () { 
   if ( echo $1 | python -m json.tool > /dev/null )
   then
      export "${3}"="$( echo $1 | python -c "import json,sys;obj=json.load(sys.stdin);print obj$2"; )"
   else
	    apiError "$ASSET_SEARCH_JSON"
   fi
}

# Handle API errors by printing the output and ending execution (we shouldn't continue)
apiError () {
	echo "Did not receive a valid response from the API. See output below: "
	echo "${1}"
	exit 1;   
}

# Run the addon after all functions are declared
main