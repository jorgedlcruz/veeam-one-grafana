#!/bin/bash
##      .SYNOPSIS
##      Grafana Dashboard for Veeam ONE Threat Center - Using API to InfluxDB Script
## 
##      .DESCRIPTION
##      This Script will query the Veeam ONE Threat Center UNOFFICIAL AND UNSUPPORTED API and send the data directly to InfluxDB, which can be used to present it to Grafana. 
##      The Script and the Grafana Dashboard it is provided as it is, and bear in mind you can not open support Tickets regarding this project. It is a Community Project
##	
##      .Notes
##      NAME:  veeam_one_threat_center.sh
##      ORIGINAL NAME: veeam_one_threat_center.sh
##      LASTEDIT: 09/03/2025
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
# Veeam Threat Center. This part will check the VONE Threat Center
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/dataprotection"
veeamONETCUrl=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

    # Extracting Widget IDs
    dashboardId=$(echo "$veeamONETCUrl" | jq --raw-output '.dashboardId')
    scoresCardId=$(echo "$veeamONETCUrl" | jq --raw-output '.dataPlatformScoresWidgetId')
    malwareDetectionsId=$(echo "$veeamONETCUrl" | jq --raw-output '.ransomwareIntelligentDetectionsWidgetId')
    RPOAnomaliesId=$(echo "$veeamONETCUrl" | jq --raw-output '.restorePointObjrctiveAnomaliesWidgetId')
    SLASuccessId=$(echo "$veeamONETCUrl" | jq --raw-output '.slaSuccessComplianceHeatmapWidgetId')

    # Extracting Widget Datasources for Malware Detection
    veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$malwareDetectionsId/datasources"
    veeamONEMalwareUrl=$(curl -X GET "$veeamONEURL" \
        -H "Authorization: Bearer $veeamBearer" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -k --silent)
    malwareDetectionsDataSource=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".[1].datasourceId")

##
# Veeam Threat Center - Malware Detections
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$malwareDetectionsId/datasources/$malwareDetectionsDataSource/data"
veeamONEMalwareUrl=$(curl -X POST "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d '' \
    2>&1 -k --silent)

    lastUpdateTime=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".lastUpdateTimeUtc")
    lastupdate=$(date -d "$lastUpdateTime" +"%s")

    declare -i arrayMalware=0
    for row in $(echo "$veeamONEMalwareUrl" | jq -c '.data[]'); do
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
            influxData="veeam_ONE_tc_malware,voneserver=$voneserver,most_affected=${mostAffected} total_rp=${totalRp},total_infected_rp=${totalInfectedRp},infected_trend=${infectedTrend},total_suspicious_rp=${totalSuspiciousRp},suspicious_trend=${suspiciousTrend},total_clean_rp=${totalCleanRp},unmapped_repositories=${unmappedRepositories} ${lastupdate}"
            if [ "$debug" = true ]; then
                echo "$influxData"
            fi
        else
            # Prepare the data for individual items
            region=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].region // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
            subregion=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].subregion // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
            city=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].city // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
            repositoryName=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].repository_name // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
            repositoryUid=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].repository_uid // \"none\"")
            workloadName=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].workload_name // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
            infectedRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].infected_rp // \"0\"")
            suspiciousRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].suspicious_rp // \"0\"")
            cleanRp=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].clean_rp // \"0\"")
            latitude=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].latitude // \"0\"")
            longitude=$(echo "$veeamONEMalwareUrl" | jq --raw-output ".data[$arrayMalware].longitude // \"0\"")
            influxData="veeam_ONE_tc_malware_items,voneserver=$voneserver,region=${region},subregion=${subregion},city=${city},repository_name=${repositoryName},repository_uid=${repositoryUid},workload_name=${workloadName} infected_rp=${infectedRp},suspicious_rp=${suspiciousRp},clean_rp=${cleanRp},latitude=${latitude},longitude=${longitude} ${lastupdate}"
            if [ "$debug" = true ]; then
                echo "$influxData"
            fi
        fi
        echo "Writing veeam_ONE_tc_malware data to InfluxDB"
        influx write \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            "$influxData"
        arrayMalware=$((arrayMalware + 1))
    done

