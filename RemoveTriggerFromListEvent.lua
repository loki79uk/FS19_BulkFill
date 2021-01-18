RemoveTriggerFromListEvent = {}
RemoveTriggerFromListEvent_mt = Class(RemoveTriggerFromListEvent, Event)
InitEventClass(RemoveTriggerFromListEvent, "RemoveTriggerFromListEvent")

function RemoveTriggerFromListEvent:emptyNew()
	local self = Event:new(RemoveTriggerFromListEvent_mt)
	return self
end

function RemoveTriggerFromListEvent:new(object, index)
	local self = RemoveTriggerFromListEvent:emptyNew()
	self.object = object
	self.index = index
	return self
end

function RemoveTriggerFromListEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	
	self:run(connection)
end

function RemoveTriggerFromListEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function RemoveTriggerFromListEvent:run(connection)
	if not connection:getIsServer() then
		--print("RemoveTriggerFromListEvent: server")
		self.object:removeTriggerFromList(index, true)
	else
		--print("RemoveTriggerFromListEvent: client")
		self.object:removeTriggerFromList(index, true)
	end
end