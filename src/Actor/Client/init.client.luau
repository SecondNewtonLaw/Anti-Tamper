--!nonstrict
local Runner = script.Parent

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScriptContext = game:GetService("ScriptContext")

local lualzw =
	require(script.Parent.__dependencies._Index["secondnewtonlaw_tabletobuffer@0.1.5"].tabletobuffer.External.lualzw)
local tabletobuffer = require(script.Parent.__dependencies.tabletobuffer)
local TypeDefinitions =
	require(script.Parent.__dependencies._Index["secondnewtonlaw_tabletobuffer@0.1.5"].tabletobuffer.TypeDefinitions)

local zoopNet: RemoteEvent = ReplicatedStorage:WaitForChild("__zoop_net")

-- #region net

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

local ReportDetectionToServerRequestSerializer = tabletobuffer
	.GetDeserializerBuilder()
	.int32WithName("DetectionID")
	.stringWithName("DetectionName", 256)
	.bufferWithName("userdata", 512)
	.build() :: TypeDefinitions.Serializer<{ DetectionID: number, DetectionName: string, userdata: buffer }>

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
        The only time the event is called is when doing the initial Handshake, which returns us a certain spec for the clients' heartbeat.
        Which we just record to a BufferAsTable construct to remain as stealthy as possible with it, so we cannot getgcd'.
    ]]

	local sRet = requestSerializer.Deserialize(buf)
	if sRet.RequestType ~= ProtocolIdentifiers.Handshake then
		-- It does not really matter, as we will be eventually kicked from the server due to not sending Heartbeat packets.
		return
	end
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
		task.synchronize()
		while true do
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

			task.wait(random:NextInteger(1, 4))
		end
	end)
end)

do
	local playerInformationSerializer = tabletobuffer
		.GetDeserializerBuilder()
		.booleanWithName("Alive")
		.doubleWithName("WalkSpeed")
		.doubleWithName("Health")
		.vectorWithName("HumanoidRootPart_Position")
		.vectorWithName("HumanoidRootPart_Rotation")
		.build() :: TypeDefinitions.Serializer<{
		Alive: boolean,
		WalkSpeed: number,
		Health: number,
		HumanoidRootPart_Position: Vector3,
		HumanoidRootPart_Rotation: Vector3,
	}>

	local lastSuccess = tick()

	Runner:BindToMessage("__GET_PLAYER_INFO", function(buf: buffer)
		if not buf or not Players.LocalPlayer.Character then
			return -- No buffer provided, no information to validate with.
			-- or no player model.
		end
		local playerInfo = playerInformationSerializer.Deserialize(buf)

		if Players.LocalPlayer.Character == nil and playerInfo.Alive then
			-- Suspicious.
			return
		end

		local humanoid = Players.LocalPlayer.Character:WaitForChild("Humanoid", 2) :: Humanoid

		if not humanoid then
			-- This makes no sense.
			return
		end

		if math.round(humanoid.Health) ~= math.round(playerInfo.Health) then
			return -- Assuming this fires the same frame, why would the health be different this much?
		end

		if math.round(humanoid.WalkSpeed) ~= math.round(playerInfo.WalkSpeed) then
			return -- Assuming this fires the same frame, why would the WalkSpeed be different?
		end

		lastSuccess = tick()
	end)

	task.spawn(function()
		while task.wait(1) do
			if tick() - lastSuccess > 10 then
				-- Suspicious. Perhaps tampering?
				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = 0x01,
						DetectionName = "Humanoid Data Mismatch",
					}),
				}))
			end
		end
	end)
end

do
	local charAdded = function(character)
		local PlayerHumanoidRootPart = character:WaitForChild("HumanoidRootPart") :: BasePart
		local previousAngularVelocityMagnitude = 0
		local deltaMagnitude = 0
		task.desynchronize()
		while task.wait() do
			deltaMagnitude = PlayerHumanoidRootPart.AssemblyAngularVelocity.Magnitude - previousAngularVelocityMagnitude

			previousAngularVelocityMagnitude = PlayerHumanoidRootPart.AssemblyAngularVelocity.Magnitude

			if deltaMagnitude > 30 then -- Generally this is due to a player flinging themselves using something like Infinite Yield.
				task.synchronize()
				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = 0x0,
						DetectionName = "PLAYER_FLING_SUSPECT",
					}),
				}))
			end
		end
	end
	if Players.LocalPlayer.Character then
		task.synchronize()
		charAdded(Players.LocalPlayer.Character)
		task.synchronize()
	end
	Players.LocalPlayer.CharacterAdded:Connect(charAdded)
end

local function obtainScriptName(trace: string)
	return string.split(trace, ",")[1]
end

local function obtainLineNumber(trace: string)
	-- The last stack trace is what we care about.
	-- We must avoid using strings other than light stuff, else we will getgcd with function consts/uprefs, bad stuff.
	return tonumber(string.split(trace, " ")[3]:split("\n")[1])
end

local errorsMap = {
	-- Line Number -> Detection Packet (as Buffer)
	[109] = ReportDetectionToServerRequestSerializer.Serialize({
		DetectionID = 0x0,
		DetectionName = "METAMETHOD_HOOK",
	}),
	[118] = ReportDetectionToServerRequestSerializer.Serialize({
		DetectionID = 0x1,
		DetectionName = "METAMETHOD_HOOK",
	}),

	[137] = ReportDetectionToServerRequestSerializer.Serialize({
		DetectionID = 0x0,
		DetectionName = "UNUSUAL_ASSETS_LOADED_ON_COREGUI",
	}),
}

