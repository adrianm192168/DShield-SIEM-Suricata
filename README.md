# DShield-SIEM-Suricata
Suricata eve.json visualization in DShield ELK SIEM

My intention is to put as little burden on the honeypot as possible to stay within the limits of the AWS Free tier. Suricata is unable to run with those limited specs so I will be using the SIEM server to perform the processing.

DShield Honeypot Sensor (Ubuntu 22.04.5 LTS) (AWS Free Instance) \
https://github.com/DShield-ISC/dshield \
https://aws.amazon.com/free/free-tier-faqs/

DShield-SIEM (Ubuntu 24.04.2 LTS) (Local Network) \
https://github.com/bruneaug/DShield-SIEM

Collect Packet Captures on Sensor
I will be using Cisco Talos Daemonlogger in this demonstration. \
Any packet capture software will work. \
https://github.com/bruneaug/DShield-SIEM/blob/main/AddOn/packet_capture.md \
https://www.talosintelligence.com/daemon





## **Part 1: Install Suricata on SIEM Server**

Suricata Install (Ubuntu / Debian) \
https://docs.suricata.io/en/latest/install.html (section 3.2.1)

	sudo apt-get install software-properties-common
	sudo add-apt-repository ppa:oisf/suricata-stable
	sudo apt-get update
	sudo apt-get install suricata (latest stable)

Fetch the default ruleset (ET Open ruleset) \
https://rules.emergingthreats.net/OPEN_download_instructions.html

	sudo suricata-update 
By default, rules are stored at "/var/lib/suricata/rules"

Set daily cron job to run suricata-update to fetch any rule updates
	
	sudo vi /etc/cron.d/suricata-update
	
 	# Fetches any updates to Suricata ET Open ruleset at 00:30 UTC daily
	30 0 * * * root /usr/bin/suricata-update > /tmp/suricata-update.txt

Since we only want to run suricata in pcap mode, we will disable it so it is not running as an IDS on the network

	sudo systemctl disable suricata.service


There are a few configuration changes we need to make in the suricata.yaml

Since we will be running Suricata in pcap mode for the sole purpose of ELK visualization, we will disable any logs other than eve.json

	sudo vi /etc/suricata/suricata.yaml

under outputs: fast, stats, file \
	enabled: no




## **Part 2: Filebeat**

Filebeat will be our method of getting the Suricata output to visualize in Kibana. We will be using the Suricata module for filebeat to parse Suricata eve.json.


Modify docker-compose.yml \
Under volumes, add: 

	# Used to access suricata logs on host
	- /var/log/suricata:/usr/share/filebeat/suricata


Then, 

	sudo docker compose down 
	sudo docker compose up -d


Enter filebeat container

	sudo docker exec -ti filebeat bash

	filebeat modules enable suricata



Modify /modules.d/suricata.yml

*note If your container does not have a text editor, you can install one using "sudo docker exec -ti filebeat apt-get nano"

	nano /modules.d/suricata.yml

	- module: suricata
	  # All logs
	  eve:
	    enabled: true
	    var.paths: ["/usr/share/filebeat/suricata/eve.json"]



In /usr/share/filebeat to build Kibana dashboards

	./filebeat setup -e





## **Part 3: Elasticsearch Suricata Integration**

Log into Kibana: https://serverIP:5601

Navigate to Management > Integrations

Search for Suricata integration 

Add Suricata integration to Existing Fleet server
	Default settings
	Under Management > Integrations > Suricata
	 Copy/paste the YML into your elastic-agent.yml file or into a file within your inputs.d directory



## **Part 4: Transferring Pcaps & Running Suricata**

I have created a script that pulls the pcap from the honeypot using scp > appends ".pcap" to daemonlogger files > Runs suricata in offline mode against pcaps > then moves the eve.json file to /var/log/suricata for filebeat to process

pull_pcap.sh:
	Customizable fields to match your setup directories:
	> sshkey private key path
	> cloud/local hostname, IP, and path to pcap files
	> directory to pcap files on local host
	> path to bpf on local host (So Suricata will not bloat logs with your sensor IP responses)
	> path to suricata log directory "/var/log/suricata" by default

Create a cron job to run this daily 

	sudo vi /etc/cron.d/pull_pcap
	0 0 * * * root /usr/bin/bash <path to pull_pcap.sh> > /tmp/pull_pcap_output.txt

Note: The DShield Honeypot will have a daily reboot time that depends on what time it was initially launched. This can cause complications if you're trying to pull pcaps and it reboots. Plan accordingly.
	On honeypot, to view what time the reboot is:
	
 	cat /etc/cron.d/dshield
	
After the script has finish running, the Suricata dashboard in Kibana should populate with the previous day's alerts and events.
