#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam ONE v2.21 - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam ONE v2.21 UNOFFICIAL AND UNSUPPORTED API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_one.sh
##      ORIGINAL NAME: veeam_one.sh
##      LASTEDIT: 05/03/2021
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

veeamBearer=$(curl -X POST --header "Content-Type: application/x-www-form-urlencoded" --header "Accept: application/json" -H  "Content-Type: application/x-www-form-urlencoded" -d "username=$veeamUsername&password=$veeamPassword&rememberMe=&asCurrentUser=&grant_type=password&refresh_token=" "$veeamONEServer:$veeamONEPort/api/token" -k --silent | jq -r '.access_token')

##
# Veeam ONE About
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/about"
veeamONEAboutUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' 2>&1 -k --silent)
    version=$(echo "$veeamONEAboutUrl" | jq --raw-output ".version")
    voneserver=$(echo "$veeamONEAboutUrl" | jq --raw-output ".machine")
    
    influxData="veeam_ONE_about,voneserver=$voneserver,voneversion=$version vone=1"

    ##Comment the influx while debugging
    echo "Writing veeam_ONE_about to InfluxDB"
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "$influxData"

##
# Veeam Backup & Replication Overview. This part will check The VONE VBR Overview
# Backup Infrastructure Inventory
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/1/widgets/1/datasources/64/data?forceRefresh=false"
veeamONEInventoryUrl=$(curl -X 'POST' $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' -d '' 2>&1 -k --silent)

    totalvbr=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[0].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalproxy" ]] || totalproxy="0"
    totalproxy=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[1].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalproxy" ]] || totalproxy="0"
    totalrepo=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[2].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalrepo" ]] || totalrepo="0"
    totalbackupjob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[3].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalbackupjob" ]] || totalbackupjob="0"
    totalreplicajob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[4].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalreplicajob" ]] || totalreplicajob="0"
    totalbackupcopyjob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[5].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalbackupcopyjob" ]] || totalbackupcopyjob="0"
    totalnasjob=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[6].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalnasjob" ]] || totalnasjob="0"
    totalcdpolicy=$(echo "$veeamONEInventoryUrl" | jq --raw-output ".data[7].name" | awk -F"[()]" '{print $2}')
    [[ ! -z "$totalcdpolicy" ]] || totalcdpolicy="0"
    
    influxData="veeam_ONE_backupinfrastructure,voneserver=$voneserver totalvbr=$totalvbr,totalproxy=$totalproxy,totalrepo=$totalrepo,totalbackupjob=$totalbackupjob,totalreplicajob=$totalreplicajob,totalbackupcopyjob=$totalbackupcopyjob,totalnasjob=$totalnasjob,totalcdpolicy=$totalcdpolicy"
    echo $influxData
    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_backupinfrastructure to InfluxDB"
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "$influxData"

##
# Veeam Backup & Replication Overview. This part will check The VONE VBR Overview
# Protected VMs
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/1/widgets/2/datasources/66/data?forceRefresh=false"
veeamONEProtectedVMsUrl=$(curl -X 'POST' $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' -d '' 2>&1 -k --silent)

    protectedvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[0].number")    
    backedupvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[1].number")    
    replicatedvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[2].number")    
    unprotectedvms=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[3].number")    
    restorepoints=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[4].number")    
    fullbackups=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[5].number" | awk '{print $1}')
    fullbackupsMetric=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[5].number" | awk '{print $2}')
        case $fullbackupsMetric in
        MB)
            fullbackupsSize=$fullbackups
        ;;
        GB)
            fullbackupsSize=$(echo "$fullbackups * 1024" | bc)
        ;;
        TB)
            fullbackupsSize=$(echo "$fullbackups * 1048576" | bc)
        ;;
        PB)
            fullbackupsSize=$(echo "$fullbackups * 1073741824" | bc)
        ;;
        esac
    increments=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[6].number" | awk '{print $1}')
    incrementsMetric=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[6].number" | awk '{print $2}')
        case $incrementsMetric in
        MB)
            incrementsbackupsSize=$increments
        ;;
        GB)
            incrementsbackupsSize=$(echo "$increments * 1024" | bc)
        ;;
        TB)
            incrementsbackupsSize=$(echo "$increments * 1048576" | bc)
        ;;
        PB)
            incrementsbackupsSize=$(echo "$increments * 1073741824" | bc)
        ;;
        esac
    sourcevmsize=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[7].number" | awk '{print $1}')
    sourcevmsizeMetric=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[7].number" | awk '{print $2}')
        case $sourcevmsizeMetric in
        MB)
            sourceSize=$sourcevmsize
        ;;
        GB)
            sourceSize=$(echo "$sourcevmsize * 1024" | bc)
        ;;
        TB)
            sourceSize=$(echo "$sourcevmsize * 1048576" | bc)
        ;;
        PB)
            sourceSize=$(echo "$sourcevmsize * 1073741824" | bc)
        ;;
        esac
    successratio=$(echo "$veeamONEProtectedVMsUrl" | jq --raw-output ".data[8].number"| awk -F'%' '{print $1}')

        
    influxData="veeam_ONE_protectedvms,voneserver=$voneserver protectedvms=$protectedvms,backedupvms=$backedupvms,replicatedvms=$replicatedvms,unprotectedvms=$unprotectedvms,restorepoints=$restorepoints,fullbackups=$fullbackupsSize,increments=$incrementsbackupsSize,sourcevmsize=$sourceSize,successratio=$successratio"
    echo $influxData

    ##Comment the influx while debugging
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "$influxData"
 
