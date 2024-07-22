--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TypeDefinitions = require(
	ReplicatedFirst.Actor.__dependencies._Index["secondnewtonlaw_tabletobuffer@0.1.5"].tabletobuffer.TypeDefinitions
)
local BanReasons = require(ServerScriptService.ZoopActor.BanReasons)
local tabletobuffer = require(ReplicatedFirst.Actor.__dependencies.tabletobuffer)
local lualzw = require(ReplicatedStorage.lualzw)

local CommunicationRemoteEvent: RemoteEvent = Instance.new("RemoteEvent")
CommunicationRemoteEvent.Name = "__zoop_net"
CommunicationRemoteEvent.Parent = ReplicatedStorage

local ProtocolIdentifiers = tabletobuffer.TableAsBuffer({
	Handshake = 0x4, -- Implemented
	Heartbeat = 0x8, -- Implemented
	BanPlayer = 0x16, -- Implemented
	ReportDetection = 0x20,
})

local requestSerializer = tabletobuffer
	.GetDeserializerBuilder()
	.int8WithName("RequestType")
	.bufferWithName("RequestData", 0x2000)
	.build() :: TypeDefinitions.Serializer<{ RequestType: number, RequestData: buffer }>

local ReportDetectionToServerRequestSerializer = tabletobuffer
	.GetDeserializerBuilder()
	.int32WithName("DetectionID")
	.stringWithName("DetectionName", 256)
	.bufferWithName("userdata", 512)
	.build()

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
			.stringWithName("AgreedUponBufferContents", 16)
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
	.bufferWithName("MagicalBuffer", 0x1000)
	.build() :: TypeDefinitions.Serializer<{ MagicalNumber_1: number, MagicalNumber_2: number, MagicalResult: number, MagicalBuffer: buffer }>

local heartbeatList = {

	[0x0] = {
		AgreedUponNumber_1 = 0x0,
		AgreedUponNumber_2 = 0x0,

		AgreedUponBufferInfo = {
			AgreedUponCompression = 0x1, -- 0x1 == lualzw. 0x0 == none
			AgreedUponBufferContents = "A", -- Repeated string
			AgreedUponBufferLength = 0x100 + 0x1 + 0x4,
		},
	},
}

CommunicationRemoteEvent.OnServerEvent:Connect(function(player: Player, buf: unknown)
	if type(buf) ~= "buffer" then
		-- TODO: Ban for this kind of stuff because this should NEVER happen.
		warn("Invalid type provided for the zoop communication remote.")

		Players:BanAsync({
			UserIds = {
				player.UserId,
			},
			ApplyToUniverse = true,
			DisplayReason = BanReasons.DataValidationError.DisplayReason,
			PrivateReason = BanReasons.DataValidationError.PrivateReason,
			Duration = BanReasons.DataValidationError.Duration,
			ExcludeAltAccounts = false,
		})

		return
	end

	if buffer.len(buf) > requestSerializer.GetBufferSize() then
		warn("Potential garbage data ignored.")
		print("Received buffer: ", buffer.tostring(buf))
		return
	end

	local success, requestInformation = pcall(function()
		return requestSerializer.Deserialize(buf)
	end)

	if not success then
		warn("Potential malicious garbage data received.")
		print("Received buffer: ", buffer.tostring(buf))
	end

	if requestInformation.RequestType == ProtocolIdentifiers.BanPlayer then
		local successful, banRequest = pcall(function()
			return BanPlayerRequestSerializer.Deserialize(requestInformation.RequestData)
		end)

		if not successful then
			warn("Warning: ban request failed due to an error when deserializing the incoming buffer.")
			print("Received buffer: ", buffer.tostring(requestInformation.RequestData))
			return
		end

		if banRequest.TargetUserId ~= player.UserId then
			Players:BanAsync({
				UserIds = {
					player.UserId,
				},
				ApplyToUniverse = true,
				DisplayReason = BanReasons.Honeypotted.DisplayReason,
				PrivateReason = BanReasons.Honeypotted.PrivateReason,
				Duration = BanReasons.Honeypotted.Duration,
				ExcludeAltAccounts = false,
			})
		end

		local banReason: string

		success, banReason = pcall(function(bufAsTbl)
			return bufAsTbl["BanReason"] :: string
		end, BanReasons :: any)

		if success then
			Players:BanAsync({
				UserIds = {
					player.UserId,
				},
				ApplyToUniverse = true,
				DisplayReason = BanReasons[banReason].DisplayReason,
				PrivateReason = BanReasons[banReason].PrivateReason,
				Duration = BanReasons[banReason].Duration,
				ExcludeAltAccounts = false,
			})
		else
			Players:BanAsync({
				UserIds = {
					player.UserId,
				},
				ApplyToUniverse = true,
				DisplayReason = BanReasons.SuspectedTampering.DisplayReason,
				PrivateReason = BanReasons.SuspectedTampering.PrivateReason,
				Duration = BanReasons[banReason].Duration,
				ExcludeAltAccounts = false,
			})
		end
	elseif requestInformation.RequestType == ProtocolIdentifiers.Heartbeat then
		local s, err = pcall(function()
			local successful, heartbeat = pcall(function()
				return HeartbeatRequestSerializer.Deserialize(requestInformation.RequestData)
			end)

			if not successful then
				warn("Deserialization unsuccessful.")
				return "e"
			end

			local sharedInformation = heartbeatList[player.UserId]
			local rand = (sharedInformation :: any).AgreedUponRandom :: Random

			local magicalBufferLength = buffer.len(heartbeat.MagicalBuffer)
			if
				magicalBufferLength > 0x1000
				or magicalBufferLength < sharedInformation.AgreedUponBufferInfo.AgreedUponBufferLength
			then
				warn("Buffer size suspicious.")
				return "e"
			end

			local compression = buffer.readu8(heartbeat.MagicalBuffer, 0x0)

			if compression ~= sharedInformation.AgreedUponBufferInfo.AgreedUponCompression then
				warn("buffer compression mismatched.")
				return "e"
			end

			local stringLength = buffer.readi32(heartbeat.MagicalBuffer, 0x1)

			if stringLength > (0x1 + 0x4 + magicalBufferLength) then
				warn("buffer string length bigger than buffer.")
				return "e"
			end

			local rawHeartbeatString = buffer.readstring(heartbeat.MagicalBuffer, 0x1 + 0x4, stringLength)

			local heartbeatString = compression == 0x1 and lualzw.decompress(rawHeartbeatString) or rawHeartbeatString
			local agreedByte = string.byte(sharedInformation.AgreedUponBufferInfo.AgreedUponBufferContents, 1)

			for _, char in { heartbeatString:byte(1) } do
				if char ~= agreedByte then
					print("buffer byte mistmatch.")
					return "e"
				end
			end

			if
				heartbeat.MagicalResult
				~= (sharedInformation.AgreedUponNumber_1 + sharedInformation.AgreedUponNumber_2)
					* rand:NextInteger(0x1, 0x2)
			then
				warn("Magical result is not (Num1 + Num2) * agree_random:int32(0x1, 0x2)")
				return "e"
			end

			if
				heartbeat.MagicalNumber_1
				~= (sharedInformation.AgreedUponNumber_1 - sharedInformation.AgreedUponNumber_2)
					* rand:NextInteger(0x2, 0x4)
			then
				warn("Magical num 1 is not (Num1 - Num2) * agree_random:int32(0x2, 0x4)")
				return "e"
			end
			if
				heartbeat.MagicalNumber_2
				~= (sharedInformation.AgreedUponNumber_2 - sharedInformation.AgreedUponNumber_1)
					* rand:NextInteger(0x4, 0x6)
			then
				warn("Magical num 2 is not (Num2 - Num1) * agree_random:int32(0x4, 0x6) ")
				return "e"
			end
			heartbeatList[player.UserId].LastContact = tick()

			return "s"
		end)

		if not s or s and err == "e" then
			warn(`A heartbeat with a player has failed. This has been logged.`)
		end
	end
end)

