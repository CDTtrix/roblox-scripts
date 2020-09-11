-- Author .Trix
-- Date 09/10/20 8:12pm
-- Based on ModRemote(hasn't been updated in 3 years, this is my personal use case rewrite)

--[[
Api:
		remote:RegisterChildren(instance) -->>  nil
		remote:GetFunctionFromInstance(instance) -->> instance
		remote:GetEventFromInstance(instance) -->> instance
		remote:GetEvent(string) -->> instance
		remote:GetFunction(string) -->> instance
		remote:CreateFunction(string) -->> instance
		remote:CreateEvent(string) -->> instance
		
		remoteEvent:SendToPlayers(table,arguments) -->> nil 
		remoteEvent:SendToAllPlayers(arguments) -->> nil 
		remoteEvent:SendToPlayer(player) -->> nil
		remoteEvent:SendToServer(arguments) -->> nil 
		remoteEvent:Listen(function) -->> nil
		remoteEvent:Wait() -->> nil
		remoteEvent:GetInstance() -->> instance
		remoteEvent:Destroy() -->> nil
		
		remoteFunction:CallPlayer(player,arguments) -->> result
		remoteFunction:Callback(function) -->> nil
		remoteFunction:GetInstance() -->> instance
		remoteFunction:Destroy() -->> nil
		remoteFunction:SetClientCache(integer,boolean) -->> nil
		remoteFunction:ResetClientCache() -->> nil
		remoteFunction:CallServer(arguments) -->> result
]]

-- Services
local replicatedStorage	= game:GetService("ReplicatedStorage")
local server = game:FindService("NetworkServer")
local remote = {remoteEvent = {}; remoteFunction = {}}

-- Objects
local remoteEvent, remoteFunction, functionCache, remoteEvents, remoteFunctions = remote.remoteEvent, remote.remoteFunction, {}, {}, {}
local osTime, traceback = os.time, debug.traceback

-- Values
local maxWait = 1
local defaultCache = 10

-------- Private Functions --------

-- .. Creates a instance
local function Create(classType, parent, name)	
	assert(type(name) == "string", "Name is not a string")
	assert(type(classType) == "string", "ClassType is not a string")
	
	local object = Instance.new(classType)
	
	object.Parent = parent
	object.Name = name
	
	return object
end

-- .. Waits for a child, more expensive then using object:WaitForChild
local function WaitForChild(parent, name, timeLimit)	
	local child = parent:FindFirstChild(name)
		
	local startTime = tick()
	local warned = false
	
	-- ## Loops until child is 
	while not child do
		wait()
		
		if child then
			break
		end
		
		child = parent:FindFirstChild(name)
		
		-- ## If not warned and startTime
		if not warned and startTime + (timeLimit or 5) <= tick() and not child then
			warned = true
			
			warn("Infinite yield possible for " .. parent:GetFullName() .. ", " .. name .. ")\n" .. traceback())
			
			if timeLimit then
				return parent:FindFirstChild(name)
			end
		end
	end
	
	return child
end

-- .. Finds the first child within replicated storage 
local functionStorage = replicatedStorage:FindFirstChild("RemoteFunctions") or Create("Folder" , replicatedStorage, "RemoteFunctions")
local eventStorage = replicatedStorage:FindFirstChild("RemoteEvents") or Create("Folder", replicatedStorage, "RemoteEvents")

-- .. Creates the functionMetatable within the script
local functionMetatable = {
	__index = function(self, i)
		if rawget(remoteFunction, i) then
			return rawget(remoteFunction, i)
		else
			return rawget(self, i)
		end
	end;
	__newindex = function(self, i, v)
		if i == 'OnCallback' and type(v) == 'function' then
			self:Callback(v)
		end
	end;
	__call = function(self, ...)
		if server then
			return self:CallPlayer(...)
		else
			return self:CallServer(...)
		end
	end;
}

-- .. Creates the eventMetatable within the script
local eventMetatable = {
	__index = function(self, i)
		if rawget(remoteEvent, i) then
			return rawget(remoteEvent, i)
		else
			return rawget(self, i)
		end
	end;
	__newindex = function(self, i, v)
		if (i == 'OnRecieved' and type(v) == 'function') then
			self:Listen(v)
		end
	end;
}

-- .. Creates the remoteMetatable within the script
local remoteMetatable = {
	__call = function(self, ...)
		assert(server, "You can only call the module from server")
		
		local arguments = {...}
		
		if #arguments > 0 then
			for a = 1, #arguments do
				remote:RegisterChildren(arguments[a])
			end
		else
			remote:RegisterChildren()
		end
		
		return self
	end;
}

-- .. Sets a remote function instance in functionMetatable
local function CreateFunctionMetatable(instance)
	return setmetatable({remoteInstance = instance}, functionMetatable)
end

-- .. Sets the remote event in the eventMetatable
local function CreateEventMetatable(instance)
	return setmetatable({remoteInstance = instance}, eventMetatable)
end

-- .. Creates a function
local function CreateFunction(name, instance)
	local instance = instance or functionStorage:FindFirstChild(name) or Instance.new("RemoteFunction")
	
	instance.Parent = functionStorage
	instance.Name = name
	
	local _event = CreateFunctionMetatable(instance)
	remoteFunctions[name] = _event
	
	return _event
end

-- .. Creates a event
local function CreateEvent(name, instance)
	local instance = instance or eventStorage:FindFirstChild(name) or Instance.new("RemoteEvent")
	
	instance.Parent = eventStorage
	instance.Name = name
	
	local _event = CreateEventMetatable(instance)
	remoteEvents[name] = _event
	
	return _event
end

-------- Public Functions ---------

-- .. Registers the children under a instace
function remote:RegisterChildren(instance)
	assert(server, "RegisterChildren can only be called from the server")
	
	local parent = instance or getfenv(0).script
	
	if parent then
		local children = parent:GetChildren()
		
		for a = 1, #children do
			local child = children[a]
			
			if child:IsA("RemoteEvent") then
				CreateEvent(child.Name, child)
			elseif child:IsA("RemoteFunction") then
				CreateFunction(child.Name, child)
			end
		end
	end
end

-- .. Gets a function from an instance
function remote:GetFunctionFromInstance(instance)
	return CreateFunctionMetatable(instance)
end

-- .. Gets a event from an instance
function remote:GetEventFromInstance(instance)
	return CreateEventMetatable(instance)
end

-- .. Gets a function stored in the functionMetatable
function remote:GetFunction(name)
	assert(type(name) == 'string', "Name must be a string")
	assert(WaitForChild(functionStorage, name, maxWait), "Function " .. name .. " not found")
	
	return remoteFunctions[name] or CreateFunction(name)
end

-- .. Gets a event stored in the eventMetatable
function remote:GetEvent(name)	
	assert(type(name) == 'string', "Name must be a string")
	assert(WaitForChild(eventStorage, name, maxWait), "Event " .. name .. " not found")
	
	return remoteEvents[name] or CreateEvent(name)
end

-- .. Creates a function
function remote:CreateFunction(name)
	if not server then 
		warn("CreateFunction should be used by the server")
		return;
	end
	
	return CreateFunction(name)
end

-- .. Creates a event
function remote:CreateEvent(name)
	if not server then 
		warn("CreateEvent should be used by the server") 
		return;
	end
	
	return CreateEvent(name)
end

-- .. Fires the clients within a table with the arguments difined
function remoteEvent:SendToPlayers(playerList, ...)
	assert(server, "SendToPlayers should be called from the Server side")
	
	local arguments = { ... }
	
	for a = 1, #playerList do
		self.Instance:FireClient(playerList[a], unpack(arguments))
	end
end

-- .. Fires the client with the arguments difined
function remoteEvent:SendToPlayer(player, ...)
	assert(server, "SendToPlayers should be called from the Server side")
	
	local arguments = { ... }
	
	self.Instance:FireClient(player, unpack(arguments))
end

-- .. Fires the server 
function remoteEvent:SendToServer(...)
	assert(not server, "SendToServer should be called from the Client side")
	
	local arguments = { ... }
	
	self.Instance:FireServer(unpack(arguments))
end

-- .. Fires all clients
function remoteEvent:SendToAllPlayers(...)
	assert(server, "SendToAllPlayers should be called from the Server side")
	
	local arguments = { ... }
	
	self.Instance:FireAllClients(unpack(arguments))
end

-- .. Connects a function to the event
function remoteEvent:Listen(functionInstance)
	if server then
		self.Instance.OnServerEvent:Connect(functionInstance)
	else
		self.Instance.OnClientEvent:Connect(functionInstance)
	end
end

-- .. Waits on an event
function remoteEvent:Wait()
	if server then
		self.Instance.OnServerEvent:Wait()
	else
		self.Instance.OnClientEvent:Wait()
	end
end

-- .. Gets the instance of the event
function remoteEvent:GetInstance()
	return self.Instance
end

-- .. Destroys the instance of the event
function remoteEvent:Destroy()
	self.Instance:Destroy()
end

-- .. Invokes the defined player with the difined arguments
function remoteFunction:CallPlayer(player, ...)
	assert(server, "CallPlayer should be called from the server side")
	
	local arguments = { ... }
	
	local attempt, err = pcall(function()
		return self.Instance:InvokeClient(player, unpack(arguments))
	end)
	
	if not attempt then
		return warn("Failed to recieve response from " .. player.Name)
	end	
end

-- .. Sets the function for when the remoteFunction gets invoked
function remoteFunction:Callback(functionInstance)
	if server then
		self.Instance.OnServerInvoke = functionInstance
	else
		self.Instance.OnClientInvoke = functionInstance
	end
end

-- .. Gets the function instance
function remoteFunction:GetInstance()
	return self.Instance
end

-- .. Destroys the function
function remoteFunction:Destroy()
	self.Instance:Destroy()
end

-- .. Sets the client cache
function remoteFunction:SetClientCache(seconds, useAction)
	local seconds = seconds or defaultCache
	
	assert(server, "SetClientCache must be called on the server")
	
	local instance = self.Instance
	
	if seconds <= 0 then
		local cache = instance:FindFirstChild("ClientCache")
		if cache then cache:Destroy() end
	else
		local cache = instance:FindFirstChild("ClientCache") or Create("IntValue", {
			Parent = instance;
			Name = "ClientCache";
			Value = seconds;
		})
	end
	
	if useAction then
		local cache = instance:FindFirstChild("UseActionCaching") or Create("BoolValue", {
			Parent = instance;
			Name = "UseActionCaching";
		})
	else
		local cache = instance:FindFirstChild("UseActionCaching")
		
		if cache then 
			cache:Destroy() 
		end
	end
end

-- .. Resets the client cache
function remoteFunction:ResetClientCache()
	assert(not server, "ResetClientCache must be used on the client")
	
	local instance = self.Instance
	
	if instance:FindFirstChild("ClientCache") then
		functionCache[instance:GetFullName()] = {Expires = 0, Value = nil}
	else
		warn(instance:GetFullName() .. " doesb't have a cache")
	end		
end

-- .. Invokes a function server side
function remoteFunction:CallServer(...)
	assert(not server, "CallServer should be called from the client side")
	
	local arguments = { ... }
	
	local instance = self.Instance
	local clientCache = instance:FindFirstChild("ClientCache")
	
	if clientCache then
		local cacheName = instance:GetFullName() .. (instance:FindFirstChild("UseActionCaching") and tostring(({...})[1]) or "")
		
		local cache = functionCache[cacheName]
		
		if cache and time() < cache.Expires then
			return unpack(cache.Value)
		else
			local cacheValue = {instance:InvokeServer(unpack(arguments))}
			
			functionCache[cacheName] = {Expires = time() + clientCache.Value, Value = cacheValue}
			
			return unpack(cacheValue)
		end
	else
		return instance:InvokeServer(unpack(arguments))
	end
end

return setmetatable(remote, remoteMetatable)
