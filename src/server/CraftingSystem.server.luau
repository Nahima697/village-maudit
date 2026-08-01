--[[
    CraftingSystem.server.luau
    Gère la collecte de ressources et le craft.
    Version modernisée avec support des pièges.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- === INITIALISATION DES REMOTE EVENTS ===
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

-- === CONFIGURATION ===
local COLLECT_COOLDOWN = 0.5
local COLLECT_RANGE = 25
local BARRICADE_LIFETIME = 60
local TRAP_DAMAGE = 25
local TRAP_LIFETIME = 120

local collectCooldowns = {}

-- === RECETTES DE CRAFT ===
local CRAFT_RECIPES = {
    Fortification = {Wood = 3, Stone = 2},
    Barricade = {Wood = 5, Stone = 0},
    Torche = {Wood = 2, Stone = 1},
    Lance = {Wood = 4, Stone = 1},
    Piege = {Wood = 2, Stone = 3}
}

-- === INITIALISATION DES ATTRIBUTS JOUEURS ===
local function initPlayerAttributes(player)
    if player:GetAttribute("Wood") == nil then
        player:SetAttribute("Wood", 0)
    end
    if player:GetAttribute("Stone") == nil then
        player:SetAttribute("Stone", 0)
    end
end

Players.PlayerAdded:Connect(initPlayerAttributes)

for _, player in ipairs(Players:GetPlayers()) do
    initPlayerAttributes(player)
end

-- === SYSTÈME DE COLLECTE ===
collectResourceEvent.OnServerEvent:Connect(function(player, resourcePart)
    local currentTime = tick()
    
    -- Vérification du cooldown
    if currentTime - (collectCooldowns[player.UserId] or 0) < COLLECT_COOLDOWN then
        return
    end
    
    -- Validation de la ressource
    if not resourcePart or not resourcePart:IsA("BasePart") then
        return
    end
    
    -- Vérification du personnage et de la distance
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local distance = (char.HumanoidRootPart.Position - resourcePart.Position).Magnitude
    if distance > COLLECT_RANGE then
        return
    end
    
    -- Détection du type de ressource
    local name = string.lower(resourcePart.Name)
    local parent = resourcePart.Parent and string.lower(resourcePart.Parent.Name) or ""
    
    local resourceType = nil
    
    if string.find(name, "tree") or string.find(parent, "tree") or 
       string.find(name, "trunk") or string.find(name, "wood") or 
       string.find(name, "leaves") then
        resourceType = "Wood"
    elseif string.find(name, "rock") or string.find(parent, "rock") or 
           string.find(name, "stone") or string.find(name, "slate") then
        resourceType = "Stone"
    end
    
    -- Attribution de la ressource
    if resourceType then
        local currentAmount = player:GetAttribute(resourceType) or 0
        player:SetAttribute(resourceType, currentAmount + 1)
        collectCooldowns[player.UserId] = currentTime
    end
end)

-- === FONCTIONS DE CRÉATION D'OBJETS ===
local function createBarricade(position, lookVector)
    local barricade = Instance.new("Part")
    barricade.Name = "PlayerBarricade"
    barricade.Size = Vector3.new(8, 6, 1)
    barricade.Anchored = true
    barricade.Material = Enum.Material.Wood
    barricade.BrickColor = BrickColor.new("Brown")
    barricade.CFrame = CFrame.new(position + (lookVector * 5) + Vector3.new(0, 2, 0))
    barricade.Parent = Workspace
    
    task.delay(BARRICADE_LIFETIME, function()
        if barricade and barricade.Parent then
            barricade:Destroy()
        end
    end)
end

local function createTorch(position, rightVector)
    local torch = Instance.new("Part")
    torch.Name = "CraftedTorch"
    torch.Size = Vector3.new(0.8, 3, 0.8)
    torch.Material = Enum.Material.Wood
    torch.BrickColor = BrickColor.new("Reddish brown")
    torch.Anchored = false
    torch.CFrame = CFrame.new(position + (rightVector * 2) + Vector3.new(0, 1, 0))
    
    local fire = Instance.new("Fire")
    fire.Size = 6
    fire.Heat = 5
    fire.Parent = torch
    
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 20
    light.Color = Color3.fromRGB(255, 180, 100)
    light.Parent = torch
    
    torch.Parent = Workspace
end

local function createLance(position, rightVector)
    local lance = Instance.new("Part")
    lance.Name = "CraftedLance"
    lance.Size = Vector3.new(0.5, 7, 0.5)
    lance.Material = Enum.Material.Wood
    lance.BrickColor = BrickColor.new("Dark orange")
    lance.Anchored = false
    lance.CFrame = CFrame.new(position + (rightVector * 2) + Vector3.new(0, 1, 0))
    
    local tip = Instance.new("Part")
    tip.Size = Vector3.new(0.8, 2, 0.8)
    tip.Shape = Enum.PartType.Wedge
    tip.Material = Enum.Material.Slate
    tip.BrickColor = BrickColor.new("Medium stone grey")
    tip.Anchored = false
    tip.Parent = lance
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = lance
    weld.Part1 = tip
    weld.Parent = lance
    
    lance.Parent = Workspace
end

local function createTrap(position, lookVector)
    local trap = Instance.new("Part")
    trap.Name = "PlayerTrap"
    trap.Size = Vector3.new(6, 0.5, 6)
    trap.Anchored = true
    trap.Material = Enum.Material.Slate
    trap.BrickColor = BrickColor.new("Dark stone grey")
    trap.Transparency = 0.3
    
    -- Positionnement au sol devant le joueur
    local rayOrigin = position + (lookVector * 4)
    local rayDirection = Vector3.new(0, -20, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = {Workspace:FindFirstChild("Players")}
    
    local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if rayResult then
        trap.CFrame = CFrame.new(rayResult.Position + Vector3.new(0, 0.25, 0))
    else
        trap.CFrame = CFrame.new(rayOrigin + Vector3.new(0, -2, 0))
    end
    
    trap.Parent = Workspace
    
    -- Détection de collision pour infliger des dégâts
    local debounce = {}
    trap.Touched:Connect(function(hit)
        local humanoid = hit.Parent:FindFirstChild("Humanoid")
        if humanoid and not debounce[hit.Parent] then
            debounce[hit.Parent] = true
            humanoid:TakeDamage(TRAP_DAMAGE)
            
            -- Effet visuel
            trap.BrickColor = BrickColor.new("Bright red")
            task.wait(0.3)
            if trap and trap.Parent then
                trap.BrickColor = BrickColor.new("Dark stone grey")
            end
            
            task.wait(2)
            debounce[hit.Parent] = nil
        end
    end)
    
    -- Destruction automatique après un certain temps
    task.delay(TRAP_LIFETIME, function()
        if trap and trap.Parent then
            trap:Destroy()
        end
    end)
end

-- === SYSTÈME DE CRAFT ===
craftItemEvent.OnServerEvent:Connect(function(player, itemName)
    local recipe = CRAFT_RECIPES[itemName]
    if not recipe then
        warn("[CraftingSystem] Recette inconnue:", itemName)
        return
    end
    
    -- Vérification des ressources
    local wood = player:GetAttribute("Wood") or 0
    local stone = player:GetAttribute("Stone") or 0
    
    if wood < recipe.Wood or stone < recipe.Stone then
        return
    end
    
    -- Déduction des ressources
    player:SetAttribute("Wood", wood - recipe.Wood)
    player:SetAttribute("Stone", stone - recipe.Stone)
    
    -- Vérification du personnage
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local rootPart = char.HumanoidRootPart
    local position = rootPart.Position
    local lookVector = rootPart.CFrame.LookVector
    local rightVector = rootPart.CFrame.RightVector
    
    -- Création de l'objet crafté
    if itemName == "Barricade" then
        createBarricade(position, lookVector)
    elseif itemName == "Torche" then
        createTorch(position, rightVector)
    elseif itemName == "Lance" then
        createLance(position, rightVector)
    elseif itemName == "Piege" then
        createTrap(position, lookVector)
    end
    
    print("[CraftingSystem]", player.Name, "a crafté:", itemName)
end)

print("[CraftingSystem] ✓ Prêt - Recettes disponibles:", #CRAFT_RECIPES)