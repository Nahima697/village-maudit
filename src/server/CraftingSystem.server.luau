--[[
    CraftingSystem.server.luau
    Détection rigoureuse et infaillible Bois vs Pierre
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
    remoteEventsFolder = Instance.new("Folder")
    remoteEventsFolder.Name = "RemoteEvents"
    remoteEventsFolder.Parent = ReplicatedStorage
end

local collectResourceEvent = remoteEventsFolder:FindFirstChild("CollectResourceEvent")
if not collectResourceEvent then
    collectResourceEvent = Instance.new("RemoteEvent")
    collectResourceEvent.Name = "CollectResourceEvent"
    collectResourceEvent.Parent = remoteEventsFolder
end

local craftItemEvent = remoteEventsFolder:FindFirstChild("CraftItemEvent")
if not craftItemEvent then
    craftItemEvent = Instance.new("RemoteEvent")
    craftItemEvent.Name = "CraftItemEvent"
    craftItemEvent.Parent = remoteEventsFolder
end

local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
if not sharedData then
    sharedData = Instance.new("Configuration")
    sharedData.Name = "SharedData"
    sharedData.Parent = ReplicatedStorage
end

local collectCooldowns = {}
local CRAFT_RECIPES = {
    Fortification = {Wood = 3, Stone = 2},
    Barricade = {Wood = 5, Stone = 0},
    Torche = {Wood = 2, Stone = 1},
    Lance = {Wood = 4, Stone = 1}
}

Players.PlayerAdded:Connect(function(p)
    if p:GetAttribute("Wood") == nil then p:SetAttribute("Wood", 0) end
    if p:GetAttribute("Stone") == nil then p:SetAttribute("Stone", 0) end
end)
for _, p in ipairs(Players:GetPlayers()) do
    if p:GetAttribute("Wood") == nil then p:SetAttribute("Wood", 0) end
    if p:GetAttribute("Stone") == nil then p:SetAttribute("Stone", 0) end
end

collectResourceEvent.OnServerEvent:Connect(function(player, resourcePart)
    local currentTime = tick()
    if currentTime - (collectCooldowns[player.UserId] or 0) < 0.5 then return end
    if not resourcePart or not resourcePart:IsA("BasePart") then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    if (char.HumanoidRootPart.Position - resourcePart.Position).Magnitude > 25 then return end
    
    local name = string.lower(resourcePart.Name)
    local parent = resourcePart.Parent and string.lower(resourcePart.Parent.Name) or ""
    
    -- Analyse explicite
    local resourceType = nil
    
    if string.find(name, "tree") or string.find(parent, "tree") or string.find(name, "trunk") or string.find(name, "wood") or string.find(name, "leaves") then
        resourceType = "Wood"
    elseif string.find(name, "rock") or string.find(parent, "rock") or string.find(name, "stone") or string.find(name, "slate") then
        resourceType = "Stone"
    end
    
    -- Si on a identifié une ressource valide, on crédite le joueur
    if resourceType then
        player:SetAttribute(resourceType, (player:GetAttribute(resourceType) or 0) + 1)
        collectCooldowns[player.UserId] = currentTime
    end
end)

craftItemEvent.OnServerEvent:Connect(function(player, itemName)
    if sharedData:GetAttribute("CurrentPhase") ~= "DAY_PHASE" then return end
    local recipe = CRAFT_RECIPES[itemName]
    if not recipe then return end
    
    local wood = player:GetAttribute("Wood") or 0
    local stone = player:GetAttribute("Stone") or 0
    if wood < recipe.Wood or stone < recipe.Stone then return end
    
    player:SetAttribute("Wood", wood - recipe.Wood)
    player:SetAttribute("Stone", stone - recipe.Stone)
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local rootPart = char.HumanoidRootPart
    
    if itemName == "Barricade" then
        local barricade = Instance.new("Part")
        barricade.Name = "PlayerBarricade"
        barricade.Size = Vector3.new(8, 6, 1)
        barricade.Anchored = true
        barricade.Material = Enum.Material.Wood
        barricade.BrickColor = BrickColor.new("Brown")
        barricade.CFrame = rootPart.CFrame + (rootPart.CFrame.LookVector * 5) + Vector3.new(0, 2, 0)
        barricade.Parent = Workspace
        
        task.delay(60, function()
            if barricade then barricade:Destroy() end
        end)
    elseif itemName == "Torche" then
        local torch = Instance.new("Part")
        torch.Name = "CraftedTorch"
        torch.Size = Vector3.new(0.8, 3, 0.8)
        torch.Material = Enum.Material.Wood
        torch.BrickColor = BrickColor.new("Reddish brown")
        
        local fire = Instance.new("Fire")
        fire.Size = 6
        fire.Heat = 5
        fire.Parent = torch
        
        local light = Instance.new("PointLight")
        light.Brightness = 2
        light.Range = 20
        light.Color = Color3.fromRGB(255, 180, 100)
        light.Parent = torch
        
        torch.CFrame = rootPart.CFrame + (rootPart.CFrame.RightVector * 2) + Vector3.new(0, 1, 0)
        torch.Anchored = false
        torch.Parent = Workspace
    elseif itemName == "Lance" then
        local lance = Instance.new("Part")
        lance.Name = "CraftedLance"
        lance.Size = Vector3.new(0.5, 7, 0.5)
        lance.Material = Enum.Material.Wood
        lance.BrickColor = BrickColor.new("Dark orange")
        
        local tip = Instance.new("Part")
        tip.Size = Vector3.new(0.8, 2, 0.8)
        tip.Shape = Enum.PartType.Wedge
        tip.Material = Enum.Material.Slate
        tip.BrickColor = BrickColor.new("Medium stone grey")
        tip.Position = lance.Position + Vector3.new(0, 4, 0)
        tip.Anchored = false
        tip.Parent = lance
        
        local weld = Instance.new("WeldConstraint")
        weld.Part0 = lance
        weld.Part1 = tip
        weld.Parent = lance
        
        lance.CFrame = rootPart.CFrame + (rootPart.CFrame.RightVector * 2) + Vector3.new(0, 1, 0)
        lance.Anchored = false
        lance.Parent = Workspace
    end
end)

print("[CraftingSystem] Logique de récolte Bois/Pierre corrigée.")
