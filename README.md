
**InfluxDB Setup**

1.	Visit: https://influxdata.com/downloads/ to download and install the latest InfluxDB.
2.	Once Influx is installed, open a web-browser to port 8888 of your Influx server. This should take you to Chronograf.
3.	Click on the “Crown” icon (InfluxDB Admin) in the left nav. bar 
4.	Create a new Database and give it a name. VapeDetectors is “default” in the powershell listener script.
5.	The “autogen” retention policy will keep data indefinitely. You cannot edit the autogen policy.

 You can have multiple retention policies on a database. For my purposes I create one named “DYNAMIC”, meaning for now I’ll retain data for 365 days, but I might change my mind and edit it to 90 days or whatever.

Hover over your new database and click on the Add Retention policy button. Give it a name and specify the duration. DYNAMIC is “default” in the powershell listener script. You can use hours, minutes, days etc. for the duration.

**Grafana Setup**

1.	Visit: https://grafana.com/grafana/download to download and install the latest Grafana.
2.	Once Grafana is installed, open a web-browser to your Grafana server.
3.	After logging in, hover on the Configuration button (Gear icon, bottom left nav. bar) and click the “Data sources” button.
4.	Add an InfluxDB datasource.
a.	Name: Something that makes sense. I used “InfluxDB (VapeDetectors)”
b.	Query Language: Should default to InfluxQL
c.	URL: If it’s on localhost, you still must type out the URL, it won’t fill it in.
d.	Scroll to the bottom.
e.	Database: Use the database name you created in Influx.
f.	Everything else can stay default.
g.	Click the Save & test button
5.	Hove over the Dashboards icon (four little squares) and select “Import”
6.	Click the “Upload JSON” file and select the “HALO3C-Dashboard.json” file included with this document.
a.	Name: Leave as default or change … up to you.
b.	Data Source: Select the InfluxDB datasource you previously created.
c.	Click Import
7.	To run Grafana as a service, you can use the “Non-Sucking Service Manager” found here: https://nssm.cc/download

**Powershell Listener Setup**

1.	Copy the “HALO-Listener-v4” powershell script to the server you intend to run it on.
2.	Update the global variables found under “Update these variables” accordingly
3.	Start the script.

**HALO 3C Configuration**

1.	Log into one of your Halo units.
2.	Click on the “Integrations” tab
3.	Scroll down to “Heartbeat”. You will see some default data already entered, replace it with the below example. Make sure to match the ip/DNS name to what you used for the ListenerURL in the powershell script.

    This heartbeat will send all event data to the (LISTENER ADDRESS) you provide as well as the name of the device:
    http://(LISTENER ADDRESS):8081/heartbeat ?%EVENTS%,location=%NAME%

4.	Adjust the interval to your taste. 15 seconds is the lowest setting and what I am using.
5.	Authentication Type can stay on Basic/Digest
6.	Save your settings.

**Confirm Setup**

If you wait for your interval, you should see “OK @ <timestamp>” in the status of your Halo unit provided it was able to connect to the listener. If you watch the listener script, you will also see a red asterisk blink whenever it receives a heartbeat. If you’re getting all that, then check your Grafana Halo dashboard. You should start seeing data points in the graphs.
1.	Web-Browse to your Grafana server
2.	Go: Dashboards > Browse
3.	Select HALO 3C (or whatever you named your dashboard)

If all of that is good, you can use the “Halo Device Manager” to download the working config. and deploy the heartbeat settings out to the rest of your units.


