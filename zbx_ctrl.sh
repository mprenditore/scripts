#! /bin/bash
#
# zbx_srv.sh
# Copyright (C) 2016 Stefano Stella <mprenditore@gmail.com>
#
# This tool is used to send actions to all threads per worker type
# on zabbix services. Ex: zabbix_server -R log_level_increase=PID 
#
# Distributed under terms of the MIT license.
#

usage (){
    echo "Usage: $0 <type> <target> <action>"
    echo ""
    echo "<type>     server|proxy"
    echo "<target>   alerter|configuration|syncer|db|watchdog|discoverer|escalator|history"
    echo "           syncer|housekeeper|http|poller|icmp|pinger|poller|proxy|poller|self-monitoring"
    echo "           task|manager|timer|trapper|unreachable|poller"
    echo "<action> config_cache_reload|housekeeper_execute|log_level_increase|log_level_decrease"
    echo ""
    echo "Example:"
    echo "$0 server discoverer log_level_decrease"
}

if [ "$#" -ne 3 ]; then
    usage
    exit 0
fi

TYPE=$1
TARGET=$2
ACTION=$3
VAR=`ps ax | grep zabbix_$TYPE | grep -v grep | awk '{print $6,$7}'| awk -F'#' '{print $1}' | awk -F'[' '{print $1}' | sort | uniq | grep -v "^ " | awk '{$1=$1};1' | awk -F'\n' '{print "\""$1"\""}'`

TARGET_N=(`ps ax | grep zabbix_$TYPE | grep "$TARGET" | awk '{print $1}'`)
for tgt in ${TARGET_N[*]}; do
    echo "zabbix_$TYPE -R ${ACTION}=$tgt"
done

