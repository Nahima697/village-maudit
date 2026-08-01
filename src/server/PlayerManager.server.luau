# PlayerManager.server.luau

Voici un système complet de gestion de survie pour Roblox :


--!strict
-- PlayerManager.server.luau
-- Gère l'état de santé et de survie des joueurs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

-- ============================
-- CONFIGURATION
-- ============================

local Config = {
	-- Valeurs initiales
	InitialHealth = 100,
	InitialMentalHealth = 100,
	InitialStamina = 100,
	InitialHunger = 100,
	InitialThirst = 100,
	
	-- Taux de dégradation (par seconde)
	HungerDecayRate = 0.15,
	ThirstDecayRate = 0.2,
	StaminaRegenRate = 2,
	
	-- Paramètres nocturnes
	NightTerrورMultiplier = 3,
	NightStartHour = 18,
	NightEndHour = 6,
	TerrорDecayRateNight = 0.5,
	TerrورDecayRateDay = -0.3, -- Régénération le jour
	
	-- Seuils critiques
	CriticalThreshold = 20,
	DeathThreshold = 0,
	
	-- Effets des stats basses
	LowHungerDamageRate = 2,
	LowThirstDamageRate = 3,
	HighTerrorDamageRate = 1,
	
	-- Intervalle de mise à jour
	UpdateInterval = 1,
}

-- ============================
-- CLASSES & MODULES
-- ============================

local PlayerData = {}
PlayerData.__index = PlayerData

function PlayerData.new(player: Player)
	local self = setmetatable({}, PlayerData)
	
	self.Player = player
	self.IsAlive = true
	self.LastUpdateTime = tick()
	
	return self
end

function PlayerData:InitializeAttributes()
	local player = self.Player
	
	-- Attributs de base
	player:SetAttribute("Health", Config.InitialHealth)
	player:SetAttribute("MaxHealth", Config.InitialHealth)
	player:SetAttribute("MentalHealth", Config.InitialMentalHealth)
	player:SetAttribute("Stamina", Config.InitialStamina)
	player:SetAttribute("Hunger", Config.InitialHunger)
	player:SetAttribute("Thirst", Config.InitialThirst)
	player:SetAttribute("Terror", 0)
	
	-- États
	player:SetAttribute("IsNight", false)
	player:SetAttribute("IsSprinting", false)
	player:SetAttribute("IsAlive", true)
	
	print(`[PlayerManager] Attributs initialisés pour {player.Name}`)
end

function PlayerData:GetAttribute(attributeName: string): number
	return self.Player:GetAttribute(attributeName) or 0
end

function PlayerData:SetAttribute(attributeName: string, value: number)
	self.Player:SetAttribute(attributeName, math.clamp(value, 0, 100))
end

function PlayerData:ModifyAttribute(attributeName: string, delta: number)
	local current = self:GetAttribute(attributeName)
	self:SetAttribute(attributeName, current + delta)
end

function PlayerData:IsNightTime(): boolean
	local clockTime = Lighting.ClockTime
	return clockTime >= Config.NightStartHour or clockTime < Config.NightEndHour
end

function PlayerData:UpdateSurvivalStats(deltaTime: number)
	if not self.IsAlive then return end
	
	-- Mise à jour de la faim
	self:ModifyAttribute("Hunger", -Config.HungerDecayRate * deltaTime)
	
	-- Mise à jour de la soif
	self:ModifyAttribute("Thirst", -Config.ThirstDecayRate * deltaTime)
	
	-- Régénération de l'endurance (si pas en sprint)
	if not self:GetAttribute("IsSprinting") then
		self:ModifyAttribute("Stamina", Config.StaminaRegenRate * deltaTime)
	end
	
	-- Gestion de la terreur nocturne
	local isNight = self:IsNightTime()
	self.Player:SetAttribute("IsNight", isNight)
	
	if isNight then
		local terrorRate = Config.TerrورDecayRateNight * deltaTime
		self:ModifyAttribute("Terror", terrorRate)
	else
		local terrorRecovery = Config.TerrورDecayRateDay * deltaTime
		self:ModifyAttribute("Terror", terrorRecovery)
	end
end

function PlayerData:ApplyCriticalEffects(deltaTime: number)
	if not self.IsAlive then return end
	
	local health = self:GetAttribute("Health")
	local hunger = self:GetAttribute("Hunger")
	local thirst = self:GetAttribute("Thirst")
	local terror = self:GetAttribute("Terror")
	
	-- Dégâts dus à la faim
	if hunger <= Config.CriticalThreshold then
		local damage = Config.LowHungerDamageRate * deltaTime
		self:ModifyAttribute("Health", -damage)
		self:UpdateMentalHealth(-damage * 0.5)
	end
	
	-- Dégâts dus à la soif
	if thirst <= Config.CriticalThreshold then
		local damage = Config.LowThirstDamageRate * deltaTime
		self:ModifyAttribute("Health", -damage)
		self:UpdateMentalHealth(-damage * 0.3)
	end
	
	-- Dégâts dus à la terreur élevée
	if terror >= 80 then
		local damage = Config.HighTerrorDamageRate * deltaTime
		self:UpdateMentalHealth(-damage * 2)
		self:ModifyAttribute("Health", -damage * 0.5)
	end
	
	-- Vérification de la mort
	if health <= Config.DeathThreshold then
		self:HandleDeath()
	end
