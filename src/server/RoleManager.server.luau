local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local RoleManager = {}
RoleManager.PlayerRoles = {}
RoleManager.IsGameStarted = false

local TRAITOR_RATIO = 0.2
local MIN_PLAYERS = 4

local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local AssignRoleEvent = RemoteEvents:WaitForChild("AssignRole") or Instance.new("RemoteEvent")
AssignRoleEvent.Name = "AssignRole"
AssignRoleEvent.Parent = RemoteEvents

local TraitorSabotageEvent = RemoteEvents:WaitForChild("TraitorSabotage") or Instance.new("RemoteEvent")
TraitorSabotageEvent.Name = "TraitorSabotage"
TraitorSabotageEvent.Parent = RemoteEvents

local function shuffleTable(tbl)
    local result = table.clone(tbl)
    for i = #result, 2, -1 do
        local j = math.random(1, i)
        result[i], result[j] = result[j], result[i]
    end
    return result
end

local function assignRoles()
    local activePlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            table.insert(activePlayers, player)
        end
    end

    if #activePlayers < MIN_PLAYERS then
        warn("Pas assez de joueurs pour commencer la partie")
        return false
    end

    RoleManager.PlayerRoles = {}

    local numTraitors = math.max(1, math.floor(#activePlayers * TRAITOR_RATIO))
    local shuffledPlayers = shuffleTable(activePlayers)

    for i, player in ipairs(shuffledPlayers) do
        local role = i <= numTraitors and "Traitor" or "Villager"
        RoleManager.PlayerRoles[player.UserId] = role
        player:SetAttribute("Role", role)
        player:SetAttribute("IsAlive", true)

        AssignRoleEvent:FireClient(player, role)

        local message = role == "Traitor" and "Vous êtes un TRAÎTRE. Sabotez le village la nuit!" or "Vous êtes un Villageois. Trouvez le traître!"
        player:SetAttribute("RoleMessage", message)
    end

    return true
end

local function getPlayerRole(player)
    return RoleManager.PlayerRoles[player.UserId]
end

local function isTraitor(player)
    return getPlayerRole(player) == "Traitor"
end

local function handleSabotage(player, targetObject)
    if not RoleManager.IsGameStarted then
        return
    end

    if not isTraitor(player) then
        player:Kick("Tentative de triche détectée")
        return
    end

    if not player:GetAttribute("IsAlive") then
        return
    end

    local isNightTime = workspace:GetAttribute("IsNight")
    if not isNightTime then
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

function RoleManager.StartGame()
    if RoleManager.IsGameStarted then
        return false
    end

    local success = assignRoles()
    if success then
        RoleManager.IsGameStarted = true
        workspace:SetAttribute("IsNight", false)
        return true
    end
    return false
end

function RoleManager.EndGame()
    RoleManager.IsGameStarted = false
    RoleManager.PlayerRoles = {}

    for _, player in ipairs(Players:GetPlayers()) do
        player:SetAttribute("Role", nil)
        player:SetAttribute("IsAlive", nil)
        player:SetAttribute("RoleMessage", nil)
    end
end

function RoleManager.GetRole(player)
    return getPlayerRole(player)
end

function RoleManager.IsTraitor(player)
    return isTraitor(player)
end

TraitorSabotageEvent.OnServerEvent:Connect(function(player, targetObject)
    handleSabotage(player, targetObject)
end)

Players.PlayerRemoving:Connect(function(player)
    if RoleManager.PlayerRoles[player.UserId] then
        RoleManager.PlayerRoles[player.UserId] = nil
    end
end)

-- NOUVEAU : ce script étant auto-exécutable (Script, pas ModuleScript),
-- "return RoleManager" ne sert à rien pour les autres scripts.
-- On écoute donc un signal externe pour déclencher StartGame().
local StartGameSignal = ReplicatedStorage:FindFirstChild("StartGameSignal")
if not StartGameSignal then
    StartGameSignal = Instance.new("BindableEvent")
    StartGameSignal.Name = "StartGameSignal"
    StartGameSignal.Parent = ReplicatedStorage
end

StartGameSignal.Event:Connect(function()
    RoleManager.StartGame()
end)

print("[RoleManager] Prêt, en attente du signal StartGameSignal")
