#!/bin/bash
pam_case=$1
threads=$2
mpi=$3
VERSION=2018

if [ -z "$mpi" ]; then
    mpi="impi"
fi

if [ -z "$threads" ]; then
    threads="1"
fi

start_time=$SECONDS

extension="${pam_case##*.}"
case_name="${pam_case%%.*}"

echo "downloading case ${pam_case}..."
wget -q "${STORAGE_ENDPOINT}/pamcrash-benchmarks/${pam_case}?${SAS_KEY}" -O ${pam_case}
case "$extension" in
    gz)
        gunzip ${pam_case}
        ;;
    zip)
        unzip ${pam_case}
        ;;
esac

# if there is a directory named with the case name, move all files one level up
if [ -d $case_name ]; then
    mv -f ./$case_name/* .
fi

end_time=$SECONDS
download_time=$(($end_time - $start_time))
echo "Download time is ${download_time}"

source /etc/profile # so we can load modules

export PAMHOME=/opt/esi-group
export PAM_LMD_LICENSE_FILE=27000@${LICENSE_SERVER}

case "$VERSION" in
    2017)
        export PAMCRASH=$PAMHOME/pamcrash_safe/2017.0.2/pamcrash
        ;;
    2018)
        export PAMCRASH=$PAMHOME/pamcrash_safe/2018.01/Linux_x86_64/bin/pamcrash
        ;;
    *)
        echo "unknown version $VERSION"
        exit 1
        ;;
esac

function setup_impi()
{
    # setup Intel MPI environment for Infiniband
    module load mpi/impi-2018.4.274
    source $MPI_BIN/mpivars.sh
    export MPI_DIR=$MPI_BIN
    PAM_MPI=impi-5.1.3
    case "$INTERCONNECT" in
        ib)
            export MPI_OPTIONS="-hosts $MPI_HOSTLIST -perhost ${PPN} -genv I_MPI_FABRICS shm:dapl -genv I_MPI_DAPL_PROVIDER ofa-v2-ib0 -genv I_MPI_DYNAMIC_CONNECTION 0 -genv I_MPI_FALLBACK_DEVICE 0"
            ;;
        sriov)
            # I_MPI_DEBUG=4
            export MPI_OPTIONS="-hosts $MPI_HOSTLIST -perhost ${PPN} -genv I_MPI_FABRICS shm:ofa -genv I_MPI_DYNAMIC_CONNECTION 0 -genv I_MPI_FALLBACK_DEVICE 0 $impi_options"
            ;;
        tcp)
            ;;
    esac
}

function setup_pmpi()
{
    module load mpi/pmpi
    export MPI_DIR=$MPI_BIN
    PAM_MPI=platform-9.1.4

    case "$INTERCONNECT" in
        ib)
            ;;
        sriov)
            export MPI_OPTIONS="-hostfile $MPI_MACHINEFILE -prot -aff -affopt=vv -e MPI_IB_PKEY=$IB_PKEY"
            ;;
        tcp)
            ;;
    esac

}


case "$mpi" in
    impi)
        setup_impi
        ;;
    pmpi)
        setup_pmpi
        ;;
    *)
        setup_impi
        ;;
esac


$PAMCRASH -np ${CORES} \
    -nt $threads \
    -lic CRASHSAF \
    -mpi $PAM_MPI \
    -mpiexe mpirun \
    -mpidir $MPI_DIR \
    -mpiext '$MPI_OPTIONS' \
    ${case_name}.pc

end_time=$SECONDS
task_time=$(($end_time - $start_time))

# extract telemetry
case_output=../stdout.txt
if [ -f "${case_output}" ]; then

    line=$(grep " ELAPSED TIME" ${case_output} | tail -1)
    printf -v elapsed_time '%.2f' $(echo $line | cut -d' ' -f3)

    line=$(grep " CPU TIME" ${case_output} | tail -1)
    printf -v cpu_time '%.2f' $(echo $line | cut -d' ' -f3)

    version=$(grep "| Version" ${case_output} | cut -d':' -f2| cut -d'|' -f1 | xargs)
    precision=$(grep "| Precision" ${case_output} | cut -d':' -f2| cut -d'|' -f1 | xargs)

    mpi_version=$(mpirun -version | head -n 1)
    cat <<EOF >$APPLICATION.json
    {
    "version": "$version",
    "mpi_version": "$mpi_version",
    "pam_mpi": "$PAM_MPI",
    "model": "$case_name",
    "precision": "$precision",
    "elapsed_time": $elapsed_time,
    "cpu_time": $cpu_time,
    "task_time": $task_time,
    "download_time": $download_time
    }
EOF
fi
