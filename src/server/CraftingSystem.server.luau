--[[
    CraftingClient.client.luau
    Gère la prévisualisation et le placement des structures côté client.
    Système de Ghost Part qui suit la souris avec Raycast au sol.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Remote Events
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local craftItemEvent = remoteEventsFolder:WaitForChild("CraftItemEvent")
local confirmPlacementEvent = remoteEventsFolder:WaitForChild("ConfirmPlacementEvent")
local startPlacementEvent = remoteEventsFolder:FindFirstChild("StartPlacementEvent")

if not startPlacementEvent then
    startPlacementEvent = Instance.new("RemoteEvent")
    startPlacementEvent.Name = "StartPlacementEvent"
    startPlacementEvent.Parent = remoteEventsFolder
end

-- Configuration
local PLACEMENT_MAX_RANGE = 30
local PLACEMENT_HEIGHT_OFFSET = {
    Barricade = 3,
    Piege = 0.25,
    Fortification = 0
}

-- Variables de placement
local isPlacementMode = false
local currentGhost = nil
local currentItemName = nil
local placementConnection = nil

-- === RAYCAST AU SOL ===
local function raycastToGround(origin)
    local rayOrigin = origin + Vector3.new(0, 10, 0)
    local rayDirection = Vector3.new(0, -100, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {player.Character}
    
    local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if rayResult then
        return rayResult.Position
    else
        return Vector3.new(origin.X, 0, origin.Z)
    end
end

-- === CRÉATION DU GHOST PART LOCAL ===
local function createLocalGhost(itemName)
    local ghost
    
    if itemName == "Barricade" then
        ghost = Instance.new("Part")
        ghost.Name = "GhostBarricade"
        ghost.Size = Vector3.new(8, 6, 1)
        ghost.Anchored = true
        ghost.CanCollide = false
        ghost.Material = Enum.Material.ForceField
        ghost.BrickColor = BrickColor.new("Cyan")
        ghost.Transparency = 0.5
        
    elseif itemName == "Piege" then
        ghost = Instance.new("Part")
        ghost.Name = "GhostTrap"
        ghost.Size = Vector3.new(6, 0.5, 6)
        ghost.Anchored = true
        ghost.CanCollide = false
        ghost.Material = Enum.Material.ForceField
        ghost.BrickColor = BrickColor.new("Bright red")
        ghost.Transparency = 0.5
        
        -- Marqueur visuel
        local decal = Instance.new("Decal")
        decal.Face = Enum.NormalId.Top
        decal.Color3 = Color3.fromRGB(255, 100, 100)
        decal.Transparency = 0.3
        decal.Parent = ghost
        
    elseif itemName == "Fortification" then
        ghost = Instance.new("Part")
        ghost.Name = "GhostFortification"
        ghost.Size = Vector3.new(10, 8, 2)
        ghost.Anchored = true
        ghost.CanCollide = false
        ghost.Material = Enum.Material.ForceField
        ghost.BrickColor = BrickColor.new("Lime green")
        ghost.Transparency = 0.5
    end
    
    if ghost then
        ghost.Parent = Workspace.CurrentCamera -- Visible uniquement pour le client
        print("[CraftingClient] Ghost créé:", itemName)
    end
    
    return ghost
end

-- === MISE À JOUR DE LA POSITION DU GHOST ===
local function updateGhostPosition()
    if not currentGhost or not currentGhost.Parent then
        stopPlacementMode()
        return
    end
    
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return end
    
    -- Raycast depuis la souris
    local mouseRay = mouse.UnitRay
    local rayOrigin = mouseRay.Origin
    local rayDirection = mouseRay.Direction * 100
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character, currentGhost}
    
    local rayResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if rayResult then
        local targetPosition = rayResult.Position
        
        -- Vérifier la distance
        local distance = (rootPart.Position - targetPosition).Magnitude
        
        if distance <= PLACEMENT_MAX_RANGE then
            -- Position valide - Ghost vert/cyan
            currentGhost.BrickColor = BrickColor.new("Lime green")
            
            -- Ajuster la hauteur selon le type
            local heightOffset = PLACEMENT_HEIGHT_OFFSET[currentItemName] or 0
            targetPosition = targetPosition + Vector3.new(0, heightOffset, 0)
            
            -- Orientation pour les barricades
            if currentItemName == "Barricade" then
                local lookVector = (targetPosition - rootPart.Position).Unit
                currentGhost.CFrame = CFrame.new(targetPosition, targetPosition + lookVector)
            else
                currentGhost.Position = targetPosition
            end
        else
            -- Position invalide - Ghost rouge
            currentGhost.BrickColor = BrickColor.new("Really red")
        end
    end
end

-- === CONFIRMER LE PLACEMENT ===
local function confirmPlacement()
    if not currentGhost or not currentGhost.Parent then return end
    
    local character = player.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return end
    
    local targetPosition = currentGhost.Position
    local distance = (rootPart.Position - targetPosition).Magnitude
    
    -- Vérifier que la position est valide (vert)
    if distance <= PLACEMENT_MAX_RANGE and currentGhost.BrickColor == BrickColor.new("Lime green") then
        -- Envoyer la position au serveur
        confirmPlacementEvent:FireServer(targetPosition)
        print("[CraftingClient] Placement confirmé à:", targetPosition)
        
        stopPlacementMode()
    else
        warn("[CraftingClient] Position invalide pour le placement")
    end
end

-- === ARRÊTER LE MODE PLACEMENT ===
function stopPlacementMode()
    isPlacementMode = false
    
    if currentGhost and currentGhost.Parent then
        currentGhost:Destroy()
    end
    currentGhost = nil
    currentItemName = nil
    
    if placementConnection then
        placementConnection:Disconnect()
        placementConnection = nil
    end
    
    print("[CraftingClient] Mode placement désactivé")
end

-- === DÉMARRER LE MODE PLACEMENT ===
function startPlacementMode(itemName)
    -- Arrêter le placement en cours
    if isPlacementMode then
        stopPlacementMode()
    end
    
    isPlacementMode = true
    currentItemName = itemName
    
    -- Créer le ghost
    currentGhost = createLocalGhost(itemName)
    
    if not currentGhost then
        warn("[CraftingClient] Impossible de créer le ghost pour:", itemName)
        stopPlacementMode()
        return
    end
    
    -- Mettre à jour la position en continu
    placementConnection = RunService.RenderStepped:Connect(updateGhostPosition)
    
    print("[CraftingClient] Mode placement activé pour:", itemName)
end

-- === ÉCOUTE DU SERVEUR POUR DÉMARRER LE PLACEMENT ===
startPlacementEvent.OnClientEvent:Connect(function(itemName)
    print("[CraftingClient] Demande de placement reçue pour:", itemName)
    startPlacementMode(itemName)
end)

-- === GESTION DES CLICS SOURIS ===
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if isPlacementMode then
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            -- Clic gauche : Confirmer le placement
            confirmPlacement()
            
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 or input.KeyCode == Enum.KeyCode.Escape then
            -- Clic droit ou Échap : Annuler
            stopPlacementMode()
            print("[CraftingClient] Placement annulé")
        end
    end
end)

-- === NETTOYAGE À LA DÉCONNEXION ===
player.CharacterRemoving:Connect(function()
    stopPlacementMode()
end)

print("[CraftingClient] ✓ Système de placement client initialisé")