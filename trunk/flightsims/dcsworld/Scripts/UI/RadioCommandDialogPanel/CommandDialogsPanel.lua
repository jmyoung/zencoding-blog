local base = _G

module('CommandDialogsPanel')

__index = base.getfenv()

local CommandMenu = base.require('CommandMenu')
local CommandDialog = base.require('CommandDialog')
local fsm = base.require('fsm')
local list = base.require('list')
local utils = base.require('utils')

local Gui = base.require("dxgui")
local Static = base.require("Static")
local Window = base.require("Window")
local Panel = base.require("Panel")
local TabSheetBar = base.require("TabSheetBar")
local Skin  = base.require('Skin')
local Size = base.require("Size")
local Color = base.require("Color")
local Text = base.require("Text")
local Insets = base.require("Insets")
local Bkg = base.require("Bkg")
local Bkg2 = base.require("Bkg2")

commandDialogIts = {} --map of iterators
dialogsList = nil
curDialogIt = nil --iterator in dialogsList
dialogsState = {}

toggled = false
showMenu = false
showSubtitles = false

local captionsMax = 5
local captionPrev = 6
local captionNext = 7

function TERMINATE()
	return { 	finish = true,
				newStage = 'Closed' }
end

function TO_STAGE(tbl, dialogName, stageName, stackOption_, depth_)
	return { 	menu 		= tbl.dialogs[dialogName].menus[stageName],
				newStage 	= stageName,
				stackOption = stackOption_,
				depth 		= depth_ }
end

--private:

local function setCurDialogIt_(self, curDialogIt)
	base.assert(curDialogIt ~= nil)			
	self.curDialogIt = curDialogIt
	local tabIndex = self.curDialogIt.element_.index
	self.tabSheetBar:setCurrentTabIndex(tabIndex)
end

function toggleDialog_(self, dialog, on)
	dialog:toggle(on)
	dialog:toggleMenu(self.showMenu)
	return on
end

local function openDialog_(self, dialog)
	if 	dialog and
		self:toggleDialog_(dialog, true) then
		--base.print(base.tostring(self.dialogsState[dialog]))
		if self.dialogsState[dialog] == nil then
			dialog:setMainMenu()
		else
			dialog:updateMenu()
		end
		self.dialogsState[dialog] = true
	end
end

local function closeDialog_(self, dialog)
	if self:toggleDialog_(dialog, false) then
		self.dialogsState[dialog] = false
	end
end

local function switchToDialog_(self, dialogIt)
	if dialogIt ~= self.curDialogIt then
		if self.curDialogIt then
			closeDialog_(self, self.curDialogIt.element_)
		end
		openDialog_(self, dialogIt.element_)
		setCurDialogIt_(self, dialogIt)
	end
end

local function getNextDialog_(self)
	local itStart = self.curDialogIt
	local itNext = itStart
	repeat
		itNext = itNext.next_ or self.dialogsList.head
	until itNext.element_:isAvailable() or itNext == itStart
	base.assert(itNext ~= nil)
	return itNext
end

local function getDialogNameFor_(self, senderId)
	local dialogs = self.commandDialogIts[senderId]
	if dialogs ~= nil then
		for dialogName, dialogIt in base.pairs(dialogs) do
			return dialogName
		end
	end
end

local function closeTabSheetBarFunc(self, time)
	self.tabSheetBar:getContainer():setVisible(false)
	self.tabSheetBarFuncRef = nil
	return nil
end

local function showTabSheetBar(self)
	self.tabSheetBar:getContainer():setVisible(true)
	local disappearTime = base.timer.getTime() + 3.0
	if self.tabSheetBarFuncRef == nil then
		self.tabSheetBarFuncRef = base.timer.scheduleFunction(closeTabSheetBarFunc, self, disappearTime)
	else
		base.timer.setFunctionTime(self.tabSheetBarFuncRef, disappearTime)
	end
end

local function closeTabSheetBar(self)
	self.tabSheetBar:getContainer():setVisible(false)
	if self.tabSheetBarFuncRef ~= nil then
		base.timer.removeFunction(self.tabSheetBarFuncRef)
		self.tabSheetBarFuncRef = nil
	end
end

