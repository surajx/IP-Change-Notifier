#!/bin/bash
function valid_ip()
{
    local  ip=$1
    local  stat=1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]
    then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

cd `echo $0 | sed 's,[^/]*$,,'` 

if [ ! -f ./script.cfg ]
then
	echo "ERROR:script.cfg file missing" > err.log
	exit
fi

USER=`cat script.cfg | grep ADMIN_USERNAME | grep -v '#' | cut -d'=' -f2`
PASS=`cat script.cfg | grep ADMIN_PASS | grep -v '#' | cut -d'=' -f2`
ROUTER_IP=`cat script.cfg | grep ROUTER_INTERNAL_IP | grep -v '#' | cut -d'=' -f2`
EMAIL=`cat script.cfg | grep TO_EMAIL | grep -v '#' | cut -d'=' -f2`
PPPOE_IF_NAME=`cat script.cfg | grep PPPOE_IF_NAME | grep -v '#' | cut -d'=' -f2`

expect -c "
   spawn telnet $ROUTER_IP
   expect \"Login:\"
   send \"$USER\r\"
   expect \"Password:\"
   send \"$PASS\r\"
   expect \"\\\\>\"
   send \"ip show interface $PPPOE_IF_NAME\r\"
   expect -re \"\\\\>\"
   send \"logout\"
" > telnet.log
IP_ADDR=`cat telnet.log | grep Ipaddr | cut -d':' -f2 | sed 's/ //g'`
PREV_IP_ADDR=`cat prev_ip.ip`
if [[ "$IP_ADDR" == "$PREV_IP_ADDR" ]]
then
   exit
fi
if [[ `valid_ip $IP_ADDR` -eq 0 ]]
then
   echo $IP_ADDR > prev_ip.ip
   echo "$IP_ADDR" | mailx -s "IP Changed!!" $EMAIL
else
   touch err.log
   echo `date`": IP address received not valid, retry in 15 min." >> err.log
fi
