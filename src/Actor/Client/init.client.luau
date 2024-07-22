--!nonstrict
local Runner = script.Parent

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lualzw =
	require(script.Parent.__dependencies._Index["secondnewtonlaw_tabletobuffer@0.1.2"].tabletobuffer.External.lualzw)
local tabletobuffer = require(script.Parent.__dependencies.tabletobuffer)
local TypeDefinitions =
	require(script.Parent.__dependencies._Index["secondnewtonlaw_tabletobuffer@0.1.2"].tabletobuffer.TypeDefinitions)

--// [[ INIT ]] \\--

-- script:Destroy() -- Destroy the script to remove external references
-- script = Instance.new("Script") -- Overwrite the last reference to the script
-- script.Parent = Runner
-- We do this to hide the script from exploiters

-- Runner:Destroy()
-- Runner = nil
-- Do the same thing we do with the script to the actor

--// [[ VARIABLES ]] \\--
local OriginalIndex
local OriginalNewIndex
local OriginalNamecall

--// [[ FUNCTIONS ]] \\--

local function GetIndexMetamethod()
	local Metamethod

	xpcall(function()
		game.___()
	end, function()
		Metamethod = debug.info(2, "f")
	end)

	return Metamethod
end

local function GetNewIndexMetamethod()
	local Metamethod

	xpcall(function()
		game.___ = 0
	end, function()
		Metamethod = debug.info(2, "f")
	end)

	return Metamethod
end

local function GetNamecallMetamethod()
	local Metamethod

	xpcall(function()
		game:___()
	end, function()
		Metamethod = debug.info(2, "f")
	end)

	return Metamethod
end

local function getnamecallmethod()
	local Result = select(
		2,
		pcall(function()
			OriginalNamecall(game.Stats.Workspace.Kernel.Bodies)
		end)
	):split(" ")[1]

	return if typeof(Result) == "Instance" then "Unable to get method from lua" else Result
end

--// [[ MAIN ]] \\--

task.spawn(function() -- // Metamethod integrity checks
	task.desynchronize()

	OriginalIndex = GetIndexMetamethod()
	OriginalNewIndex = GetNewIndexMetamethod()
	OriginalNamecall = GetNamecallMetamethod()
	-- store the original functions
	-- print(OriginalIndex, "actor")

	while true do
		if
			GetIndexMetamethod() ~= OriginalIndex
			or GetNewIndexMetamethod() ~= OriginalNewIndex
			or GetNamecallMetamethod() ~= OriginalNamecall
		then
			-- One of the metamethods have been modified.
			print("Metamethod modification detected!")
		end

		pcall(OriginalIndex, game, "Name")
		pcall(OriginalNewIndex, {}, "a", 0)
		pcall(OriginalNamecall, game)

		if getnamecallmethod() ~= "___" then
			print("poor hook placed!", getnamecallmethod())
			-- A poorly made hook as been placed on one of the metamethods.
		end
		task.wait(20)
	end
end)

local zoopNet: RemoteEvent = ReplicatedStorage:WaitForChild("__zoop_net")

-- #region net

local ProtocolIdentifiers = tabletobuffer.TableAsBuffer({
	Handshake = 0x4,
	Heartbeat = 0x8,
	BanPlayer = 0x16,
})

local requestSerializer = tabletobuffer
	.GetDeserializerBuilder()
	.int8WithName("RequestType")
	.bufferWithName("RequestData", 4096)
	.build() :: TypeDefinitions.Serializer<{ RequestType: number, RequestData: buffer }>

local HandshakeToClientRequestSerializer = tabletobuffer
	.GetDeserializerBuilder()
	.int16WithName("AgreedUponNumber_1")
	.int16WithName("AgreedUponNumber_2")
	.int16WithName("AgreedUponSeed")
	.tableWithName(
		"AgreedUponBufferInfo",
		tabletobuffer
			.GetDeserializerBuilder()
			.int8WithName("AgreedUponCompression")
			.stringWithName("AgreedUponBufferContents", 1)
			.int16WithName("AgreedUponBufferLength")
			.build()
	)
	.build()

