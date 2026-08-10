--[[
    CraftingSystem.server.luau
    Système de craft côté serveur avec création d'outils équipables automatiquement
    et gestion du placement des structures.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

-- Remote Events
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
    remoteEventsFolder = Instance.new("Folder")
    remoteEventsFolder.Name = "RemoteEvents"
    remoteEventsFolder.Parent = ReplicatedStorage
end

local craftItemEvent = remoteEventsFolder:FindFirstChild("CraftItemEvent")
if not craftItemEvent then
    craftItemEvent = Instance.new("RemoteEvent")
    craftItemEvent.Name = "CraftItemEvent"
    craftItemEvent.Parent = remoteEventsFolder
end

local confirmPlacementEvent = remoteEventsFolder:FindFirstChild("ConfirmPlacementEvent")
if not confirmPlacementEvent then
    confirmPlacementEvent = Instance.new("RemoteEvent")
    confirmPlacementEvent.Name = "ConfirmPlacementEvent"
    confirmPlacementEvent.Parent = remoteEventsFolder
end

local startPlacementEvent = remoteEventsFolder:FindFirstChild("StartPlacementEvent")
if not startPlacementEvent then
    startPlacementEvent = Instance.new("RemoteEvent")
    startPlacementEvent.Name = "StartPlacementEvent"
    startPlacementEvent.Parent = remoteEventsFolder
end

local craftSuccessEvent = remoteEventsFolder:FindFirstChild("CraftSuccessEvent")
if not craftSuccessEvent then
    craftSuccessEvent = Instance.new("RemoteEvent")
    craftSuccessEvent.Name = "CraftSuccessEvent"
    craftSuccessEvent.Parent = remoteEventsFolder
end

local collectResourceEvent = remoteEventsFolder:FindFirstChild("CollectResourceEvent")
if not collectResourceEvent then
    collectResourceEvent = Instance.new("RemoteEvent")
    collectResourceEvent.Name = "CollectResourceEvent"
    collectResourceEvent.Parent = remoteEventsFolder
end

-- Inventaire des joueurs
local playerInventories = {}

-- Cooldowns pour la collecte de ressources
local collectCooldowns = {}

-- Recettes de craft
local recipes = {
    Lance = {
        Bois = 3,
        Pierre = 1
    },
    Torche = {
        Bois = 2,
        Pierre = 1
    },
    Barricade = {
        Bois = 5,
        Pierre = 2
    },
    Piege = {
        Bois = 4,
        Pierre = 2
    },
    Fortification = {
        Bois = 10,
        Pierre = 5
    }
}

-- Items nécessitant un placement
local itemsNeedingPlacement = {
    Barricade = true,
    Piege = true,
    Fortification = true
}

-- Placements en attente
local pendingPlacements = {}

-- === SYNCHRONISATION DES RESSOURCES VERS ATTRIBUTS ===
local function syncResourceAttributes(player)
    local inventory = playerInventories[player.UserId]
    if not inventory then return end
    
    player:SetAttribute("Wood", inventory.Bois)
    player:SetAttribute("Stone", inventory.Pierre)
    
    print("[CraftingSystem] Attributs synchronisés pour:", player.Name, "- Bois:", inventory.Bois, "Pierre:", inventory.Pierre)
end

-- === INITIALISATION JOUEUR ===
local function initializePlayer(player)
    playerInventories[player.UserId] = {
        Bois = 10,
        Pierre = 5
    }
    
    syncResourceAttributes(player)
    
    print("[CraftingSystem] Inventaire initialisé pour:", player.Name)
end

-- === CRÉATION D'UNE LANCE (TOOL) ===
local function createLance()
    local lance = Instance.new("Tool")
    lance.Name = "Lance"
    lance.RequiresHandle = true
    lance.CanBeDropped = false
    
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.3, 6, 0.3)
    handle.BrickColor = BrickColor.new("Brown")
    handle.Material = Enum.Material.Wood
    handle.Parent = lance
    
    -- Pointe de la lance
    local tip = Instance.new("Part")
    tip.Name = "Tip"
    tip.Size = Vector3.new(0.4, 1, 0.4)
    tip.BrickColor = BrickColor.new("Medium stone grey")
    tip.Material = Enum.Material.Slate
    tip.Parent = lance
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = tip
    weld.Parent = handle
    
    tip.Position = handle.Position + Vector3.new(0, 3.5, 0)
    
    -- Script de dégâts (basique)
    local script = Instance.new("Script")
    script.Source = [[
        local tool = script.Parent
        local damage = 20
        
        tool.Activated:Connect(function()
            local character = tool.Parent
            local humanoid = character and character:FindFirstChild("Humanoid")
            if not humanoid then return end
            
            -- Raycast pour détecter un ennemi
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then return end
            
            local ray = Ray.new(rootPart.Position, rootPart.CFrame.LookVector * 10)
            local hit, position = workspace:FindPartOnRay(ray, character)
            
            if hit then
                local enemyHumanoid = hit.Parent:FindFirstChild("Humanoid")
                if enemyHumanoid and enemyHumanoid ~= humanoid then
                    enemyHumanoid:TakeDamage(damage)
                end
            end
        end)
    ]]
    script.Parent = lance
    
    return lance
end

-- === CRÉATION D'UNE TORCHE (TOOL) ===
local function createTorche()
    local torche = Instance.new("Tool")
    torche.Name = "Torche"
    torche.RequiresHandle = true
    torche.CanBeDropped = false
    
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.3, 4, 0.3)
    handle.BrickColor = BrickColor.new("Brown")
    handle.Material = Enum.Material.Wood
    handle.Parent = torche
    
    -- Flamme
    local flame = Instance.new("Part")
    flame.Name = "Flame"
    flame.Size = Vector3.new(1, 1, 1)
    flame.BrickColor = BrickColor.new("Bright orange")
    flame.Material = Enum.Material.Neon
    flame.Shape = Enum.PartType.Ball
    flame.Parent = torche
    
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = flame
    weld.Parent = handle
    
    flame.Position = handle.Position + Vector3.new(0, 2.5, 0)
    
    -- Lumière
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 30
    light.Color = Color3.fromRGB(255, 150, 50)
    light.Parent = flame
    
    return torche
