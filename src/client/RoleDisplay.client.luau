-- RoleDisplay.client.luau
-- Affiche le rôle du joueur (Traître ou Villageois) via un overlay temporaire et un badge permanent

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Référence au RemoteEvent créé par GameManager
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local AssignRoleEvent = RemoteEvents:WaitForChild("AssignRole")

-- Configuration visuelle
local ROLE_COLORS = {
	Traitor = Color3.fromRGB(200, 30, 30),
	Villager = Color3.fromRGB(80, 200, 120)
}

local ROLE_TEXTS = {
	Traitor = {
		title = "Vous êtes un TRAÎTRE",
		subtitle = "Sabotez le village la nuit, sans vous faire démasquer."
	},
	Villager = {
		title = "Vous êtes un VILLAGEOIS",
		subtitle = "Survivez et démasquez le traître."
	}
}

local OVERLAY_DURATION = 5 -- secondes
local FADE_DURATION = 1 -- secondes pour le fondu de sortie

-- Variables pour stocker les UI actuelles
local currentRoleRevealUI = nil
local currentRoleBadge = nil
local currentRole = nil

-- Fonction pour supprimer proprement les UI existantes
local function CleanupExistingUI()
	if currentRoleRevealUI then
		currentRoleRevealUI:Destroy()
		currentRoleRevealUI = nil
	end
	if currentRoleBadge then
		currentRoleBadge:Destroy()
		currentRoleBadge = nil
	end
end

-- Fonction pour créer l'overlay de révélation du rôle
local function CreateRoleRevealOverlay(role)
	local roleColor = ROLE_COLORS[role]
	local roleText = ROLE_TEXTS[role]
	
	if not roleColor or not roleText then
		warn("[RoleDisplay] Rôle inconnu reçu:", role)
		return
	end
	
	-- Création du ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoleRevealUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = playerGui
	
	-- Frame plein écran semi-transparente
	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.Name = "Background"
	backgroundFrame.Size = UDim2.new(1, 0, 1, 0)
	backgroundFrame.Position = UDim2.new(0, 0, 0, 0)
	backgroundFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backgroundFrame.BackgroundTransparency = 0.3
	backgroundFrame.BorderSizePixel = 0
	backgroundFrame.Parent = screenGui
	
	-- Container central pour le texte
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(0, 600, 0, 200)
	contentFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
	contentFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = backgroundFrame
	
	-- Titre principal (rôle)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 60)
	titleLabel.Position = UDim2.new(0, 0, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = roleText.title
	titleLabel.TextColor3 = roleColor
	titleLabel.TextSize = 42
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextWrapped = true
	titleLabel.Parent = contentFrame
	
	-- Sous-titre (description)
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "Subtitle"
	subtitleLabel.Size = UDim2.new(1, -40, 0, 80)
	subtitleLabel.Position = UDim2.new(0, 20, 0, 100)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = roleText.subtitle
	subtitleLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	subtitleLabel.TextSize = 22
	subtitleLabel.Font = Enum.Font.Gotham
	subtitleLabel.TextWrapped = true
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
	subtitleLabel.Parent = contentFrame
	
	return screenGui
end

-- Fonction pour créer le badge permanent
local function CreateRoleBadge(role)
	local roleColor = ROLE_COLORS[role]
	local badgeText = role == "Traitor" and "TRAÎTRE" or "VILLAGEOIS"
	
	-- ScreenGui pour le badge
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "RoleBadgeUI"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 50
	screenGui.Parent = playerGui
	
	-- Frame du badge
	local badgeFrame = Instance.new("Frame")
	badgeFrame.Name = "Badge"
	badgeFrame.Size = UDim2.new(0, 140, 0, 40)
	badgeFrame.Position = UDim2.new(1, -150, 0, 10)
	badgeFrame.BackgroundColor3 = roleColor
	badgeFrame.BorderSizePixel = 0
	badgeFrame.Parent = screenGui
	
	-- Coins arrondis
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = badgeFrame
	
	-- Texte du badge
	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Name = "Label"
	badgeLabel.Size = UDim2.new(1, -10, 1, -10)
	badgeLabel.Position = UDim2.new(0, 5, 0, 5)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Text = badgeText
	badgeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	badgeLabel.TextSize = 18
	badgeLabel.Font = Enum.Font.GothamBold
	badgeLabel.Parent = badgeFrame
	
	return screenGui
end

-- Fonction pour animer le fondu de sortie
local function FadeOutOverlay(screenGui)
	local backgroundFrame = screenGui:FindFirstChild("Background")
	if not backgroundFrame then return end
	
	-- Récupération de tous les éléments à animer
	local elementsToFade = {}
	
	-- Background
	table.insert(elementsToFade, {
		instance = backgroundFrame,
		property = "BackgroundTransparency",
		endValue = 1
	})
	
	-- Textes
	for _, descendant in ipairs(backgroundFrame:GetDescendants()) do
		if descendant:IsA("TextLabel") then
			table.insert(elementsToFade, {
				instance = descendant,
				property = "TextTransparency",
				endValue = 1
			})
		end
	end
	
	-- Création des tweens
	local tweenInfo = TweenInfo.new(
		FADE_DURATION,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	
	local tweens = {}
	for _, data in ipairs(elementsToFade) do
		local tween = TweenService:Create(
			data.instance,
			tweenInfo,
			{[data.property] = data.endValue}
		)
		table.insert(tweens, tween)
		tween:Play()
	end
	
	-- Attendre la fin de l'animation puis détruire
	task.wait(FADE_DURATION)
	screenGui:Destroy()
end

-- Fonction principale de gestion de l'affichage du rôle
local function OnRoleAssigned(role)
	-- Nettoyage des UI précédentes
	CleanupExistingUI()
	
	-- Mise à jour du rôle actuel
	currentRole = role
	
	-- Création de l'overlay de révélation
	currentRoleRevealUI = CreateRoleRevealOverlay(role)
	
	if not currentRoleRevealUI then
		warn("[RoleDisplay] Impossible de créer l'overlay pour le rôle:", role)
		return
	end
	
	-- Création du badge permanent (invisible tant que l'overlay est visible)
	currentRoleBadge = CreateRoleBadge(role)
	if currentRoleBadge then
		currentRoleBadge.Enabled = false
	end
	
	-- Programmation de la disparition de l'overlay
	task.spawn(function()
		task.wait(OVERLAY_DURATION)
		
		-- Animation de fondu
		if currentRoleRevealUI and currentRoleRevealUI.Parent then
			FadeOutOverlay(currentRoleRevealUI)
			currentRoleRevealUI = nil
		end
		
		-- Affichage du badge permanent
		if currentRoleBadge and currentRoleBadge.Parent then
			currentRoleBadge.Enabled = true
		end
	end)
	
	print("[RoleDisplay] Rôle assigné:", role)
end

-- Connexion à l'événement d'assignation de rôle
AssignRoleEvent.OnClientEvent:Connect(OnRoleAssigned)

-- Nettoyage à la déconnexion du joueur (optionnel mais propre)
player.AncestryChanged:Connect(function()
	if not player:IsDescendantOf(game) then
		CleanupExistingUI()
	end
end)

print("[RoleDisplay] Client initialisé et en attente du rôle...")