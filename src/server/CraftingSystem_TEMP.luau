-- FICHIER: CraftingSystem.server.luau
--[[
    CraftingSystem.server.luau
    Gère la collecte de ressources (bois, pierre) et le craft d'objets pour le Village Maudit.
    Ressources stockées en attributs joueur ("Wood", "Stone").
    Craft autorisé uniquement en DAY_PHASE.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

-- Modules et références
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SharedData = ReplicatedStorage:WaitForChild("SharedData")

-- RemoteEvents
local RemoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not RemoteEventsFolder then
    RemoteEventsFolder = Instance.new("Folder")
    RemoteEventsFolder.Name = "RemoteEvents"
    RemoteEventsFolder.Parent = ReplicatedStorage
end

local CollectResourceEvent = RemoteEventsFolder:FindFirstChild("CollectResourceEvent")
if not CollectResourceEvent then
    CollectResourceEvent = Instance.new("RemoteEvent")
    CollectResourceEvent.Name = "CollectResourceEvent"
    CollectResourceEvent.Parent = RemoteEventsFolder
end

local CraftItemEvent = RemoteEventsFolder:FindFirstChild("CraftItemEvent")
if not CraftItemEvent then
    CraftItemEvent = Instance.new("RemoteEvent")
    CraftItemEvent.Name = "CraftItemEvent"
    CraftItemEvent.Parent = RemoteEventsFolder
end

-- Cooldowns de collecte par joueur
local collectCooldowns = {}

-- Définition des recettes de craft
local CRAFT_RECIPES = {
    Fortification = {
        Wood = 3,
        Stone = 2
    },
    Barricade = {
        Wood = 5,
        Stone = 0
    },
    Torche = {
        Wood = 2,
        Stone = 1
    },
    Lance = {
        Wood = 4,
        Stone = 1
    }
}

-- Durée de vie d'une barricade (en secondes)
local BARRICADE_DURATION = 60

-- Initialisation des attributs de ressources pour un joueur
local function initializePlayerResources(player)
    if player:GetAttribute("Wood") == nil then
        player:SetAttribute("Wood", 0)
    end
    if player:GetAttribute("Stone") == nil then
        player:SetAttribute("Stone", 0)
    end
end

-- Connexion des nouveaux joueurs
Players.PlayerAdded:Connect(function(player)
    initializePlayerResources(player)
end)

-- Initialisation des joueurs déjà présents
for _, player in ipairs(Players:GetPlayers()) do
    initializePlayerResources(player)
end

-- Gestion de la collecte de ressources
CollectResourceEvent.OnServerEvent:Connect(function(player, resourcePart)
    -- Vérification du cooldown
    local currentTime = tick()
    local lastCollect = collectCooldowns[player.UserId] or 0
    if currentTime - lastCollect < 2 then
        return -- Cooldown actif
    end
    
    -- Vérification de l'objet ciblé
    if not resourcePart or not resourcePart:IsA("BasePart") then
        return
    end
    
    -- Vérification de la distance (anti-cheat basique)
    local character = player.Character
    if not character then return end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local distance = (humanoidRootPart.Position - resourcePart.Position).Magnitude
    if distance > 15 then
        return -- Trop loin
    end
    
    -- Déterminer le type de ressource
    local resourceType = nil
    if resourcePart.Name == "TreeTrunk" then
        resourceType = "Wood"
    elseif resourcePart.Name == "Rock" then
        resourceType = "Stone"
    else
        return -- Type non reconnu
    end
    
    -- Incrémenter la ressource
    local currentAmount = player:GetAttribute(resourceType) or 0
    player:SetAttribute(resourceType, currentAmount + 1)
    
    -- Mettre à jour le cooldown
    collectCooldowns[player.UserId] = currentTime
end)

-- Vérifier si le joueur a assez de ressources
local function hasEnoughResources(player, recipe)
    local wood = player:GetAttribute("Wood") or 0
    local stone = player:GetAttribute("Stone") or 0
    
    return wood >= recipe.Wood and stone >= recipe.Stone
end

-- Déduire les ressources du joueur
local function deductResources(player, recipe)
    local wood = player:GetAttribute("Wood") or 0
    local stone = player:GetAttribute("Stone") or 0
    
    player:SetAttribute("Wood", wood - recipe.Wood)
    player:SetAttribute("Stone", stone - recipe.Stone)
end

-- Fortifier une porte (répare +100 HP)
local function craftFortification(player)
    local village = Workspace:FindFirstChild("Village")
    if not village then
        warn("Village introuvable dans Workspace")
        return
    end
    
    local fortifications = village:FindFirstChild("Fortifications")
    if not fortifications then
        warn("Fortifications introuvables dans Village")
        return
    end
    
    -- Chercher la porte la plus proche du joueur
    local character = player.Character
    if not character then return end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    local closestDoor = nil
    local closestDistance = math.huge
    
    for _, doorModel in ipairs(fortifications:GetChildren()) do
        if doorModel:IsA("Model") and doorModel.Name:match("^Door_") then
            local doorPart = doorModel:FindFirstChild("DoorPart")
            if doorPart and doorPart:IsA("BasePart") then
                local distance = (humanoidRootPart.Position - doorPart.Position).Magnitude
                if distance < closestDistance and distance <= 20 then
                    closestDistance = distance
                    closestDoor = doorPart
                end
            end
        end
    end
    
    if not closestDoor then
        warn("Aucune porte à proximité pour fortifier")
        return
    end
    
    local currentHealth = closestDoor:GetAttribute("Health") or 0
    local maxHealth = 500
    local newHealth = math.min(currentHealth + 100, maxHealth)
    closestDoor:SetAttribute("Health", newHealth)
end

-- Créer une barricade temporaire
local function craftBarricade(player)
    local character = player.Character
    if not character then return end
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Créer une barricade devant le joueur
    local barricade = Instance.new("Part")
    barricade.Name = "Barricade"
    barricade.Size = Vector3.new(8, 6, 1)
    barricade.Anchored = true
    barricade.BrickColor = BrickColor.new("Brown")
    barricade.Material = Enum.Material.Wood
    
    -- Positionner devant le joueur
    local forwardVector = humanoidRootPart.CFrame.LookVector
    barricade.Position = humanoidRootPart.Position + forwardVector * 5
    barricade.Parent = Workspace
    
    -- Détruire après la durée définie
    task.delay(BARRICADE_DURATION, function()
        if barricade and barricade.Parent then
            barricade:Destroy()
        end
    end)
end

-- Créer une torche portable
local function craftTorche(player)
    local character = player.Character
    if not character then return end
    
    -- Vérifier si le joueur a déjà une torche
    if character:FindFirstChild("TorchePortable") then
        warn("Le joueur a déjà une torche")
        return
    end
    
    -- Créer la torche (Part avec PointLight)
    local torche = Instance.new("Part")
    torche.Name = "TorchePortable"
    torche.Size = Vector3.new(0.5, 2, 0.5)
    torche.BrickColor = BrickColor.new("Brown")
    torche.Material = Enum.Material.Wood
    
    local light = Instance.new("PointLight")
    light.Brightness = 2
    light.Range = 20
    light.Color = Color3.fromRGB(255, 150, 50)
    light.Parent = torche
    
    -- Attacher au joueur
    local weld = Instance.new("Weld")
    weld.Part0 = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    weld.Part1 = torche
    weld.C1 = CFrame.new(1, 1, 0)
    weld.Parent = torche
    
    torche.Parent = character
    
    -- Augmenter légèrement la vitesse de déplacement
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = humanoid.WalkSpeed + 2
    end
    
    -- Stocker la valeur pour restauration lors de la destruction
    torche:SetAttribute("SpeedBoost", 2)
end

-- Créer une lance rudimentaire
local function craftLance(player)
    local character = player.Character
    if not character then return end
    
    -- Vérifier si le joueur a déjà une lance
    if character:FindFirstChild("LanceRudimentaire") then
        warn("Le joueur a déjà une lance")
        return
    end
    
    -- Créer la lance (Tool simple)
    local lance = Instance.new("Tool")
    lance.Name = "LanceRudimentaire"
    lance.RequiresHandle = true
    lance.CanBeDropped = false
    
    local handle = Instance.new("Part")
    handle.Name = "Handle"
    handle.Size = Vector3.new(0.5, 4, 0.5)
    handle.BrickColor = BrickColor.new("Brown")
    handle.Material = Enum.Material.Wood
    handle.Parent = lance
    
    -- Ajouter un attribut de dégâts
    lance:SetAttribute("Damage", 25)
    
    -- Script d'attaque (géré par un script séparé ou par contact)
    lance.Activated:Connect(function()
        -- Animation d'attaque basique (à développer)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            -- Détecter les monstres à proximité
            local monstersFolder = Workspace:FindFirstChild("Monsters")
            if monstersFolder then
                for _, monster in ipairs(monstersFolder:GetChildren()) do
                    if monster:IsA("Model") then
                        local monsterHumanoid = monster:FindFirstChildOfClass("Humanoid")
                        local monsterRoot = monster:FindFirstChild("HumanoidRootPart")
                        if monsterHumanoid and monsterRoot then
                            local distance = (character:FindFirstChild("HumanoidRootPart").Position - monsterRoot.Position).Magnitude
                            if distance <= 8 then
                                monsterHumanoid:TakeDamage(lance:GetAttribute("Damage"))
                            end
                        end
                    end
                end
            end
        end
    end)
    
    lance.Parent = player.Backpack
end

-- Gestion du craft
CraftItemEvent.OnServerEvent:Connect(function(player, itemName)
    -- Vérifier la phase actuelle
    local currentPhase = SharedData:GetAttribute("CurrentPhase")
    if currentPhase ~= "DAY_PHASE" then
        return -- Craft autorisé uniquement en phase de jour
    end
    
    -- Vérifier que la recette existe
    local recipe = CRAFT_RECIPES[itemName]
    if not recipe then
        warn("Recette inconnue:", itemName)
        return
    end
    
    -- Vérifier les ressources
    if not hasEnoughResources(player, recipe) then
        return -- Ressources insuffisantes
    end
    
    -- Déduire les ressources
    deductResources(player, recipe)
    
    -- Appliquer l'effet du craft
    if itemName == "Fortification" then
        craftFortification(player)
    elseif itemName == "Barricade" then
        craftBarricade(player)
    elseif itemName == "Torche" then
        craftTorche(player)
    elseif itemName == "Lance" then
        craftLance(player)
    end
end)

-- Nettoyage lors de la déconnexion
Players.PlayerRemoving:Connect(function(player)
    collectCooldowns[player.UserId] = nil
end)

-- FICHIER: CraftingClient.client.luau
--[[
    CraftingClient.client.luau
    Interface client pour la collecte de ressources et le craft d'objets.
    Affiche les ressources du joueur et un menu de craft.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- RemoteEvents
local RemoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local CollectResourceEvent = RemoteEventsFolder:WaitForChild("CollectResourceEvent")
local CraftItemEvent = RemoteEventsFolder:WaitForChild("CraftItemEvent")

-- Définition des recettes (côté client pour l'affichage)
local CRAFT_RECIPES = {
    {Name = "Fortification", Wood = 3, Stone = 2, Description = "Répare une porte (+100 HP)"},
    {Name = "Barricade", Wood = 5, Stone = 0, Description = "Barricade temporaire (60s)"},
    {Name = "Torche", Wood = 2, Stone = 1, Description = "Éclairage et vitesse +"},
    {Name = "Lance", Wood = 4, Stone = 1, Description = "Arme de mêlée (25 dégâts)"}
}

-- Création de l'interface utilisateur
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CraftingUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Affichage des ressources
local resourceFrame = Instance.new("Frame")
resourceFrame.Name = "ResourceFrame"
resourceFrame.Size = UDim2.new(0, 200, 0, 60)
resourceFrame.Position = UDim2.new(0, 10, 0, 10)
resourceFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
resourceFrame.BackgroundTransparency = 0.3
resourceFrame.BorderSizePixel = 0
resourceFrame.Parent = screenGui

local woodLabel = Instance.new("TextLabel")
woodLabel.Name = "WoodLabel"
woodLabel.Size = UDim2.new(1, 0, 0.5, 0)
woodLabel.Position = UDim2.new(0, 0, 0, 0)
woodLabel.BackgroundTransparency = 1
woodLabel.Text = "Bois: 0"
woodLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
woodLabel.TextScaled = true
woodLabel.Font = Enum.Font.SourceSansBold
woodLabel.Parent = resourceFrame

local stoneLabel = Instance.new("TextLabel")
stoneLabel.Name = "StoneLabel"
stoneLabel.Size = UDim2.new(1, 0, 0.5, 0)
stoneLabel.Position = UDim2.new(0, 0, 0.5, 0)
stoneLabel.BackgroundTransparency = 1
stoneLabel.Text = "Pierre: 0"
stoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stoneLabel.TextScaled = true
stoneLabel.Font = Enum.Font.SourceSansBold
stoneLabel.Parent = resourceFrame

-- Menu de craft
local craftFrame = Instance.new("Frame")
craftFrame.Name = "CraftFrame"
craftFrame.Size = UDim2.new(0, 300, 0, 400)
craftFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
craftFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
craftFrame.BackgroundTransparency = 0.2
craftFrame.BorderSizePixel = 2
craftFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
craftFrame.Visible = false
craftFrame.Parent = screenGui

local craftTitle = Instance.new("TextLabel")
craftTitle.Name = "Title"
craftTitle.Size = UDim2.new(1, 0, 0, 40)
craftTitle.BackgroundTransparency = 1
craftTitle.Text = "Menu de Craft"
craftTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
craftTitle.TextScaled = true
craftTitle.Font = Enum.Font.SourceSansBold
craftTitle.Parent = craftFrame

local craftList = Instance.new("ScrollingFrame")
craftList.Name = "CraftList"
craftList.Size = UDim2.new(1, -20, 1, -60)
craftList.Position = UDim2.new(0, 10, 0, 50)
craftList.BackgroundTransparency = 1
craftList.BorderSizePixel = 0
craftList.ScrollBarThickness = 6
craftList.Parent = craftFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = craftList

-- Créer les boutons de craft
for _, recipe in ipairs(CRAFT_RECIPES) do
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = recipe.Name
    itemFrame.Size = UDim2.new(1, -10, 0, 80)
    itemFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    itemFrame.BorderSizePixel = 0
    itemFrame.Parent = craftList
    
    local itemName = Instance.new("TextLabel")
    itemName.Size = UDim2.new(1, -10, 0, 20)
    itemName.Position = UDim2.new(0, 5, 0, 5)
    itemName.BackgroundTransparency = 1
    itemName.Text = recipe.Name
    itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemName.Font = Enum.Font.SourceSansBold
    itemName.TextSize = 18
    itemName.TextXAlignment = Enum.TextXAlignment.Left
    itemName.Parent = itemFrame
    
    local itemCost = Instance.new("TextLabel")
    itemCost.Size = UDim2.new(1, -10, 0, 15)
    itemCost.Position = UDim2.new(0, 5, 0, 25)
    itemCost.BackgroundTransparency = 1
    itemCost.Text = string.format("Coût: %d Bois, %d Pierre", recipe.Wood, recipe.Stone)
    itemCost.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemCost.Font = Enum.Font.SourceSans
    itemCost.TextSize = 14
    itemCost.TextXAlignment = Enum.TextXAlignment.Left
    itemCost.Parent = itemFrame
    
    local itemDesc = Instance.new("TextLabel")
    itemDesc.Size = UDim2.new(1, -10, 0, 15)
    itemDesc.Position = UDim2.new(0, 5, 0, 40)
    itemDesc.BackgroundTransparency = 1
    itemDesc.Text = recipe.Description
    itemDesc.TextColor3 = Color3.fromRGB(180, 180, 180)
    itemDesc.Font = Enum.Font.SourceSansItalic
    itemDesc.TextSize = 12
    itemDesc.TextXAlignment = Enum.TextXAlignment.Left
    itemDesc.Parent = itemFrame
    
    local craftButton = Instance.new("TextButton")
    craftButton.Name = "CraftButton"
    craftButton.Size = UDim2.new(0, 100, 0, 20)
    craftButton.Position = UDim2.new(1, -110, 1, -25)
    craftButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    craftButton.BorderSizePixel = 0
    craftButton.Text = "Fabriquer"
    craftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    craftButton.Font = Enum.Font.SourceSansBold
    craftButton.TextSize = 14
    craftButton.Parent = itemFrame
    
    craftButton.MouseButton1Click:Connect(function()
        CraftItemEvent:FireServer(recipe.Name)
    end)
end

-- Mise à jour de l'affichage des ressources
local function updateResourceDisplay()
    local wood = player:GetAttribute("Wood") or 0
    local stone = player:GetAttribute("Stone") or 0
    
    woodLabel.Text = "Bois: " .. wood
    stoneLabel.Text = "Pierre: " .. stone
    
    -- Mettre à jour l'état des boutons de craft
    for _, itemFrame in ipairs(craftList:GetChildren()) do
        if itemFrame:IsA("Frame") then
            local craftButton = itemFrame:FindFirstChild("CraftButton")
            if craftButton then
                local recipeName = itemFrame.Name
                local recipe = nil
                for _, r in ipairs(CRAFT_RECIPES) do
                    if r.Name == recipeName then
                        recipe = r
                        break
                    end
                end
                
                if recipe then
                    local canCraft = wood >= recipe.Wood and stone >= recipe.Stone
                    craftButton.BackgroundColor3 = canCraft and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(100, 100, 100)
                    craftButton.TextColor3 = canCraft and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
                end
            end
        end
    end
end

-- Écouter les changements d'attributs
player:GetAttributeChangedSignal("Wood"):Connect(updateResourceDisplay)
player:GetAttributeChangedSignal("Stone"):Connect(updateResourceDisplay)

-- Initialisation
updateResourceDisplay()

-- Toggle du menu de craft avec la touche C
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.C then
        craftFrame.Visible = not craftFrame.Visible
    end
end)

-- Collecte de ressources au clic sur un objet
local mouse = player:GetMouse()

mouse.Button1Down:Connect(function()
    local target = mouse.Target
    if target and (target.Name == "TreeTrunk" or target.Name == "Rock") then
        CollectResourceEvent:FireServer(target)
    end
end)