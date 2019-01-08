#!/bin/bash
MODEL=$1

echo "----- get Abaqus test case $MODEL -----"
wget -q "${STORAGE_ENDPOINT}/abaqus-benchmarks/${MODEL}.inp?${SAS_KEY}" -O ${MODEL}.inp

if [ "$INTERCONNECT" == "ib" ]; then
    export mpi_options="-env IMPI_FABRICS=shm:dapl -env I_MPI_DAPL_PROVIDER=ofa-v2-ib0 -env I_MPI_DYNAMIC_CONNECTION=0 -env I_MPI_FALLBACK_DEVICE=0"
    export MPI_RDMA_MSGSIZE="16384,1048576,4194304"
elif [ "$INTERCONNECT" == "sriov" ]; then
    export mpi_options="-env IMPI_FABRICS=shm:ofa -env I_MPI_FALLBACK_DEVICE=0"
    #export MPI_RDMA_MSGSIZE="16384,1048576,4194304"
else
    export mpi_options="-env IMPI_FABRICS=shm:tcp"
fi

#define hosts in abaqus_v6.env file
# mp_file_system=(LOCAL,LOCAL)
# verbose=3
cat <<EOF >abaqus_v6.env
mp_host_list=[['$(sed "s/,/',$PPN],['/g" <<< $MPI_HOSTLIST)',$PPN]]
mp_host_split=8
scratch="$AZ_BATCH_TASK_WORKING_DIR"
mp_mpirun_options="$mpi_options"
license_server_type=FLEXNET
abaquslm_license_file="27000@${LICENSE_SERVER}"
EOF

# need to unset CCP_NODES otherwise Abaqus think it is running on HPC Pack
unset CCP_NODES

source /opt/intel/impi/*/bin64/mpivars.sh
export MPI_ROOT=$I_MPI_ROOT


ABQ2017="/opt/abaqus/applications/DassaultSystemes/SimulationServices/V6R2017x/linux_a64/code/bin/SMALauncher"
JOBNAME=$MODEL-$CORES

start_time=$SECONDS
$ABQ2017 -j $JOBNAME -input $MODEL.inp -cpus $CORES -interactive 
end_time=$SECONDS
task_time=$(($end_time - $start_time))


completed=$(grep "THE ANALYSIS HAS COMPLETED SUCCESSFULLY" $JOBNAME.sta)
if [[ ! -z $completed ]]; then 
    cat <<EOF >$APPLICATION.json
    {
    "version": "2017.x",
    "model": "$MODEL",
    "task_time": $task_time    
    }
EOF
fi