end

-- === CRÉATION D'UNE BARRICADE ===
local function createBarricade(position)
    local barricade = Instance.new("Model")
    barricade.Name = "Barricade"
    
    -- Structure principale
    local mainPart = Instance.new("Part")
    mainPart.Name = "MainPart"
    mainPart.Size = Vector3.new(8, 6, 1)
    mainPart.Position = position
    mainPart.Anchored = true
    mainPart.BrickColor = BrickColor.new("Brown")
    mainPart.Material = Enum.Material.Wood
    mainPart.Parent = barricade
    
    -- Planches horizontales
    for i = 1, 3 do
        local plank = Instance.new("Part")
        plank.Size = Vector3.new(8.5, 0.5, 0.3)
        plank.Position = mainPart.Position + Vector3.new(0, -2 + (i * 2), 0.4)
        plank.Anchored = true
        plank.BrickColor = BrickColor.new("Reddish brown")
        plank.Material = Enum.Material.Wood
        plank.Parent = barricade
    end
    
    barricade.PrimaryPart = mainPart
    barricade.Parent = workspace
    
    return barricade
end

-- === CRÉATION D'UN PIÈGE (STRUCTURE VOLUMÉTRIQUE) ===
local function createPiege(position)
    local piege = Instance.new("Model")
    piege.Name = "Piege"
    
    -- Base du piège (cadre en bois)
    local base = Instance.new("Part")
    base.Name = "Base"
    base.Size = Vector3.new(6, 0.5, 6)
    base.Position = position
    base.Anchored = true
    base.BrickColor = BrickColor.new("Brown")
    base.Material = Enum.Material.Wood
    base.Parent = piege
    
    -- Piques sortant du piège
    for x = -2, 2, 2 do
        for z = -2, 2, 2 do
            local spike = Instance.new("Part")
            spike.Name = "Spike"
            spike.Size = Vector3.new(0.3, 2, 0.3)
            spike.Position = position + Vector3.new(x, 1, z)
            spike.Anchored = true
            spike.BrickColor = BrickColor.new("Medium stone grey")
            spike.Material = Enum.Material.Slate
            spike.Parent = piege
            
            -- Forme conique pour les piques
            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = "rbxassetid://1033714"
            mesh.Scale = Vector3.new(0.5, 2, 0.5)
            mesh.Parent = spike
        end
    end
    
    -- Script de dégâts
    local script = Instance.new("Script")
    script.Source = [[
        local piege = script.Parent
        local damage = 30
        local debounce = {}
        
        piege.Base.Touched:Connect(function(hit)
            local humanoid = hit.Parent:FindFirstChild("Humanoid")
            if humanoid then
                local player = game.Players:GetPlayerFromCharacter(hit.Parent)
                if player and not debounce[player.UserId] then
                    debounce[player.UserId] = true
                    humanoid:TakeDamage(damage)
                    wait(2)
                    debounce[player.UserId] = nil
                end
            end
        end)
    ]]
    script.Parent = piege
    
    piege.PrimaryPart = base
    piege.Parent = workspace
    
    return piege