##
# Data Platform Scorecard
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$scoresCardId/datasources"
veeamONEDPSDataSources=$(curl -X GET "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -k --silent)

    if [ "$debug" = true ]; then
        echo "Data Platform Scorecard datasources: $veeamONEDPSDataSources"
    fi

    ##
    # Best Practices Compliance => datasourceId = 109
    ##
    datasourceIdBestPractices=$(echo "$veeamONEDPSDataSources" | jq -r '.[] | select(.datasourceId == 109) | .datasourceId')
    if [ -n "$datasourceIdBestPractices" ]; then
        veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$scoresCardId/datasources/$datasourceIdBestPractices/data?forceRefresh=false"
        bestPracticesData=$(curl -X POST "$veeamONEURL" \
            -H "Authorization: Bearer $veeamBearer" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -d '' \
            -k --silent)
        lastUpdateTime=$(echo "$bestPracticesData" | jq --raw-output '.lastUpdateTimeUtc')
        lastupdate=$(date -d "$lastUpdateTime" +"%s")
        bp_passed=$(echo "$bestPracticesData" | jq --raw-output '.data[0].bp_passed // 0')
        bp_not_passed=$(echo "$bestPracticesData" | jq --raw-output '.data[0].bp_not_passed // 0')
        passed_percent=$(echo "$bestPracticesData" | jq --raw-output '.data[0].passed_percent // 0')
        influxData="veeam_ONE_tc_dps_bpCompliance,voneserver=$voneserver,widgetId=$scoresCardId bp_passed=${bp_passed},bp_not_passed=${bp_not_passed},passed_percent=${passed_percent} ${lastupdate}"
        if [ "$debug" = true ]; then
            echo "$influxData"
        fi
        echo "Writing veeam_ONE_tc_dps_bpCompliance data to InfluxDB"
        influx write \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            "$influxData"
    fi

    ##
    # Data Recovery Health => datasourceId = 111
    ##
    datasourceIdDataRecovery=$(echo "$veeamONEDPSDataSources" | jq -r '.[] | select(.datasourceId == 111) | .datasourceId')
    if [ -n "$datasourceIdDataRecovery" ]; then
        veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$scoresCardId/datasources/$datasourceIdDataRecovery/data?forceRefresh=false"
        drhData=$(curl -X POST "$veeamONEURL" \
            -H "Authorization: Bearer $veeamBearer" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -d '' \
            -k --silent)
        lastUpdateTime=$(echo "$drhData" | jq --raw-output '.lastUpdateTimeUtc')
        lastupdate=$(date -d "$lastUpdateTime" +"%s")
        healthy=$(echo "$drhData" | jq --raw-output '.data[0].healthy // 0')
        unhealthy=$(echo "$drhData" | jq --raw-output '.data[0].unhealthy // 0')
        healthy_percent=$(echo "$drhData" | jq --raw-output '.data[0].healthy_percent // 0')
        influxData="veeam_ONE_tc_dps_dataHealth,voneserver=$voneserver,widgetId=$scoresCardId healthy=${healthy},unhealthy=${unhealthy},healthy_percent=${healthy_percent} ${lastupdate}"
        if [ "$debug" = true ]; then
            echo "$influxData"
        fi
        echo "Writing veeam_ONE_tc_dps_dataHealth data to InfluxDB"
        influx write \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            "$influxData"
    fi

    ##
    # Data Protection Status => datasourceId = 112
    ##
    datasourceIdDataProtection=$(echo "$veeamONEDPSDataSources" | jq -r '.[] | select(.datasourceId == 112) | .datasourceId')
    if [ -n "$datasourceIdDataProtection" ]; then
        veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$scoresCardId/datasources/$datasourceIdDataProtection/data?forceRefresh=false"
        dpsData=$(curl -X POST "$veeamONEURL" \
            -H "Authorization: Bearer $veeamBearer" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -d '' \
            -k --silent)
        lastUpdateTime=$(echo "$dpsData" | jq --raw-output '.lastUpdateTimeUtc')
        lastupdate=$(date -d "$lastUpdateTime" +"%s")
        protected=$(echo "$dpsData" | jq --raw-output '.data[0].protected // 0')
        unprotected=$(echo "$dpsData" | jq --raw-output '.data[0].unprotected // 0')
        protected_percent=$(echo "$dpsData" | jq --raw-output '.data[0].protected_percent // 0')
        influxData="veeam_ONE_tc_dps_RPO,voneserver=$voneserver,widgetId=$scoresCardId protected=${protected},unprotected=${unprotected},protected_percent=${protected_percent} ${lastupdate}"
        if [ "$debug" = true ]; then
            echo "$influxData"
        fi
        echo "Writing veeam_ONE_tc_dps_RPO data to InfluxDB"
        influx write \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            "$influxData"
    fi

    ##
    # Backup Immutability Status => datasourceId = 113
    ##
    datasourceIdImmutability=$(echo "$veeamONEDPSDataSources" | jq -r '.[] | select(.datasourceId == 113) | .datasourceId')
    if [ -n "$datasourceIdImmutability" ]; then
        veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$scoresCardId/datasources/$datasourceIdImmutability/data?forceRefresh=false"
        immData=$(curl -X POST "$veeamONEURL" \
            -H "Authorization: Bearer $veeamBearer" \
            -H "accept: application/json" \
            -H "Content-Type: application/json" \
            -d '' \
            -k --silent)
        lastUpdateTime=$(echo "$immData" | jq --raw-output '.lastUpdateTimeUtc')
        lastupdate=$(date -d "$lastUpdateTime" +"%s")
        immutable=$(echo "$immData" | jq --raw-output '.data[0].immutable // 0')
        mutable=$(echo "$immData" | jq --raw-output '.data[0].mutable // 0')
        immutable_percent=$(echo "$immData" | jq --raw-output '.data[0].immutable_percent // 0')
        influxData="veeam_ONE_tc_dps_immutability,voneserver=$voneserver,widgetId=$scoresCardId immutable=${immutable},mutable=${mutable},immutable_percent=${immutable_percent} ${lastupdate}"
        if [ "$debug" = true ]; then
            echo "$influxData"
        fi
        echo "Writing veeam_ONE_tc_dps_immutability data to InfluxDB"
        influx write \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            "$influxData"
    fi

##
# RPO Anomalies => datasourceId = 116
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$RPOAnomaliesId/datasources/116/data?forceRefresh=false"
rpoData=$(curl -X POST "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d '[]' \
    -k --silent)

    lastUpdateTime=$(echo "$rpoData" | jq --raw-output '.lastUpdateTimeUtc')
    lastupdate=$(date -d "$lastUpdateTime" +"%s")
    declare -i arrayIndex=0
    dataCount=$(echo "$rpoData" | jq '.data | length')
    while [ $arrayIndex -lt $dataCount ]; do
        workloadName=$(echo "$rpoData" | jq -r ".data[$arrayIndex].workload_name // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
        workloadType=$(echo "$rpoData" | jq -r ".data[$arrayIndex].workload_type // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
        workloadTypeId=$(echo "$rpoData" | jq -r ".data[$arrayIndex].workload_type_id // 0")
        backupServer=$(echo "$rpoData" | jq -r ".data[$arrayIndex].backup_server // \"none\"" | awk '{gsub(/ /,"\\ ");print}')
        backupServerId=$(echo "$rpoData" | jq -r ".data[$arrayIndex].backup_server_id // 0")
        lastSuccess=$(echo "$rpoData" | jq -r ".data[$arrayIndex].last_success // \"0\"")
        missingRpo=$(echo "$rpoData" | jq -r ".data[$arrayIndex].missing_rpo // \"0\"")
        influxData="veeam_ONE_tc_rpo_anomalies,voneserver=$voneserver,workload_name=${workloadName},workload_type=${workloadType},backup_server=${backupServer},backup_server_id=${backupServerId} last_success=\"${lastSuccess}\",missing_rpo=\"${missingRpo}\",workload_type_id=${workloadTypeId} ${lastupdate}"
        if [ "$debug" = true ]; then
            echo "$influxData"
        fi
        echo "Writing veeam_ONE_tc_rpo_anomalies data to InfluxDB"
        influx write \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            "$influxData"
        arrayIndex=$((arrayIndex + 1))
    done


##
# SLA Success Compliance Heatmap => widgetId = $SLASuccessId (e.g. 105), datasourceId = 117
##
veeamONEURL="$veeamONEServer:$veeamONEPort/api/v2.2/dashboards/$dashboardId/widgets/$SLASuccessId/datasources/117/data?forceRefresh=false"
slaData=$(curl -X POST "$veeamONEURL" \
    -H "Authorization: Bearer $veeamBearer" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d '[]' \
    -k --silent)

    declare -i arrayIndex=0
    dataCount=$(echo "$slaData" | jq '.data | length')
    while [ $arrayIndex -lt $dataCount ]; do
        recordDateTime=$(echo "$slaData" | jq -r ".data[$arrayIndex].date_time")
        recordEpoch=$(date -d "$recordDateTime" +"%s")
        successRate=$(echo "$slaData" | jq -r ".data[$arrayIndex].success_rate // 0")
        isCompliance=$(echo "$slaData" | jq -r ".data[$arrayIndex].is_compliance // 0")
        success=$(echo "$slaData" | jq -r ".data[$arrayIndex].success // 0")
        notSuccess=$(echo "$slaData" | jq -r ".data[$arrayIndex].not_success // 0")
        influxData="veeam_ONE_tc_sla,voneserver=$voneserver success_rate=$successRate,is_compliance=$isCompliance,success=$success,not_success=$notSuccess $recordEpoch"
        if [ "$debug" = true ]; then
            echo "$influxData"
        fi
        echo "Writing veeam_ONE_tc_sla data to InfluxDB"
        influx write \
            -t "$veeamInfluxDBToken" \
            -b "$veeamInfluxDBBucket" \
            -o "$veeamInfluxDBOrg" \
            -p s \
            "$influxData"
        arrayIndex=$((arrayIndex + 1))
    done
