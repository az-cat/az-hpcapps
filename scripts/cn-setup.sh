#!/bin/bash

# fail on any error
set -e

# change hpcuser uid to 1001
usermod -u 1001 hpcuser
groupmod -g 1001 hpcuser

HEADNODE=10.0.2.4

cat << EOF >> /etc/fstab
$HEADNODE:/home    /home   nfs defaults 0 0
EOF

mount -a

