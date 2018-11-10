# Tutorial

## Goal

The goal for this tutorial is walk through all the step required to run
applications.  This involves creating an image, building a pool or cluster,
running the application and viewing the results.

You can choose whether to run with CycleCloud or Azure Batch (or try both if
time permits).  The same instructions apply to both (except the configuration
file).

If you are using Azure Batch it is advised to download and install [Batch
    Labs](https://github.com/Azure/BatchExplorer) for scaling your Azure Batch pools.

## Step-by-step instructions

This tutorial can all be run from the Cloud Shell (`shell.azure.com`).
Alternatively the Ubuntu Bash can be used on Windows or a Linux VM but this
requires installing the Azure CLI and
[jq](https://stedolan.github.io/jq/download/).

Clone the git repository to get started:

    git clone git@github.com:az-cat/az-hpcapps.git

### Setting up the config file

A single configuration file is required to run (the default file is
`config.json` although all the scripts have the `-c` to specify a different
file.  For this tutorial a `setup.sh` script has been created in order to
interactively create this file and create the resources required.  The
`setup.sh` will look for items that are not set and so can be run with a
partially filled in config file if you would like to use existing resources
(e.g. an Azure Batch account which has a larger quota).  The template config is
in the root folder called `template-config.json` and below is some information
on the options:

* subscription_id  
  This is the subscription to run in.
* location  
  The location to be used for all resources.
* resource_group   
  This will be the resource group used by the `setup.sh` script for anything
  that is created.
* packer  
  This is the location of the packer executable and the base image to use before
  installing applications.  This is dependent on the OS/distribution.
* service_principal  
  This is required by packer to run.  The service principal will not be used by
  any of the scripts (`build_image.sh`, `create_cluster.sh`, or `run_app.sh`) if
  launched while logged in to the correct subscription.
* images  
  This stores the information about the distribution to use and the storage
  account to store the images created by packer.  The `setup.sh` script can set
  these values for one the following options: CentOS 7.1 (H16r), CentOS 7.4
  (H16r) or Ubuntu 16.04 (NC24r).
* cluster_type  
  The options here are `batch` or `cyclecloud`.  This value will determine the
  method to run applications.
* __infrastructure__  
  The `setup.sh` script will prompt for a VNET name here and an ARM template
  will be run to create the VNET and NFS server.  
  This section also contains a section for Log Analytics where you should insert
  the `workspace` and `key`.  This is not automated by the `setup.sh` script and
  must be created with the Azure Portal.
* __appstorage__  
  For the purpose of this tutorial an app storage account with a SAS key will be
  provided.  This contains the application executables and the data for the
  cases to run.
* results  
  This is the storage account/container for the results to be stored from runs.

### Build an image

The `build_image.sh` command:

    $ ./build_image.sh -h

    Usage:
    build_image.sh -c config.json -a APPNAME
        -c: config file to use
        -a: application (application list)
        -h: help

The first step is to create a image for the application.  Execute the following
to build an image for OpenFOAM:

    ./build_image.sh -a openfoam

This will use run packer and generate the image.  It uses the marketplace image
specified in the config file, runs the base image script for standard setup
(default is `packer/baseimage.sh`) and then runs the install script for the
application located in `apps/<application-name>/install_<application-name>.sh`.
Take time to familiarize yourself with these files while packer is running.

### Create the cluster/pool

The `create_cluster.sh` command:

    $ ./create_cluster.sh -h

    Usage:
    create_cluster.sh -c config.json -a APPNAME
        -c: config file to use
        -a: application (application list)
        -h: help

The next step is to create a pool if using Azure Batch or set up a cluster for
Cyclecloud.

    ./create_cluster.sh -a openfoam

This step will deploy the CycleCloud application server if it is not already
available.

If you are running with Azure Batch you should see the pool once this has
completed.  There is no auto scaling set up on the Azure Batch pools and so this
should be done either through the Azure Portal or with Batch Labs.

If you are running with Azure CycleCloud, `create_cluster` searches for a
Azure container running CycleCloud in the resource group. If it does not exist, it will set
one up. This takes about 5mins. After the CycleCloud container has been started,
`create_cluster` imports and starts a Grid Engine cluster called
appcatalog_gridengine. 



### Submit a task

The `run_app.sh` command:

    $ ./run_app.sh -h

    Usage:
    run_app.sh -c config.json -a APPNAME
        -c: config file to use
        -a: application (application list)
        -j: job name (create job if not exists) - if not specified application name is used
        -t: task name - if not specified automatically built
        -s: script to run
        -n: number of nodes
        -m: machine_size
        -p: processes per node
        -x: script flags to pass
        -h: help

The OpenFOAM test has pre-generated models decomposed for each number of MPI
ranks.  Many decompositions are available on the `cathpcappsncus` storage
account in the `data` container.  Details in the OpenFOAM specific document
describe how to the case was generated.

This command line will run on 1 node with 16 processes per node.  The `-x` flag
is passed through to the `run_motorbike.sh` script and is used to select the
case to download.

    ./run_app.sh \
        -a openfoam \
        -s motorbike \
        -n 1 \
        -p 16 \
        -t motorbike20M_1x16 \
        -x 20


`run_app.sh` generates a task file that is submitted to either Batch or the
CycleCloud cluster, depending on what was specified in your `config.json`. 

You can track the run of the application through the CycleCloud application
server or Batch Labs.

While this is running familiarized yourself with the application run script,
`apps/openfoam/run_motorbike.sh`.  The script includes downloading the case,
setting all the MPI environment variables required for Azure and storing salient
information into the `$APPLICATION.json` (`openfoam.json` in this case) which is
the data going into log analytics.

### View the results

Log in to the Azure Portal and try the following query:

    openfoam_CL 
    | where model_s == "motorbike" 
    | summarize percentile(todouble(cpu_time_s), 99) by Nodes_s, ppn_s
    | order by toint(Nodes_s) asc
    | render timechart

## Extensions

As an extension you can try deploying with CycleCloud if Azure Batch was used or
vice versa.  Alternatively you can try other applications already implemented or
try one of the following:

### Select number of iteration of the OpenFOAM solver

The OpenFOAM motorbike cases are set to run for 250 iterations and this is
controlled by the `system/controlDict` config file inside the case directory.
Edit OpenFOAM run script to add a parameter to select the the number of
iterations of the solver to run.  

Hints:

* This sed script can be run the root directory of the case to set the number of
  iterations to `$niters`:  
  `sed -i "s/^endTime .*;$/endTime ${niters};/g" system/controlDict`
* The `-x` parameter for `run_app.sh` contains parameters to be passed to the
  `apps/<app-name>/run_<app-script>.sh`.  This argument should be in quotes to
  pass multiple parameters separated by spaces.

### Auto scale batch pools

There are no currently parameters exposed in Azure Batch for the number of nodes
a task requires.  This means that an auto-scale formula within Azure Batch
cannot be used (unless all tasks use the same number of nodes).   Here is a link
to a script that uses the Python Batch API and can be deployed to scale pools in
an Azure Batch account:

    https://github.com/edwardsp/AzureBatchAutoScale

### Add another application

Create the directory inside apps and add an install and run script.
