-- @Eagle Dynamics (C)
-- @author Ilja A.Belov
--package.cpath = './bin/x86/vc90.debug/?.dll;./bin/x86/vc90.debug/lua-?.dll;'

-- при добавлении новых устройств не забыть обновить inputevents.lua!!!
local NewInput = require('NewInput')
local lfs = require('lfs')

local file = io.open(lfs.writedir() .. 'Logs/inputscript.log', 'w')

function logError(err)
  file:write('Error: ')
  file:write(err)
  file:write('\n')
end

function logMsg(msg)
  file:write('Info: ')
  file:write(msg)
  file:write('\n')  
end

local sysPath = 'Config/Input/Aircrafts/'
local userPath = lfs.writedir() .. 'Config/Input/'

-- path to headtracker plugin dll
NewInput.setHeadTrackerDllPath('./bin/headtracker/headtracker.dll')

NewInput.enableKeyboardLog(false)
NewInput.enableMouseLog(false)
NewInput.enableJoystickLog(false)
NewInput.enableInfoLog(false)

-- отрезает от имени устройства CLSID, назначенный для него DirectX
function getDeviceTemplateName(deviceName)
  return string.gsub(deviceName, '(.*)(%s{.*})', '%1')
end

function getInputDevices()
  local result = {}
  local devices = NewInput.getDevices()
  
  for i, deviceName in ipairs(devices) do
    local deviceTypeName = NewInput.getDeviceTypeName(deviceName)
    local deviceTemplateName = getDeviceTemplateName(deviceName)
    
    table.insert(result, {name = deviceName, typeName = deviceTypeName, templateName = deviceTemplateName})
  end
  
  return result
end

function getUserDeviceProfileFilename(plane, device)
  local result
  
  -- патаемся загрузить раскладку из пользовательской папки
  local path = string.format("%s/%s/%s/%s.lua", userPath, plane, device.typeName, device.name)
  
  if lfs.attributes(path) then
    result = path
  end
  
  return result
end

function getPluginDeviceProfileFilename(device, pluginPath)
  local result
  
  if pluginPath then      
      -- сначала ищем шаблоны для устройства
      local path = string.format("%s/%s/%s.lua", pluginPath, device.typeName, device.templateName)
      
      if lfs.attributes(path) then
        result = path
      else
        -- затем ищем дефолтные устройства
        path = string.format("%s/%s/default.lua", pluginPath, device.typeName)
        
        if lfs.attributes(path) then
          result = path
        end
      end
    end
  
  return result
end

function getDefaultDeviceProfileFilename(plane, device)
  local result
 
  -- сначала пытаемся загрузить раскладку из дефолтной папки из шаблона устройства
  local path = string.format("%s/%s/%s/%s.lua", sysPath, plane, device.typeName, device.templateName)
  
  if lfs.attributes(path) then
    result = path
  else
    -- затем пытаемся загрузить раскладку из дефолтной папки из дефолтного устройства
    path = string.format("%s/%s/%s/default.lua", sysPath, plane, device.typeName)
    
    if lfs.attributes(path) then
      result = path
    end
  end
  
  return result
end

function loadPlaneDeviceProfile(plane, device, pluginPath)
  local filename = getUserDeviceProfileFilename(plane, device) or
                   getPluginDeviceProfileFilename(device, pluginPath) or
                   getDefaultDeviceProfileFilename(plane, device)
  
  return loadInputFile(filename)
end

function getJoystickNumber(deviceName)
  local result
  
  if not joystickNumbers_ then
    result = NewInput.getJoystickNumber(deviceName)
    
    joystickNumbers_ = {
      [deviceName] = result
    }
  end
  
  result = joystickNumbers_[deviceName]
  
  if not result then
    result = NewInput.getJoystickNumber(deviceName)
    joystickNumbers_[deviceName] = result
  end
  
  return result
end

function getNewInputEnvTable()
  if not envTable_ then
    envTable_ = NewInput.getEnvTable()
  end
  
  return envTable_
end

function getNewInputEventsTable()
  return getNewInputEnvTable().Events
end

function getNewInputActionsTable()
  return getNewInputEnvTable().Actions
end

