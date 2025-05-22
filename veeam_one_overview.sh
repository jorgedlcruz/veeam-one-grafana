#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam ONE - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam ONE API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_one_overview.sh
##      ORIGINAL NAME: veeam_one_overview.sh
##      LASTEDIT: 21/05/2025
##      VERSION: 1.0
##      KEYWORDS: Veeam, InfluxDB, Grafana
   
##      .Link
##      https://jorgedelacruz.es/
##      https://jorgedelacruz.uk/

# Configurations
##
# Endpoint URL for InfluxDB
veeamInfluxDBURL="YOURINFLUXSERVER" ##Use https://fqdn or https://IP in case you use SSL
veeamInfluxDBPort="8086" #Default Port
veeamInfluxDB="YOURINFLUXDB" #Default Database
veeamInfluxDBUser="YOURINFLUXUSER" #User for Database
veeamInfluxDBPassword="YOURINFLUXPASS" #Password for Database

# Endpoint URL for login action
veeamUsername="YOURVEEAMONEUSER" #Usually domain\user or user@domain.tld
veeamPassword="YOURVEEAMONEPASS"
veeamONEServer="https://YOURVEEAMONEIP" #You can use FQDN if you like as well
veeamONEPort="1239" #Default Port

# Set debug to true to enable printing of the InfluxDB line protocol and debug messages,
# or false to disable.
debug=false

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -H  "Content-Type: application/x-www-form-urlencoded" -d "username=$veeamUsername&password=$veeamPassword&rememberMe=&asCurrentUser=&grant_type=password&refresh_token=" "$veeamONEServer:$veeamONEPort/api/token" -k --silent | jq -r '.access_token')

##
# Veeam ONE About
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/about"
veeamONEAboutUrl=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    2>&1 -k --silent)

    version=$(echo "$veeamONEAboutUrl" | jq --raw-output ".version")
    voneserver=$(echo "$veeamONEAboutUrl" | jq --raw-output ".machine")

    influxData="veeam_ONE_about,voneserver=$voneserver,voneversion=$version vone=1"
    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_about to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

##
# Veeam ONE - Protected VMs Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/virtualMachines?Offset=0&Limit=10000"
protectedVMsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i vmIndex=0
vmCount=$(echo "$protectedVMsResponse" | jq '.items | length')

