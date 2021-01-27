-- ============================================================= --
-- BULK FILL MOD
-- ============================================================= --
BulkFill = {};

addModEventListener(BulkFill);
source(g_currentModDirectory.."OpenCoverEvent.lua")
source(g_currentModDirectory.."StopFillingEvent.lua")
source(g_currentModDirectory.."StartFillingEvent.lua")

function BulkFill.prerequisitesPresent(specializations)
	return  SpecializationUtil.hasSpecialization(FillUnit, specializations) and
			SpecializationUtil.hasSpecialization(FillVolume, specializations) and
			SpecializationUtil.hasSpecialization(Cover, specializations)
end

function BulkFill.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdate", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "saveToXMLFile", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", BulkFill)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", BulkFill)
end

function BulkFill.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "toggleBulkFill", BulkFill["toggleBulkFill"])
	SpecializationUtil.registerFunction(vehicleType, "openCover", BulkFill["openCover"])
	SpecializationUtil.registerFunction(vehicleType, "stopFilling", BulkFill["stopFilling"])
	SpecializationUtil.registerFunction(vehicleType, "startFilling", BulkFill["startFilling"])
	SpecializationUtil.registerFunction(vehicleType, "toggleFillSelection", BulkFill["toggleFillSelection"])
	SpecializationUtil.registerFunction(vehicleType, "cycleFillTriggers", BulkFill["cycleFillTriggers"])
end

-- SAVE AND RETRIEVE TOGGLED STATE TO/FROM VEHICLES.XML
function BulkFill:onLoad(savegame)
	self.isFilling = false
	self.selectedIndex = 1
	self.canFillFrom = {}
	self.hasFillCovers = false
	
	if self.spec_cover ~= nil and self.spec_cover.hasCovers then
		self.hasFillCovers = true
	end

	if 	self.typeName == 'tractor' or
		self.typeName == 'locomotive' or
		self.typeName == 'trainTrailer' or
		self.typeName == 'trainTimberTrailer' or
		self.typeDesc == 'auger wagon' or
		self.typeName == 'receivingHopper' or
		self.typeName == 'pallet' or
		self.typeName == 'baler' or
		self.typeName == 'tedder'
	then
		self.spec_bulkFill.isValid = false
		--print("BULK FILL NOT LOADED: " .. self.typeDesc .. ", " .. self.typeName)
	else
		self.spec_bulkFill.isValid = true
		--print("BULK FILL LOADED: " .. self.typeDesc .. ", " .. self.typeName)
	end
	
	if savegame ~= nil and self.spec_bulkFill.isValid then
		self.spec_bulkFill.isEnabled = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key..".bulkFill#isEnabled"), true)
		self.spec_bulkFill.isSelectEnabled = Utils.getNoNil(getXMLBool(savegame.xmlFile, savegame.key..".bulkFill#isSelectEnabled"), true)
	else
		self.spec_bulkFill.isEnabled = true
		self.spec_bulkFill.isSelectEnabled = true
	end
end
function BulkFill:saveToXMLFile(xmlFile, key, usedModNames)
	if self.spec_bulkFill.isValid then
		setXMLBool(xmlFile, key ..".bulkFill#isEnabled", self.spec_bulkFill.isEnabled)
		setXMLBool(xmlFile, key ..".bulkFill#isSelectEnabled", self.spec_bulkFill.isSelectEnabled)
	end
end

-- MULTIPLAYER
function BulkFill:onReadStream(streamId, connection)
	if connection:getIsServer() then
		local spec = self.spec_bulkFill
		if spec.isValid then
			spec.isFilling = streamReadBool(streamId)
		end
	end
end

function BulkFill:onWriteStream(streamId, connection)
	if not connection:getIsServer() then
		local spec = self.spec_bulkFill
		if spec.isValid then
			streamWriteBool(streamId, spec.isFilling)
		end
	end
end

