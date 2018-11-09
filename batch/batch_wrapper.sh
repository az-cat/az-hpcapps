#!/bin/bash
set +x
echo "Command to launch: $@"

export MPI_HOSTLIST=$AZ_BATCH_HOST_LIST
export MPI_HOSTFILE=$AZ_BATCH_TASK_WORKING_DIR/hostfile
tr ',' '\n' <<< $MPI_HOSTLIST > $MPI_HOSTFILE
export MPI_MACHINEFILE=$AZ_BATCH_TASK_WORKING_DIR/machinefile
sed "s/\$/:$PPN/g" $MPI_HOSTFILE > $MPI_MACHINEFILE
export CORES=$(($NODES * $PPN))

export OUTPUT_DIR=$AZ_BATCH_TASK_WORKING_DIR/output
mkdir $OUTPUT_DIR

export SHARED_DIR=/data/$AZ_BATCH_JOB_ID/$AZ_BATCH_TASK_ID
mkdir -p $SHARED_DIR

is_rdma_capable()
{
    grep -o '^OS.EnableRDMA=y' /etc/waagent.conf
    return $?
}

export INTERCONNECT=tcp
if is_rdma_capable; then
    export INTERCONNECT=ib
fi

chmod +x $1
./$@

if [ $? != 0 ]; then
    echo "ERROR: Failed to run '$@''"
    exit 1
fi

send_to_loganalytics() {
# upload a json file in to a log analytics custom table
# https://docs.microsoft.com/en-us/azure/log-analytics/log-analytics-data-collector-api

    workspace_id=$1
    logName=$2
    key=$3
    jsonFile=$4

    echo "uploading $jsonFile to Azure Log Analytics workspace $workspace_id"
    content=$(cat $jsonFile | iconv -t utf8)
    content_len=${#content}

    rfc1123date="$(date -u +%a,\ %d\ %b\ %Y\ %H:%M:%S\ GMT)"

    string_to_hash="POST\n${content_len}\napplication/json\nx-ms-date:${rfc1123date}\n/api/logs"
    utf8_to_hash=$(echo -n "$string_to_hash" | iconv -t utf8)

    signature="$(echo -ne "$utf8_to_hash" | openssl dgst -sha256 -hmac "$(echo "$key" | base64 --decode)" -binary | base64)"
    auth_token="SharedKey $workspace_id:$signature"

    curl   -s -S \
            -H "Content-Type: application/json" \
            -H "Log-Type: $logName" \
            -H "Authorization: $auth_token" \
            -H "x-ms-date: $rfc1123date" \
            -X POST \
            --data "$content" \
            https://$workspace_id.ods.opinsights.azure.com/api/logs?api-version=2016-04-01
}

mpi_stats="{}"
if [ -f "stats.ipm" ]; then
    cp stats.ipm ${OUTPUT_DIR}
    mpi_stats=$(awk '/^# MPI/ { gsub("MPI_", "", $2); if ($5 > 1.0) print $2,$3,$4,$5,$6}' stats.ipm | jq --slurp --raw-input --raw-output 'split("\n")|.[:-1]|map(split(" "))|map({(.[0]): {"time":.[1]|tonumber,"calls":.[2]|tonumber,"mpip":.[3]|tonumber,"Wallp":.[4]|tonumber}})|reduce .[] as $item ({}; . + $item)')
fi

app_metrics=$APPLICATION.json
if [ -f "$app_metrics" ]; then

    app_perf=$(cat $app_metrics)
    compute=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-12-01" | jq '.compute')
    jq -n '.Compute=$compute | .Application=$app | .Nodes=$nodes | .ppn=$ppn | .MPI=$mpi | . += $app_perf' \
        --argjson compute "$compute" \
        --argjson app_perf "$app_perf" \
        --argjson mpi "$mpi_stats" \
        --arg app $APPLICATION \
        --arg nodes $NODES \
        --arg ppn $PPN  > $OUTPUT_DIR/telemetry.json

    echo "Sending application metrics to log analytics"
    send_to_loganalytics $ANALYTICS_WORKSPACE $APPLICATION $ANALYTICS_KEY $OUTPUT_DIR/telemetry.json
fi