local BanPlayerRequestSerializer = tabletobuffer
	.GetDeserializerBuilder()
	.stringWithName("BanReason", 255)
	.doubleWithName("TargetUserId")
	.build() :: TypeDefinitions.Serializer<{ BanReason: string, TargetUserId: number }>

local HeartbeatRequestSerializer = tabletobuffer
	.GetDeserializerBuilder()
	.int32WithName("MagicalNumber_1")
	.int32WithName("MagicalNumber_2")
	.int32WithName("MagicalResult")
	.bufferWithName("MagicalBuffer", 1024)
	.build() :: TypeDefinitions.Serializer<{ MagicalNumber_1: number, MagicalNumber_2: number, MagicalResult: number, MagicalBuffer: buffer }>

-- #endregion net

local HandshakeMetadata = tabletobuffer.TableAsBuffer({
	AgreedUponNumber_1 = 0x0,
	AgreedUponNumber_2 = 0x0,
	AgreedUponSeed = 0x0,

	AgreedUponBufferInfo = {
		AgreedUponCompression = 0x1, -- 0x1 == lualzw. 0x0 == none
		AgreedUponBufferContents = "_", -- Repeated string
		AgreedUponBufferLength = 0x100 + 0x1 + 0x4,
	},
})

zoopNet.OnClientEvent:ConnectParallel(function(buf: buffer)
	--[[
        The only time the event is called is when doing the initial Handshake, which we just record to a BufferAsTable construct.

    ]]

	local sRet = requestSerializer.Deserialize(buf)
	HandshakeMetadata = tabletobuffer.TableAsBuffer(HandshakeToClientRequestSerializer.Deserialize(sRet.RequestData))

	task.spawn(function()
		local agreedRandom = Random.new(HandshakeMetadata.AgreedUponSeed)
		local random = Random.new(
			HandshakeMetadata.AgreedUponNumber_1
				+ HandshakeMetadata.AgreedUponNumber_2 % HandshakeMetadata.AgreedUponNumber_1
				- HandshakeMetadata.AgreedUponNumber_2
		)
		local checkBuf = buffer.create(HandshakeMetadata.AgreedUponBufferInfo.AgreedUponBufferLength)
		local temporalBufferContents = string.rep(
			HandshakeMetadata.AgreedUponBufferInfo.AgreedUponBufferContents,
			HandshakeMetadata.AgreedUponBufferInfo.AgreedUponBufferLength - 0x1 - 0x4
		)
		buffer.writeu8(checkBuf, 0x0, HandshakeMetadata.AgreedUponBufferInfo.AgreedUponCompression)
		buffer.writei32(checkBuf, 0x1, HandshakeMetadata.AgreedUponBufferInfo.AgreedUponBufferLength)
		buffer.writestring(
			checkBuf,
			0x1 + 0x4,
			HandshakeMetadata.AgreedUponBufferInfo.AgreedUponCompression == 0x1
					and lualzw.compress(temporalBufferContents)
				or HandshakeMetadata.AgreedUponBufferInfo.AgreedUponCompression == 0x0 and temporalBufferContents,
			HandshakeMetadata.AgreedUponBufferInfo.AgreedUponBufferLength - 0x1 - 0x4
		)
		while task.wait(random:NextInteger(1, 4)) do
			local nBuf = HeartbeatRequestSerializer.Serialize({
				MagicalResult = (HandshakeMetadata.AgreedUponNumber_1 + HandshakeMetadata.AgreedUponNumber_2)
					* agreedRandom:NextInteger(0x1, 0x2),
				MagicalNumber_1 = (HandshakeMetadata.AgreedUponNumber_1 - HandshakeMetadata.AgreedUponNumber_2)
					* agreedRandom:NextInteger(0x2, 0x4),
				MagicalNumber_2 = (HandshakeMetadata.AgreedUponNumber_2 - HandshakeMetadata.AgreedUponNumber_1)
					* agreedRandom:NextInteger(0x4, 0x6),
				MagicalBuffer = checkBuf,
			})

			zoopNet:FireServer(requestSerializer.Serialize({
				RequestType = ProtocolIdentifiers.Heartbeat,
				RequestData = nBuf,
			}))
		end
	end)
end)