-- TOGGLE ENABLE/DISABLE BULK FILL
function BulkFill:onRegisterActionEvents(isSelected, isOnActiveVehicle)
	if isOnActiveVehicle and self.spec_bulkFill.isValid then
		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'TOGGLE_BULK_FILL', self, BulkFill.actionEventHandler, false, true, false, true)
		if self.spec_bulkFill.isEnabled then
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_ENABLED"))
		else
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_DISABLED"))
		end
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, true)
		g_inputBinding:setActionEventActive(actionEventId, true)
		self.spec_bulkFill.toggleActionEventId = actionEventId

		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'TOGGLE_FILL_SELECT', self, BulkFill.actionEventHandler, false, true, false, true)
		if self.spec_bulkFill.isSelectEnabled then
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_FILL_SELECT_ENABLED"))
		else
			g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_FILL_SELECT_DISABLED"))
		end
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, true)
		g_inputBinding:setActionEventActive(actionEventId, true)
		self.spec_bulkFill.showActionEventId = actionEventId
		
		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'BULK_FILL_CYCLE_FW', self, BulkFill.actionEventHandler, false, true, false, true)
		g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_CYCLE_FW"))
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, false)
		g_inputBinding:setActionEventActive(actionEventId, false)
		self.spec_bulkFill.cycleFwActionEventId = actionEventId
		
		local _, actionEventId = InputBinding.registerActionEvent(g_inputBinding, 'BULK_FILL_CYCLE_BW', self, BulkFill.actionEventHandler, false, true, false, true)
		g_inputBinding:setActionEventText(actionEventId, g_i18n:getText("action_BULK_FILL_CYCLE_BW"))
		g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
		g_inputBinding:setActionEventTextVisibility(actionEventId, false)
		g_inputBinding:setActionEventActive(actionEventId, false)
		self.spec_bulkFill.cycleBwActionEventId = actionEventId
	end
