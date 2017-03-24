#! /bin/sh
#
# spot_attackers.sh
# Copyright (C) 2017 Stefano Stella <mprenditore@gmail.com>
#
# Distributed under terms of the GPLv3 license.
#

RATE_LOG="/tmp/http_rate.log"
HIGH_LOG="/tmp/attacker_ip.log"
WHITELIST="127.0.0.1" # separate values by '\|'
TABLE="table"

while true; do
    HIGH_CON=$(echo "show table $TABLE" | socat unix-connect:/var/run/haproxy.sock stdio|sort -n -t\= -k6 -r| grep -v "$WHITELIST"| head -1);
    HIGH_IP=$(echo $HIGH_CON | awk '{print $2}'| cut -d= -f2)
    HIGH_RATE=$(echo $HIGH_CON | awk '{print $6}'| cut -d= -f2)
    if [ ! -z "$HIGH_RATE" ]; then
        echo `date +%s` $HIGH_IP $HIGH_RATE >> $RATE_LOG
        if [ $HIGH_RATE -gt 100 ]; then
            echo `date +%s` $HIGH_IP $HIGH_RATE >> $HIGH_LOG
        fi
        # echo `date +%s` $HIGH_IP $HIGH_RATE
    fi
    sleep 1
done
