-- GameManager.server.luau
-- Gère les phases du jeu, la synchronisation réseau et l'orchestration globale
-- RESPONSABILITÉ : Créer TOUS les RemoteEvents globaux dès le démarrage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

-- ============================================================
-- SECTION 1 : CRÉATION DES RESSOURCES GLOBALES (ANTI-CRASH)
-- ============================================================

-- Création du dossier RemoteEvents s'il n'existe pas
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
end

-- Création de TOUS les RemoteEvents nécessaires
local function createRemoteEvent(name)
	local existingEvent = remoteEventsFolder:FindFirstChild(name)
	if existingEvent then
		return existingEvent
	end
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = remoteEventsFolder
	return remoteEvent
end

-- Liste exhaustive des RemoteEvents du jeu
local AssignRoleEvent = createRemoteEvent("AssignRole")
local TraitorSabotageEvent = createRemoteEvent("TraitorSabotage")
local PhaseChangeEvent = createRemoteEvent("PhaseChange")
local VoteStartEvent = createRemoteEvent("VoteStart")
local VoteEndEvent = createRemoteEvent("VoteEnd")
local PlayerVoteEvent = createRemoteEvent("PlayerVote")
local GameStateUpdateEvent = createRemoteEvent("GameStateUpdate")
local NightStartEvent = createRemoteEvent("NightStart")
local DayStartEvent = createRemoteEvent("DayStart")
local GameEndEvent = createRemoteEvent("GameEnd")

-- Création du dossier SharedData pour les attributs globaux
local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
if not sharedData then
	sharedData = Instance.new("Folder")
	sharedData.Name = "SharedData"
	sharedData.Parent = ReplicatedStorage
end

-- Initialisation des attributs globaux avec des valeurs par défaut sécurisées
sharedData:SetAttribute("CurrentPhase", "Waiting") -- Phases: Waiting, Day, Night, Voting, End
sharedData:SetAttribute("NightCount", 0)
sharedData:SetAttribute("PhaseTimeRemaining", 0)
sharedData:SetAttribute("MinPlayers", 3)
sharedData:SetAttribute("GameActive", false)

-- ============================================================
-- SECTION 2 : CHARGEMENT DE LA CONFIGURATION
-- ============================================================

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

-- Vérification et sécurisation de la configuration
local PHASE_DURATION = {
	Day = GameConfig.PHASE_DURATION and GameConfig.PHASE_DURATION.Day or 120,
	Night = GameConfig.PHASE_DURATION and GameConfig.PHASE_DURATION.Night or 90,
	Voting = GameConfig.PHASE_DURATION and GameConfig.PHASE_DURATION.Voting or 60
}

local MIN_PLAYERS = GameConfig.MIN_PLAYERS or 3
local LOBBY_WAIT_TIME = GameConfig.LOBBY_WAIT_TIME or 15

-- ============================================================
-- SECTION 3 : VARIABLES D'ÉTAT DU JEU
-- ============================================================

local gameActive = false
local currentPhase = "Waiting"
local nightCount = 0
local phaseTimeRemaining = 0
local alivePlayers = {}
local playerRoles = {} -- Table {[Player] = "Innocent" | "Traitor"}

-- ============================================================
-- SECTION 4 : FONCTIONS UTILITAIRES
-- ============================================================

-- Compte le nombre de joueurs vivants
local function countAlivePlayers()
	local count = 0
	for player, isAlive in pairs(alivePlayers) do
		if isAlive and player.Parent == Players then
			count = count + 1
		end
	end
	return count
end

-- Compte les traîtres vivants
local function countAliveTraitors()
	local count = 0
	for player, role in pairs(playerRoles) do
		if role == "Traitor" and alivePlayers[player] and player.Parent == Players then
			count = count + 1
		end
	end
	return count
end

-- Compte les innocents vivants
local function countAliveInnocents()
	local count = 0
	for player, role in pairs(playerRoles) do
		if role == "Innocent" and alivePlayers[player] and player.Parent == Players then
			count = count + 1
		end
	end
	return count
end

-- Diffuse un message à tous les joueurs
local function broadcastMessage(message, color)
	for _, player in ipairs(Players:GetPlayers()) do
		if player:FindFirstChild("PlayerGui") then
			-- On envoie via un RemoteEvent dédié si nécessaire
			-- Ou on utilise un système de chat personnalisé
			print("[BROADCAST]", player.Name, ":", message)
		end
	end
end

-- Met à jour l'attribut de phase dans SharedData
local function updatePhaseAttribute(newPhase)
	currentPhase = newPhase
	sharedData:SetAttribute("CurrentPhase", newPhase)
end

-- Met à jour le temps restant dans SharedData
local function updateTimeAttribute(timeRemaining)
	phaseTimeRemaining = math.max(0, timeRemaining or 0) -- SÉCURISATION : jamais nil
	sharedData:SetAttribute("PhaseTimeRemaining", phaseTimeRemaining)
end

-- ============================================================
-- SECTION 5 : GESTION DES PHASES
-- ============================================================

