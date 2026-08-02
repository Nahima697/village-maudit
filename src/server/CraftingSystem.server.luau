--[[
    CraftingSystem.server.luau
    Gère la collecte de ressources et le craft.
    Version modernisée avec support des pièges et objets physiques corrigés.
    CORRECTIONS : Tools fonctionnels (Torche/Lance), objets visibles et clampés dans CraftZone
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

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
local LANCE_DAMAGE = 25
local GATE_REPAIR_AMOUNT = 100

local collectCooldowns = {}

-- === RECETTES DE CRAFT ===
local CRAFT_RECIPES = {
    Fortification = {Wood = 3, Stone = 2},
    Barricade = {Wood = 5, Stone = 0},
    Torche = {Wood = 2, Stone = 1},
    Lance = {Wood = 4, Stone = 1},
    Piege = {Wood = 2, Stone = 3}
}

-- === INITIALISATION DE LA ZONE DE CRAFT ===
local function initCraftZone()
    local craftZone = Workspace:FindFirstChild("CraftZone")
    if not craftZone then
        craftZone = Instance.new("Part")
        craftZone.Name = "CraftZone"
        craftZone.Size = Vector3.new(40, 1, 40)
        craftZone.Position = Vector3.new(0, 0.5, 0)
        craftZone.Anchored = true
        craftZone.Transparency = 1
        craftZone.CanCollide = false
        craftZone.Parent = Workspace
        print("[CraftingSystem] Zone de craft créée au centre du village")
    end
    return craftZone
end

local craftZone = initCraftZone()

-- === FONCTION UTILITAIRE : CLAMP POSITION DANS CRAFT ZONE ===
local function clampPositionToCraftZone(position)
    if not craftZone then
        warn("[CraftingSystem] CraftZone introuvable, utilisation position brute")
        return position
    end
    
    local zonePos = craftZone.Position
    local halfSize = craftZone.Size / 2
    
    local clampedX = math.clamp(position.X, zonePos.X - halfSize.X, zonePos.X + halfSize.X)
    local clampedZ = math.clamp(position.Z, zonePos.Z - halfSize.Z, zonePos.Z + halfSize.Z)
    
    return Vector3.new(clampedX, position.Y, clampedZ)
end

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
    -- Calcul de la position devant le joueur
    local targetPosition = position + (lookVector * 5) + Vector3.new(0, 3, 0)
    
    -- Clamp dans la zone de craft
    targetPosition = clampPositionToCraftZone(targetPosition)
    
    local barricade = Instance.new("Part")
    barricade.Name = "PlayerBarricade"
    barricade.Size = Vector3.new(8, 6, 1)
    barricade.Anchored = true
    barricade.Material = Enum.Material.Wood
    barricade.BrickColor = BrickColor.new("Brown")
    barricade.Transparency = 0
    barricade.CanCollide = true
    barricade.CFrame = CFrame.new(targetPosition)
    barricade.Parent = Workspace
    
    -- Ajout de textures visuelles
    local texture = Instance.new("Texture")
    texture.Texture = "rbxasset://textures/wood.png"
    texture.Face = Enum.NormalId.Front
    texture.Parent = barricade
    
    local texture2 = texture:Clone()
    texture2.Face = Enum.NormalId.Back
    texture2.Parent = barricade
    
    print("[CraftingSystem] Barricade créée à la position:", targetPosition)
    
    task.delay(BARRICADE_LIFETIME, function()
        if barricade and barricade.Parent then
            barricade:Destroy()
        end
    end)
end

local function createTorch(player)
    local tool = Instance.new("Tool")
    tool.Name = "Torche"
    tool.RequiresHandle = true
    tool.CanBeDropped = true
    tool.ToolTip = "Éclaire les ténèbres"
    
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.5, 2, 0.5)
    handle.Material = Enum.Material.Wood
    handle.BrickColor = BrickColor.new("Reddish brown")
    handle.CanCollide = false
    handle.Parent = tool
    
    -- Effet de feu
    local fire = Instance.new("Fire")
    fire.Size = 6
    fire.Heat = 5
    fire.Parent = handle
    
    -- Lumière qui éclaire
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 20
    light.Color = Color3.fromRGB(255, 180, 100)
    light.Enabled = true
    light.Parent = handle
    
    -- Activation de la lumière uniquement quand équipée
    tool.Equipped:Connect(function()
        light.Enabled = true
        fire.Enabled = true
    end)
    
    tool.Unequipped:Connect(function()
        light.Enabled = false
        fire.Enabled = false
    end)
    
    tool.Parent = player.Backpack
    print("[CraftingSystem] Torche créée pour", player.Name)
end

local function createLance(player)
    local tool = Instance.new("Tool")
    tool.Name = "Lance"
    tool.RequiresHandle = true
    tool.CanBeDropped = true
    tool.ToolTip = "Attaque : 25 dégâts"
    
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.3, 4, 0.3)
    handle.Material = Enum.Material.Wood
    handle.BrickColor = BrickColor.new("Dark orange")
    handle.CanCollide = false
    handle.Parent = tool
    
    -- Pointe de la lance
    local tip = Instance.new("Part")
    tip.Name = "Tip"
    tip.Size = Vector3.new(0.6, 1.5, 0.6)
    tip.Shape = Enum.PartType.Ball
    tip.Material = Enum.Material.Slate
    tip.BrickColor = BrickColor.new("Medium stone grey")
    tip.CanCollide = false
    tip.Parent = handle
    
    -- Weld pour attacher la pointe
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = handle
    weld.Part1 = tip
    weld.Parent = handle
    
    -- Ajustement position pointe (en haut du manche)
    local attachment0 = Instance.new("Attachment")
    attachment0.Position = Vector3.new(0, 2, 0)
    attachment0.Parent = handle
    
    local attachment1 = Instance.new("Attachment")
    attachment1.Position = Vector3.new(0, -0.75, 0)
    attachment1.Parent = tip
    
    weld.Attachment0 = attachment0
    weld.Attachment1 = attachment1
    
    -- Système d'attaque avec Activated
    local attackCooldown = false
    
    tool.Activated:Connect(function()
        if attackCooldown then return end
        
        local character = tool.Parent
        if not character or not character:IsA("Model") then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoid or not rootPart then return end
        
        attackCooldown = true
        
        -- Animation visuelle de l'attaque
        local originalCFrame = handle.CFrame
        
        -- Détection des ennemis dans un rayon devant le joueur
        local attackRange = 8
        local attackOrigin = rootPart.Position + rootPart.CFrame.LookVector * 4
        
        for _, part in ipairs(Workspace:GetPartBoundsInRadius(attackOrigin, attackRange)) do
            local targetHumanoid = part.Parent:FindFirstChildOfClass("Humanoid")
            if targetHumanoid and targetHumanoid ~= humanoid then
                -- Vérifier si c'est un monstre
                local isMonster = part.Parent:FindFirstChild("Monster") or 
                                  string.find(part.Parent.Name:lower(), "monster") or
                                  string.find(part.Parent.Name:lower(), "zombie") or
                                  string.find(part.Parent.Name:lower(), "enemy")
                
                if isMonster then
                    targetHumanoid:TakeDamage(LANCE_DAMAGE)
                    print("[CraftingSystem] Lance a infligé", LANCE_DAMAGE, "dégâts à", part.Parent.Name)
                    
                    -- Effet visuel sur la cible
                    local hitEffect = Instance.new("Part")
                    hitEffect.Size = Vector3.new(1, 1, 1)
                    hitEffect.Shape = Enum.PartType.Ball
                    hitEffect.BrickColor = BrickColor.new("Bright red")
                    hitEffect.Material = Enum.Material.Neon
                    hitEffect.Anchored = true
                    hitEffect.CanCollide = false
                    hitEffect.Transparency = 0.3
                    hitEffect.Position = part.Position
                    hitEffect.Parent = Workspace
                    
                    task.delay(0.2, function()
                        if hitEffect and hitEffect.Parent then
                            hitEffect:Destroy()
                        end
                    end)
                end
            end
        end
        
        task.wait(1)
        attackCooldown = false
    end)
    
    tool.Parent = player.Backpack
    print("[CraftingSystem] Lance créée pour", player.Name)