local errorConnection = ScriptContext.Error:Connect(
	function(message: string, stackTrace: string, affectedContainer: LuaSourceContainer)
		local isInvalidDatamodelIndex = not not string.match(message, "is not a valid member of DataModel")

		print(obtainScriptName(stackTrace), ":", obtainLineNumber(stackTrace))
		if
			isInvalidDatamodelIndex
			and affectedContainer
			and not affectedContainer:GetFullName():match("cloud_")
			and not affectedContainer:GetFullName():match("user_")
		then
			zoopNet:FireServer(requestSerializer.Serialize({
				RequestType = ProtocolIdentifiers.ReportDetection,
				RequestData = ReportDetectionToServerRequestSerializer.Serialize({
					DetectionID = 0x0, --
					DetectionName = "INDEX_INTO_DATAMODEL_WITHOUT_GETSERVICE",
				}),
			}))
		end

		if obtainScriptName(stackTrace) == "ReplicatedFirst.LocalScript" then
			if errorsMap[obtainLineNumber(stackTrace)] then
				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = errorsMap[obtainLineNumber(stackTrace)],
				}))
			end
		end
	end
)

do
	--[[
		Making cl like this makes it be referenced as an upvalue, most people will search for constants, ignoring upvalues, just one more thing to add to the list for fun!
	]]
	local cl
	task.spawn(function()
		local detectionId = ""
		local detectionName = ""
		cl = function()
			detectionId = 0x01
			detectionName = "ERROR_EVENTDISCONNECTED"
		end
		cl()

		while task.wait(1) do
			if not errorConnection.Connected then
				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))
			end
		end
	end)

	if not cl then
		cl()
	end
end

do
	local cl_1, cl_2, cl_3
	task.spawn(function()
		local detectionId = ""
		local detectionName = ""
		cl_1 = function()
			detectionId = 0x00
			detectionName = "__CLIENTTOCLIENT__HANDSHAKE"
		end
		cl_2 = function()
			detectionId = 0x01
			detectionName = "__CLIENTTOCLIENT__HANDSHAKE"
		end
		cl_3 = function()
			detectionId = 0x02
			detectionName = "__CLIENTTOCLIENT__HANDSHAKE"
		end
		local random = nil
		local seed = 0
		Runner:BindToMessage("__HANDSHAKE_WITH_PÄRAMETERS", function(backingMagic: number)
			if not random then
				random = Random.new(backingMagic)
				seed = backingMagic
				return
			end

			cl_1()

			zoopNet:FireServer(requestSerializer.Serialize({
				RequestType = ProtocolIdentifiers.ReportDetection,
				RequestData = ReportDetectionToServerRequestSerializer.Serialize({
					DetectionID = detectionId, --
					DetectionName = detectionName,
				}),
			}))
		end)
		local ClientToActorHeartbeatSerializer = tabletobuffer
			.GetDeserializerBuilder()
			.int32WithName("FirstMagic")
			.doubleWithName("SecondMagic")
			.doubleWithName("ThirdMagic")
			.doubleWithName("RunAt")
			.build()

		local lastRunTime = nil

		Runner:BindToMessage("__Heartbeat", function(buf: buffer)
			if lastRunTime and lastRunTime - tick() > 4 then
				cl_3()

				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))

				return
			end
			if not random then
				cl_2()

				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))
				return
			end
			local s, initialHeartbeat = pcall(function()
				return ClientToActorHeartbeatSerializer.Deserialize(buf)
			end)

			if not s then
				cl_3()

				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))
				return
			end

			local expectedFirst = random:NextInteger(math.round(seed / 2), seed)
			if expectedFirst ~= initialHeartbeat.FirstMagic then
				cl_3()

				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))
				return
			end

			local expectedSecond = bit32.bxor(expectedFirst, seed)

			if expectedSecond ~= initialHeartbeat.SecondMagic then
				cl_3()

				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))
				return
			end

			local expectedThird = initialHeartbeat.RunAt * expectedSecond

			if expectedThird ~= initialHeartbeat.ThirdMagic then
				cl_3()

				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))
				return
			end

			if tick() - initialHeartbeat.RunAt > 4 then
				-- this is a terrible drop in fps no cap.
				cl_3()

				zoopNet:FireServer(requestSerializer.Serialize({
					RequestType = ProtocolIdentifiers.ReportDetection,
					RequestData = ReportDetectionToServerRequestSerializer.Serialize({
						DetectionID = detectionId, --
						DetectionName = detectionName,
					}),
				}))
				return
			end

			lastRunTime = tick()
		end)

		task.spawn(function()
			lastRunTime = tick()
			while true do
				task.wait(5)
				if not lastRunTime or tick() - lastRunTime > 8 then
					cl_3()

					zoopNet:FireServer(requestSerializer.Serialize({
						RequestType = ProtocolIdentifiers.ReportDetection,
						RequestData = ReportDetectionToServerRequestSerializer.Serialize({
							DetectionID = detectionId, --
							DetectionName = detectionName,
						}),
					}))
				end
			end
		end)
	end)
end

local function randomstring(len)
	local Str = ""

	for _ = 1, len do
		Str ..= string.char(math.random(1, 127))
	end

	return Str
end

for _, child in game:GetChildren() do
	child.Name = randomstring(64)
	child.Changed:Connect(function(propName)
		if propName == "Name" then
			zoopNet:FireServer(requestSerializer.Serialize({
				RequestType = ProtocolIdentifiers.ReportDetection,
				RequestData = ReportDetectionToServerRequestSerializer.Serialize({
					DetectionID = 0x0,
					DetectionName = "_DATAMODEL_CHILD_RENAME",
				}),
			}))
		end
	end)
end
