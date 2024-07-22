--!strict
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TypeDefinitions = require(
	ReplicatedFirst.Actor.__dependencies._Index["secondnewtonlaw_tabletobuffer@0.1.2"].tabletobuffer.TypeDefinitions
)
local BanReasons = require(ServerScriptService.ZoopActor.BanReasons)
local tabletobuffer = require(ReplicatedFirst.Actor.__dependencies.tabletobuffer)
local lualzw = require(ReplicatedStorage.lualzw)

local CommunicationRemoteEvent = Instance.new("RemoteEvent")
CommunicationRemoteEvent.Name = "__zoop_net"
CommunicationRemoteEvent.Parent = ReplicatedStorage

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
	.int16WithName("MagicalNumber_1")
	.int16WithName("MagicalNumber_2")
	.int32WithName("MagicalResult")
	.bufferWithName("MagicalBuffer", 1024)
	.build() :: TypeDefinitions.Serializer<{ MagicalNumber_1: number, MagicalNumber_2: number, MagicalResult: number, MagicalBuffer: buffer }>

local heartbeatList = {

	[0x0] = {
		AgreedUponNumber_1 = 0x0,
		AgreedUponNumber_2 = 0x0,

		AgreedUponBufferInfo = {
			AgreedUponCompression = 0x1, -- 0x1 == lualzw. 0x0 == none
			AgreedUponBufferContents = "A", -- Repeated string
			AgreedUponBufferLength = 0x100,
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
		local successful, heartbeat = pcall(function()
			return HeartbeatRequestSerializer.Deserialize(requestInformation.RequestData)
		end)

		if not successful then
			warn("Deserialization unsuccessful.")
			return
		end

		local sharedInformation = heartbeatList[player.UserId]

		if buffer.len(heartbeat.MagicalBuffer) ~= sharedInformation.AgreedUponBufferInfo.AgreedUponBufferLength then
			print("Buffer mismatch.")
			return
		end

		local compression = buffer.readu8(heartbeat.MagicalBuffer, 0x0)

		if compression ~= sharedInformation.AgreedUponBufferInfo.AgreedUponCompression then
			print("Buffer compression mismatched.")
			return
		end

		local stringLength = buffer.readi32(heartbeat.MagicalBuffer, 0x1)

		if stringLength > (0x1 + 0x4 + buffer.len(heartbeat.MagicalBuffer)) then
			print("Buffer string length messed up.")
			return
		end

		local heartbeatString = buffer.readstring(heartbeat.MagicalBuffer, 0x1 + 0x4, stringLength)

		local agreedByte = string.byte(sharedInformation.AgreedUponBufferInfo.AgreedUponBufferContents, 1)

		for _, char in { heartbeatString:byte(1) } do
			if char ~= agreedByte then
				print("buffer byte mistmatch.")
				return
			end
		end

		if heartbeat.MagicalResult ~= (sharedInformation.AgreedUponNumber_1 + sharedInformation.AgreedUponNumber_2) then
			warn("Magical result is not Num1 + Num2")
			return
		end

		if
			heartbeat.MagicalNumber_1 ~= (sharedInformation.AgreedUponNumber_1 - sharedInformation.AgreedUponNumber_2)
		then
			warn("Magical num 1 is not Num1 - Num2")
			return
		end
		if
			heartbeat.MagicalNumber_2 ~= (sharedInformation.AgreedUponNumber_2 - sharedInformation.AgreedUponNumber_1)
		then
			warn("Magical num 2 is not Num2 - Num1")
			return
		end
		heartbeatList[player.UserId].LastContact = tick()
	end
end)

Players.PlayerAdded:Connect(function(newPlayer: Player)
	heartbeatList[newPlayer.UserId] = {
		AgreedUponNumber_1 = math.random(-32767, 32767),
		AgreedUponNumber_2 = math.random(-32767, 32767),

		AgreedUponBufferInfo = {
			AgreedUponCompression = math.random(0, 1), -- 0x0 = no compress, 0x1 = lualzw
			AgreedUponBufferContents = math.random(0, 1) and "A" or "B",
			AgreedUponBufferLength = 0x100 + 0x1,
		},

		LastContact = -1, -- -1 == never
	}

	CommunicationRemoteEvent:FireClient(
		newPlayer,
		requestSerializer.Serialize({
			RequestType = ProtocolIdentifiers.Handshake,
			RequestData = HandshakeToClientRequestSerializer.Serialize(heartbeatList[newPlayer.UserId]),
		})
	)
end)