##
# Veeam Backup & Replication Overview. This part will check The VONE VBR Overview
# Veeam Backup Window
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/1/widgets/3/datasources/68/data?forceRefresh=false"
veeamONEOverviewUrl=$(curl -X 'POST' $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' -d '' 2>&1 -k --silent)

    declare -i arraybackupwindow=0
    for row in $(echo "$veeamONEOverviewUrl" | jq -r '.data[].backup'); do
        windowDate=$(echo "$veeamONEOverviewUrl" | jq --raw-output ".data[$arraybackupwindow].display_date")
        backupwindowdate=$(date -d "$windowDate" +"%s")
        windowbackup=$(echo "$veeamONEOverviewUrl" | jq --raw-output ".data[$arraybackupwindow].backup")
        [[ ! -z "$windowbackup" ]] || windowbackup="0"
        windowreplica=$(echo "$veeamONEOverviewUrl" | jq --raw-output ".data[$arraybackupwindow].replica")
        [[ ! -z "$windowreplica" ]] || windowreplica="0"
        
        influxData="veeam_ONE_backupwindow,voneserver=$voneserver windowbackup=$windowbackup,windowreplica=$windowreplica $backupwindowdate"
        echo $influxData
        arraybackupwindow=$arraybackupwindow+1
        
                ##Comment the influx while debugging
        echo "Writing veeam_ONE_backupwindow to InfluxDB"
        influx write \
        -t "$veeamInfluxDBToken" \
        -b "$veeamInfluxDBBucket" \
        -o "$veeamInfluxDBOrg" \
        -p s \
        "$influxData"
    done 
    
##
# Veeam Backup & Replication Overview. This part will check The VONE VBR Overview
# Top Jobs by Duration
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/1/widgets/4/datasources/65/data?forceRefresh=false"
veeamONEJobsDurationUrl=$(curl -X 'POST' $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' -d '' 2>&1 -k --silent)

lastUpdateTime=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".lastUpdateTimeUtc")
lastupdate=$(date -d "$lastUpdateTime" +"%s")
    
declare -i arrayjobduration=0
for row in $(echo "$veeamONEJobsDurationUrl" | jq -r '.data[].duration'); do
    jobname=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].name" | awk '{gsub(/ /,"\\ ");print}')
    if [[ $jobname = "null" ]]; then
        break
    else
    status=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].job_status")
      case $status in
        Success)
            jobStatus="1"
        ;;
        Warning)
            jobStatus="2"
        ;;
        Failed)
            jobStatus="3"
        ;;
        esac
    jobdurationH=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].duration" | awk '{print $1}')
    jobdurationM=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].duration" | awk '{print $3}')
    jobduration=$(echo "$jobdurationH * 60 + $jobdurationM" | bc)
    jobcompare=$(echo "$veeamONEJobsDurationUrl" | jq --raw-output ".data[$arrayjobduration].prev_dur")

    influxData="veeam_ONE_jobsduration,voneserver=$voneserver,jobname=$jobname,jobstatus=$jobStatus,jobduration=$jobduration trend=$jobcompare $lastupdate"
    echo $influxData

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_jobsduration to InfluxDB"
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "$influxData"

    arrayjobduration=$arrayjobduration+1
    fi