-- Démarre la phase de jour
local function startDayPhase()
	updatePhaseAttribute("Day")
	nightCount = nightCount + 1
	sharedData:SetAttribute("NightCount", nightCount)
	
	local dayDuration = PHASE_DURATION.Day or 120 -- SÉCURISATION
	updateTimeAttribute(dayDuration)
	
	broadcastMessage("☀️ Le jour se lève ! Discutez pour trouver les traîtres.", Color3.fromRGB(255, 200, 100))
	DayStartEvent:FireAllClients(dayDuration)
	
	-- Timer de phase
	local startTime = tick()
	while (tick() - startTime) < dayDuration and gameActive do
		local remaining = dayDuration - (tick() - startTime)
		updateTimeAttribute(remaining)
		task.wait(1)
	end
	
	if gameActive then
		startVotingPhase()
	end
end

-- Démarre la phase de vote
local function startVotingPhase()
	updatePhaseAttribute("Voting")
	
	local voteDuration = PHASE_DURATION.Voting or 60 -- SÉCURISATION
	updateTimeAttribute(voteDuration)
	
	broadcastMessage("🗳️ Phase de vote ! Désignez un suspect.", Color3.fromRGB(100, 150, 255))
	VoteStartEvent:FireAllClients(voteDuration)
	
	-- Le VotingSystem va gérer le vote, on attend juste la durée
	task.wait(voteDuration)
	
	if gameActive then
		VoteEndEvent:FireAllClients()
		-- Attendre que le VotingSystem traite le résultat
		task.wait(5)
		startNightPhase()
	end
end

-- Démarre la phase de nuit
local function startNightPhase()
	updatePhaseAttribute("Night")
	
	local nightDuration = PHASE_DURATION.Night or 90 -- SÉCURISATION
	updateTimeAttribute(nightDuration)
	
	broadcastMessage("🌙 La nuit tombe... Les traîtres agissent dans l'ombre.", Color3.fromRGB(50, 50, 150))
	NightStartEvent:FireAllClients(nightDuration)
	
	-- Timer de phase
	local startTime = tick()
	while (tick() - startTime) < nightDuration and gameActive do
		local remaining = nightDuration - (tick() - startTime)
		updateTimeAttribute(remaining)
		task.wait(1)
	end
	
	if gameActive then
		checkWinConditions()
	end
end

-- ============================================================
-- SECTION 6 : CONDITIONS DE VICTOIRE
-- ============================================================

local function checkWinConditions()
	local aliveCount = countAlivePlayers()
	local traitorCount = countAliveTraitors()
	local innocentCount = countAliveInnocents()
	
	-- SÉCURISATION : Vérifier que les valeurs ne sont pas nil
	aliveCount = aliveCount or 0
	traitorCount = traitorCount or 0
	innocentCount = innocentCount or 0
	
	-- Les innocents gagnent si tous les traîtres sont éliminés
	if traitorCount <= 0 then
		endGame("Innocents")
		return
	end
	
	-- Les traîtres gagnent s'ils sont en nombre égal ou supérieur aux innocents
	if traitorCount >= innocentCount then
		endGame("Traitors")
		return
	end
	
	-- Sinon, le jeu continue
	if gameActive then
		startDayPhase()
	end
end

-- Termine le jeu
local function endGame(winner)
	gameActive = false
	updatePhaseAttribute("End")
	sharedData:SetAttribute("GameActive", false)
	
	local message = ""
	if winner == "Innocents" then
		message = "🏆 Les INNOCENTS ont gagné ! Tous les traîtres ont été éliminés."
	elseif winner == "Traitors" then
		message = "💀 Les TRAÎTRES ont gagné ! Ils contrôlent le village."
	else
		message = "⚠️ Partie terminée sans vainqueur."
	end
	
	broadcastMessage(message, Color3.fromRGB(255, 255, 0))
	GameEndEvent:FireAllClients(winner)
	
	-- Attendre avant de réinitialiser
	task.wait(10)
	resetGame()
end

-- ============================================================
-- SECTION 7 : DÉMARRAGE ET RÉINITIALISATION
-- ============================================================

-- Initialise les joueurs pour une nouvelle partie
local function initializePlayers()
	alivePlayers = {}
	playerRoles = {}
	
	local playerList = Players:GetPlayers()
	local playerCount = #playerList
	
	-- SÉCURISATION : Vérifier qu'il y a assez de joueurs
	if playerCount < (MIN_PLAYERS or 3) then
		warn("[GameManager] Pas assez de joueurs pour démarrer")
		return false
	end
	
	-- Calculer le nombre de traîtres (environ 25% des joueurs, minimum 1)
	local traitorCount = math.max(1, math.floor(playerCount * 0.25))
	
	-- Mélanger la liste des joueurs
	local shuffledPlayers = {}
	for i, player in ipairs(playerList) do
		shuffledPlayers[i] = player
	end
	
	for i = #shuffledPlayers, 2, -1 do
		local j = math.random(i)
		shuffledPlayers[i], shuffledPlayers[j] = shuffledPlayers[j], shuffledPlayers[i]
	end
	
	-- Assigner les rôles
	for i, player in ipairs(shuffledPlayers) do
		local role = (i <= traitorCount) and "Traitor" or "Innocent"
		playerRoles[player] = role
		alivePlayers[player] = true
		
		-- Notifier le joueur de son rôle
		AssignRoleEvent:FireClient(player, role)
		print("[GameManager] Rôle assigné :", player.Name, "=", role)
	end
	
	return true