end

-- === CRÉATION D'UNE FORTIFICATION ===
local function createFortification(position)
    local fortification = Instance.new("Model")
    fortification.Name = "Fortification"
    
    -- Mur principal renforcé
    local mainWall = Instance.new("Part")
    mainWall.Name = "MainWall"
    mainWall.Size = Vector3.new(10, 8, 2)
    mainWall.Position = position
    mainWall.Anchored = true
    mainWall.BrickColor = BrickColor.new("Dark stone grey")
    mainWall.Material = Enum.Material.Concrete
    mainWall.Parent = fortification
    
    -- Renforts métalliques
    for i = 1, 2 do
        local reinforce = Instance.new("Part")
        reinforce.Size = Vector3.new(0.5, 8, 2.5)
        reinforce.Position = mainWall.Position + Vector3.new(-5 + (i * 10), 0, 0)
        reinforce.Anchored = true
        reinforce.BrickColor = BrickColor.new("Really black")
        reinforce.Material = Enum.Material.Metal
        reinforce.Parent = fortification
    end
    
    fortification.PrimaryPart = mainWall
    fortification.Parent = workspace
    
    return fortification
end

-- === VÉRIFICATION DES RESSOURCES ===
local function hasResources(player, recipe)
    local inventory = playerInventories[player.UserId]
    if not inventory then return false end
    
    for resource, amount in pairs(recipe) do
        if not inventory[resource] or inventory[resource] < amount then
            return false
        end
    end
    
    return true
end

-- === CONSOMMATION DES RESSOURCES ===
local function consumeResources(player, recipe)
    local inventory = playerInventories[player.UserId]
    
    for resource, amount in pairs(recipe) do
        inventory[resource] = inventory[resource] - amount
    end
    
    syncResourceAttributes(player)
    
    print("[CraftingSystem] Ressources consommées pour:", player.Name)
end

-- === ÉQUIPER AUTOMATIQUEMENT UN OUTIL ===
local function autoEquipTool(player, tool)
    local character = player.Character
    local humanoid = character and character:FindFirstChild("Humanoid")
    
    if humanoid then
        -- Attendre un court instant pour que le tool soit bien dans le Backpack
        task.wait(0.1)
        humanoid:EquipTool(tool)
        print("[CraftingSystem] Outil équipé automatiquement:", tool.Name, "pour", player.Name)
    end
end

