ChangeFillOrderEvent = {}
ChangeFillOrderEvent_mt = Class(ChangeFillOrderEvent, Event)
InitEventClass(ChangeFillOrderEvent, "ChangeFillOrderEvent")

function ChangeFillOrderEvent:emptyNew()
	local self = Event:new(ChangeFillOrderEvent_mt)
	return self
end

function ChangeFillOrderEvent:new(object)
	local self = ChangeFillOrderEvent:emptyNew()
	self.object = object
	return self
end

function ChangeFillOrderEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.object.spec_bulkFill.isFilling = streamReadBool(streamId)
	self.object.spec_bulkFill.selectedIndex = streamReadInt32(streamId)
	
	self:run(connection)
end

function ChangeFillOrderEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.object.spec_bulkFill.isFilling)
	streamWriteInt32(streamId, self.object.spec_bulkFill.selectedIndex)
end

function ChangeFillOrderEvent:run(connection)
	if not connection:getIsServer() then
		--print("ChangeFillOrderEvent: server")
		self.object:changeFillOrder(true)
	else
		--print("ChangeFillOrderEvent: client")
		self.object:changeFillOrder(true)
	end
end