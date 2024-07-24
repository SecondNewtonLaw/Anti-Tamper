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
	]]--

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
	local PreloadAsync = ContentProvider.PreloadAsync
	local InstancesToBeChecked = {game:GetService("CoreGui")}

	local function CheckAsset(AssetId : string)
		if table.find(BlacklistedAssetIds, AssetId) then
			(true)()
		end
	end

	while true do
		PreloadAsync(ContentProvider, InstancesToBeChecked, CheckAsset)
		
		task.wait(20)
	end
end)