done      


##
# Veeam Backup & Replication Overview. This part will check The VONE VBR Overview
# Jobs Status
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/1/widgets/5/datasources/67/data?forceRefresh=false"
veeamONEJobsUrl=$(curl -X 'POST' $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' -d '' 2>&1 -k --silent)

declare -i arrayjobs=0
for row in $(echo "$veeamONEJobsUrl" | jq -r '.data[].fail'); do
    display_date=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].display_date")
    jobdate=$(date -d "$display_date" +"%s")
    jobsuccess=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].success")    
    jobwarning=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].warning")
    jobfail=$(echo "$veeamONEJobsUrl" | jq --raw-output ".data[$arrayjobs].fail")
    
    influxData="veeam_ONE_jobs,voneserver=$voneserver jobsuccess=$jobsuccess,jobwarning=$jobwarning,jobfail=$jobfail $jobdate"
    echo $influxData

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_jobs to InfluxDB"
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "$influxData"

    arrayjobs=$arrayjobs+1
done  


##
# Veeam Backup & Replication Overview. This part will check The VONE VBR Overview
# Top Repositories by Used Space
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/1/widgets/6/datasources/69/data?forceRefresh=false"
veeamONERepositoriesUrl=$(curl -X 'POST' $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' -d '' 2>&1 -k --silent)

lastUpdateTime=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".lastUpdateTimeUtc")
lastupdate=$(date -d "$lastUpdateTime" +"%s")
    
declare -i arrayrepositories=0
for row in $(echo "$veeamONERepositoriesUrl" | jq -r '.data[].trend'); do
    backupsrvname=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].backup_srv_name" | awk '{gsub(/ /,"\\ ");print}')    
    repositoryname=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].repository_name" | awk '{gsub(/ /,"\\ ");print}')
    repocapacity=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].capacity")    
    repofreespace=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].free_space")
    repodaysleft=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].days_to_die")    
    repocompare=$(echo "$veeamONERepositoriesUrl" | jq --raw-output ".data[$arrayrepositories].trend")

    influxData="veeam_ONE_repositories,voneserver=$voneserver,vbrserver=$backupsrvname,repositoryname=$repositoryname repocapacity=$repocapacity,repofreespace=$repofreespace,repodaysleft=$repodaysleft,trend=$repocompare $lastupdate"
    echo $influxData

    ##Comment the Curl while debugging
    echo "Writing veeam_ONE_repositories to InfluxDB"
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "$influxData"

    arrayrepositories=$arrayrepositories+1
done

##
# Veeam Threat Center. This part will check the VONE Threat Center
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/dataprotection"
veeamONETCUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -k --silent)