end

local function createTrap(position, lookVector)
    -- Calcul de la position devant le joueur
    local targetPosition = position + (lookVector * 4)
    
    -- Raycast pour trouver le sol
    local rayOrigin = targetPosition + Vector3.new(0, 10, 0)
    local rayDirection = Vector3.new(0, -20, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {Workspace:FindFirstChild("Players")}
    
    local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if rayResult then
        targetPosition = rayResult.Position + Vector3.new(0, 0.25, 0)
    else
        targetPosition = Vector3.new(targetPosition.X, 0.25, targetPosition.Z)
    end
    
    -- Clamp dans la zone de craft
    targetPosition = clampPositionToCraftZone(targetPosition)
    
    local trap = Instance.new("Part")
    trap.Name = "PlayerTrap"
    trap.Size = Vector3.new(6, 0.5, 6)
    trap.Anchored = true
    trap.Material = Enum.Material.Slate
    trap.BrickColor = BrickColor.new("Dark stone grey")
    trap.Transparency = 0
    trap.CanCollide = false
    trap.CFrame = CFrame.new(targetPosition)
    trap.Parent = Workspace
    
    -- Marqueur visuel rouge sur le dessus
    local decal = Instance.new("Decal")
    decal.Texture = "rbxasset://textures/face.png"
    decal.Face = Enum.NormalId.Top
    decal.Color3 = Color3.fromRGB(200, 0, 0)
    decal.Transparency = 0
    decal.Parent = trap
    
    -- Zone de détection invisible plus grande
    local detectionZone = Instance.new("Part")
    detectionZone.Size = Vector3.new(6, 4, 6)
    detectionZone.Anchored = true
    detectionZone.Transparency = 1
    detectionZone.CanCollide = false
    detectionZone.CFrame = CFrame.new(targetPosition) + Vector3.new(0, 2, 0)
    detectionZone.Parent = trap
    
    print("[CraftingSystem] Piège créé à la position:", targetPosition)
    
    -- Détection de collision pour infliger des dégâts
    local debounce = {}
    detectionZone.Touched:Connect(function(hit)
        local humanoid = hit.Parent:FindFirstChildOfClass("Humanoid")
        if humanoid and not debounce[hit.Parent] then
            debounce[hit.Parent] = true
            humanoid:TakeDamage(TRAP_DAMAGE)
            print("[CraftingSystem] Piège a infligé", TRAP_DAMAGE, "dégâts à", hit.Parent.Name)
            
            -- Effet visuel d'activation
            trap.BrickColor = BrickColor.new("Bright red")
            trap.Material = Enum.Material.Neon
            
            task.wait(0.5)
            if trap and trap.Parent then
                trap.BrickColor = BrickColor.new("Dark stone grey")
                trap.Material = Enum.Material.Slate
            end
            
            task.wait(3)
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

local function fortifyGate()
    -- Recherche de la porte dans le Workspace
    local gate = Workspace:FindFirstChild("Gate") or Workspace:FindFirstChild("VillageGate")
    
    if not gate then
        -- Recherche dans les descendants
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and (obj.Name == "Gate" or obj.Name == "VillageGate") then
                gate = obj
                break
            end
        end
    end
    
    if not gate then
        warn("[CraftingSystem] Porte introuvable pour la fortification")
        return
    end
    
    -- Trouver la partie principale de la porte
    local gatePart = gate:IsA("BasePart") and gate or gate:FindFirstChildWhichIsA("BasePart", true)
    
    if not gatePart then
        warn("[CraftingSystem] Partie principale de la porte introuvable")
        return
    end
    
    -- Réparation de la porte
    local currentHealth = gate:GetAttribute("Health") or 0
    local maxHealth = gate:GetAttribute("MaxHealth") or 500
    local newHealth = math.min(currentHealth + GATE_REPAIR_AMOUNT, maxHealth)
    gate:SetAttribute("Health", newHealth)
    
    print("[CraftingSystem] Porte fortifiée:", currentHealth, "->", newHealth)
    
    -- Effet visuel de réparation : clignotement vert
    local originalColor = gatePart.BrickColor
    local originalMaterial = gatePart.Material
    
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 3, true)
    local tween = TweenService:Create(gatePart, tweenInfo, {
        BrickColor = BrickColor.new("Lime green")
    })
    tween:Play()
    
    tween.Completed:Connect(function()
        gatePart.BrickColor = originalColor
    end)
    
    -- Particules de réparation scintillantes
    local particles = Instance.new("ParticleEmitter")
    particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    particles.Color = ColorSequence.new(Color3.fromRGB(100, 255, 100))
    particles.Rate = 100
    particles.Lifetime = NumberRange.new(0.5, 1.5)
    particles.Speed = NumberRange.new(3, 8)
    particles.SpreadAngle = Vector2.new(180, 180)
    particles.Parent = gatePart
    
    -- Effet sonore (optionnel, si des sons existent)
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxasset://sounds/impact.mp3"
    sound.Volume = 0.5
    sound.Parent = gatePart
    sound:Play()
    
    task.delay(2, function()
        if particles and particles.Parent then
            particles.Enabled = false
            task.wait(2)
            if particles.Parent then
                particles:Destroy()
            end
        end
        if sound and sound.Parent then
            sound:Destroy()
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
        warn("[CraftingSystem] Ressources insuffisantes pour", itemName, "- Requis:", recipe.Wood, "bois,", recipe.Stone, "pierre - Disponible:", wood, "bois,", stone, "pierre")
        return
    end
    
    -- Vérification du personnage (sauf pour Fortification qui ne nécessite pas de position)
    local char = player.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    
    if itemName ~= "Fortification" and (not char or not rootPart) then
        warn("[CraftingSystem] Personnage ou HumanoidRootPart introuvable pour", player.Name)
        return
    end
    
    -- Déduction des ressources
    player:SetAttribute("Wood", wood - recipe.Wood)
    player:SetAttribute("Stone", stone - recipe.Stone)
    
    -- Création de l'objet crafté
    if itemName == "Barricade" then
        if rootPart then
            local position = rootPart.Position
            local lookVector = rootPart.CFrame.LookVector
            createBarricade(position, lookVector)
        end
    elseif itemName == "Torche" then
        createTorch(player)
    elseif itemName == "Lance" then
        createLance(player)
    elseif itemName == "Piege" then
        if rootPart then
            local position = rootPart.Position
            local lookVector = rootPart.CFrame.LookVector
            createTrap(position, lookVector)
        end
    elseif itemName == "Fortification" then
        fortifyGate()
    end
    
    print("[CraftingSystem]", player.Name, "a crafté:", itemName)
end)

print("[CraftingSystem] ✓ Prêt - Recettes disponibles:", 5, "- CraftZone initialisée")