#!/usr/bin/bash

# This script is to pull yesterday's pcap files from cloud, append ".pcap" if necessary, run suricata in offline mode against them, and mv eve.json output to /var/log/suricata/

# CHANGE ME
sshkey=<path to sshkey>  #"/home/dshield/.ssh/sensor.pem"
cloud_pcap=<path to pcaps on honeypot>  #"ubuntu@35.175.174.46:/srv/NSM/dailylogs/$(date -d "yesterday" '+%Y-%m-%d')/*"
cloud_port=<honeypot ssh port>  #"2222"
pcap_dir=<path to pcaps on local server>  #"/var/log/pcaps/$(date -d "yesterday" '+%Y-%m-%d')"
bpf_filter=<path to suricata bpf>  #"/var/lib/suricata/capture-filter.bpf"
suricata_log=<path to suricata log directory>  #"/var/log/suricata"

# Check to see if pcap directory already exists
if [ -d "$pcap_dir" ]; then
        echo "Directory "$pcap_dir" was found"
else
        echo "Pulling pcaps from sensor"
        scp -P "$cloud_port" -i "$sshkey" "$cloud_pcap" $pcap_dir
fi

# Check directory exists and warns if not
if [ -d "$pcap_dir" ]; then
        echo "Navigating to directory '$pcap_dir'"
        cd "$pcap_dir"
else
        echo "ERROR: Directory '$pcap_dir' does not exist."
        exit
fi

# Appending .pcap to daemonlogger pcap files
for file in *; do
        if [[ -f "$file" && "$file" == daemonlogger* && "$file" != *.pcap ]]; then
                mv "$file" "$file.pcap"
                echo "$file is now $file.pcap"
        else
                echo "No changes made to "$file""
        fi
done

# Checks if directory exists and changes to it, warns if not
if [ -d "$pcap_dir" ]; then
        cd "$pcap_dir"
else
        echo "ERROR: Directory '$pcap_dir' does not exist"
        exit
fi

# Running Suricata in offline mode against pcaps in directory
if [ "$(pwd)" = "$pcap_dir" ]; then
        echo "Running Suricata against files in '$pcap_dir'"
        find "$pcap_dir" -type f -exec suricata -r "{}" -F "$bpf_filter" \;
else
        echo "ERROR: Suricata error"
        exit
fi

# Move Suricata output eve.json to /var/log/suricata for filebeat to read
if [ "$(pwd)" = "$pcap_dir" ]; then
        echo "Moving eve.json to $suricata_log"
        mv "$pcap_dir"/eve.json $suricata_log
else
        echo "ERROR: mv error"
        exit
fi