-- === COLLECTE DE RESSOURCES ===
collectResourceEvent.OnServerEvent:Connect(function(player, targetPart)
    -- Vérifier que targetPart existe et est une BasePart
    if not targetPart or not targetPart:IsA("BasePart") then
        return
    end
    
    -- Vérifier que c'est bien un ResourceNode
    if not CollectionService:HasTag(targetPart, "ResourceNode") then
        return
    end
    
    local userId = player.UserId
    local now = tick()
    
    -- Vérifier le cooldown
    if collectCooldowns[userId] and (now - collectCooldowns[userId]) < 1 then
        warn("[CraftingSystem] Cooldown actif pour:", player.Name)
        return
    end
    
    collectCooldowns[userId] = now
    
    local inventory = playerInventories[userId]
    if not inventory then
        warn("[CraftingSystem] Inventaire introuvable pour:", player.Name)
        return
    end
    
    -- Lire le type de ressource depuis l'attribut
    local resourceType = targetPart:GetAttribute("ResourceType")
    
    -- Ajouter la ressource
    if resourceType == "Wood" or resourceType == "Bois" then
        inventory.Bois = inventory.Bois + 1
        print("[CraftingSystem] +1 Bois collecté par:", player.Name)
    elseif resourceType == "Stone" or resourceType == "Pierre" then
        inventory.Pierre = inventory.Pierre + 1
        print("[CraftingSystem] +1 Pierre collectée par:", player.Name)
    else
        warn("[CraftingSystem] Type de ressource inconnu:", resourceType)
        return
    end
    
    syncResourceAttributes(player)
end)

-- === CRAFT D'UN ITEM ===
craftItemEvent.OnServerEvent:Connect(function(player, itemName)
    print("[CraftingSystem] Demande de craft reçue:", player.Name, "->", itemName)
    
    local recipe = recipes[itemName]
    
    if not recipe then
        warn("[CraftingSystem] Recette inexistante:", itemName)
        return
    end
    
    if not hasResources(player, recipe) then
        warn("[CraftingSystem] Ressources insuffisantes pour:", player.Name)
        craftSuccessEvent:FireClient(player, false, "Ressources insuffisantes!")
        return
    end
    
    consumeResources(player, recipe)
    
    -- Items nécessitant un placement
    if itemsNeedingPlacement[itemName] then
        pendingPlacements[player.UserId] = itemName
        startPlacementEvent:FireClient(player, itemName)
        print("[CraftingSystem] Mode placement activé pour:", player.Name, itemName)
    else
        -- Outils directement équipables
        local tool = nil
        
        if itemName == "Lance" then
            tool = createLance()
        elseif itemName == "Torche" then
            tool = createTorche()
        end
        
        if tool then
            tool.Parent = player.Backpack
            autoEquipTool(player, tool)
            craftSuccessEvent:FireClient(player, true, itemName .. " créé et équipé!")
            print("[CraftingSystem] Outil créé et équipé:", itemName, "pour", player.Name)
        end
    end
end)

-- === CONFIRMATION DU PLACEMENT ===
confirmPlacementEvent.OnServerEvent:Connect(function(player, position)
    local itemName = pendingPlacements[player.UserId]
    
    if not itemName then
        warn("[CraftingSystem] Aucun placement en attente pour:", player.Name)
        return
    end
    
    -- Créer la structure
    if itemName == "Barricade" then
        createBarricade(position)
    elseif itemName == "Piege" then
        createPiege(position)
    elseif itemName == "Fortification" then
        createFortification(position)
    end
    
    pendingPlacements[player.UserId] = nil
    craftSuccessEvent:FireClient(player, true, itemName .. " placé avec succès!")
    print("[CraftingSystem] Structure placée:", itemName, "pour", player.Name, "à", position)
end)

-- === INITIALISATION DES JOUEURS ===
Players.PlayerAdded:Connect(function(player)
    initializePlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
    playerInventories[player.UserId] = nil
    pendingPlacements[player.UserId] = nil
    collectCooldowns[player.UserId] = nil
end)

print("[CraftingSystem] ✓ Système de craft serveur initialisé")