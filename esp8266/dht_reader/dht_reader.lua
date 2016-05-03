-- Uses an ESP8266 board with NodeMCU and a DHT11/22 sensor in order to
-- read temperature/humidity data and publish it to an MQTT channel
--
-- Written by James Young <jyoung@zencoffee.org> April 2016
--
-- NO WARRANTIES EXPRESS OR IMPLIED, USE AT YOUR OWN RISK

-- Configure stuff here
dht_gpio = 4							-- GPIO pin that the sensor is attached to
mqtt_hostname = "mqtt.zencoffee.org"	-- Hostname for the MQTT server
mqtt_topic = "homeiot"					-- MQTT topic prefix to publish messages to
mqtt_clientname = "esp8226-1"			-- MQTT clientname for this host
check_interval = 60						-- Number of seconds between checks

-- Don't mess with this
mqtt_ip = nil							-- IP address for the MQTT server
mqtt_client = nil						-- The MQTT client object we're manipulating
mqtt_data = nil							-- The sensor data we're outputting

-- Generate the sensor status as a table
function get_sensor_table(gpio)
	-- Get the DHT sensor status from GPIO pin
	status,temp,humi = dht.read(gpio)
	if( status == dht.OK ) then
		output = {}
		output["temperature"] = temp
		output["relhumidity"] = humi
		return output
	else
		error()
	end
end

-- Outputs a mqtt message json for the next sensor
-- Once we run out of data, we send a status message
function output_sensor_mqtt()
	-- Is there any data left?
	if next(mqtt_data) == nil then
		output_json_status(1,"online")
		
		-- We sent everything.  Rearm watchdog.
		tmr.softwd(check_interval*3)
		return
	end

	-- Shift off the next value from the sensor list
	sensor,value = next(mqtt_data)
	mqtt_data[sensor] = nil

	-- Assemble the JSON packet
	topic = mqtt_topic .. "/sensor/" .. sensor .. "/" .. mqtt_clientname
	output = {}
	output["value"] = value
	output["clientid"] = mqtt_clientname
	ok, json = pcall(cjson.encode, output)
		
	if ok then
		-- Push the JSON out to MQTT
		print("sending mqtt " .. sensor .. " json")
		mqtt_client:publish(topic,json,0,1,
			function(client)
				print("mqtt " .. sensor .. " json sent")
				
				-- And now send the next sensor
				output_sensor_mqtt()
			end
		)
	else
		print(sensor .. " json encoding failed")
	end
end

-- Outputs a status message about the device
function output_json_status(validity,statustext)
	topic = mqtt_topic .. "/status/" .. mqtt_clientname
	output = {}
	output["valid"] = validity
	output["status"] = statustext
	output["clientid"] = mqtt_clientname
	ok, json = pcall(cjson.encode, output)

	if ok then
		-- Deliver MQTT message about the status of the device
		print("sending mqtt status json")
		mqtt_client:publish(topic,json,0,1,
			function(client)
				print("mqtt status sent")
			end,
			function(client)
				print("mqtt status send failed")
			end
		)
	else
		print("status json encoding failed")
	end
end
		

-- Callback triggered when timer expires, for fetching status and publishing it
function callback_timer()
	-- Retrieve the sensor status
	print("fetching sensor data")
	ok, data = pcall(get_sensor_table, dht_gpio)
	if ok then
		-- Start pushing messages for the sensors we've detected
		mqtt_data = data
		output_sensor_mqtt()
	else
		-- Push the JSON out to MQTT
		output_json_status(0,"error")
	end
end

-- Callback triggered when connection established to MQTT server
function callback_mqtt_connected(client)
	print("broker connected")
	mqtt_client = client
	
	-- Push an online message to the status channel
	-- Note that data is potentially invalid at this time!
	output_json_status(0,"online")
	
	-- This causes the main loop alarm to be configured
	print("started main loop")
	tmr.alarm(0,check_interval*1000,tmr.ALARM_AUTO,callback_timer)
	
	-- And fire once immediately
	callback_timer()
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
		print("assert: mqtt_client not populated")
	end
	
	-- Try and reconnect
	connect_mqtt(mqtt_ip)
end

-- Call this to connect to the MQTT broker
function connect_mqtt(ip)
	print("connecting to broker")

	-- Connect up to the mqtt broker
	m = mqtt.Client(mqtt_clientname, 120, "", "")

	-- Register the LWT for this sensor
	m:lwt(mqtt_topic .. "/status/" .. mqtt_clientname, '{"valid":0,"status":"offline","clientid":"' .. mqtt_clientname .. '"}', 0, 1)

	-- Set up a callback to handle the broker going offline
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