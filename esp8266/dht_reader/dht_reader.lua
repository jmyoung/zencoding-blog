-- Uses an ESP8266 board with NodeMCU and a DHT11/22 sensor in order to
-- read temperature/humidity data and publish it to an MQTT channel
--
-- Written by James Young <jyoung@zencoffee.org> April 2016
--
-- NO WARRANTIES EXPRESS OR IMPLIED, USE AT YOUR OWN RISK

dht_gpio = 4							-- GPIO pin that the sensor is attached to
mqtt_hostname = "mqtt.zencoffee.org"	-- Hostname for the MQTT server
mqtt_ip = nil							-- IP address for the MQTT server
mqtt_topic = "homeiot/raw"				-- MQTT topic to publish messages to
mqtt_clientname = "esp8226-1"			-- MQTT clientname for this host
mqtt_client = nil						-- The MQTT client object we're manip
check_interval = 60						-- Number of seconds between checks

-- Generate the sensor status as a table
function get_sensor_table(gpio)
	-- Get the DHT sensor status from GPIO pin
	status,temp,humi = dht.read(gpio)
	if( status == dht.OK ) then
		output = {}
		output["temp"] = temp
		output["relhumi"] = humi
		return output
	else
		error()
	end
end

-- Callback triggered when timer expires, for fetching status and publishing it
function callback_timer()
	print("timer callbacked")
	
	-- Retrieve the sensor status
	ok, output = pcall(get_sensor_table, dht_gpio)
	if ok then
		-- Add some stuff to the table, then generate JSON from that
		output["type"] = "reading"
		output["status"] = "ok"
		output["clientid"] = mqtt_clientname
		ok, json = pcall(cjson.encode, output)
		if ok then
			-- Push the JSON out to MQTT, re-arm the watchdog if the send worked
			print("sending mqtt ok json")
			mqtt_client:publish(mqtt_topic,json,0,0, 	
				function(client) 
					print("mqtt ok json sent") 
					tmr.softwd(check_interval*3)
				end
			)
		else
			print("json ok encoding failed")
		end
	else
		-- Stub error output, not using json library (don't need it)
		json = '{"type":"reading","status":"error","clientid":"' .. mqtt_clientname .. '"}'
		
		-- Push the JSON out to MQTT
		print("sending mqtt error json")
		mqtt_client:publish(mqtt_topic,json,0,0, function(client) print("mqtt error json sent") end)
	end
end

-- Callback triggered when connection established to MQTT server
function callback_mqtt_connected(client)
	print("broker connected")
	mqtt_client = client
	
	-- This causes the main loop alarm to be configured
	print("started main loop")
	tmr.alarm(0,check_interval*1000,tmr.ALARM_AUTO,callback_timer)
end

-- Callback triggered when connection to MQTT server fails
function callback_mqtt_failed(client, reason)
	print("broker connect failed " .. reason)
end

-- Callback triggered when MQTT server goes offline
function callback_mqtt_offline(client)
	print("mqtt broker offline")
	
	-- Stop the main loop
	tmr.unregister(0)
	print("stopped main loop")
	
	-- Shut down the main MQTT client
	if (mqtt_client ~= nil) then
		mqtt_client:close()
		mqtt_client = nil
	else
		print("asset: mqtt_client not populated")
	end
	
	-- Try and reconnect
	connect_mqtt(mqtt_ip)
end

-- Call this to connect to the MQTT broker
function connect_mqtt(ip)
	print("connecting to broker")

	-- Connect up to the mqtt broker
	m = mqtt.Client(mqtt_clientname, 120, "", "")

	-- Register a Last Will and Testament
	m:lwt(mqtt_topic, '{"type":"lwt","status":"offline","clientid":"' .. mqtt_clientname .. '"}', 0, 0)

	-- Connect some callbacks to display status (for now!)
	m:on("connect", function(client) print ("mqtt broker connected") end)
	m:on("offline", callback_mqtt_offline)

	-- And now connect to the broker
	m:connect(ip, 1883, 0, callback_mqtt_connected, callback_mqtt_failed)                                   
end

-- Callback triggered when DNS resolution for the MQTT servername is successful
function process_mqtt_ip(socket, ip)
	mqtt_ip = ip
	if (ip == nil) then 
		print("mqtt dns resolve error")
	else
		-- We have an IP address
		print("mqtt broker at " .. ip)
		
		-- Connect to MQTT (rest of processing happens there)
		connect_mqtt(ip)
	end
end

---------------------------------------------
-- EXECUTION BEGINS HERE
---------------------------------------------

-- Arm the software watchdog
tmr.softwd(check_interval*3)

-- Resolve the MQTT broker IP, rest of code is callbacks in this
net.dns.resolve(mqtt_hostname, process_mqtt_ip)

-- If the above callback doesn't eventually post a successful message, the unit will reboot.