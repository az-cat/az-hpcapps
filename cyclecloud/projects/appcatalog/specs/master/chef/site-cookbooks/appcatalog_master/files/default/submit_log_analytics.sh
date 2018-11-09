#!/bin/bash
set +x
echo "Running epilog to upload data into Analsyis"

echo "ENV-WORKSPACE: $ANALYTICS_WORKSPACE"
echo "ENV-APPLICATION: $APPLICATION"
echo "ENV-ANALYTICS_KEY: $ANALYTICS_KEY"
echo "ENV-OUTPUT_DIR: $OUTPUT_DIR"

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


app_metrics=$APPLICATION.json
if [ -f "$app_metrics" ]; then

    cluster_type=cycle
    app_perf=$(cat $app_metrics)

    compute=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-12-01" | jq '.compute')
    jq -n '.Compute=$compute | .Application=$app | .Nodes=$nodes | .ppn=$ppn | .cluster_type=$cluster_type | . += $app_perf' \
        --argjson compute "$compute" \
        --argjson app_perf "$app_perf" \
        --arg app $APPLICATION \
        --arg nodes $NODES \
        --arg cluster_type $cluster_type \
        --arg ppn $PPN  > $OUTPUT_DIR/telemetry.json

    echo "Sending application metrics to log analytics"
    send_to_loganalytics $ANALYTICS_WORKSPACE $APPLICATION $ANALYTICS_KEY $OUTPUT_DIR/telemetry.json
fi