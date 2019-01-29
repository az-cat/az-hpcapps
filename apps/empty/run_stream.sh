#!/bin/bash
array_size=$1
output_file=${OUTPUT_DIR}/stream.log

if [ "$VMSIZE" = "standard_hb60rs" ]; then
    wget -q "${HPC_APPS_STORAGE_ENDPOINT}/bench/stream_zen_double?${HPC_APPS_SASKEY}" -O stream_zen_double
    chmod +x stream_zen_double
    export OMP_DISPLAY_ENV=TRUE
    export OMP_NUM_THREADS=15
    export OMP_PROC_BIND=SPREAD
    export OMP_PLACES='{1},{5},{9},{13},{17},{21},{25},{29},{33},{37},{41},{45},{49},{53},{57}'
    stream_zen_double | tee ${output_file}
elif [ "$VMSIZE" = "standard_hc44rs" ]; then
    export OMP_DISPLAY_ENV=TRUE
    export OMP_PROC_BIND=SPREAD
    wget -q "${HPC_APPS_STORAGE_ENDPOINT}/bench/stream_sky_double?${HPC_APPS_SASKEY}" -O stream_sky_double
    chmod +x stream_sky_double
    stream_sky_double | tee ${output_file}
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

