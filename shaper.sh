#!/bin/bash

BURST="burst 15k"
LAN=ens32

function shaper_cmd {

if [ "$1" = "stop" ]; then
        tc qdisc del dev $LAN root 2> /dev/null
        iptables -t mangle -F
        iptables -t mangle -X
fi


if [ "$1" = "start" ]; then

    shaper_cmd stop

#Główna kolejka
    tc qdisc add dev $LAN root handle 1:0 htb default 3 r2q 1

#Limit dla interfejsu sieciowego
    tc class add dev $LAN parent 1:0 classid 1:1 htb rate 900Mbit ceil 900Mbit $BURST quantum 1500

#Limit dla wszystkich nie sklasyfikowanych
    tc class add dev $LAN parent 1:1 classid 1:3 htb rate 1Mbit ceil 50Mbit prio 7 $BURST quantum 1500
    tc qdisc add dev $LAN parent 1:3 sfq perturb 10

#Limit dla portu źródłowego: 53 (DNS)
    tc class add dev $LAN parent 1:1 classid 1:4 htb rate 1Mbit ceil 100Mbit $BURST prio 2 quantum 1500
    tc qdisc add dev $LAN parent 1:4 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 53 -j CLASSIFY --set-class 1:4

#Limit dla portów źródłowych: 25,587,465 (SMTP)
    tc class add dev $LAN parent 1:1 classid 1:5 htb rate 1Mbit ceil 100Mbit $BURST prio 4 quantum 1500
    tc qdisc add dev $LAN parent 1:5 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 25 -j CLASSIFY --set-class 1:5
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 587 -j CLASSIFY --set-class 1:5
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 465 -j CLASSIFY --set-class 1:5

#Limit dla portów źródłowych 80,443 (WWW)
    tc class add dev $LAN parent 1:1 classid 1:6 htb rate 1Mbit ceil 100Mbit $BURST prio 3 quantum 1500
    tc qdisc add dev $LAN parent 1:6 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 443 -j CLASSIFY --set-class 1:6
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 80 -j CLASSIFY --set-class 1:6

#Limit dla portu źródłowego 22 (SSH)
    tc class add dev $LAN parent 1:1 classid 1:7 htb rate 2Mbit ceil 10Mbit $BURST prio 1 quantum 1500
    tc qdisc add dev $LAN parent 1:7 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 22 -j CLASSIFY --set-class 1:7

#Limit dla portów źródłowych 143,993 (IMAP)
    tc class add dev $LAN parent 1:1 classid 1:8 htb rate 2Mbit ceil 100Mbit $BURST prio 4 quantum 1500
    tc qdisc add dev $LAN parent 1:8 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 143 -j CLASSIFY --set-class 1:8
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 993 -j CLASSIFY --set-class 1:8

#Limit dla portów źródłowych 110,995 (POP3)
    tc class add dev $LAN parent 1:1 classid 1:9 htb rate 2Mbit ceil 50Mbit $BURST prio 5 quantum 1500
    tc qdisc add dev $LAN parent 1:9 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 110 -j CLASSIFY --set-class 1:9
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 995 -j CLASSIFY --set-class 1:9
    
#Limit dla portu źródłowego 8080 (MGMT)
    tc class add dev $LAN parent 1:1 classid 1:10 htb rate 2Mbit ceil 100Mbit $BURST prio 1 quantum 1500
    tc qdisc add dev $LAN parent 1:10 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 8080 -j CLASSIFY --set-class 1:10

#Limit dla portu źródłowego 21 (FTP)
    tc class add dev $LAN parent 1:1 classid 1:11 htb rate 1Mbit ceil 50Mbit $BURST prio 6 quantum 1500
    tc qdisc add dev $LAN parent 1:11 sfq perturb 10
    iptables -t mangle -A OUTPUT -o $LAN -p tcp --sport 21 -j CLASSIFY --set-class 1:11

fi


if [ "$1" = "stats" ]; then
        currentdate=$(date "+%H:%M:%S-%d%m%Y")
        echo "Ruch wychodzący"
        iptables -t mangle -nvL OUTPUT |tail -n +3 |awk '{print $2":"$11}'| awk -F\: '{print "Source port: "$                                                                                               3" - "$1"B"}'
fi


if [ "$1" = "status" ]; then

    iptables -t mangle -nvL

    echo
    echo "$LAN interface"
    echo "----------------"
    for TC_OPTIONS in qdisc class; do
        if [ ! -z "$LAN" ]; then
            echo
            echo "$TC_OPTIONS"
            echo "------"
            tc -s -d $TC_OPTIONS show dev $LAN
        fi
    done
fi

}
case "$1" in

    'stop')
        shaper_cmd stop
    ;;
    'start')
        shaper_cmd start
    ;;
    'restart')
        shaper_cmd stop
        shaper_cmd start
    ;;
    'status')
        shaper_cmd status
    ;;
    'stats')
        shaper_cmd stats
    ;;
        *)
        echo -e "\nUsage: shaper.sh start|stop|status|stats"
    ;;

esac
