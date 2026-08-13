-- GameManager.server.luau
-- Gère le cycle de jeu (Lobby → Jour → Nuit → Vote), la synchronisation globale et la création des ressources partagées

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) CRÉATION DES RESSOURCES GLOBALES (dossiers + RemoteEvents)
-- ═══════════════════════════════════════════════════════════════════════════
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

local function getOrCreateRemote(name: string): RemoteEvent
	local existing = remoteEventsFolder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local newRemote = Instance.new("RemoteEvent")
	newRemote.Name = name
	newRemote.Parent = remoteEventsFolder
	return newRemote
end

-- Événements globaux
local AssignRoleEvent = getOrCreateRemote("AssignRole")
local PhaseChangeEvent = getOrCreateRemote("PhaseChange")
local TraitorSabotageEvent = getOrCreateRemote("TraitorSabotage")

-- SharedData (stockage des attributs globaux)
local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
if not sharedData then
	sharedData = Instance.new("Folder")
	sharedData.Name = "SharedData"
	sharedData.Parent = ReplicatedStorage
end

-- Initialisation des attributs
sharedData:SetAttribute("CurrentPhase", "Lobby")
sharedData:SetAttribute("NightCounter", 0)
sharedData:SetAttribute("GameRunning", false)

-- ═══════════════════════════════════════════════════════════════════════════
-- 2) CHARGEMENT DE LA CONFIG
-- ═══════════════════════════════════════════════════════════════════════════
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

-- ═══════════════════════════════════════════════════════════════════════════
-- 3) VARIABLES D'ÉTAT
-- ═══════════════════════════════════════════════════════════════════════════
local currentPhase = "Lobby"
local nightCounter = 0
local gameRunning = false

-- ═══════════════════════════════════════════════════════════════════════════
-- 4) FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

-- Met à jour la phase et synchronise l'attribut dans SharedData
local function setPhase(newPhase: string)
	currentPhase = newPhase
	sharedData:SetAttribute("CurrentPhase", newPhase)
	PhaseChangeEvent:FireAllClients(newPhase)
	print("[GameManager] Phase changée : " .. newPhase)
end

-- Compte les joueurs vivants
local function countAlivePlayers(): number
	local count = 0
	for _, player in pairs(Players:GetPlayers()) do
		local alive = player:GetAttribute("Alive")
		if alive == nil or alive == true then
			count = count + 1
		end
	end
	return count
end

-- Vérifie si le jeu doit se terminer (victoire villageois ou traîtres)
local function checkWinCondition(): string?
	local aliveVillagers = 0
	local aliveTraitors = 0
	
	for _, player in pairs(Players:GetPlayers()) do
		local alive = player:GetAttribute("Alive")
		local role = player:GetAttribute("Role")
		if (alive == nil or alive == true) and role then
			if role == "Traitor" then
				aliveTraitors += 1
			else
				aliveVillagers += 1
			end
		end
	end
	
	if aliveTraitors == 0 then
		return "Villagers"
	elseif aliveTraitors >= aliveVillagers then
		return "Traitors"
	end
	
	return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 5) PHASES DU JEU
-- ═══════════════════════════════════════════════════════════════════════════

local function runDayPhase()
	setPhase("Day")
	task.wait(GameConfig.PHASE_DURATION.Day)
end

local function runNightPhase()
	nightCounter += 1
	sharedData:SetAttribute("NightCounter", nightCounter)
	setPhase("Night")
	print("[GameManager] Nuit n°" .. nightCounter)
	task.wait(GameConfig.PHASE_DURATION.Night)
end

local function runVotingPhase()
	setPhase("Voting")
	task.wait(GameConfig.PHASE_DURATION.Voting)
	-- Le VotingSystem.server.luau gère l'exécution du joueur éliminé
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 6) BOUCLE PRINCIPALE
-- ═══════════════════════════════════════════════════════════════════════════

local function startGame()
	gameRunning = true
	sharedData:SetAttribute("GameRunning", true)
	nightCounter = 0
	
	print("[GameManager] Démarrage du jeu avec " .. #Players:GetPlayers() .. " joueurs")
	
	-- Attribution des rôles (signal pour RoleManager)
	sharedData:SetAttribute("AssignRoles", true)
	task.wait(2) -- Laisse le temps au RoleManager de traiter
	
	while gameRunning do
		runDayPhase()
		
		local winner = checkWinCondition()
		if winner then
			print("[GameManager] Victoire des " .. winner)
			setPhase("GameOver")
			break
		end
		
		runNightPhase()
		
		winner = checkWinCondition()
		if winner then
			print("[GameManager] Victoire des " .. winner)
			setPhase("GameOver")
			break
		end
		
		runVotingPhase()
		
		winner = checkWinCondition()
		if winner then
			print("[GameManager] Victoire des " .. winner)
			setPhase("GameOver")
			break
		end
	end
	
	-- Fin de partie
	gameRunning = false
	sharedData:SetAttribute("GameRunning", false)
	task.wait(10)
	
	-- Retour au lobby
	setPhase("Lobby")
	for _, player in pairs(Players:GetPlayers()) do
		player:SetAttribute("Alive", true)
		player:SetAttribute("Role", nil)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 7) LOBBY (attente de joueurs)
-- ═══════════════════════════════════════════════════════════════════════════

local function lobbyWait()
	while true do
		local playerCount = #Players:GetPlayers()
		if playerCount >= GameConfig.MIN_PLAYERS then
			print("[GameManager] Assez de joueurs (" .. playerCount .. "), lancement dans " .. GameConfig.LOBBY_WAIT_TIME .. "s")
			task.wait(GameConfig.LOBBY_WAIT_TIME)
			
			-- Re-vérification après le délai
			if #Players:GetPlayers() >= GameConfig.MIN_PLAYERS then
				startGame()
			else
				print("[GameManager] Pas assez de joueurs après le délai, retour en attente")
			end
		else
			print("[GameManager] En attente de joueurs (" .. playerCount .. "/" .. GameConfig.MIN_PLAYERS .. ")")
			task.wait(5)
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- 8) DÉMARRAGE
-- ═══════════════════════════════════════════════════════════════════════════

print("[GameManager] Initialisation terminée, en attente de joueurs...")
lobbyWait()