end
function BulkFill:onUpdate(dt, isActiveForInput, isSelected)
	if isActiveForInput and self.spec_bulkFill.isValid then
		local bf = self.spec_bulkFill
		local spec = self.spec_fillUnit
		
		-- I cannot find where this happens: when a container stops filling due to becoming full
		if self.spec_bulkFill.isFilling ~= self.spec_fillUnit.fillTrigger.isFilling then
			--print("isFilling was changed without us knowing..")
			self.spec_bulkFill.isFilling = self.spec_fillUnit.fillTrigger.isFilling
			bf.lastNumberTriggers = 0 -- change this to trigger 'MULTIPLE FILL TYPES AVAILABLE'
		end
		
		if #spec.fillTrigger.triggers == 0 then
			-- --print("NO TRIGGERS AVAILABLE")
			bf.selectedIndex = 1
			g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, false)
			g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, false)
			g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, false)
			g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, false)
			
			if spec.fillTrigger.currentTrigger ~= nil then
				--print("STOP FILLING")
				self:stopFilling()
			end
			
		else
			-- --print("TRIGGERS AVAILABLE")
			bf.selectedIndex = MathUtil.clamp(bf.selectedIndex, 1, #spec.fillTrigger.triggers)
			
			
			if bf.isSelectEnabled and bf.hasFillCovers and #spec.fillUnits>1 and
			   (bf.lastCoverOpen ~= self.spec_cover.state or
				bf.lastSelectedIndex ~= bf.selectedIndex or
				bf.lastNumberTriggers ~=# spec.fillTrigger.triggers)
			then
				-- --print("VEHICLE HAS COVERS WITH MULTIPLE FILL TYPES AVAILABLE")
				bf.lastCoverOpen = self.spec_cover.state
				bf.lastSelectedIndex = bf.selectedIndex
				bf.lastNumberTriggers = #spec.fillTrigger.triggers
				
				openCoverFillType = 0
				if self.spec_cover.state ~= 0 then
					local openCoverFillIndex = self.spec_cover.covers[self.spec_cover.state].fillUnitIndices[1]
					if spec.fillUnits[openCoverFillIndex].fillLevel < spec.fillUnits[openCoverFillIndex].capacity then
						openCoverFillType = next(spec.fillUnits[openCoverFillIndex].supportedFillTypes)
					else
						--print("TEST NEXT STATE")
						local newState = self.spec_cover.state + 1
						if newState > #self.spec_cover.covers then
							newState = 1
						end
						if not self:getIsNextCoverStateAllowed(newState) then
							--print("CLOSE COVER")
							self:openCover(0)
						end
					end
				end

				for i = 1, #spec.fillTrigger.triggers do
					if spec.fillTrigger.triggers[i] ~= nil then
						local trigger = spec.fillTrigger.triggers[i]
						if trigger.sourceObject ~= nil then
							local sourceObject = trigger.sourceObject
							if sourceObject.spec_fillUnit.fillUnits[1].fillType == openCoverFillType then
								bf.canFillFrom[sourceObject.id] = true
							else
								bf.canFillFrom[sourceObject.id] = false
								
								if i == bf.selectedIndex then
									for j = 1, #self.spec_cover.covers do
										if spec.fillUnits[j].fillLevel < spec.fillUnits[j].capacity then
											local thisCoverFillType = next(spec.fillUnits[j].supportedFillTypes)
											local requiredFillType = sourceObject.spec_fillUnit.fillUnits[1].fillType
											if thisCoverFillType == requiredFillType then
												--print("OPEN COVER FOR SELECTED INDEX")
												local cover = self:getCoverByFillUnitIndex(j)
												if cover ~= nil then
													self:openCover(cover.index)
												end
											end
										end
									end
								end
							end	
						end
					end
				end
			end

			if spec.fillTrigger.currentTrigger ~= nil then
				if spec.fillTrigger.triggers[bf.selectedIndex]~=nil and spec.fillTrigger.triggers[bf.selectedIndex]~=spec.fillTrigger.currentTrigger then
					-- --print("CURRENT TRIGGER HAS CHANGED")
					if spec.fillTrigger.currentTrigger.sourceObject ~= nil then
						if spec.fillTrigger.currentTrigger.sourceObject.isDeleted then
							--print("DELETED: "..tostring(spec.fillTrigger.currentTrigger.sourceObject.id))
							
							if bf.isEnabled then
								local nextFillType = spec.fillTrigger.triggers[bf.selectedIndex].sourceObject.spec_fillUnit.fillUnits[1].lastValidFillType
								local previousFillType = spec.fillTrigger.currentTrigger.sourceObject.spec_fillUnit.fillUnits[1].lastValidFillType
								if nextFillType == previousFillType then
									--print("FILL FROM NEXT: "..tostring(spec.fillTrigger.triggers[bf.selectedIndex].sourceObject.id))
									if #spec.fillUnits==1 then
										local sourceObject = spec.fillTrigger.triggers[bf.selectedIndex].sourceObject
										bf.canFillFrom[sourceObject.id] = nil
									end
									spec.fillTrigger.activatable:onActivateObject()
								else
									if #spec.fillTrigger.triggers > 0 then
										--print("FILL TYPES ARE DIFFERENT")
										if #spec.fillUnits==1 then
											local sourceObject = spec.fillTrigger.triggers[bf.selectedIndex].sourceObject
											bf.canFillFrom[sourceObject.id] = false
										end
										self:cycleFillTriggers('FW')
										if bf.selectedIndex == 1 then
											self:stopFilling()
										end
									end
								end
							else
								--print("STOP FILLING 2")
								self:stopFilling()
							end
						end
					end
				end
			end

			if bf.isSelectEnabled and not g_gui:getIsGuiVisible() then
				if bf.isFilling then
					g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, false)
					g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, false)
					g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, false)
					g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, false)
				else
					g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, true)
					g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, true)
					g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, true)
					g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, true)
				end

				for i = 1, #spec.fillTrigger.triggers do
					if spec.fillTrigger.triggers[i] ~= nil then
						local trigger = spec.fillTrigger.triggers[i]
						if trigger.sourceObject ~= nil then
							if trigger.sourceObject.numComponents == 1 then
								local sourceObject = trigger.sourceObject
								if sourceObject.isAddedToPhysics and not sourceObject.isDeleted then
									local colour = {}
									if i==bf.selectedIndex then
										if bf.canFillFrom[sourceObject.id] == nil then
											colour = {1.0,1.0,0.1,1.0} -- YELLOW
										else
											if bf.canFillFrom[sourceObject.id] then
												colour = {0.1,1.0,0.1,1.0} -- GREEN
											else
												colour = {1.0,0.1,0.1,1.0} -- RED
											end
										end
									else
										colour = {1.0,1.0,1.0,0.3}
									end
									local fillLevelBuffer = {}
									sourceObject:getFillLevelInformation(fillLevelBuffer)
									local fillLevelInformation = fillLevelBuffer[1]
									local fillLevel = string.format("%.0f", fillLevelInformation.fillLevel)
									local x, y, z = getWorldTranslation(sourceObject.rootNode)
									Utils.renderTextAtWorldPosition(x, y+1, z, "#"..i.."\n[ "..fillLevel.." ]", getCorrectTextSize(0.02), 0, colour)
								end
							end
						end
					end
				end
			else
				g_inputBinding:setActionEventTextVisibility(bf.cycleFwActionEventId, false)
				g_inputBinding:setActionEventTextVisibility(bf.cycleBwActionEventId, false)
				g_inputBinding:setActionEventActive(bf.cycleFwActionEventId, false)
				g_inputBinding:setActionEventActive(bf.cycleBwActionEventId, false)
			end
		end
	end