local function updateVisible_(self)
--base.print('self.commonCommandMenuIt.element_:isLogEmpty() = '..base.tostring(self.commonCommandMenuIt.element_:isLogEmpty()))
--[[
	self.window:setVisible(	self.dialogsList:get_size() > 1 or
							self.commonCommandMenuIt.element_:isMenuVisible() or
							not self.commonCommandMenuIt.element_:isLogEmpty())
--]]
end

--public:

function new(self, menus, mainMenu, dialogsData)
	local newCommandDialogsPanel = {}
	base.setmetatable(newCommandDialogsPanel, self)
	if dialogsData_ then
		newCommandDialogsPanel:initialize(menus, mainMenu, dialogsData)
	end
	return newCommandDialogsPanel
end

function initialize(self, menus, mainMenu, dialogsData)
	
	--UI
	do
		local screenWidth, screenHeight = Gui.GetWindowSize()		
		local xOffset = 2560
		screenWidth = 2560
		screenHeight = 1440
		
		local containerSkin = {}
		local height = 400
		local window = Window.new(xOffset, 0, xOffset + screenWidth, height, "CommandDialogsPanel.Window")
    
		window:setHasCursor(false)
		window:setSkin(containerSkin)
		window:setHasCursor(false)
		window:setVisible(true)
		self.window = window
		
		do
			local font = base.skinPath..'../fonts/DejaVuLGCSansMono.ttf'
			local itemSkin = Skin.staticSkin()
			local colorGray = Color.grey(0.75)
			itemSkin.skinData.params.insets = Insets.new(5, 5)
			itemSkin.skinData.states.released[1].text.font = font
			itemSkin.skinData.states.released[1].text.fontSize = 13
			itemSkin.skinData.states.released[1].text.color = colorGray
			itemSkin.skinData.states.released[1].text.shadowColor = Color.black()
			itemSkin.skinData.states.released[1].text.shadowOffset = Size.new(1, 1)			
			itemSkin.skinData.states.released[1].bkg = Bkg2.singleLineBorder(colorGray)

			local boldFont = base.skinPath..'../fonts/DejaVuLGCSansMono-Bold.ttf'
			local selectedItemSkin = Skin.staticSkin()
			selectedItemSkin.skinData.params.insets = Insets.new(5, 5)
			selectedItemSkin.skinData.states.released[1].text.font = boldFont
			selectedItemSkin.skinData.states.released[1].text.fontSize = 13
			selectedItemSkin.skinData.states.released[1].text.color = Color.white()
			selectedItemSkin.skinData.states.released[1].text.shadowColor = Color.black()
			selectedItemSkin.skinData.states.released[1].text.shadowOffset = Size.new(1, 1)			
			selectedItemSkin.skinData.states.released[1].bkg = Bkg2.doubleLineBorder(Color.white())
			
			local arrowsSkin = Skin.staticSkin()
			arrowsSkin.skinData.states.released[1].text.font = boldFont
			arrowsSkin.skinData.states.released[1].text.fontSize = 13
			arrowsSkin.skinData.states.released[1].text.color = Color.white()
			arrowsSkin.skinData.states.released[1].text.shadowColor = Color.black()
			arrowsSkin.skinData.states.released[1].text.shadowOffset = Size.new(1, 1)			

			local skin = {
				container = containerSkin,
				item = itemSkin,
				selectedItem = selectedItemSkin,
				arrows = arrowsSkin,
				spacing = 10
			}
			
			local upperBarHeight = 25
			local tabSheetBar = TabSheetBar.new()
			tabSheetBar:setSkin(skin)
			tabSheetBar:setBounds(0, 0, screenWidth - CommandMenu.menuWidth, upperBarHeight)
			tabSheetBar:addTab('')
			tabSheetBar:getContainer():setVisible(false)
			window:insertWidget(tabSheetBar:getContainer())			
			self.tabSheetBar = tabSheetBar
			
			local textSkin = Skin.staticSkin()
			textSkin.skinData.params.textWrapping = true
			textSkin.skinData.states.released[1].text.font = font
			textSkin.skinData.states.released[1].text.fontSize = 15;
			textSkin.skinData.states.released[1].text.color = Color.white()
			textSkin.skinData.states.released[1].text.shadowColor = Color.black()
			textSkin.skinData.states.released[1].text.shadowOffset = Size.new(1, 1)						
			textSkin.skinData.states.released[1].bkg = Bkg.singleLineBorder(Color.new(0, 0.5, 0))
			
			local mainCaption = Static.new('')
			mainCaption:setSkin(textSkin)
			mainCaption:setBounds(screenWidth - CommandMenu.menuWidth, 0, CommandMenu.menuWidth, upperBarHeight)
			window:insertWidget(mainCaption)
			self.mainCaption = mainCaption
			
			local container = Panel.new()
			container:setSkin(containerSkin)
			container:setBounds(0, upperBarHeight, screenWidth, height - upperBarHeight)
			window:insertWidget(container)
			self.container = container
		end
	end	
	--base.print('CommandDialogsPanel.initialize()')
	self.dialogsData = dialogsData
	local commonCommandMenu = CommandMenu:new(menus, mainMenu, self.container)
	self.container:insertWidget(commonCommandMenu:getContainer())
	commonCommandMenu.index = 1
	commonCommandMenu:setHandler(self)
	function commonCommandMenu:isAvailable()
		return true
	end
	--openDialog_(self, commonCommandMenu)
	self.dialogsList = list:new()
	self.commonCommandMenuIt = self.dialogsList:push_back(commonCommandMenu)
	self.curDialogIt = self.commonCommandMenuIt
	updateVisible_(self)