local function randomstring(len)
	local Str = ""

	for _ = 1, len do
		Str ..= string.char(math.random(1, 127))
	end

	return Str
end

Players.PlayerAdded:Connect(function(newPlayer: Player)
	local seed = math.random(-32767, 32767)
	heartbeatList[newPlayer.UserId] = {
		AgreedUponNumber_1 = math.random(-32767, 32767),
		AgreedUponNumber_2 = math.random(-32767, 32767),
		AgreedUponSeed = seed :: number,

		AgreedUponBufferInfo = {
			AgreedUponCompression = math.random(0, 1), -- 0x0 = no compress, 0x1 = lualzw
			AgreedUponBufferContents = randomstring(16),
			AgreedUponBufferLength = 0x100 * 8 + 0x4 + 0x1,
		},

		LastContact = -1, -- -1 == never
		AgreedUponRandom = Random.new(seed) :: Random,
	}

	local nBuf = requestSerializer.Serialize({
		RequestType = ProtocolIdentifiers.Handshake,
		RequestData = HandshakeToClientRequestSerializer.Serialize(heartbeatList[newPlayer.UserId]),
	})

	local playerHeartbeatCfg = heartbeatList[newPlayer.UserId]
	print(
		string.format(
			[[
Initiating Handshake with %s...
		
Handshake_Config: {
	AgreedUponNumber_1 = %d,
	AgreedUponNumber_2 = %d,
	AgreedUponSeed = %d,

	AgreedUponBufferInfo = {
		AgreedUponCompression = '%s',
		AgreedUponBufferContents = '%s',
		AgreedUponBufferLength = '%d',
	}
}
]],
			newPlayer.Name,
			playerHeartbeatCfg.AgreedUponNumber_1,
			playerHeartbeatCfg.AgreedUponNumber_2,
			playerHeartbeatCfg.AgreedUponSeed :: number,
			playerHeartbeatCfg.AgreedUponBufferInfo.AgreedUponCompression == 1 and "lzw" or "none",
			playerHeartbeatCfg.AgreedUponBufferInfo.AgreedUponBufferContents,
			playerHeartbeatCfg.AgreedUponBufferInfo.AgreedUponBufferLength
		)
	)

	CommunicationRemoteEvent:FireClient(newPlayer, nBuf)

	task.delay(5, function()
		if heartbeatList[newPlayer.UserId] and heartbeatList[newPlayer.UserId].LastContact == -1 then
			newPlayer:Kick("Client-Server Handshake failed.")
		end
	end)
	task.spawn(function()
		task.desynchronize() -- Exec on parallel.
		local rand = Random.new(task.wait(0.3) * tick())
		local oldLastContact = heartbeatList[newPlayer.UserId].LastContact
		local heartbeatLeniance = rand:NextInteger(3, 5) -- The amount of heartbeats the client is allowed to miss before initiating a disconnect

		while task.wait((6 * heartbeatLeniance) + newPlayer:GetNetworkPing() * 2) do
			if heartbeatList[newPlayer.UserId].LastContact == oldLastContact then
				newPlayer:Kick("Client initiated disconnect.")
			end
		end
	end)
end)

Players.PlayerRemoving:Connect(function(leavingPlayer: Player)
	if heartbeatList[leavingPlayer.UserId] then
		heartbeatList[leavingPlayer.UserId] = nil
	end
end)
