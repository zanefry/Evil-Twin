# Evil Twin
Project demonstrating an evil twin attack on WPA2-Personal networks. The attack exploits the fact that many devices silently try to connect to access points with SSIDs they've connected to in the past. The script listens for attempted connections to the malicious AP and grabs the hashes for offline cracking.

depends:
    airmon-ng
    tshark
    hcxtools