end
function BulkFill:actionEventHandler(actionName, inputValue, callbackState, isAnalog)
	if actionName=='TOGGLE_BULK_FILL' then
		self:toggleBulkFill()
	elseif actionName=='TOGGLE_FILL_SELECT' then
		self:toggleFillSelection()
	elseif actionName=='BULK_FILL_CYCLE_FW' then
		self:cycleFillTriggers('FW')
	elseif actionName=='BULK_FILL_CYCLE_BW' then
		self:cycleFillTriggers('BW')
	end
end
function BulkFill:toggleBulkFill()
	if not self.spec_bulkFill.isEnabled then
		--print("ENABLE BULK FILL")
		self.spec_bulkFill.isEnabled = true
		g_inputBinding:setActionEventText(self.spec_bulkFill.toggleActionEventId, g_i18n:getText("action_BULK_FILL_ENABLED"))
		self.spec_bulkFill.isFilling = self.spec_fillUnit.fillTrigger.isFilling
	else
		--print("DISABLE BULK FILL")
		self.spec_bulkFill.isEnabled = false
		self.spec_bulkFill.isFilling = false
		g_inputBinding:setActionEventText(self.spec_bulkFill.toggleActionEventId, g_i18n:getText("action_BULK_FILL_DISABLED"))
	end
end
function BulkFill:toggleFillSelection()
	if not self.spec_bulkFill.isSelectEnabled then
		--print("ENABLE FILL SELECTION")
		self.spec_bulkFill.isSelectEnabled = true
		g_inputBinding:setActionEventText(self.spec_bulkFill.showActionEventId, g_i18n:getText("action_FILL_SELECT_ENABLED"))
	else
		--print("DISABLE FILL SELECTION")
		self.spec_bulkFill.isSelectEnabled = false
		g_inputBinding:setActionEventText(self.spec_bulkFill.showActionEventId, g_i18n:getText("action_FILL_SELECT_DISABLED"))
	end
end
function BulkFill:cycleFillTriggers(direction)
	local bf = self.spec_bulkFill
	local spec = self.spec_fillUnit
	
	if direction == 'FW' then
		--print("CYCLE_FORWARDS")
		bf.selectedIndex = bf.selectedIndex + 1
	else
		--print("CYCLE_BACKWARDS")
		bf.selectedIndex = bf.selectedIndex - 1
	end
	
	if bf.selectedIndex < 1 then
		bf.selectedIndex = #spec.fillTrigger.triggers
	end
	if bf.selectedIndex > #spec.fillTrigger.triggers then
		bf.selectedIndex = 1
	end
end

-- AUTO FILLING:
function BulkFill.FillActivatableOnActivateObject(self, superFunc)
	local bf = self.vehicle.spec_bulkFill
	local spec = self.vehicle.spec_fillUnit
	
	if bf~=nil and bf.isValid then
		local sourceObject = spec.fillTrigger.triggers[bf.selectedIndex].sourceObject
		if sourceObject ~= nil then
			if bf.canFillFrom[sourceObject.id] == false then
				--print("INCORRECT FILL TYPE")
				return superFunc(self)
			else
				--print("CHANGE FILL ORDER")
				self.vehicle:startFilling(sourceObject.id)
			end
		end
	end

	superFunc(self)
	
	if bf~=nil and bf.isValid then
		if spec.fillTrigger.isFilling then
			--print("START FILLING: " .. tostring(spec.fillTrigger.currentTrigger.sourceObject.id))
			bf.isFilling = true
		else
			--print("CANCEL FILLING")
			bf.isFilling = false
		end
	end
end

-- NETWORK EVENTS:
function BulkFill:openCover(myState, noEventSend)
	--print("OPENING COVER: " .. myState)
	self:setCoverState(myState)
	self.spec_cover.isStateSetAutomatically = true

	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("g_server:broadcastEvent: openCover")
			g_server:broadcastEvent(OpenCoverEvent:new(self, myState), nil, nil, self)
		else
			--print("g_client:sendEvent: openCover")
			g_client:getServerConnection():sendEvent(OpenCoverEvent:new(self, myState))
		end
	end