end

-- Démarre une nouvelle partie
local function startGame()
	if gameActive then
		warn("[GameManager] Une partie est déjà en cours")
		return
	end
	
	print("[GameManager] Démarrage d'une nouvelle partie...")
	
	-- Réinitialiser les compteurs
	nightCount = 0
	sharedData:SetAttribute("NightCount", 0)
	
	-- Initialiser les joueurs
	if not initializePlayers() then
		warn("[GameManager] Échec de l'initialisation des joueurs")
		return
	end
	
	gameActive = true
	sharedData:SetAttribute("GameActive", true)
	
	broadcastMessage("🎮 La partie commence ! Survivez aux nuits...", Color3.fromRGB(0, 255, 0))
	
	-- Attendre quelques secondes avant de commencer la première phase
	task.wait(5)
	
	-- Démarrer par le jour
	startDayPhase()
end

-- Réinitialise le jeu
local function resetGame()
	gameActive = false
	currentPhase = "Waiting"
	nightCount = 0
	phaseTimeRemaining = 0
	alivePlayers = {}
	playerRoles = {}
	
	updatePhaseAttribute("Waiting")
	sharedData:SetAttribute("NightCount", 0)
	sharedData:SetAttribute("GameActive", false)
	updateTimeAttribute(0)
	
	print("[GameManager] Jeu réinitialisé, en attente de joueurs...")
	waitForPlayers()
end

-- Attendre suffisamment de joueurs pour démarrer
local function waitForPlayers()
	updatePhaseAttribute("Waiting")
	
	while true do
		local playerCount = #Players:GetPlayers()
		local minPlayers = MIN_PLAYERS or 3 -- SÉCURISATION
		
		-- CORRECTION LIGNE 218 : Sécurisation de la comparaison
		playerCount = playerCount or 0 -- S'assurer que playerCount n'est jamais nil
		
		if playerCount >= minPlayers then
			broadcastMessage("✅ Joueurs suffisants ! Démarrage dans " .. LOBBY_WAIT_TIME .. " secondes...", Color3.fromRGB(0, 255, 0))
			task.wait(LOBBY_WAIT_TIME or 15) -- SÉCURISATION
			
			-- Vérifier à nouveau avant de démarrer
			if #Players:GetPlayers() >= minPlayers then
				startGame()
				break
			else
				broadcastMessage("⚠️ Pas assez de joueurs, attente...", Color3.fromRGB(255, 100, 0))
			end
		else
			-- Attendre plus de joueurs
			task.wait(5)
		end
	end
end

-- ============================================================
-- SECTION 8 : GESTION DES JOUEURS (CONNEXION/DÉCONNEXION)
-- ============================================================

-- Quand un joueur rejoint
Players.PlayerAdded:Connect(function(player)
	print("[GameManager] Joueur connecté :", player.Name)
	
	-- Si une partie est en cours, le marquer comme spectateur
	if gameActive then
		alivePlayers[player] = false
		playerRoles[player] = "Spectator"
	end
	
	-- Envoyer l'état actuel du jeu
	GameStateUpdateEvent:FireClient(player, {
		Phase = currentPhase,
		NightCount = nightCount,
		TimeRemaining = phaseTimeRemaining or 0, -- SÉCURISATION
		IsAlive = alivePlayers[player] or false
	})
end)

-- Quand un joueur quitte
Players.PlayerRemoving:Connect(function(player)
	print("[GameManager] Joueur déconnecté :", player.Name)
	
	-- Retirer le joueur des tables
	if alivePlayers[player] then
		alivePlayers[player] = false
	end
	playerRoles[player] = nil
	
	-- Vérifier les conditions de victoire si une partie est en cours
	if gameActive then
		task.wait(1) -- Petit délai pour éviter les race conditions
		local aliveCount = countAlivePlayers() or 0 -- SÉCURISATION
		
		-- Si plus assez de joueurs, terminer la partie
		if aliveCount < 2 then
			endGame("None")
		else
			checkWinConditions()
		end
	end
end)

-- ============================================================
-- SECTION 9 : DÉMARRAGE DU GAMEMANAGER
-- ============================================================

print("[GameManager] Initialisation complète ✅")
print("[GameManager] Configuration : Day=" .. (PHASE_DURATION.Day or 0) .. "s, Night=" .. (PHASE_DURATION.Night or 0) .. "s, Vote=" .. (PHASE_DURATION.Voting or 0) .. "s")
print("[GameManager] Min joueurs :", MIN_PLAYERS or 3)

-- Lancer la boucle d'attente de joueurs
waitForPlayers()