end

function PlayerData:UpdateMentalHealth(delta: number)
	local current = self:GetAttribute("MentalHealth")
	self:SetAttribute("MentalHealth", math.clamp(current + delta, 0, 100))
	
	-- Effets de la santé mentale basse
	if current <= Config.CriticalThreshold then
		self:ApplyMentalHealthEffects()
	end
end

function PlayerData:ApplyMentalHealthEffects()
	local character = self.Player.Character
	if not character then return end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		-- Réduire la vitesse de marche
		humanoid.WalkSpeed = math.max(10, 16 * (self:GetAttribute("MentalHealth") / 100))
	end
end

function PlayerData:HandleDeath()
	if not self.IsAlive then return end
	
	self.IsAlive = false
	self.Player:SetAttribute("IsAlive", false)
	
	print(`[PlayerManager] {self.Player.Name} est mort!`)
	
	local character = self.Player.Character
	if character then
		local humanoid = character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Health = 0
		end
	end
end

function PlayerData:Update()
	local currentTime = tick()
	local deltaTime = currentTime - self.LastUpdateTime
	self.LastUpdateTime = currentTime
	
	self:UpdateSurvivalStats(deltaTime)
	self:ApplyCriticalEffects(deltaTime)
	self:ApplyMentalHealthEffects()
end

-- ============================
-- GESTIONNAIRE PRINCIPAL
-- ============================

local PlayerManager = {}
PlayerManager.ActivePlayers = {}

function PlayerManager:OnPlayerAdded(player: Player)
	print(`[PlayerManager] Joueur connecté: {player.Name}`)
	
	-- Créer les données du joueur
	local playerData = PlayerData.new(player)
	playerData:InitializeAttributes()
	
	self.ActivePlayers[player.UserId] = playerData
	
	-- Attendre que le personnage soit chargé
	player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(player, character)
	end)
	
	if player.Character then
		self:OnCharacterAdded(player, player.Character)
	end
end

function PlayerManager:OnCharacterAdded(player: Player, character: Model)
	print(`[PlayerManager] Personnage chargé pour {player.Name}`)
	
	local playerData = self.ActivePlayers[player.UserId]
	if not playerData then return end
	
	-- Réinitialiser l'état vivant
	playerData.IsAlive = true
	player:SetAttribute("IsAlive", true)
	
	-- Synchroniser la santé avec l'attribut
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 then
			playerData:HandleDeath()
		else
			player:SetAttribute("Health", health)
		end
	end)
end

function PlayerManager:OnPlayerRemoving(player: Player)
	print(`[PlayerManager] Joueur déconnecté: {player.Name}`)
	self.ActivePlayers[player.UserId] = nil
end

function PlayerManager:UpdateAllPlayers()
	for _, playerData in pairs(self.ActivePlayers) do
		playerData:Update()
	end
end

function PlayerManager:Initialize()
	print("[PlayerManager] Initialisation du système de survie...")
	
	-- Connexion des événements
	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)
	
	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)
	
	-- Gérer les joueurs déjà connectés
	for _, player in ipairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end
	
	-- Boucle de mise à jour
	task.spawn(function()
		while true do
			self:UpdateAllPlayers()
			task.wait(Config.UpdateInterval)
		end
	end)
	
	print("[PlayerManager] Système de survie opérationnel!")
end

-- ============================
-- API PUBLIQUE
-- ============================

function PlayerManager:GetPlayerData(player: Player)
	return self.ActivePlayers[player.UserId]
end

function PlayerManager:HealPlayer(player: Player, amount: number)
	local playerData = self:GetPlayerData(player)
	if playerData then
		playerData:ModifyAttribute("Health", amount)
	end
end

function PlayerManager:FeedPlayer(player: Player, hungerAmount: number, thirstAmount: number)
	local playerData = self:GetPlayerData(player)
	if playerData then
		playerData:ModifyAttribute("Hunger", hungerAmount or 0)
		playerData:ModifyAttribute("Thirst", thirstAmount or 0)
	end
end

function PlayerManager:ReduceTerror(player: Player, amount: number)
	local playerData = self:GetPlayerData(player)
	if playerData then
		playerData:ModifyAttribute("Terror", -amount)
	end
end

-- ============================
-- DÉMARRAGE
-- ============================

PlayerManager:Initialize()

return PlayerManager


## 🎮 Fonctionnalités implémentées

### ✅ **Système de Survie Complet**
- **Faim & Soif** : Décroissance automatique
- **Endurance** : Régénération automatique
- **Santé Mentale** : Affectée par les stats critiques
- **Terreur Nocturne** : Augmente la nuit, diminue le jour

### ✅ **Effets Critiques**
- Dégâts si faim/soif < 20
- Terreur élevée affecte santé mentale et physique
- Vitesse réduite selon santé mentale

### ✅ **Code Modulaire & Robuste**
- Architecture orientée objet
- Type checking avec `--!strict`
- Gestion propre de la mort
- API publique pour interactions externes

**Prêt à l'emploi sur Roblox Studio!** 🚀