script.Parent.Parent = nil :: any

local Runner = script.Parent

local TableToBuffer = require(script.Parent.__dependencies.tabletobuffer)

local SerializerBuilder = TableToBuffer.GetDeserializerBuilder()
