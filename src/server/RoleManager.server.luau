local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedData = ReplicatedStorage:WaitForChild("SharedData")
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local TraitorSabotageEvent = RemoteEvents:WaitForChild("TraitorSabotage")

local function isTraitor(player)
	return player:GetAttribute("Role") == "Traitor"
end

local function handleSabotage(player, targetObject)
	local isGameActive = SharedData:GetAttribute("GameActive")
	if not isGameActive then
		return
	end

	if not isTraitor(player) then
		player:Kick("Tentative de triche détectée")
		return
	end

	if not player:GetAttribute("IsAlive") then
		return
	end

	local currentPhase = SharedData:GetAttribute("CurrentPhase")
	if currentPhase ~= "NIGHT_PHASE" then
		return
	end

	if typeof(targetObject) == "Instance" and targetObject:IsA("BasePart") then
		local door = targetObject:FindFirstAncestorOfClass("Model")
		if door and door:FindFirstChild("DoorScript") then
			local doorHinge = door:FindFirstChild("Hinge") or door:FindFirstChild("Door")
			if doorHinge then
				doorHinge:SetAttribute("Sabotaged", true)
				doorHinge:SetAttribute("IsLocked", false)

				local fireEvent = ReplicatedStorage:FindFirstChild("DoorSabotaged")
				if fireEvent then
					fireEvent:FireAllClients(door)
				end
			end
		end
	end
end

TraitorSabotageEvent.OnServerEvent:Connect(function(player, targetObject)
	handleSabotage(player, targetObject)
end)

print("[RoleManager] Système de sabotage initialisé")