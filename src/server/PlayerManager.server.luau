--!strict
-- PlayerManager.server.luau
-- Gère l'état de santé et de survie des joueurs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ============================
-- CONFIGURATION
-- ============================

local Config = {
	InitialHealth = 100,
	InitialMentalHealth = 100,
	InitialStamina = 100,
	InitialHunger = 100,
	InitialThirst = 100,

	HungerDecayRate = 0.15,
	ThirstDecayRate = 0.2,
	StaminaRegenRate = 2,

	NightTerrorMultiplier = 3,
	TerrorDecayRateNight = 0.5,
	TerrorDecayRateDay = -0.3, -- Régénération le jour

	CriticalThreshold = 20,
	DeathThreshold = 0,

	LowHungerDamageRate = 2,
	LowThirstDamageRate = 3,
	HighTerrorDamageRate = 1,

	UpdateInterval = 1,
}

-- SharedData contient l'attribut CurrentPhase écrit par GameManager.server.luau
local SharedData = ReplicatedStorage:FindFirstChild("SharedData")
if not SharedData then
	SharedData = Instance.new("Folder")
	SharedData.Name = "SharedData"
	SharedData.Parent = ReplicatedStorage
end

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

	player:SetAttribute("Health", Config.InitialHealth)
	player:SetAttribute("MaxHealth", Config.InitialHealth)
	player:SetAttribute("MentalHealth", Config.InitialMentalHealth)
	player:SetAttribute("Stamina", Config.InitialStamina)
	player:SetAttribute("Hunger", Config.InitialHunger)
	player:SetAttribute("Thirst", Config.InitialThirst)
	player:SetAttribute("Terror", 0)

	player:SetAttribute("IsSprinting", false)

	-- IsAlive est géré en priorité par RoleManager (assignation de rôles / vote).
	-- On ne l'initialise ici que s'il n'a jamais été défini, pour ne pas
	-- écraser un état de "mort" déjà posé par RoleManager/VotingSystem.
	if player:GetAttribute("IsAlive") == nil then
		player:SetAttribute("IsAlive", true)
	end

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

-- Nuit détectée via la phase de jeu officielle (GameManager), pas via
-- Lighting.ClockTime qui n'est pas garanti d'être synchronisé.
function PlayerData:IsNightTime(): boolean
	return SharedData:GetAttribute("CurrentPhase") == "NIGHT_PHASE"
end

function PlayerData:UpdateSurvivalStats(deltaTime: number)
	if not self.IsAlive then return end

	self:ModifyAttribute("Hunger", -Config.HungerDecayRate * deltaTime)
	self:ModifyAttribute("Thirst", -Config.ThirstDecayRate * deltaTime)

	if not self:GetAttribute("IsSprinting") then
		self:ModifyAttribute("Stamina", Config.StaminaRegenRate * deltaTime)
	end

	local isNight = self:IsNightTime()

	if isNight then
		local terrorRate = Config.TerrorDecayRateNight * deltaTime
		self:ModifyAttribute("Terror", terrorRate)
	else
		local terrorRecovery = Config.TerrorDecayRateDay * deltaTime
		self:ModifyAttribute("Terror", terrorRecovery)
	end
end

function PlayerData:ApplyCriticalEffects(deltaTime: number)
	if not self.IsAlive then return end

	local health = self:GetAttribute("Health")
	local hunger = self:GetAttribute("Hunger")
	local thirst = self:GetAttribute("Thirst")
	local terror = self:GetAttribute("Terror")

	if hunger <= Config.CriticalThreshold then
		local damage = Config.LowHungerDamageRate * deltaTime
		self:ModifyAttribute("Health", -damage)
		self:UpdateMentalHealth(-damage * 0.5)
	end

	if thirst <= Config.CriticalThreshold then
		local damage = Config.LowThirstDamageRate * deltaTime
		self:ModifyAttribute("Health", -damage)
		self:UpdateMentalHealth(-damage * 0.3)
	end

	if terror >= 80 then
		local damage = Config.HighTerrorDamageRate * deltaTime
		self:UpdateMentalHealth(-damage * 2)
		self:ModifyAttribute("Health", -damage * 0.5)
	end

	if health <= Config.DeathThreshold then
		self:HandleDeath()
	end
end

function PlayerData:UpdateMentalHealth(delta: number)
	local current = self:GetAttribute("MentalHealth")
	self:SetAttribute("MentalHealth", math.clamp(current + delta, 0, 100))

	if current <= Config.CriticalThreshold then
		self:ApplyMentalHealthEffects()
	end
end

function PlayerData:ApplyMentalHealthEffects()
	local character = self.Player.Character
	if not character then return end

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
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

	local playerData = PlayerData.new(player)
	playerData:InitializeAttributes()

	self.ActivePlayers[player.UserId] = playerData

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

	-- Ne réinitialise IsAlive à true que si le joueur n'a pas déjà été
	-- éliminé de la partie en cours (vote, sabotage, etc. géré par RoleManager).
	if player:GetAttribute("IsAlive") ~= false then
		playerData.IsAlive = true
		player:SetAttribute("IsAlive", true)
	else
		playerData.IsAlive = false
	end

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

	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			self:UpdateAllPlayers()
			task.wait(Config.UpdateInterval)
		end
	end)

	print("[PlayerManager] Système de survie opérationnel!")
end

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

PlayerManager:Initialize()