end

function clear(self)
	for curSenderID, dialogIts in base.pairs(self.commandDialogIts) do
		for dialogName, dialogIt in base.pairs(dialogIts) do
			closeDialog_(self, dialogIt.element_)
			dialogsState[dialogIt.element_] = nil
			self.dialogsList:erase(dialogIt)
			self.container:removeWidget(dialogIt.element_:getContainer())
			dialogIt.element_:release()
		end
	end
	closeTabSheetBar(self)
	self.commandDialogIts = {}
	setCurDialogIt_(self, self.commonCommandMenuIt)
	updateVisible_(self)
end

function release(self)
	self:clear()
	--UI
	self.container:removeWidget(self.commonCommandMenuIt.element_:getContainer())	
	self.commonCommandMenuIt.element_:release()
	self.commonCommandMenuIt = nil
	self.tabSheetBar:destroy()
	self.tabSheetBar = nil
	self.mainCaption = nil
	self.container = nil
	self.window:kill()
	self.window = nil
	
	self.commandDialogIts = {}
	self.dialogsList = nil
	self.curDialogIt = nil
	self.dialogsState = {}

	self.showMenu = false
end

function toggle(self, on)
	self.toggled = on
	--self.window:setVisible(self.showSubtitles and self.toggled)
	self.dialogsState[self.curDialogIt.element_] = nil
	if on then
		openDialog_(self, self.curDialogIt.element_)
	else
		closeDialog_(self, self.curDialogIt.element_)
	end
end

function setShowSubtitles(self, on)
	self.showSubtitles = on
	--self.window:setVisible(self.showSubtitles and self.toggled) TO DO!!!
end

function setShowMenu(self, on)
	self.showMenu = on
	if 	on and
		not self.curDialogIt.element_:isAvailable() then
		switchToDialog_(self, getNextDialog_(self))
	end
	local menuVisibilityChanged = self.curDialogIt.element_:isMenuVisible() ~= on
	self:toggleDialog_(self.curDialogIt.element_, self.dialogsState[self.curDialogIt.element_] or false)
	if menuVisibilityChanged then
		self.curDialogIt.element_:setMainMenu()	
	end
	updateVisible_(self)
end

function isMenuVisible(self)
	return self.curDialogIt.element_:isMenuVisible()
end

function setMainCaption(self, text)
	self.mainCaption:setText(text)
end

function getDialogFor(self, senderId)
	local dialogName = getDialogNameFor_(self, senderId)
	if dialogName ~= nil then
		return self.commandDialogIts[senderId][dialogName]
	end
end

function switchToDialogFor(self, senderId)
	switchToDialog_(self, self:getDialogFor(senderId))
end

