# Add application specific settings
HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"

if [ "${vmSize,,}" = "standard_hb60rs" ]; then
    # Install OpenMPI
    if [ ! -d "/opt/openmpi" ]; then
        echo "download OpenMPI 4.0.x package"
        pushd /opt
        PACKAGE=openmpi-4.0.0.tgz
        wget -q "${HPC_APPS_STORAGE_ENDPOINT}/openmpi/${PACKAGE}?${HPC_APPS_SASKEY}" -O - | tar zx

        yum install -y hwloc

        popd
    fi

    # check if IB is up
    status=$(ibv_devinfo | grep "state:")
    status=$(echo $status | cut -d' ' -f 2)
    if [ "$status" = "PORT_DOWN" ]; then
        echo "ERROR: IB is down"
        ibv_devinfo 
        exit 1
    fi
fi