function loadInputFile(fname)
	print(fname)
	local f, err  		 = loadfile(fname)
	local env 	   		 = getNewInputActionsTable()
	env.external_profile = loadInputFile
	env.join			 = function(to,from)
								for i,o in ipairs(from) do
									to[#to + 1] = o
								end
								return to
						   end
	local res
	local old_layout = env.layout
	env.layout       = nil
	if f then
	   setfenv(f, env) 
	   res = f()
	   if  env.layout then
		   res = env.layout()
		end
	else
		logError(err)
	end
    env.layout = old_layout
	return res
end

function getInputEvents()
  if not inputEvents_ then
    local f, err = loadfile('scripts/input/inputevents.lua')

    if f then
      local env = getNewInputEventsTable()
      
      setfenv(f, env)
      inputEvents_ = f()
    else
      logError(err)
    end  
  end
  
  return inputEvents_
end

function getInputEvent(key, deviceName)
  local result = getInputEvents()[key]
  
  if result then
    local joystickNumber = getJoystickNumber(deviceName)
    
    if joystickNumber > 0 then
      result = result + joystickNumber * NewInput.getMaxDeviceActionCount()
    end
  end
  
  return result
end

function getReformersEvents(reformers, modifiers)
  local result = true
  local events
  local err
  
  if reformers and #reformers > 0 then
    events = {}
    
    for i, reformer in ipairs(reformers) do
      local event = modifiers[reformer]
      
      if event then
        table.insert(events, event)
      else
        err = string.format('Combo reformers contain unknown reformer[%s]!', reformer)
        result = false
        break
      end
    end
  end
  
  return result, events, err
end

function getComboEvents(combo, deviceName, modifiers)
  local result = false
  local key
  local reformers
  local err
  
  if combo.key then
    key = getInputEvent(combo.key, deviceName)
    
    if key then
      result, reformers, err = getReformersEvents(combo.reformers, modifiers)
    else
      err = string.format('Combo contains unknown key[%s]!', combo.key)
    end
  end  
  
  return result, key, reformers, err
end

function addKeyCombo(layerName, key, reformers, filter, command)
  reformers = reformers or {}
  logMsg(string.format('%s key command %s [key %s reformers{%s, %s, %s}] down %s pressed %s up %s', 
      layerName, tostring(command.name), 
      tostring(key), tostring(reformers[1]), tostring(reformers[2]), tostring(reformers[3]), 
      tostring(command.down), tostring(command.pressed), tostring(command.up)))
  NewInput.addKeyCombo(layerName, 
					   key,
					   reformers, 
					   command.down,
					   command.pressed, 
					   command.up, 
					   command.cockpit_device_id,
					   command.value_down, 
					   command.value_pressed,
					   command.value_up)
end

function addAxisCombo(layerName, axis, reformers, filter, command)
  local msg = string.format('%s axis command %s action %s', layerName, tostring(command.name), tostring(command.action))
  
  if filter then
    msg = msg .. string.format(' filter(sx: %s sy: %s deadzone %s invert %s slider %s)', 
        tostring(filter.saturationX), tostring(filter.saturationY), tostring(filter.deadzone), 
        tostring(filter.invert), tostring(filter.slider))
  end
  
  logMsg(msg)
  
  NewInput.addAxisCombo(layerName,
						axis,
						reformers,
						command.action,
						filter,
						command.cockpit_device_id)
end

function getCommandHash(command)
   return 'down: ' .. tostring(command.down) .. 
          ' pressed: ' .. tostring(command.pressed) .. 
          ' up: ' .. tostring(command.up)..
          ' cd: '.. tostring(command.cockpit_device_id)..
          ' vd: '.. tostring(command.value_down)..
          ' vp: '.. tostring(command.value_pressed)..
          ' vu: '.. tostring(command.value_up) .. 
          ' action: '.. tostring(command.action)
end

function addDeviceProfileCommands(layerName, deviceName, commands, modifiers, func)
  if commands then
    for i, command in ipairs(commands) do
      local combos = command.combos
      
      if combos then
        for j, combo in ipairs(combos) do
          local result, key, reformers, comboErr = getComboEvents(combo, deviceName, modifiers)
          
          if result then
            func(layerName, key, reformers, combo.filter, command)
          else
            local commandName = command.name
            
            if not commandName then
              commandName = getCommandHash(command)
            end
      
            local err = string.format('Command[%s] in layer[%s] device[%s] contains invalid combo! %s', commandName, layerName, deviceName, comboErr)
            
            logError(err)
          end
        end
      end
    end
  end
end

function addDeviceProfileForceFeedback(layerName, deviceName, forceFeedback)
  if forceFeedback then
    NewInput.setForceFeedback(layerName, deviceName, forceFeedback.trimmer, forceFeedback.shake, forceFeedback.swapAxes)
  end
end

function addDeviceProfile(layerName, deviceName, deviceProfile, modifiers)
  addDeviceProfileCommands(layerName, deviceName, deviceProfile.keyCommands, modifiers, addKeyCombo)
  addDeviceProfileCommands(layerName, deviceName, deviceProfile.axisCommands, modifiers, addAxisCombo)
  addDeviceProfileForceFeedback(layerName, deviceName, deviceProfile.forceFeedback)
  
  NewInput.setFullSync(deviceName, layerName, deviceProfile.fullSync)
end

function getAircraftMarker()
  return 'Aircraft'
end

function getDefaultAircraft()
  return 'Default'
end

function createNewInputLayer(layerName)
  logMsg('Create layer ' .. layerName)
  
  NewInput.createLayer(layerName)
end

function createInputLayer(plane, profile, modifiers)
  local layerName = getAircraftMarker() .. plane
  
  createNewInputLayer(layerName)
  
  for deviceName, deviceProfile in pairs(profile) do
    addDeviceProfile(layerName, deviceName, deviceProfile, modifiers)
  end
end

function getKeyboardDeviceName()
  if not keyboard_ then
    local devices = NewInput.getDevices()
    
    for i, deviceName in ipairs(devices) do
      local deviceTypeName = NewInput.getDeviceTypeName(deviceName)
      
      if 'keyboard' == deviceTypeName then
        keyboard_ = deviceName
        break
      end
    end
  end
  
  return keyboard_
end

function loadCommandsLayer(layerName, keyCommands, modifiers)
  createNewInputLayer(layerName)
  addDeviceProfileCommands(layerName, getKeyboardDeviceName(), keyCommands, modifiers, addKeyCombo)
end

function loadCommandMenuItems(modifiers)
  local res = loadInputFile('scripts/input/CommandMenuItems.lua')
  if res then
    loadCommandsLayer('CommandMenuItems', res, modifiers)
  end  
end

function loadTrainingWaitForUser(modifiers)
  local res = loadInputFile('scripts/input/TrainingWaitForUser.lua')
  if res then
    loadCommandsLayer('TrainingWaitForUser', res, modifiers)
  end  
end

function loadJFT(modifiers)
  local JFT = loadInputFile('scripts/input/JFT.lua')
  if JFT then
    loadCommandsLayer('JFT_global', JFT.global, modifiers)
    loadCommandsLayer('JFT_when_camera_set'  , JFT.when_camera_set, modifiers)
    loadCommandsLayer('JFT_when_binocular_view_set', JFT.when_binocular_view_set, modifiers)
  end  
end

function loadModifiersFromFolder(folder)
  local result
  
  local f, err = loadfile(folder .. 'modifiers.lua')
  
  if f then
    result = f()
  end
  
  return result, err
end

function getModifierEvent(modifier, folder, devices)
  local result
  local modifierDeviceName = modifier.device
    
  for i, device in ipairs(devices) do
    if folder == sysPath then
      if modifierDeviceName == device.templateName then
        result = getInputEvent(modifier.key, device.name)
        logMsg('Modifier from template ' .. device.templateName .. ' key ' .. modifier.key .. ' device ' .. device.name .. ' event ' .. tostring(result))
        break
      end
    else
      if modifierDeviceName == device.name then
        result = getInputEvent(modifier.key, device.name)
        logMsg('Modifier from device profile ' .. device.name .. ' key ' .. modifier.key .. ' event ' .. tostring(result))
        break
      end        
    end
  end
    
  return result  
end

function loadModifiers(devices)
  local result = {}
  local modifiers, err1, err2
  local folder = userPath  
  
  modifiers, err1 = loadModifiersFromFolder(folder)
  
  if not modifiers then
    folder = sysPath
    modifiers, err2 = loadModifiersFromFolder(folder)
  end
  
  if not modifiers then
    logError(string.format('Cannot load modifiers.lua file! Error [%s]', err1))
    logError(string.format('Cannot load modifiers.lua file! Error [%s]', err2))
  end  
  
  local modifierEvents = {}
  local switchEvents = {}
  
  for name, modifier in pairs(modifiers) do
    local event = getModifierEvent(modifier, folder, devices)
    
    if event then
      result[name] = event
      
      if modifier.switch then
        table.insert(switchEvents, event) 
      else
        table.insert(modifierEvents, event)        
      end
    end
  end
  
  NewInput.addModifiers(modifierEvents)
  NewInput.addSwitches(switchEvents)
  
  return result
end

local profiles_ = {}

function createPlaneLayer(planeName, pluginPath) 
	if profiles_[planeName] ~= nil then
		return
	end
    local profile = nil
    local devices = getDevices() 
    for i, device in ipairs(devices) do
		local result = loadPlaneDeviceProfile(planeName, device, pluginPath)
		if result then
		   if not profile then
			   profile = {}
		   end
		   profile[device.name] = result
		end
    end
	--nothing found
	if not profile then 
		print("profile for "..planeName.." not found")
		return
	end  
    createInputLayer(planeName, profile, getModifiers())
    profiles_[planeName] = profile
end

local devices = getInputDevices()
local modifiers = loadModifiers(devices)

function getModifiers()
  return modifiers
end

function getDevices()
  return devices
end

loadCommandMenuItems(modifiers)
loadTrainingWaitForUser(modifiers)
loadJFT(modifiers)

NewInput.setAircraftMarker(getAircraftMarker())

createPlaneLayer("default")

NewInput.setDefaultLayer(getAircraftMarker() .. getDefaultAircraft())
NewInput.setDefaultLayerTop()

file:close()