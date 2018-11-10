# Guidance and framework for running HPC application on Azure

This repository provides automation scripts for creating [Azure
Batch](https://azure.microsoft.com/services/batch/) pools and Azure CycleCloud
clusters that you can use to run common high-performance
computing (HPC) applications. This repo also serves as a catalog of HPC
applications that you can use for testing. More than a dozen common
HPC applications are currently supported, including several ANSYS solvers and
Star-CCM+, and you can add more as needed as described in this guide.

**In this guide:**

- [Overview](#overview)
    - [Azure Batch considerations](#azure-batch-considerations)
    - [Azure CycleCloud considerations](#azure-cyclecloud-considerations)
- [Prerequisites](#prerequisites)
    - [Set up NFS server and network](#set-up-nfs-server-and-virtual-network)
    - [Create site-to-site VPN](#create-site-to-site-vpn)
- [Create Azure resources and
  configuration](#create-azure-resources-and-configuration)
    - [Specify subscription and location](#specify-subscription-and-location)
    - [Get Packer](#get-packer)
    - [Store the images](#store-the-images)
    - [Specify the cluster type](#specify-the-cluster-type)
    - [Identify infrastructure addresses](#identify-infrastructure-addresses)
    - [Set up analytics](#set-up-analytics)
    - [Application storage](#application-storage)
    - [Store results](#store-results)
- [Run application](#run-application)
    - [Set up an HPC application](#set-up-an-hpc-application)
    - [Add an application to the catalog](#add-an-application-to-the-catalog)
    - [Add test cases](#add-test-cases)
    - [Log data](#log-data)
- [Collect telemetry data](#collect-telemetry-data)

# Overview

The goal of this repo is to help you set up an environment in Azure
using either [Azure Batch](https://azure.microsoft.com/services/batch/) pools or
[Azure CycleCloud](https://cyclecomputing.com/products-solutions/cyclecloud/)
clusters. These compute job scheduling services connect to an HPC application
and run it efficiently on Azure so you can perform tests.

As the following figure shows, this readme describes a three-step approach:

1.  Build an image. The automation scripts use [HashiCorp
    Packer](https://www.packer.io/), an open source tool for creating build
    images. Custom images are stored in separate infrastructure blobs.

2.  Create a Batch pool or CycleCloud cluster to automate the creation of the
    compute nodes (virtual machines) used to run your HPC application.

3.  Run the application. Pools of virtual machines are created with a custom
    image on demand. You can optionally set up Azure Log Analytics to collect
    telemetry during the testing.

![](./documentation/images/architecture.png)

## Azure Batch considerations

Batch offers clustering as a service that includes an integrated scheduler.
Batch creates and manages a pool of virtual machines , installs the applications
you want to run, and schedules jobs to run on the nodes. You only pay for the
underlying resources consumed, such as the virtual machines, storage, and
networking. 

## Azure CycleCloud considerations

CycleCloud is cluster manager software that requires a one-time license. The
CycleCloud application server must be provisioned separately, a step that is
automated by the [deployment template](https://github.com/az-cat/az-hpcapps).

CycleCloud also installs and configures a scheduler—GridEngine in this case. You
can use the automation scripts to set up two types of environments:

-   A single GridEngine cluster capable of running all the apps in the HPC
    application catalog. Do this when you want to create one environment and use
    it for running all the HPC applications. The cluster accepts Azure
    Batch task files and translates them into GridEngine jobs.

-   A GridEngine cluster for a specific HPC application.

For more information, see the [CycleCloud User
Guide](https://docs.cyclecomputing.com/user-guide-launch).

# Prerequisites

Before using these scripts, do the following:

1.  Install [Azure CLI
    2.0](https://docs.microsoft.com/cli/azure/?view=azure-cli-latest). If
    running Bash on Windows, follow these
    [instructions](https://www.michaelcrump.net/azure-cli-with-win10-bash/).

> NOTE : You can also use [Cloud Shell](https://azure.microsoft.com/en-us/features/cloud-shell/) which is an easy way to start faster

2.  Install [Packer](https://www.packer.io/docs/install/index.html). Copy
    packer.exe to the directory specified in **config.json** for Packer.

3.  Install [jq](https://stedolan.github.io/jq/download/).

4.  *Optional*. Install [Batch Explorer](https://github.com/Azure/BatchExplorer) for
    scaling your Azure Batch pools.

5.  Clone the repo:
```
    git clone git@github.com:az-cat/az-hpcapps.git
```

## Set up NFS server and virtual network

A network file system (NFS) server is used as a shared storage for applications
that need to share data across message passing interface (MPI) processes. In the
GitHub repo, the deploy\_nfs.json file builds a virtual network and an NFS
server with a 1 TB data disk.

> **IMPORTANT: This step is mandatory as virtual machine pools will be created
> within this virtual network.**

The virtual network is created with these properties:

-   Default name: `hpcvnet`
-   Address space: `10.0.0.0/20`
-   Subnets:
    -   admin : `10.0.2.0/24`
    -   compute : `10.0.8.0/21`
-   NSG:
    -   admin : Allow SSH and HTTPS inbound connections

The NFS server is created with these properties:

-   Name : `nfsnode`
-   Private IP : `10.0.2.4`
-   Admin : `hpcadmin`
-   SSH Key : `~/.ssh/id_rsa.pub`
-   Data disk : `1 TB` (P30)
-   NFS mount : `/data`

**To set up the NFS server and network:**

1.  Create a resource group to host your virtual network and NFS server if
    needed:

```
    az group create --location <location> --name <resource_group>
```

- If using Azure Batch, the resource group by default is the one that includes
  your Batch account. 
- If using CycleCloud, the virtual machine and the cluster are deployed in that
  virtual network, and the cluster mounts that NFS server.

2.  Deploy the virtual network and the NFS server.

```
    ./deploy_nfs.sh <resource_group> <vnet_name>
```

  The admin account created for the NFS server is named **hpcadmin**, and your
  local public SSH key located here will be used for authentication. After the
  script is run, the full DNS name of the virtual machine is displayed.

## Create site-to-site VPN

If your HPC application needs a license server, make sure it can be accessed
from the virtual machines in the Batch pools or CycleCloud clusters. We used
site-to-site VPN to connect the license servers located in the different
subscriptions to the compute and batch resources. We considered using virtual
network peering, but found it impractical in this scenario since it needs
permission from the virtual network owners on both sides of the peering
connection.

We created subnets and gateways across two subscriptions that hosted three
resource groups and three virtual networks. We used a hub-spoke model to connect
the compute and batch resource groups and virtual networks to the ISV License
Server network. The connections were set up bidirectionally to allow for
troubleshooting.

To create a site-to-site VPN or set of site-to-site VPN tunnels between virtual
networks:

1.  Create a virtual network if you do not have one already with its
    corresponding address spaces and subnets. Repeat this again for the
    secondary virtual network and so on. Detailed instructions are located
    [here](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal).

2.  If you already have two or more virtual networks or have completed the
    creation phase above, do the following under each of the virtual networks
    you want to connect together using site-to site-VPNs.

    1.  Create a gateway subnet.

    2.  Specify the DNS server (optional).

    3.  Create a virtual network gateway.

3.  When all the gateways are completed, create your virtual network gateway
    connections [using the Azure
    portal](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-howto-vnet-vnet-resource-manager-portal).

**NOTE:** These steps work only for virtual networks in the same subscription.
If your virtual networks are in different subscriptions, you must [use
PowerShell to make the
connection](https://docs.microsoft.com/azure/vpn-gateway/vpn-gateway-vnet-vnet-rm-ps).
However, if your virtual networks are in different resource groups in the *same*
subscription, you can connect them using the portal.

For more information about virtual network peering, see these resources:

-   [General availability: Global VNet
    Peering](https://azure.microsoft.com/updates/global-vnet-peering-general-availability/)
-   [Virtual network peering
    documentation](https://docs.microsoft.com/azure/virtual-network/virtual-network-peering-overview)
-   [Create, change, or delete a virtual
    network](https://docs.microsoft.com/azure/virtual-network/manage-virtual-network)

# Create Azure resources and configuration

All of the scripts used to build an image, create a cluster, and run
applications use the same configuration file, config.json. This file is an Azure
Resource Manager template in JavaScript Object Notation (JSON) format that
defines the resources to deploy. It also defines the dependencies between the
deployed resources. Before running the automation scripts, you must update the
config.json file with your values as explained in the sections below.

**config.json**

```json
{
    "subscription_id": "",
    "location": "",
    "packer": {
        "executable": "/bin/packer",
        "base_image": "baseimage.sh"
    },
    "service_principal": {
        "tenant_id": "",
        "client_id": "",
        "client_secret": ""
    },
    "images": {
        "resource_group": "",
        "storage_account": "",
        "name": "centos74",
        "publisher": "OpenLogic",
        "offer": "CentOS-HPC",
        "sku": "7.4",
        "vm_size": "STANDARD_H16R",
        "nodeAgentSKUId": "batch.node.centos 7"
    },
    "cluster_type": "batch",
    "batch": {
        "resource_group": "",
        "account_name": "",
        "storage_account": "",
        "storage_container": "starttasks"
    },
    "cyclecloud": {
        "resource_group": "",
        "storage_account": "",
        "admin_password": "",
        "admin_user": "admin"
    },
    "infrastructure": {
        "nfsserver": "10.0.2.4",
        "nfsmount": "/data",
        "beegfs": {
            "mgmt":"x.x.x.x",
            "mount":"/beegfs"
        },
        "licserver": "",
        "network": {
            "resource_group": "",
            "vnet": "hpcvnet",
            "subnet": "compute",
            "admin_subnet": "admin"
        },
        "analytics": {
            "workspace":"",
            "key":""
        }
    },
    "appstorage": {
        "resource_group": "",
        "storage_account": "",
        "app_container": "apps",
        "data_container": "data"
    },
    "results": {
        "resource_group": "",
        "storage_account": "",
        "container": "results"
    }
}
```

## Specify subscription and location

The region where deploy your resources must match the region used by your Batch
account.

Update the following lines in config.json:

```json
{
    "subscription_id": "your subscription id",
    "location": "region where to deploy your resources"
}
```

## Get Packer

You must copy the [Packer](https://www.packer.io/intro/index.html) binary and
add it to the `bin` directory of the repo. Then retrieve the full Packer path
and update the executable value in config.json as follows:

```json
"packer": {
    "executable": "bin/packer.exe",
    "base_image": "baseimage.sh"
}
```

If you don't have one, create a service principal for Packer as follows:

```
az ad sp create-for-rbac --name my-packer
```

Outputs:

```json
{
    "appId": "99999999-9999-9999-9999-999999999999",
    "displayName": "my-packer",
    "name": "http://my-packer",
    "password": "99999999-9999-9999-9999-999999999999",
    "tenant": "99999999-9999-9999-9999-999999999999"
}
```

Using these output values, in config.json, update the values for tenant\_id,
client\_id, and client\_secret:

```json
"service_principal": {
    "tenant_id": "tenant",
    "client_id": "appId",
    "client_secret": "password"
}
```

## Store the images

To store the images, create a storage account in the same location as your Batch
account as follows:

```
az group create --location <location> --name my-images-here
az storage account create -n "myimageshere" -g my-images-here --kind StorageV2 -l <location> --sku Standard_LRS
```

Then specify the operating system, virtual machine size, and batch node agent to
be used. You can use the following command to list the agents and operating
systems supported by Azure Batch:

```
az batch pool node-agent-skus list --output table
```

To list the virtual machines sizes available in your region, run this command:

```
az vm list-sizes --location <region> --output table
```

In config.json, update the values in the **images** section:

```json
"images": {
    "resource_group": "my-images-here",
    "storage_account": "myimageshere",
    "name": "centos74",
    "publisher": "OpenLogic",
    "offer": "CentOS-HPC",
    "sku": "7.4",
    "vm_size": "STANDARD_H16R",
    "nodeAgentSKUId": "batch.node.centos 7"
}
```

## Specify the cluster type


Depending on whether you use Azure Batch or Azure CycleCloud, set the cluster
type to be `batch` or `cyclecloud` in config.json:

```
    "cluster_type": "batch",
```

If using Azure Batch, specify the resource group containing the Batch account,
the name of the Batch account, and the name of the storage account linked to the
Batch account. If you don't have a Batch account, use these
[instructions](https://docs.microsoft.com/azure/batch/batch-account-create-portal)
to create one.

```json
"batch": {
    "resource_group": "batchrg",
    "account_name": "mybatch",
    "storage_account": "mybatchstorage",
    "storage_container": "starttasks"
}
```

If using Azure CycleCloud, specify the resource group containing the account,
the name of the storage account linked to the CycleCloud account, and the logon
credentials. For example:

```json
"cyclecloud": {
    "resource_group": "cyclecloud-rg",
    "storage_account": "cyclecloudstorage",
    "admin_password": "mystrongpassword",
    "admin_user": "admin"
}
```

> **NOTE:** You do not need to provision a CycleCloud virtual machine in
> advance. The create\_cluster.sh script looks for a CycleCloud installation
> named appcatalog, and if it doesn’t find one, it provisions, installs, and
> sets up the virtual machine.

## Identify infrastructure addresses

In config.json, you must specify the IP addresses of the NFS server and license
server. If you use the default scripts to build your NFS server, the IP address
is 10.0.2.4. The default mount is **/data**. For the **network** values, specify the **resource\_group** name.
The values for **vnet**, **subnet**, and **admin\_subnet** are the same as those
used earlier when building the NFS server and virtual network.

> **NOTE:** If you have an Avere system deployed in your network, you can specify its IP and mount point in the NFS settings.

If you have a BeeGFS system setup, you can specify the management IP and the mount point (default is **/beegfs**). By default the client version 7.0 is setup inside the images.

```json
"infrastructure": {
    "nfsserver": "10.0.2.4",
    "nfsmount": "/data",
    "beegfs": {
        "mgmt":"x.x.x.x",
        "mount":"/beegfs"
    },
    "licserver": "w.x.y.z",
    "network": {
        "resource_group": "batchrg",
        "vnet": "hpcvnet",
        "subnet": "compute",
        "admin_subnet": "admin"
    }
}
```

## Set up analytics

If you want to store the telemetry data collected during the runs,
you can create an Azure [Log Analytics
workspace](https://docs.microsoft.com/azure/log-analytics/log-analytics-quick-create-workspace).
Once in place, update config.json and specify the Log Analytics workspace ID and
application key from your environment:

```json
"analytics": {
    "workspace":"99999999-9999-9999-9999-999999999999",
    "key":"key=="
}
```

## Application storage

Application packages are stored in an Azure Storage account that uses one
container for the HPC application binaries and one container for the test
cases. Each HPC application is listed in a subfolder of the **apps** folder that
contains both binaries and data. Many applications are already included in the
repo, but if you do not see the one you want, you can add one as described
[later](#add-an-application-to-the-catalog) in this guide.

In config.json, update the following:

```json
"appstorage": {
    "resource_group": "myappstore resource group",
    "storage_account": "myappstore",
    "app_container": "apps",
    "data_container": "data"
}
```

## Store results

Application outputs and logs are automatically stored inside blobs within the
Storage account and container specified in config.json. Specify the location for
your results as follows:

```json
"results": {
    "resource_group": "myresults resource group",
    "storage_account": "myresults",
    "container": "results"
}
```

# Run application

To run a specific HPC application, do the following:

1.  Build an image for that application by running the following script,
    replacing \<app-name\> with the value documented in the table below:

```
    ./build\_image.sh -a \<app-name\>
```

2.  Create a virtual machine pool for Batch or a cluster for CycleCloud by
    running the following script, replacing \<app-name\> with the value
    documented in the [table](#set-up-an-hpc-application) below:

```
    ./create\_cluster.sh -a \<app-name\>
```

3.  After the Azure Batch pool is created, scale it to the number of nodes you
    want to run on. (Note that CycleCloud does this automatically). To scale a
    pool, use Azure portal or [Batch Explorer](https://github.com/Azure/BatchExplorer).

4.  Run the HPC application you want as the following section
    describes.

## Set up an HPC application 

Instructions for setting up, running, and analyzing results for the following
HPC applications are included in this repo, and more are being added. If the
application you want is not shown here, see the next section.

| **Application**                                                          | **\<app-name\>**       | **Versions**               |
|--------------------------------------------------------------------------|------------------------|----------------------------|
| [ANSYS Mechanical](.\documentation\apps\mechanical.md)                   | mechanical             | 18.2   |
| [ANSYS Fluent](.\documentation\apps\fluent.md)                           | fluent                 | 18.2   |
| [Gromacs](.\documentation\apps\gromacs.md)                               | gromacs                | 2018.1 |

## Add an application to the catalog

Many common HPC applications are included in the repo’s catalog in the **apps**
folder. To add an application to the catalog:

1.  Under **apps**, create a new folder with the name of the application. Use
    only the lowercase letters *a* to *z*. Do not include numbers, special
    characters, or capital letters.

2.  Add a file to the folder called `install_<app-name>.sh`. The folder name
    must match the name used by `create_image.sh` to call
    `install_<app-name>.sh`.

3.  In the new `install_<app-name>.sh` file, add steps to copy the executables
    for the application and include any required installation dependencies.

    -   Our convention is to install in /opt, but anywhere other than the home
        directories or ephemeral disk will work.

    -   Pull the binaries from the Azure storage account specified in
        config.json as the `.appstorage.storage.account` property.

    -   Specify the container used for `.appstorage.app.container`.

4.  Add the following lines to your `install_<app-name>.sh` script to get the
    storage endpoint and SAS key:

```
    HPC_APPS_STORAGE_ENDPOINT="#HPC_APPS_STORAGE_ENDPOINT#"
    HPC_APPS_SASKEY="#HPC_APPS_SASKEY#"
```

> **NOTE:** The `build_image.sh` script replaces `#HPC_APPS_STORAGE_ENDPOINT#`
> and `#HPC_APPS_SASKEY#` in the install file before it is used.

After you add a new application script, use the steps provided earlier to run it. That is, build the image, create the pools or clusters, then run
the application. Make sure the value of \<app\_name\> in the commands (such as
`install_<app_name>`) exactly matches the name you used.

## Add test cases

New tests cases must be added to their **app** folder and called
`run_<CASE-NAME>.sh`. This script is run after all the resources are ready. The
following environment variables are available to use:

| **Variable**         | **Description**                                  |
|----------------------|--------------------------------------------------|
| APPLICATION          | Application name                                 |
| SHARED\_DIR          | Path to shared directory accessible by all nodes |
| CORES                | Number of MPI ranks                              |
| NODES                | Number of nodes for the task                     |
| PPN                  | Number of processes per node to use              |
| MPI\_HOSTFILE        | File containing an MPI hostfile                  |
| MPI\_MACHINEFILE     | File containing an MPI machinefile               |
| MPI\_HOSTLIST        | A comma-separated list of hosts                  |
| LICENSE\_SERVER      | Hostname/IP address of the license server        |
| OUTPUT\_DIR          | Directory for output that is uploaded            |
| STORAGE\_ENDPOINT    | Application data endpoint                        |
| SAS\_KEY             | Application data SAS key                         |
| ANALYTICS\_WORKSPACE | Log Analytics workspace ID                       |
| ANALYTICS\_KEY       | Log Analytics key                                |
| INTERCONNECT         | Type of interconnect (**tcp** or **ib**)                 |


The creator of the script is responsible for setting up the MPI environment in
addition to specifying all the MPI flags. To set up the MPI environment, run:

```
source /opt/intel/impi/*/bin64/mpivars.sh
```

> **NOTE:** The wildcard is used here to avoid issues if the Intel MPI version
> changes.

The mandatory environment variables when using Azure are I\_MPI\_FABRICS,
I\_MPI\_DAPL\_PROVIDER and I\_MPI\_DYNAMIC\_CONNECTION. We also recommend using
I\_MPI\_DAPL\_TRANSLATION\_CACHE because some applications crash if it is not
set. The environment variables can be passed to **mpirun** with the following
arguments:

```
-genv I_MPI_FABRICS shm:dapl
-genv I_MPI_DAPL_PROVIDER ofa-v2-ib0
-genv I_MPI_DYNAMIC_CONNECTION 0
-genv I_MPI_DAPL_TRANSLATION_CACHE 0
```

## Log data

The application run script uploads any data in OUTPUT\_DIR to the results
storage account. Additionally, any JSON data that is stored in
\$APPLICATION.json when the script exits is uploaded to Log Analytics. This
information includes run time or iterations per second, and can be used to track
the application performance. Ideally this data can be extracted from the program
output, but the following simple example shows a timing metric for **mpirun**:

```
start_time=$SECONDS
mpirun ...insert parameters here...
end_time=$SECONDS
# write telemetry data
cat <<EOF >$APPLICATION.json
{
"clock_time": "$(($end_time - $start_time))"
}
EOF
```

# Collect telemetry data

For each application, you can collect and push key performance indicators (KPI)
into Log Analytics. To do so, each application run script needs to build an
\$APPLICATION.json file as explained in the previous section. You should extract
from the application logs and outputs the data needed to compare application
performance, like Wall Clock Time, CPU Time, iterations, and any ranking
metrics.

In addition to application-specific data, the Azure metadata service and the
execution framework also collect node configuration data (virtual machine size,
series), Azure running context (location, batch account, and so on.), and the
number of cores and processes per nodes.

# Upcoming applications

The application catalog is growing regularly, below is the list of what is currently in our pipeline :

- Abaqus
- Ansys CFX
- Converge CFD
- GAMMES
- LAMMPS
- Linpack
- NAMD
- NWChem
- OpenFoam
- Pamcrash
- Quantum Espresso
- StarCCM

Send us a note as an issue in the repo if you want to have a need for others applications.