function releaseDialog(self, senderId, dialogName)
	local dialogIt = self.commandDialogIts[senderId][dialogName]
	base.assert(dialogIt ~= nil)
	
	do
		self.tabSheetBar:removeTab(dialogIt.element_.index)
		if self.tabSheetBar:getTabCount() < 2 then
			closeTabSheetBar(self)
		end
		local nextDialogIt = dialogIt.next_
		while nextDialogIt ~= nil do
			nextDialogIt.element_.index = nextDialogIt.element_.index - 1
			nextDialogIt = nextDialogIt.next_
		end
	end

	local nextDialogIt = self.curDialogIt	
	closeDialog_(self, dialogIt.element_)
	self.container:removeWidget(dialogIt.element_:getContainer())
	dialogIt.element_:release()
	if dialogIt == self.curDialogIt then
		nextDialogIt = getNextDialog_(self)
		self.curDialogIt = nil
		self.showMenu = false
	end
	self.dialogsList:erase(dialogIt)				
	self.commandDialogIts[senderId][dialogName] = nil
	if nextDialogIt ~= self.curDialogIt then
		switchToDialog_(self, nextDialogIt)
	end
	updateVisible_(self)
end

function closeSenderDialogs(self, senderId)
	local dialogName = getDialogNameFor_(self, senderId)
	while dialogName ~= nil do
		self:releaseDialog(senderId, dialogName)
		dialogName = getDialogNameFor_(self, senderId)
	end
end

innerFsms = {}

function addFsm(self, senderId, name, data)
	innerFsms[senderId] = innerFsms[senderId] or {}
	local handler = {
		handle = function(recepient, symbol)
			--base.print('commandDialogsPanel:onEvent() from '..name)
			recepient.commandDialogsPanel:onEvent(symbol, senderId)
		end,
		commandDialogsPanel = self
	}
	innerFsms[senderId][name] = innerFsms[senderId][name] or fsm:new(data, handler.handle, handler, name)
	base.table.insert(innerFsms, newFsm)
end

--public:

DialogStartTrigger = {
	new = function(self, commandDialogsPanelIn, dialogIn)
		local newTrigger = {}
		newTrigger.commandDialogsPanel = commandDialogsPanelIn
		newTrigger.dialog = dialogIn
		self.__index = self
		base.setmetatable(newTrigger, self)
		return newTrigger
	end,
	run = function(self, senderId)
		--base.print('start dialog '..self.dialog.name)
		self.commandDialogsPanel:openDialog(self.dialog, senderId, nil)
	end
}

StartFSMTrigger = {
	new = function(self, commandDialogsPanelIn, fsmNameIn, fsmDataIn)
		local newTrigger = {}
		newTrigger.commandDialogsPanel = commandDialogsPanelIn
		newTrigger.fsmName = fsmNameIn
		newTrigger.fsmData = fsmDataIn
		self.__index = self
		base.setmetatable(newTrigger, self)	
		return newTrigger
	end,
	run = function(self, senderId)
		--base.print('start fsm '..self.fsmName..' for sender '..base.tostring(senderId))
		self.commandDialogsPanel:addFsm(senderId, self.fsmName, self.fsmData)
	end
}

function onEvent(self, event, senderId, receiverId, receiverAsRecepient)
	--base.print('event = '..base.tostring(event))
	--base.print('senderId = '..base.tostring(senderId))
	local trigger = self.dialogsData.triggers[event]
	if trigger then
		trigger:run(receiverAsRecepient and receiverId or senderId)
	end
	local dialogToSwitchTo = nil
	local dialogsToRelease = {}
	for recepientId, dialogs in base.pairs(self.commandDialogIts) do
		if senderId == recepientId or receiverId == recepientId then
			for dialogName, dialogIt in base.pairs(dialogs) do
				--base.print('dialog['..base.tostring(recepientId)..']['..base.tostring(dialogName)..']:onEvent('..base.tostring(event)..')')
				--base.print('dialog.dialogFsm.state='..dialogIt.element_.dialogFsm.state)
				local result = dialogIt.element_:onEvent(event)
				--base.print('dialog.dialogFsm.state='..dialogIt.element_.dialogFsm.state)
				if result == CommandDialog.OnEventResult.MENU_CHANGED then
					--base.print('result == CommandDialog.OnEventResult.MENU_CHANGED')
					--base.print('onEvent '..base.tostring(event))
					if 	dialogToSwitchTo == nil and
						dialogIt.element_:isAvailable() then
						dialogToSwitchTo = dialogIt
					end
				elseif result == CommandDialog.OnEventResult.FINISHED then
					--base.print('result == CommandDialog.OnEventResult.FINISHED')
					--dialog
					base.table.insert(dialogsToRelease, { recepientId = recepientId, dialogName = dialogName })
					--self:releaseDialog(recepientId, dialogName)
				end
			end
		end
	end
	for dialogToReleaseIndex, dialogToRelease in base.pairs(dialogsToRelease) do
		self:releaseDialog(dialogToRelease.recepientId, dialogToRelease.dialogName)
	end
	if dialogToSwitchTo ~= nil then
		switchToDialog_(self, dialogToSwitchTo)
	end
	for senderId, senderFsms in base.pairs(self.innerFsms) do
		for theFsmName, theFsm in base.pairs(senderFsms) do
			--base.print('fsm '..theFsmName..' on event '..base.tostring(event))
			theFsm:onSymbol(event)
		end
	end
