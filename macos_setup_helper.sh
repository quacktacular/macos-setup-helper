#!/bin/bash

# MACOS SETUP HELPER 
# Script to gather resource and health information on Mac computers. 
# Maintained by Brendan DeBrincat <brendan[at]quacktacular.net>
#
# Please use and modify this script as you like, but share any improvements or features in 
# a GitHub issue or pull request https://github.com/quacktacular/macos-setup-helper

# Set the relative directory so script and addons can run without cd
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Lets populate the basic hardware info
DEVICE_PROFILE=$(/usr/sbin/system_profiler SPHardwareDataType)
DEVICE_SERIAL=$(ioreg -c "IOPlatformExpertDevice" | awk -F '"' '/IOPlatformSerialNumber/ {print $4}')
DEVICE_MAC=$(networksetup -getmacaddress Wi-Fi | awk -F ' ' '{print $3}')
DEVICE_RAM=$( echo "$DEVICE_PROFILE" | awk -F ' ' '/Memory/ {print $2 " " $3}' )
DEVICE_CPU_SPEED=$( echo "$DEVICE_PROFILE" | awk -F ' ' '/Processor Speed/ {for (i=3; i<NF; i++) printf $i " "; print $NF}' )
DEVICE_CPU_BRAND=$( echo "$DEVICE_PROFILE" | awk -F ' ' '/Processor Name/ {for (i=3; i<NF; i++) printf $i " "; print $NF}' )
DEVICE_BATTERY_CYCLES=$( system_profiler SPPowerDataType | grep "Cycle Count" | awk '{print $3}' )
DEVICE_BATTERY_HEALTH=$( ioreg -l | awk '$3~/Capacity/{c[$3]=$5}END{OFMT="%.3f";max=c["\"DesignCapacity\""];print(max>0?100*c["\"MaxCapacity\""]/max:"?")}' )
DEVICE_STORAGE_CAPACITY=$( diskutil info /dev/disk0 | grep "Disk Size" | awk {'print $3 " " $4'} )

# Which os version are we running
OS_PRODUCT_VERSION=$(sw_vers -productVersion)
OS_VERSION=( ${OS_PRODUCT_VERSION//./ } )
OS_VERSION_MAJOR="${OS_VERSION[0]}"
OS_VERSION_MINOR="${OS_VERSION[1]}"
OS_VERSION_PATCH="${OS_VERSION[2]}"
OS_VERSION_BUILD=$(sw_vers -buildVersion)

# Now we'll fetch software details
DEVICE_NAME=$(scutil --get ComputerName)
FILEVAULT_STATUS=$(fdesetup status | awk '{print substr($NF, 1, length($NF)-1)}')
EMPLOYEE_USERNAME=$(id -nu 502 2> /dev/null)

# Determine the model and year
DEVICE_MODEL=$( curl -s https://support-sp.apple.com/sp/product?cc=` echo $DEVICE_SERIAL | cut -c 9-` | sed 's|.*<configCode>\(.*\)</configCode>.*|\1|' )
DEVICE_YEAR=$( echo "$DEVICE_MODEL" | grep -o -E '[0-9][0-9][0-9][0-9]' )

# Formatting variables
FORMATTING_HR=$( echo "===============================================" )
FORMATTING_DATE=$( date )

# Let's print out the profile
echo $FORMATTING_HR
echo "DEVICE REPORT - $FORMATTING_DATE"
echo $FORMATTING_HR
echo "Name: $DEVICE_NAME"
echo "Serial: $DEVICE_SERIAL"
echo "MAC (WiFi): $DEVICE_MAC"
echo "Model: $DEVICE_MODEL"
echo "Year: $DEVICE_YEAR"
echo "CPU Speed: $DEVICE_CPU_SPEED"
echo "CPU Type: $DEVICE_CPU_BRAND"
echo "CPU Full: $DEVICE_CPU_SPEED $DEVICE_CPU_BRAND"
echo "RAM: $DEVICE_RAM"
echo "Storage: $DEVICE_STORAGE_CAPACITY"
if [ $DEVICE_BATTERY_CYCLES ] ; then
  # If a battery was found we'll show the cycles and health
  echo "Battery Cycles: $DEVICE_BATTERY_CYCLES"
  echo "Battery Health: $DEVICE_BATTERY_HEALTH"
fi
echo "macOS Version: ${OS_VERSION_MAJOR}.${OS_VERSION_MINOR}.${OS_VERSION_PATCH}+${OS_VERSION_BUILD}"
echo "FileVault: $FILEVAULT_STATUS"
if [ $EMPLOYEE_USERNAME ] ; then
  # If a username has been set we'll show it here
  echo "Employee username: $EMPLOYEE_USERNAME"
else
  # Notify of username error, in case we forgot to create it
  echo "Couldn't find employee user"
fi
echo $FORMATTING_HR

# Run an onboarding script if the option was set
while test $# -gt 0; do
  case "$1" in
    -h|--help|-u|--usage)
      echo "options:"
      echo "  -h, --help, -u, --usage      show brief help"
      echo "  -p, --prepare                set the password policy and change volume name"
      echo "  -s, --snipeit                add or update the machine in Snipe-IT"
      exit 0
      ;;
    -p|--prepare)
      sudo pwpolicy -u $EMPLOYEE_USERNAME -setpolicy "newPasswordRequired=1";
      diskutil rename / "Macintosh HD"
      shift
      ;;
    -s|--snipeit)
			# Include Snipe-IT API bash script
			source "${SCRIPT_DIR}/addons/snipeit.sh"
      shift
      ;;
  esac
done