# Extracting Widget IDs
dashboardId=$(echo "$veeamONETCUrl" | jq --raw-output '.dashboardId')
scoresCardId=$(echo "$veeamONETCUrl" | jq --raw-output '.dataPlatformScoresWidgetId')
malwareDetectionsId=$(echo "$veeamONETCUrl" | jq --raw-output '.ransomwareIntelligentDetectionsWidgetId')
RPOAnomaliesId=$(echo "$veeamONETCUrl" | jq --raw-output '.restorePointObjrctiveAnomaliesWidgetId')
SLASuccessId=$(echo "$veeamONETCUrl" | jq --raw-output '.slaSuccessComplianceHeatmapWidgetId')

# Extracting Widget Datasources
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$malwareDetectionsId/datasources"
veeamONEMalwareUrl=$(curl -X GET $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H "accept: application/json" -k --silent)
malwareDetectionsDataSource=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".[1].datasourceId")

# Exploring Malware Detections
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$malwareDetectionsId/datasources/$malwareDetectionsDataSource/data"
veeamONEMalwareUrl=$(curl -X 'POST' $veeamONEURL -H "Authorization: Bearer $veeamBearer" -H  "accept: application/json" -H 'Content-Type: application/json' -d '' 2>&1 -k --silent)

# Extract and format the last update time
lastUpdateTime=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".lastUpdateTimeUtc")
lastupdate=$(date -d "$lastUpdateTime" +"%s")

# Initialize counter for array indexing
declare -i arrayMalware=0

# Process each item in the data array
for row in $(echo "$veeamONEMalwareUrl" | jq -c '.data[]'); do
     # Extracting fields
    itemId=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].item_id // \"none\"")

    if [[ "$itemId" == "0" ]]; then
        # Prepare the data for summary
        totalRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].total_rp // \"none\"")
        totalInfectedRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].total_infected_rp // \"none\"")
        infectedTrend=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].infected_trend // \"none\"")
        totalSuspiciousRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].total_suspicious_rp // \"none\"")
        suspiciousTrend=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].suspicious_trend // \"none\"")
        totalCleanRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].total_clean_rp // \"none\"")
        mostAffected=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].most_affected // \"none\"")
        unmappedRepositories=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].unmapped_repositories // \"none\"")
        selectedPeriod=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].selected_period // \"none\"")

        influxData="veeam_ONE_malware_summary,most_affected=${mostAffected} total_rp=${totalRp},total_infected_rp=${totalInfectedRp},infected_trend=${infectedTrend},total_suspicious_rp=${totalSuspiciousRp},suspicious_trend=${suspiciousTrend},total_clean_rp=${totalCleanRp},unmapped_repositories=${unmappedRepositories} ${lastupdate}"
        echo $influxData
    else
        # Prepare the data for individual items
        region=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].region // \"none\"")
        subregion=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].subregion // \"none\"")
        city=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].city // \"none\"")
        repositoryName=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].repository_name // \"none\"")
        repositoryUid=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].repository_uid // \"none\"")
        workloadName=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].workload_name // \"none\"")
        infectedRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].infected_rp // \"0\"")
        suspiciousRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].suspicious_rp // \"0\"")
        cleanRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].clean_rp // \"0\"")
        latitude=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].latitude // \"0\"")
        longitude=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].longitude // \"0\"")
        influxData="veeam_ONE_malware_items,region=${region},subregion=${subregion},city=${city},repository_name=${repositoryName},repository_uid=${repositoryUid},workload_name=${workloadName} infected_rp=${infectedRp},suspicious_rp=${suspiciousRp},clean_rp=${cleanRp},latitude=${latitude},longitude=${longitude} ${lastupdate}"
        echo $influxData    
    fi


    # Send the data to InfluxDB
    echo "Writing veeam_ONE_malware data to InfluxDB"
    influx write \
    -t "$veeamInfluxDBToken" \
    -b "$veeamInfluxDBBucket" \
    -o "$veeamInfluxDBOrg" \
    -p s \
    "$influxData"

    # Increment the array index for accessing the correct data item
    arrayMalware=$arrayMalware+1
done