end

function openDialog(self, dialog, senderId, action, color)
	if 	self.commandDialogIts[senderId] and 
		self.commandDialogIts[senderId][dialog.name] then
		return nil
	else
		self.commandDialogIts[senderId] = self.commandDialogIts[senderId] or {}
		--dialog
		local senderName = self.getSenderName(senderId)
		local dialogCaption = (senderName ~= nil and senderName..'. ' or '')..dialog.name
		local newDialog = CommandDialog:new(dialogCaption, dialog, action, {[1] = senderId}, color, self.container, self.commonCommandMenuIt)
		self.container:insertWidget(newDialog:getContainer())
		newDialog.index = self.dialogsList:get_size() + 1
		newDialog:setHandler(self)				
		self.commandDialogIts[senderId][dialog.name] = self.dialogsList:push_back(newDialog)
		self.tabSheetBar:addTab(dialog.name)
		if self.tabSheetBar:getTabCount() > 1 then
			showTabSheetBar(self)
		end
		updateVisible_(self)
		return newDialog
	end
end

function switchToMainMenu(self)
	if self.tabSheetBar:getTabCount() > 1 then
		showTabSheetBar(self)
	end
	switchToDialog_(self, self.commonCommandMenuIt)
end

function switchToNextDialog(self)
	if self.tabSheetBar:getTabCount() > 1 then
		showTabSheetBar(self)
	end
	switchToDialog_(self, getNextDialog_(self))
end

function selectMenuItem(self, num)
	self.curDialogIt.element_:selectMenuItem(num)
end

function onDialogsMsg_(self, objectId, msg, color, duration)
	local dialogItToSwitch = nil
	if objectId then
		local dialogIts = self.commandDialogIts[objectId]
		if dialogIts then
			for dialogName, dialogIt in base.pairs(dialogIts) do
				if self.showSubtitles then
					dialogIt.element_:onMsg(msg, color, duration)
				end
				dialogItToSwitch = dialogIt
			end
		end
	end
	return dialogItToSwitch
end

function onMsg(self, senderId, receiverId, msg, color, duration)
	if self.showSubtitles then
		self.commonCommandMenuIt.element_:onMsg(msg, color, duration)
	end
	local dialogItToSwitch = self.commonCommandMenuIt		
	local res1 = self:onDialogsMsg_(receiverId, msg, color, duration)
	dialogItToSwitch = dialogItToSwitch or res1
	local res2 = self:onDialogsMsg_(senderId, msg, color, duration)
	dialogItToSwitch = dialogItToSwitch or res2
	if 	dialogItToSwitch and
		dialogItToSwitch.element_ ~= self.commonCommandMenuIt.element_ then
		switchToDialog_(self, dialogItToSwitch)
	end
	updateVisible_(self)
end

--CommandMenus & CommandDialogs events handlers

function onDialogSetCaption(self, dialog, caption)
	self.tabSheetBar:setTabText(dialog.index, caption)
end

function onDialogToggle(self, dialog, on)
end

function onDialogCommand(self, dialog)
end

function onCommandMenuEmpty(self, menu)
	updateVisible_(self)
end

function switchToDialog(self, dialog)
	switchToDialog_(self, self.commonCommandMenuIt)
end