while [ $vmIndex -lt $vmCount ]; do
    vm=$(echo "$protectedVMsResponse" | jq ".items[$vmIndex]")

    backupServerName=$(echo "$vm" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$vm" | jq -r '.vmIdInHypervisor // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$vm" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$vm" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$vm" | jq -r '.parentHostName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName=$(echo "$vm" | jq -r '.jobName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    usedSourceSizeBytes=$(echo "$vm" | jq -r '.usedSourceSizeBytes // 0')
    provisionedSourceSizeBytes=$(echo "$vm" | jq -r '.provisionedSourceSizeBytes // 0')
    lastProtectedDateRaw=$(echo "$vm" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedvms,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedvms data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    vmIndex=$((vmIndex + 1))
done

##
# Veeam ONE - Protected Computers Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/computers?Offset=0&Limit=10000"
protectedComputersResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i computerIndex=0
computerCount=$(echo "$protectedComputersResponse" | jq '.items | length')

while [ $computerIndex -lt $computerCount ]; do
    computer=$(echo "$protectedComputersResponse" | jq ".items[$computerIndex]")

    backupServerName=$(echo "$computer" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$computer" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$computer" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$computer" | jq -r '.computerUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$computer" | jq -r '.protectionGroups[0].groupName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$computer" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedcomputers,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedcomputers data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    computerIndex=$((computerIndex + 1))
done

##
# Veeam ONE - Protected File Shares Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/unstructuredData/fileShares?Offset=0&Limit=10000"
protectedFileSharesResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i fsIndex=0
fsCount=$(echo "$protectedFileSharesResponse" | jq '.items | length')

while [ $fsIndex -lt $fsCount ]; do
    fileShare=$(echo "$protectedFileSharesResponse" | jq ".items[$fsIndex]")

    backupServerName=$(echo "$fileShare" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$fileShare" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$fileShare" | jq -r '.type // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$fileShare" | jq -r '.fileShareUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName="none"
    jobName=$(echo "$fileShare" | jq -r '.jobs[0].jobName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$fileShare" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedfileshares,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedfileshares data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    fsIndex=$((fsIndex + 1))
done

##
# Veeam ONE - Protected Object Storage Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/unstructuredData/objectStorages?Offset=0&Limit=10000"
protectedObjectStorageResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i osIndex=0
osCount=$(echo "$protectedObjectStorageResponse" | jq '.items | length')

while [ $osIndex -lt $osCount ]; do
    objectStorage=$(echo "$protectedObjectStorageResponse" | jq ".items[$osIndex]")

    backupServerName=$(echo "$objectStorage" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$objectStorage" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$objectStorage" | jq -r '.type // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$objectStorage" | jq -r '.objectStorageUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName="none"
    jobName=$(echo "$objectStorage" | jq -r '.jobs[0].jobName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$objectStorage" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedobjectstorage,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedobjectstorage data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    osIndex=$((osIndex + 1))
done

##
# Veeam ONE - Protected Applications Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/applications?Offset=0&Limit=10000"
protectedApplicationsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i appIndex=0
appCount=$(echo "$protectedApplicationsResponse" | jq '.items | length')

while [ $appIndex -lt $appCount ]; do
    app=$(echo "$protectedApplicationsResponse" | jq ".items[$appIndex]")

    backupServerName=$(echo "$app" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$app" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$app" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$app" | jq -r '.applicationUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName="none"
    jobName=$(echo "$app" | jq -r '.protectionGroups[0].groupName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$app" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"' | cut -d. -f1) # truncate milliseconds for safety
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedapplications,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedapplications data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    appIndex=$((appIndex + 1))
done

##
# Veeam ONE - Protected Microsoft 365 Users Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/vb365/users?Offset=0&Limit=10000"
protectedVB365UsersResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i userIndex=0
userCount=$(echo "$protectedVB365UsersResponse" | jq '.items | length')

while [ $userIndex -lt $userCount ]; do
    user=$(echo "$protectedVB365UsersResponse" | jq ".items[$userIndex]")

    backupServerName=$(echo "$user" | jq -r '.vb365ServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$user" | jq -r '.userName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$user" | jq -r '.type // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$user" | jq -r '.userUid // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$user" | jq -r '.organizationName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$user" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedvb365users,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedvb365users data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    userIndex=$((userIndex + 1))
done

##
# Veeam ONE - Protected Microsoft 365 Groups Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/vb365/groups?Offset=0&Limit=10000"
protectedVB365GroupsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i groupIndex=0
groupCount=$(echo "$protectedVB365GroupsResponse" | jq '.items | length')

while [ $groupIndex -lt $groupCount ]; do
    group=$(echo "$protectedVB365GroupsResponse" | jq ".items[$groupIndex]")

    backupServerName=$(echo "$group" | jq -r '.vb365ServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$group" | jq -r '.groupName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$group" | jq -r '.type // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$group" | jq -r '.groupUid // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$group" | jq -r '.organizationName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$group" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedvb365groups,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedvb365groups data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    groupIndex=$((groupIndex + 1))
done

##
# Veeam ONE - Protected Microsoft 365 Sites Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/vb365/sites?Offset=0&Limit=10000"
protectedVB365SitesResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i siteIndex=0
siteCount=$(echo "$protectedVB365SitesResponse" | jq '.items | length')

while [ $siteIndex -lt $siteCount ]; do
    site=$(echo "$protectedVB365SitesResponse" | jq ".items[$siteIndex]")

    backupServerName=$(echo "$site" | jq -r '.vb365ServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$site" | jq -r '.siteName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform="VB365Site"
    vmIdInHypervisor=$(echo "$site" | jq -r '.siteUid // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$site" | jq -r '.organizationName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName=$(echo "$site" | jq -r '.title // "none"' | awk '{gsub(/ /,"\\ ");print}')
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$site" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedvb365sites,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedvb365sites data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    siteIndex=$((siteIndex + 1))
done

##
# Veeam ONE - Protected Microsoft 365 Teams Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/vb365/teams?Offset=0&Limit=10000"
protectedVB365TeamsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i teamIndex=0
teamCount=$(echo "$protectedVB365TeamsResponse" | jq '.items | length')

while [ $teamIndex -lt $teamCount ]; do
    team=$(echo "$protectedVB365TeamsResponse" | jq ".items[$teamIndex]")

    backupServerName=$(echo "$team" | jq -r '.vb365ServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$team" | jq -r '.teamName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform="VB365Team"
    vmIdInHypervisor=$(echo "$team" | jq -r '.teamUid // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$team" | jq -r '.organizationName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$team" | jq -r '.lastProtectedDate // "1970-01-01T00:00:00Z"')
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedvb365teams,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedvb365teams data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    teamIndex=$((teamIndex + 1))
done

##
# Veeam ONE - Protected Public Cloud VMs Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/publicCloud/virtualMachines?Offset=0&Limit=10000"
protectedCloudVMsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i vmIndex=0
vmCount=$(echo "$protectedCloudVMsResponse" | jq '.items | length')

while [ $vmIndex -lt $vmCount ]; do
    vm=$(echo "$protectedCloudVMsResponse" | jq ".items[$vmIndex]")

    backupServerName=$(echo "$vm" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$vm" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    rawPlatform=$(echo "$vm" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    instanceType=$(echo "$vm" | jq -r '.instanceType // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform="${rawPlatform}-${instanceType}"
    platform=$(echo "$platform" | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$vm" | jq -r '.cloudVmUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$vm" | jq -r '.region // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=$(echo "$vm" | jq -r '.sizeBytes // 0')
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$vm" | jq -r '.lastProtectionDate // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedpubliccloudvms,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedpubliccloudvms data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    vmIndex=$((vmIndex + 1))
done

##
# Veeam ONE - Protected Public Cloud File Shares Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/publicCloud/fileShares?Offset=0&Limit=10000"
protectedCloudFSResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i fsIndex=0
fsCount=$(echo "$protectedCloudFSResponse" | jq '.items | length')

while [ $fsIndex -lt $fsCount ]; do
    fs=$(echo "$protectedCloudFSResponse" | jq ".items[$fsIndex]")

    backupServerName=$(echo "$fs" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$fs" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    rawPlatform=$(echo "$fs" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    instanceType=$(echo "$fs" | jq -r '.instanceType // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform="${rawPlatform}-${instanceType}"
    platform=$(echo "$platform" | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$fs" | jq -r '.cloudFileShareUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$fs" | jq -r '.region // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=$(echo "$fs" | jq -r '.sizeBytes // 0')
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$fs" | jq -r '.lastProtectionDate // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedpubliccloudfileshares,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedpubliccloudfileshares data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    fsIndex=$((fsIndex + 1))
done

##
# Veeam ONE - Protected Public Cloud Databases Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/publicCloud/databases?Offset=0&Limit=10000"
protectedCloudDBsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i dbIndex=0
dbCount=$(echo "$protectedCloudDBsResponse" | jq '.items | length')

while [ $dbIndex -lt $dbCount ]; do
    db=$(echo "$protectedCloudDBsResponse" | jq ".items[$dbIndex]")

    backupServerName=$(echo "$db" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$db" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    rawPlatform=$(echo "$db" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    instanceType=$(echo "$db" | jq -r '.instanceType // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform="${rawPlatform}-${instanceType}"
    platform=$(echo "$platform" | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$db" | jq -r '.cloudDatabaseUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$db" | jq -r '.region // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=$(echo "$db" | jq -r '.sizeBytes // 0')
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$db" | jq -r '.lastProtectionDate // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedpublicclouddatabases,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedpublicclouddatabases data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    dbIndex=$((dbIndex + 1))
done

##
# Veeam ONE - Protected Public Cloud Networks Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/protectedData/publicCloud/networks?Offset=0&Limit=10000"
protectedCloudNetworksResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i netIndex=0
netCount=$(echo "$protectedCloudNetworksResponse" | jq '.items | length')

while [ $netIndex -lt $netCount ]; do
    network=$(echo "$protectedCloudNetworksResponse" | jq ".items[$netIndex]")

    backupServerName=$(echo "$network" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    workloadName=$(echo "$network" | jq -r '.name // "none"' | awk '{gsub(/ /,"\\ ");print}')
    rawPlatform=$(echo "$network" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform="${rawPlatform}-Network"
    vmIdInHypervisor=$(echo "$network" | jq -r '.cloudNetworkUidInVbr // "none"' | awk '{gsub(/ /,"\\ ");print}')
    parentHostName=$(echo "$network" | jq -r '.region // "none"' | awk '{gsub(/ /,"\\ ");print}')
    jobName="none"
    usedSourceSizeBytes=0
    provisionedSourceSizeBytes=0
    lastProtectedDateRaw=$(echo "$network" | jq -r '.lastProtectionDate // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastProtectedDateRaw" +"%s")

    influxData="veeam_ONE_overview_protectedpubliccloudnetworks,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$workloadName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName usedSourceSizeBytes=$usedSourceSizeBytes,provisionedSourceSizeBytes=$provisionedSourceSizeBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_protectedpubliccloudnetworks data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    netIndex=$((netIndex + 1))
done

##
# Veeam ONE - VM Backup Jobs Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/vmBackupJobs?Offset=0&Limit=10000"
vmBackupJobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i jobIndex=0
jobCount=$(echo "$vmBackupJobsResponse" | jq '.items | length')

while [ $jobIndex -lt $jobCount ]; do
    job=$(echo "$vmBackupJobsResponse" | jq ".items[$jobIndex]")

    jobName=$(echo "$job" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$job" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$job" | jq -r '.platform // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$job" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=$(echo "$job" | jq -r '.lastRunDurationSec // 0')
    avgDurationSec=$(echo "$job" | jq -r '.avgDurationSec // 0')
    lastTransferredDataBytes=$(echo "$job" | jq -r '.lastTransferredDataBytes // 0')

    influxData="veeam_ONE_overview_vmBackupJobs,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_vmBackupJobs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    jobIndex=$((jobIndex + 1))
done

##
# Veeam ONE - Cloud Director Backup Jobs Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/cloudDirectorBackupJobs?Offset=0&Limit=10000"
cloudDirectorJobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i cdJobIndex=0
cdJobCount=$(echo "$cloudDirectorJobsResponse" | jq '.items | length')

while [ $cdJobIndex -lt $cdJobCount ]; do
    cdJob=$(echo "$cloudDirectorJobsResponse" | jq ".items[$cdJobIndex]")

    jobName=$(echo "$cdJob" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$cdJob" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform="CloudDirector"

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$cdJob" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=$(echo "$cdJob" | jq -r '.lastRunDurationSec // 0')
    avgDurationSec=$(echo "$cdJob" | jq -r '.avgDurationSec // 0')
    lastTransferredDataBytes=$(echo "$cdJob" | jq -r '.lastTransferredDataBytes // 0')

    influxData="veeam_ONE_overview_cloudDirectorVMs,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_cloudDirectorVMs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    cdJobIndex=$((cdJobIndex + 1))
done

##
# Veeam ONE - VM Replication Jobs Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/vmReplicationJobs?Offset=0&Limit=10000"
vmReplicationJobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i replJobIndex=0
replJobCount=$(echo "$vmReplicationJobsResponse" | jq '.items | length')

while [ $replJobIndex -lt $replJobCount ]; do
    job=$(echo "$vmReplicationJobsResponse" | jq ".items[$replJobIndex]")

    jobName=$(echo "$job" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$job" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$job" | jq -r '.platform // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$job" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=$(echo "$job" | jq -r '.lastRunDurationSec // 0')
    avgDurationSec=$(echo "$job" | jq -r '.avgDurationSec // 0')
    lastTransferredDataBytes=$(echo "$job" | jq -r '.lastTransferredDataBytes // 0')

    influxData="veeam_ONE_overview_vmReplicationJobs,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_vmReplicationJobs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    replJobIndex=$((replJobIndex + 1))
done

##
# Veeam ONE - Backup Copy Jobs Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/backupCopyJobs?Offset=0&Limit=10000"
backupCopyJobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i bcIndex=0
bcCount=$(echo "$backupCopyJobsResponse" | jq '.items | length')

while [ $bcIndex -lt $bcCount ]; do
    job=$(echo "$backupCopyJobsResponse" | jq ".items[$bcIndex]")

    jobName=$(echo "$job" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$job" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform="none"

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$job" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=0
    avgDurationSec=0
    lastTransferredDataBytes=0

    influxData="veeam_ONE_overview_backupCopyJobs,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_backupCopyJobs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    bcIndex=$((bcIndex + 1))
done

##
# Veeam ONE - VM Copy Jobs Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/vmCopyJobs?Offset=0&Limit=10000"
vmCopyJobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i copyIndex=0
copyCount=$(echo "$vmCopyJobsResponse" | jq '.items | length')

while [ $copyIndex -lt $copyCount ]; do
    job=$(echo "$vmCopyJobsResponse" | jq ".items[$copyIndex]")

    jobName=$(echo "$job" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$job" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform="none"

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$job" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=$(echo "$job" | jq -r '.lastRunDurationSec // 0')
    avgDurationSec=$(echo "$job" | jq -r '.avgDurationSec // 0')
    lastTransferredDataBytes=$(echo "$job" | jq -r '.lastTransferredDataBytes // 0')

    influxData="veeam_ONE_overview_vmCopyJobs,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_vmCopyJobs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    copyIndex=$((copyIndex + 1))
done

##
# Veeam ONE - File Backup Jobs Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/fileBackupJobs?Offset=0&Limit=10000"
fileBackupJobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i jobIndex=0
jobCount=$(echo "$fileBackupJobsResponse" | jq '.items | length')

while [ $jobIndex -lt $jobCount ]; do
    job=$(echo "$fileBackupJobsResponse" | jq ".items[$jobIndex]")

    jobName=$(echo "$job" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$job" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform="FileBackup"

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$job" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=$(echo "$job" | jq -r '.lastRunDurationSec // 0')
    avgDurationSec=$(echo "$job" | jq -r '.avgDurationSec // 0')
    lastTransferredDataBytes=$(echo "$job" | jq -r '.lastTransferredDataBytes // 0')

    influxData="veeam_ONE_overview_fileBackupJobs,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_fileBackupJobs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    jobIndex=$((jobIndex + 1))
done

##
# Veeam ONE - Agent Backup Jobs Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/agentBackupJobs?Offset=0&Limit=10000"
agentBackupJobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i jobIndex=0
jobCount=$(echo "$agentBackupJobsResponse" | jq '.items | length')

while [ $jobIndex -lt $jobCount ]; do
    job=$(echo "$agentBackupJobsResponse" | jq ".items[$jobIndex]")

    jobName=$(echo "$job" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$job" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$job" | jq -r '.platform // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$job" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=$(echo "$job" | jq -r '.lastRunDurationSec // 0')
    avgDurationSec=$(echo "$job" | jq -r '.avgDurationSec // 0')
    lastTransferredDataBytes=$(echo "$job" | jq -r '.lastTransferredDataBytes // 0')

    influxData="veeam_ONE_overview_agentBackupJobs,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_agentBackupJobs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    jobIndex=$((jobIndex + 1))
done

##
# Veeam ONE - Agent Policies Overview (with Status Mapping)
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vbrJobs/agentPolicies?Offset=0&Limit=10000"
agentPoliciesResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i policyIndex=0
policyCount=$(echo "$agentPoliciesResponse" | jq '.items | length')

while [ $policyIndex -lt $policyCount ]; do
    policy=$(echo "$agentPoliciesResponse" | jq ".items[$policyIndex]")

    jobName=$(echo "$policy" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$policy" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform=$(echo "$policy" | jq -r '.platform // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    # Policies have no lastRun, so just use current timestamp for now
    lastupdate=$(date +"%s")

    lastRunDurationSec=0
    avgDurationSec=0
    lastTransferredDataBytes=0

    influxData="veeam_ONE_overview_agentPolicies,voneserver=$voneserver,jobName=$jobName,status=$status,platform=$platform jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_agentPolicies data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    policyIndex=$((policyIndex + 1))
done

##
# Veeam ONE - Microsoft 365 Backup Jobs Overview
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/vb365Jobs/backupJobs?Offset=0&Limit=10000"
vb365JobsResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i vbJobIndex=0
vbJobCount=$(echo "$vb365JobsResponse" | jq '.items | length')

while [ $vbJobIndex -lt $vbJobCount ]; do
    job=$(echo "$vb365JobsResponse" | jq ".items[$vbJobIndex]")

    jobName=$(echo "$job" | jq -r '.name // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    status=$(echo "$job" | jq -r '.status // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    platform="VB365-BackupJob"
    parentHostName=$(echo "$job" | jq -r '.organizationName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    backupServerName=$(echo "$job" | jq -r '.proxyName // "none"' | awk '{gsub(/ /,"\\ ");print}')
    vmIdInHypervisor=$(echo "$job" | jq -r '.backupJobUid // "none"' | awk '{gsub(/ /,"\\ ");print}')

    case "$status" in
        Success)
            jobResult="1"
            ;;
        Warning)
            jobResult="2"
            ;;
        Failed)
            jobResult="3"
            ;;
        *)
            jobResult="0"
            ;;
    esac

    lastRunRaw=$(echo "$job" | jq -r '.lastRun // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "$lastRunRaw" +"%s" 2>/dev/null || echo 0)
    lastRunDurationSec=$(echo "$job" | jq -r '.lastRunDurationSec // 0')
    avgDurationSec=0
    lastTransferredDataBytes=$(echo "$job" | jq -r '.lastTransferredDataBytes // 0')
    processedItems=$(echo "$job" | jq -r '.processedItems // 0')

    influxData="veeam_ONE_overview_vb365Jobs,voneserver=$voneserver,backupServerName=$backupServerName,vmIdInHypervisor=$vmIdInHypervisor,workloadName=$jobName,platform=$platform,parentHostName=$parentHostName,jobName=$jobName,status=$status jobResult=$jobResult,lastRunDurationSec=$lastRunDurationSec,avgDurationSec=$avgDurationSec,lastTransferredDataBytes=$lastTransferredDataBytes,processedItems=$processedItems $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_vb365Jobs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    vbJobIndex=$((vbJobIndex + 1))
done

##
# Veeam ONE - Public Cloud VM Policies Overview
##

veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/publicCloud/policies/virtualMachines?Offset=0&Limit=10000"
cloudVmPoliciesResponse=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

declare -i policyIndex=0
policyCount=$(echo "$cloudVmPoliciesResponse" | jq '.items | length')

while [ $policyIndex -lt $policyCount ]; do
    policy=$(echo "$cloudVmPoliciesResponse" | jq ".items[$policyIndex]")

    jobName=$(echo "$policy" | jq -r '.policyName // "none"' | sed 's/[\\/"]/ /g' | awk '{gsub(/ /,"\\ ");print}')
    rawPlatform=$(echo "$policy" | jq -r '.platform // "none"' | awk '{gsub(/ /,"\\ ");print}')
    instanceType=$(echo "$policy" | jq -r '.instanceType // "none"' | awk '{gsub(/ /,"\\ ");print}')
    platform="${rawPlatform}-${instanceType}"

    backupServerName=$(echo "$policy" | jq -r '.backupServerName // "none"' | awk '{gsub(/ /,"\\ ");print}')

    # Statuses (string)
    snapshotStatus=$(echo "$policy" | jq -r '.lastSnapshotStatus // "Unknown"')
    backupStatus=$(echo "$policy" | jq -r '.lastBackupStatus // "Unknown"')
    replicationStatus=$(echo "$policy" | jq -r '.lastReplicationStatus // "Unknown"')
    archiveStatus=$(echo "$policy" | jq -r '.lastArchiveStatus // "Unknown"')

    # Status codes
    case "$snapshotStatus" in
        Success) snapshotResult=1 ;;
        Warning) snapshotResult=2 ;;
        Failed)  snapshotResult=3 ;;
        *)       snapshotResult=0 ;;
    esac
    case "$backupStatus" in
        Success) backupResult=1 ;;
        Warning) backupResult=2 ;;
        Failed)  backupResult=3 ;;
        *)       backupResult=0 ;;
    esac
    case "$replicationStatus" in
        Success) replicationResult=1 ;;
        Warning) replicationResult=2 ;;
        Failed)  replicationResult=3 ;;
        *)       replicationResult=0 ;;
    esac
    case "$archiveStatus" in
        Success) archiveResult=1 ;;
        Warning) archiveResult=2 ;;
        Failed)  archiveResult=3 ;;
        *)       archiveResult=0 ;;
    esac

    # Timestamps
    snapshotDate=$(echo "$policy" | jq -r '.lastSnapshotDate // empty' | cut -d. -f1)
    backupDate=$(echo "$policy" | jq -r '.lastBackupDate // "1970-01-01T00:00:00Z"' | cut -d. -f1)
    lastupdate=$(date -d "${snapshotDate:-$backupDate}" +"%s" 2>/dev/null || echo 0)

    influxData="veeam_ONE_overview_publicCloudPoliciesVMs,voneserver=$voneserver,jobName=$jobName,platform=$platform,backupServerName=$backupServerName snapshotResult=$snapshotResult,backupResult=$backupResult,replicationResult=$replicationResult,archiveResult=$archiveResult $lastupdate"

    if [ "$debug" = true ]; then
        echo "$influxData"
    fi
    echo "Writing veeam_ONE_overview_publicCloudPoliciesVMs data to InfluxDB"
    influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"

    policyIndex=$((policyIndex + 1))
done


