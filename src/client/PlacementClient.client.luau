--[[
	PlacementClient.client.luau
	Gère le placement côté client des structures craftées (Barricade, Piège, Fortification).
	
	Flux :
	1. Le serveur envoie StartPlacementEvent avec le nom de l'item
	2. Le client affiche un aperçu semi-transparent qui suit la souris
	3. Clic gauche confirme le placement (envoie la position au serveur)
	4. Échap annule le placement (détruit l'aperçu localement)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Références aux RemoteEvents (créés par CraftingSystem.server.luau)
local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
local startPlacementEvent = remoteEventsFolder:WaitForChild("StartPlacementEvent")
local confirmPlacementEvent = remoteEventsFolder:WaitForChild("ConfirmPlacementEvent")

-- État du placement
local isPlacing = false
local previewPart = nil
local currentItemName = ""
local renderConnection = nil

-- Configuration des dimensions par type d'item
local ITEM_SIZES = {
	Barricade = Vector3.new(8, 6, 1),
	Piege = Vector3.new(4, 0.5, 4),
	Fortification = Vector3.new(6, 8, 6)
}

-- Couleurs par type
local ITEM_COLORS = {
	Barricade = Color3.fromRGB(139, 69, 19),    -- Brun
	Piege = Color3.fromRGB(150, 150, 150),      -- Gris
	Fortification = Color3.fromRGB(100, 100, 100) -- Gris foncé
}

--[[
	Crée l'aperçu visuel de la structure à placer
--]]
local function createPreview(itemName)
	local preview = Instance.new("Part")
	preview.Name = "PlacementPreview"
	preview.Size = ITEM_SIZES[itemName] or Vector3.new(4, 4, 4)
	preview.Color = ITEM_COLORS[itemName] or Color3.fromRGB(255, 255, 255)
	preview.Transparency = 0.5
	preview.CanCollide = false
	preview.Anchored = true
	preview.Material = Enum.Material.SmoothPlastic
	preview.Parent = workspace
	
	return preview
end

--[[
	Met à jour la position de l'aperçu en fonction de la souris
--]]
local function updatePreviewPosition()
	if not previewPart then return end
	
	-- Raycast depuis la caméra vers la position de la souris
	local mouseRay = workspace.CurrentCamera:ScreenPointToRay(mouse.X, mouse.Y)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {previewPart, player.Character}
	
	local raycastResult = workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000, raycastParams)
	
	if raycastResult then
		-- Positionne l'aperçu au point d'impact, légèrement au-dessus du sol
		local hitPosition = raycastResult.Position
		local yOffset = previewPart.Size.Y / 2
		previewPart.Position = Vector3.new(hitPosition.X, hitPosition.Y + yOffset, hitPosition.Z)
		
		-- Change la couleur selon si le placement est valide (pour le retour visuel)
		-- Vert si au-dessus du terrain, rouge sinon
		if raycastResult.Instance and raycastResult.Instance:IsA("Part") then
			previewPart.Color = Color3.fromRGB(100, 255, 100) -- Vert translucide
		else
			previewPart.Color = ITEM_COLORS[currentItemName] or Color3.fromRGB(255, 255, 255)
		end
	end
end

--[[
	Démarre le mode placement
--]]
local function startPlacement(itemName)
	if isPlacing then
		-- Nettoie l'ancien placement si existant
		stopPlacement(false)
	end
	
	isPlacing = true
	currentItemName = itemName
	previewPart = createPreview(itemName)
	
	-- Connecte la boucle de rendu pour mettre à jour l'aperçu
	renderConnection = RunService.RenderStepped:Connect(updatePreviewPosition)
end

--[[
	Arrête le mode placement
	@param confirm : si true, envoie la position au serveur
--]]
function stopPlacement(confirm)
	if not isPlacing then return end
	
	-- Déconnecte la boucle de rendu
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	
	-- Envoie la confirmation au serveur si demandé
	if confirm and previewPart then
		local placementPosition = previewPart.Position
		confirmPlacementEvent:FireServer(placementPosition)
	end
	
	-- Nettoie l'aperçu
	if previewPart then
		previewPart:Destroy()
		previewPart = nil
	end
	
	isPlacing = false
	currentItemName = ""
end

--[[
	Gère les entrées utilisateur (clic gauche, Échap)
--]]
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	if not isPlacing then return end
	
	-- Clic gauche : confirme le placement
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		stopPlacement(true)
	end
	
	-- Touche Échap : annule le placement
	if input.KeyCode == Enum.KeyCode.Escape then
		stopPlacement(false)
	end
end

-- Connexions des événements
startPlacementEvent.OnClientEvent:Connect(startPlacement)
UserInputService.InputBegan:Connect(onInputBegan)

print("[PlacementClient] Système de placement initialisé")