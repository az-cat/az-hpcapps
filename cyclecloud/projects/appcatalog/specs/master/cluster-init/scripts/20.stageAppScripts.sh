#! /bin/bash

destinationDir=/shared/appcatalog
mkdir -p $destinationDir
cp -a $CYCLECLOUD_SPEC_PATH/files/apps $destinationDir/

chmod -R a+rwX $destinationDir