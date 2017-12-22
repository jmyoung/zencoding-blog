-- Uses an ESP8266 board with NodeMCU and a DHT11/22 sensor in order to
-- read temperature/humidity data and publish it as a JSON message
--
-- Written by James Young <jyoung@zencoffee.org> April 2016
--
-- NO WARRANTIES EXPRESS OR IMPLIED, USE AT YOUR OWN RISK

-- Configure stuff here
dht_gpio = 4									-- GPIO pin that the sensor is attached to
dht2_gpio = 5 									-- GPIO pin that second sensor is attached to
json_hostname = "splunk.zencoffee.org"  	    -- Hostname for the json server
json_port = 5000							    -- TCP port to connect to
json_location = "gym-store"					    -- Where this device is located
json2_location = "gym"							-- Where the second sensor is located
json_type = "sensor_data"					    -- Content of 'type' field in output JSON
check_interval = 20								-- Number of seconds between checks

-- Don't mess with this
json_ip = nil        								-- IP address for the json server
json_message = nil									-- The message we're going to send

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

-- Callback triggered when timer expires, for fetching status and publishing it
function callback_timer()
	-- Retrieve the sensor status
	print("fetching sensor data")
	ok, data = pcall(get_sensor_table, dht_gpio)
	ok2, data2 = pcall(get_sensor_table, dht2_gpio)
	if ok then
		output = {}
		output["type"] = json_type
		output["temperature"] = data["temperature"]
		output["relhumidity"] = data["relhumidity"]
		output["deviceid"] = wifi.sta.getmac()
		output["location"] = json_location
		
		ok, json = pcall(cjson.encode, output)
		if ok then		
			-- Start pushing messages for the sensors we've detected
			print("connecting to json")
			json_message = json
			sock = net.createConnection(net.TCP, 0)
			sock:on("receive", function(sck, c) print(c) end)
			sock:connect(json_port, json_ip)
			sock:on("connection", function (sck, c)
				print("outputting message")
				sck:send(json_message .. "\n")
				sck:close()
				
				-- Everything is ok, so re-arm the watchdog
				tmr.softwd(check_interval*3)
			end)
		end		
	else
		-- No sensor data?  Do nothing, and don't re-arm the watchdog!
	end
	
	if ok2 then
		output = {}
		output["type"] = json_type
		output["temperature"] = data2["temperature"]
		output["relhumidity"] = data2["relhumidity"]
		output["deviceid"] = wifi.sta.getmac()
		output["location"] = json2_location
		
		ok, json = pcall(cjson.encode, output)
		if ok then		
			-- Start pushing messages for the sensors we've detected
			print("connecting to json")
			json_message = json
			sock = net.createConnection(net.TCP, 0)
			sock:on("receive", function(sck, c) print(c) end)
			sock:connect(json_port, json_ip)
			sock:on("connection", function (sck, c)
				print("outputting message")
				sck:send(json_message .. "\n")
				sck:close()
				
				-- Everything is ok, so re-arm the watchdog
				tmr.softwd(check_interval*3)
			end)
		end		
	else
		-- No sensor data?  Do nothing, and don't re-arm the watchdog!
	end
	
end

-- Callback triggered when DNS resolution for the json servername is successful
function process_json_ip(socket, ip)
	json_ip = ip
	if (ip == nil) then 
		print("json dns resolve error")
	else
		-- We have an IP address
		print("json broker at " .. ip)
		
		-- This causes the main loop alarm to be configured
		print("started main loop")
		tmr.alarm(0,check_interval*1000,tmr.ALARM_AUTO,callback_timer)
	
		-- And fire once immediately
		callback_timer()
	end
end






---------------------------------------------
-- EXECUTION BEGINS HERE
---------------------------------------------

-- Arm the software watchdog
tmr.softwd(check_interval*3)

-- Resolve the JSON server IP, rest of code is callbacks in this
net.dns.resolve(json_hostname, process_json_ip)

