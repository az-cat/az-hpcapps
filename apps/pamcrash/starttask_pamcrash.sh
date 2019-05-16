
# Stop WAAGENT to save cycles
systemctl stop waagent.service
systemctl status waagent.service

case "$VMSIZE" in
    "standard_hb60rs"|"standard_hc44rs")
        sed -i 's/LOAD_EIPOIB=yes/LOAD_EIPOIB=no/g' /etc/infiniband/openib.conf
        /etc/init.d/openibd restart
#        /etc/init.d/openibd force-stop
        /etc/init.d/openibd status
        ;;
esac