local Players = game:GetService("Players")
local mainRunner = script.Parent.Actor

local tableToBuffer = require(script.Parent.Actor.__dependencies.tabletobuffer)
local TypeDefinitions = require(
	script.Parent.Actor.__dependencies["_Index"]["secondnewtonlaw_tabletobuffer@0.1.5"].tabletobuffer.TypeDefinitions
)

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
