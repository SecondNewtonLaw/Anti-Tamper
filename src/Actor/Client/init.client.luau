--// [[ INIT ]] \\--
local Runner = script.Parent

script:Destroy() -- Destroy the script to remove external references
script = Instance.new("Script") -- Overwrite the last reference to the script
-- We do this to hide the script from exploiters

local TableToBuffer = require(Runner.__dependencies.tabletobuffer)

Runner:Destroy()
Runner = nil
-- Do the same thing we do with the script to the actor

local SerializerBuilder = TableToBuffer.GetDeserializerBuilder()

--// [[ VARIABLES ]] \\--
local OriginalIndex;
local OriginalNewIndex;
local OriginalNamecall;


--// [[ FUNCTIONS ]] \\--

local function GetIndexMetamethod()
    local Metamethod;

    xpcall(function()
        game.___()
    end, function()
        Metamethod = debug.info(2, "f")
    end)

    return Metamethod
end

local function GetNewIndexMetamethod()
    local Metamethod;

    xpcall(function()
        game.___ = 0
    end, function()
        Metamethod = debug.info(2, "f")
    end)

    return Metamethod
end

local function GetNamecallMetamethod()
    local Metamethod;

    xpcall(function()
        game:___()
    end, function()
        Metamethod = debug.info(2, "f")
    end)

    return Metamethod
end

local function getnamecallmethod()
    local Result = select(2, pcall(function()
        OriginalNamecall(game.Stats.Workspace.Kernel.Bodies)
    end)):split(" ")[1]

    return if typeof(Result) == "Instance" then
        "Unable to get method from lua"
    else
        Result
end

--// [[ MAIN ]] \\--

task.spawn(function() -- // Metamethod integrity checks
    task.desynchronize();

    OriginalIndex = GetIndexMetamethod()
    OriginalNewIndex = GetNewIndexMetamethod()
    OriginalNamecall = GetNamecallMetamethod()
    -- store the original functions
    print(OriginalIndex, "actor")

    while true do
        if GetIndexMetamethod() ~= OriginalIndex or GetNewIndexMetamethod() ~= OriginalNewIndex or GetNamecallMetamethod() ~= OriginalNamecall then
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
