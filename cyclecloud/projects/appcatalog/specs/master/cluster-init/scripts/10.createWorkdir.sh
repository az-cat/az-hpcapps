#! /bin/bash

user=$(jetpack config cyclecloud.cluster.user.name)

workdir=/shared/home/$user/appcatalog
mkdir -p $workdir

chown -R $user. $workdir