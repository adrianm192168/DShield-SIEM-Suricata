# DShield-SIEM-Suricata
Suricata eve.json visualization in DShield ELK SIEM

This guide will demonstrate how to populate Suricata eve.json output into an ELK stack with the Suricata Logs integration [1] using yesterday's completed pcap files. 
My intention is to put as little burden on the honeypot as possible to stay within the limits of the AWS Free tier. Suricata is unable to run with those limited specs so I will be using the SIEM server to perform the processing.


DShield Honeypot Sensor (Ubuntu 22.04.5 LTS) (AWS Free Instance) [2] [3]

DShield-SIEM (Ubuntu 24.04.2 LTS) (Local Network) [4]

Collect Packet Captures on Sensor
I will be using Cisco Talos Daemonlogger in this demonstration. \
Any packet capture software will work. [5] [6]


## **Part 1: Install Suricata on SIEM Server**

Suricata Install (Ubuntu / Debian) [7]

	sudo apt-get install software-properties-common
	sudo add-apt-repository ppa:oisf/suricata-stable
	sudo apt-get update
	sudo apt-get install suricata (latest stable)

Fetch the default ruleset (ET Open ruleset) [8] 

	sudo suricata-update 
By default, rules are stored at "/var/lib/suricata/rules"

Set daily cron job to run suricata-update to fetch any rule updates
	
	sudo vi /etc/cron.d/suricata-update
	
 	# Fetches any updates to Suricata ET Open ruleset at 00:30 UTC daily
	30 0 * * * root /usr/bin/suricata-update > /tmp/suricata-update.txt
Write and quit


Since we only want to run suricata in pcap mode, we will disable it so it is not running as an IDS on the network

	sudo systemctl disable suricata.service


There are a few configuration changes we need to make in the suricata.yaml

Since we will be running Suricata in pcap mode for the sole purpose of ELK visualization, we will disable any logs other than eve.json

	sudo vi /etc/suricata/suricata.yaml

under outputs: fast, stats, file \
	enabled: no 
 
![image](https://github.com/user-attachments/assets/9b8b8186-ad2c-4cfe-8beb-c61735969d78)
![image](https://github.com/user-attachments/assets/c690b950-cb81-4f79-8aae-33fc0f878098)
![image](https://github.com/user-attachments/assets/afaa049d-7549-4be4-9510-872dc472d673)

Write and quit


## **Part 2: Filebeat**

Filebeat will be our method of getting the Suricata output to visualize in Kibana. We will be using the Suricata module for filebeat to parse Suricata eve.json.


Modify docker-compose.yml \
Under filebeat configurations > Under volumes add: 

	# Used to access suricata logs from the host machine 
	- /var/log/suricata:/usr/share/filebeat/suricata
![image](https://github.com/user-attachments/assets/8d02b695-7532-47d8-95e0-f50f8acb1a62)


Write and quit

Then, 

	sudo docker compose down 
	sudo docker compose up -d


Enter filebeat container and enable filebeat suricata module

	sudo docker exec -ti filebeat bash

	filebeat modules enable suricata



Modify /modules.d/suricata.yml

*note If your container does not have a text editor, you can install one using "sudo docker exec -ti filebeat apt-get install nano"

	nano /usr/share/filebeat/modules.d/suricata.yml

	- module: suricata
	  # All logs
	  eve:
	    enabled: true
	    var.paths: ["/usr/share/filebeat/suricata/eve.json"]
Write and quit


In /usr/share/filebeat to build Kibana dashboards

	./filebeat setup -e


## **Part 3: Transferring Pcaps & Running Suricata**

I have created a script that pulls the pcap from the honeypot using scp > appends ".pcap" to daemonlogger files > Runs suricata in offline mode against pcaps > then moves the eve.json file to /var/log/suricata for filebeat to process

pull_pcap.sh: \
	Customizable fields to match your setup directories: \
	> sshkey private key path \
	> cloud/local honeypot hostname, IP, and path to pcap files \
	> directory to pcap files on local host \
	> path to .bpf file on local host (So Suricata will not bloat logs with your honeypot IP responses) \
	> path to suricata log directory "/var/log/suricata" by default \

	git clone https://github.com/adrianm192168/DShield-SIEM-Suricata

Edit the variables in the pull_pcap.sh script to match your environment

You can create a bpf filter file so Suricata won't create alerts against your sensor's IP \
It would look something like 

	not src host <honeypot ip>

Create a cron job to run this daily 

	sudo vi /etc/cron.d/pull_pcap

 	# Runs pull_pcap.sh at 0000 UTC daily and writes output to /tmp/pull_pcap_output.txt
	0 0 * * * root /usr/bin/bash <path to pull_pcap.sh> > /tmp/pull_pcap_output.txt

Note: The DShield Honeypot will have a daily reboot time that depends on what time it was initially launched. This can cause complications if you're trying to pull pcaps and it reboots. Plan accordingly.
	On honeypot, to view what time the reboot is:
	
 	cat /etc/cron.d/dshield
	

## **Part 4: Elasticsearch Suricata Logs Integration**

Log into Kibana: https://serverIP:5601

Navigate to Management > Integrations

At the bottom left of the screen, show "Beats Only" \
![image](https://github.com/user-attachments/assets/263a2bda-5d60-41d6-ac59-0453a68e1480)

Then, \
Search for Suricata logs integration (not to be confused with the Suricata integration) 
![image](https://github.com/user-attachments/assets/d9f6bb67-5cd2-42d3-bbb9-064be11c2329)


You shouldn't have to follow any of the steps on the page as we did them earlier in the guide, but this is a way of testing whether or not the Suricata module is pushing data.

![image](https://github.com/user-attachments/assets/a046d0f8-eeac-4354-9823-b5d5ff0179ef)


After the script has finish running, the Suricata dashboard in Kibana should populate with the previous day's alerts and events.

![image](https://github.com/user-attachments/assets/4d9ccc0b-794b-451f-affa-69fbcdd96bf7)
![image](https://github.com/user-attachments/assets/7a1294c2-b8ba-4ace-a4a1-5d923320cc7f)


## **References**

[1] https://www.elastic.co/docs/reference/beats/filebeat/filebeat-module-suricata \
[2] https://github.com/DShield-ISC/dshield \
[3] https://aws.amazon.com/free/free-tier-faqs/ \
[4] https://github.com/bruneaug/DShield-SIEM \
[5] https://github.com/bruneaug/DShield-SIEM/blob/main/AddOn/packet_capture.md \
[6] https://www.talosintelligence.com/daemon \
[7] https://docs.suricata.io/en/latest/install.html \
[8] https://rules.emergingthreats.net/OPEN_download_instructions.html 

