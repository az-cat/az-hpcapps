#!/bin/bash
array_size=$1
vmSize=$(curl -s -H Metadata:true "http://169.254.169.254/metadata/instance?api-version=2017-12-01" | jq -r '.compute.vmSize')
echo "vmSize is $vmSize"
output_file=${OUTPUT_DIR}/stream.log

if [ "${vmSize,,}" = "standard_hb60rs" ]; then
    $APP_PACKAGE_DIR/Stream/stream_zen_double $1 0 1,5,9,13,17,21,25,29,33,37,41,45,49,53,57 | tee ${output_file}
fi

if [ -f "${output_file}" ]; then

    version=$(grep "Revision" ${output_file} | cut -d' ' -f 4)
    array_size=$(grep "Array size =" ${output_file} | cut -d' ' -f 4)
    threads=$(grep "Number of Threads counted" ${output_file} | cut -d' ' -f 6)
    clock_ticks=$(grep " clock ticks)" ${output_file} | cut -d' ' -f 5)
    copy=$(grep "Copy:" ${output_file} | sed 's/  */ /g' | cut -d' ' -f 2)
    scale=$(grep "Scale:" ${output_file} | sed 's/  */ /g' | cut -d' ' -f 2)
    add=$(grep "Add:" ${output_file} | sed 's/  */ /g' | cut -d' ' -f 2)
    triad=$(grep "Triad:" ${output_file} | sed 's/  */ /g' | cut -d' ' -f 2)

    cat <<EOF >$APPLICATION.json
    {
    "bench":"stream",
    "version": "$version",
    "array_size": $array_size,
    "threads": $threads,
    "clock_ticks": $clock_ticks,
    "copy": $copy,
    "scale": $scale,
    "add": $add,
    "triad": $triad
    }
EOF
fi