end

function BulkFill:stopFilling(noEventSend)
	self.spec_fillUnit.fillTrigger.currentTrigger = nil
	self.spec_bulkFill.isFilling = false
	
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("g_server:broadcastEvent: stopFilling")
			g_server:broadcastEvent(StopFillingEvent:new(self), nil, nil, self)
		else
			--print("g_client:sendEvent: stopFilling")
			g_client:getServerConnection():sendEvent(StopFillingEvent:new(self))
		end
	end
end

function BulkFill:startFilling(myID, noEventSend)
	local spec = self.spec_fillUnit
	local objectFound = false
	
	for i = 1, #spec.fillTrigger.triggers do
		if spec.fillTrigger.triggers[i].sourceObject ~= nil then
			if spec.fillTrigger.triggers[i].sourceObject.id == myID then
				--print("index:" .. tostring(i) .. "  id:" .. tostring(spec.fillTrigger.triggers[i].sourceObject.id))
				if i~=1 then
					table.insert(spec.fillTrigger.triggers, 1, spec.fillTrigger.triggers[i])
					table.remove(spec.fillTrigger.triggers, i+1)
					spec.fillTrigger.currentTrigger = spec.fillTrigger.triggers[1]
				end
				objectFound = true
			end
		end
	end
	
	if not objectFound then
		--print("Couldn't find the object with id: " .. tostring(myID))
		if g_server ~= nil then
			table.insert(spec.fillTrigger.triggers, 1, spec.fillTrigger.triggers[1])
			spec.fillTrigger.triggers[1].sourceObject = g_server.objects[myID]
		end
	end
	
	if self.spec_bulkFill.selectedIndex ~= 1 then
		--print("CHANGING SELECTED INDEX BACK TO 1")
		self.spec_bulkFill.selectedIndex = 1
	end
	
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			--print("g_server:broadcastEvent: startFilling")
			g_server:broadcastEvent(StartFillingEvent:new(self, myID), nil, nil, self)
		else
			--print("g_client:sendEvent: startFilling")
			g_client:getServerConnection():sendEvent(StartFillingEvent:new(self, myID))
		end
	end
end

-- STOP FILLING WHEN UNLOADING
function BulkFill.FillUnitActionEventUnload(self, actionName, inputValue, callbackState, isAnalog)
	--print("UNLOADING")
	if self.spec_bulkFill ~= nil then
		local spec = self.spec_fillUnit
		if spec.fillTrigger.isFilling then
			--print("CANCEL LOADING")
			self:setFillUnitIsFilling(false)
			self.spec_bulkFill.isFilling = false
		end
	end
end

-- BULK FILL FUNCTIONS
function BulkFill:loadMap(name)
	--print("Load Mod: 'BULK FILL'")
	FillActivatable.onActivateObject = Utils.overwrittenFunction(FillActivatable.onActivateObject, BulkFill.FillActivatableOnActivateObject)
	FillUnit.actionEventUnload = Utils.prependedFunction(FillUnit.actionEventUnload, BulkFill.FillUnitActionEventUnload)

	BulkFill.initialised = false
end

function BulkFill:deleteMap()
end

function BulkFill:mouseEvent(posX, posY, isDown, isUp, button)
end

function BulkFill:keyEvent(unicode, sym, modifier, isDown)
end

function BulkFill:draw()
end

function BulkFill:update(dt)
	if not BulkFill.initialised then
		--print("g_client: "..tostring(g_client))
		--print("g_server: "..tostring(g_server))
		--print("self.isServer: "..tostring(self.isServer))
		BulkFill.initialised = true
	end
end

-- ADD custom strings from ModDesc.xml to g_i18n
local i = 0
local xmlFile = loadXMLFile("modDesc", g_currentModDirectory.."modDesc.xml")
while true do
	local key = string.format("modDesc.l10n.text(%d)", i)
	
	if not hasXMLProperty(xmlFile, key) then
		break
	end
	
	local name = getXMLString(xmlFile, key.."#name")
	local text = getXMLString(xmlFile, key.."."..g_languageShort)
	
	if name ~= nil then
		g_i18n:setText(name, text)
	end
	
	i = i + 1
end