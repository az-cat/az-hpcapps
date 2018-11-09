# Add application specific settings

# We have to change the hostname so it will be shorter than the one set by Azure Batch which breaks the FlexLM licence checking part of Mechanical
function sethostname
{
        # change the hostname, use the IP to name it in hexa like 0A000004
        IP=`ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
        W1=$(echo $IP | awk -F"." '{print $1}')
        W1=$(printf '%02x' $W1)
        W2=$(echo $IP | awk -F"." '{print $2}')
        W2=$(printf '%02x' $W2)
        W3=$(echo $IP | awk -F"." '{print $3}')
        W3=$(printf '%02x' $W3)
        W4=$(echo $IP | awk -F"." '{print $4}')
        W4=$(printf '%02x' $W4)

        newname='IP'$W1$W2$W3$W4
        hostname $newname
        hostname
}

sethostname
