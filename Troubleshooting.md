## Elasticsearch not receiving data from Filebeat Suricata module ##

![image](https://github.com/user-attachments/assets/060d3063-5653-433f-9be0-b1a6d4b32518)

### Verify that Filebeat Suricata module is enabled ### 

    sudo docker exec -ti filebeat bash

    filebeat modules list

It should look like: 

![image](https://github.com/user-attachments/assets/4f3287e9-a5d6-424e-81ad-59956a8c2edd)

If not, enable it using 

    filebeat modules enable suricata

### Verify /modules.d/suricata.yml is configured correctly ###

    cat /usr/share/filebeat/modules.d/suricata.yml

![image](https://github.com/user-attachments/assets/f1857190-99db-40a8-8304-9d223bc656b0)

ensure enabled is set to "true"


## Container Rebuilt ## 

If you rebuild your filebeat container, the filebeat modules will be reset to defaults \
Refer to README.md "Part 2: Filebeat" to reenable filebeat suricata module
