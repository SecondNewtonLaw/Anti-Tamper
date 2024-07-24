local Players = game:GetService("Players")
local mainRunner = script.Parent.Actor

local tableToBuffer = require(script.Parent.Actor.__dependencies.tabletobuffer)
local TypeDefinitions = require(
	script.Parent.Actor.__dependencies["_Index"]["secondnewtonlaw_tabletobuffer@0.1.5"].tabletobuffer.TypeDefinitions
)

--// [[ INIT ]] \\--
script:Destroy()
script = Instance.new("Script")
-- Hide script from exploiters via erasing all references to it

--// [[ VARIABLES ]] \\--
local OriginalIndex
local OriginalNewIndex
local OriginalNamecall

local BlacklistedAssetIds = {
	--// Wave drawing library
	"rbxasset://fonts/families/Arial.json",
	"rbxasset://fonts/families/HighwayGothic.json",
	"rbxasset://fonts/families/Roboto.json",
	"rbxasset://fonts/families/Ubuntu.json",

	--// Abnormal Fonts
	"rbxasset://fonts/SourceSansPro-It.ttf",
	"rbxasset://fonts/SourceSansPro-Light.ttf",
	"rbxasset://fonts/Ubuntu-Regular.ttf",
	"rbxasset://fonts/Montserrat-Regular.ttf",
	"rbxasset://fonts/Montserrat-Bold.ttf",
	--[[ 
	Detects the following:
		IY
		Hydroxide
		SimpleSpy
		OwlHub
	]]
	--

	--// Dex
	"rbxassetid://textures/ClassImages.png",
}

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
	)

	return if typeof(Result) == "Instance" then "Unable to get method from lua" else Result:split(" ")[1]
end

--// [[ MAIN ]] \\--

task.spawn(function() -- // Metamethod integrity checks
	OriginalIndex = GetIndexMetamethod()
	OriginalNewIndex = GetNewIndexMetamethod()
	OriginalNamecall = GetNamecallMetamethod()
	-- store the original functions

	while true do
		if
			GetIndexMetamethod() ~= OriginalIndex
			or GetNewIndexMetamethod() ~= OriginalNewIndex
			or GetNamecallMetamethod() ~= OriginalNamecall
		then
			-- One of the metamethods has been modified.
			(true)()
		end

		pcall(OriginalIndex, game, "Name")
		pcall(OriginalNewIndex, {}, "a", 0)
		pcall(OriginalNamecall, game)

		if getnamecallmethod() ~= "___" then
			-- A poorly made hook as been placed on one of the metamethods.
			(true)()
		end
		task.wait(20)
	end
end)

task.spawn(function() -- // Blacklisted assetId monitor
	local ContentProvider = game:GetService("ContentProvider")
	local ReplicatedFirst = game:GetService("ReplicatedFirst")
	local RunService = game:GetService("RunService")

	local PreloadAsync = ContentProvider.PreloadAsync
	local InstancesToBeChecked = { game:GetService("CoreGui") }

	local function CheckAsset(AssetId: string)
		if table.find(BlacklistedAssetIds, AssetId) then
			(true)()
		end
	end

	while true do
		if RunService["IsStudio\0\0\0"](RunService) then
			return
		end

		PreloadAsync(ContentProvider, InstancesToBeChecked, CheckAsset)

		task.wait(20)
	end
end)

do
	local playerInformationSerializer = tableToBuffer
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

	task.spawn(function()
		while task.wait(3) do
			local isAlive = false
			if Players.LocalPlayer.Character then
				isAlive = true
			end
			local serialized = not isAlive and playerInformationSerializer.Serialize({ Alive = false })
				or playerInformationSerializer.Serialize({
					Alive = true,
					WalkSpeed = Players.LocalPlayer.Character:WaitForChild("Humanoid").WalkSpeed,
					Health = Players.LocalPlayer.Character:WaitForChild("Humanoid").Health,
					HumanoidRootPart_Position = Players.LocalPlayer.Character.PrimaryPart.CFrame.Position,
					HumanoidRootPart_Rotation = Players.LocalPlayer.Character.PrimaryPart.CFrame.Rotation,
				})
			mainRunner:SendMessage("__GET_PLAYER_INFO", serialized)
		end
	end)
end

do
	local ClientToActorHeartbeatSerializer = tableToBuffer
		.GetDeserializerBuilder()
		.int32WithName("FirstMagic")
		.doubleWithName("SecondMagic")
		.doubleWithName("ThirdMagic")
		.doubleWithName("RunAt")
		.build()

	local seed = math.random(-21474836487, 2147483647)
	local rand = Random.new(seed)
	mainRunner:SendMessage("__HANDSHAKE_WITH_PÄRAMETERS", seed)

	task.spawn(function()
		while true do
			local first = rand:NextInteger(math.round(seed / 2), seed)
			local second = bit32.bxor(first, seed)
			local third = tick() * second

			mainRunner:SendMessage(
				"__Heartbeat",
				ClientToActorHeartbeatSerializer.Serialize({
					FirstMagic = first,
					SecondMagic = second,
					ThirdMagic = third,
					RunAt = third / second,
				})
			)
			task.wait(3)
		end
	end)
end
