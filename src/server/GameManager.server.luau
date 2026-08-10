-- GameManager.server.luau
-- Gère les phases du jeu, la synchronisation réseau et l'orchestration globale
-- RESPONSABILITÉ : Créer TOUS les RemoteEvents globaux dès le démarrage

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")

local function setDayLighting()
	Lighting.ClockTime = 12
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(150, 150, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
	Lighting.FogEnd = 100000
end

local function setNightLighting()
	Lighting.ClockTime = 21
	Lighting.Brightness = 3
	Lighting.Ambient = Color3.fromRGB(110, 110, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(110, 110, 150)
	Lighting.FogEnd = 2000
	Lighting.FogColor = Color3.fromRGB(60, 60, 90)
end

-- ============================================================
-- SECTION 1 : CRÉATION DES RESSOURCES GLOBALES (ANTI-CRASH)
-- ============================================================

-- Création du dossier RemoteEvents s'il n'existe pas
local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not remoteEventsFolder then
	remoteEventsFolder = Instance.new("Folder")
	remoteEventsFolder.Name = "RemoteEvents"
	remoteEventsFolder.Parent = ReplicatedStorage
	warn("[GameManager] Dossier RemoteEvents créé")
end

-- Création de TOUS les RemoteEvents nécessaires avec vérification stricte
local function createRemoteEvent(name)
	local existingEvent = remoteEventsFolder:FindFirstChild(name)
	if existingEvent and existingEvent:IsA("RemoteEvent") then
		print("[GameManager] RemoteEvent existant réutilisé :", name)
		return existingEvent
	end
	
	local remoteEvent = Instance.new("RemoteEvent")
	remoteEvent.Name = name
	remoteEvent.Parent = remoteEventsFolder
	print("[GameManager] RemoteEvent créé :", name)
	return remoteEvent
end

-- Liste exhaustive des RemoteEvents du jeu (AVEC VALIDATION)
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

-- 🔧 FIX #1 : Création du RemoteEvent manquant pour le système de craft
local CollectResourceEvent = createRemoteEvent("CollectResourceEvent")

-- VALIDATION CRITIQUE : Vérifier que tous les events sont créés
assert(AssignRoleEvent, "[CRASH PREVENTION] AssignRoleEvent est nil")
assert(DayStartEvent, "[CRASH PREVENTION] DayStartEvent est nil")
assert(NightStartEvent, "[CRASH PREVENTION] NightStartEvent est nil")
assert(VoteStartEvent, "[CRASH PREVENTION] VoteStartEvent est nil")
assert(VoteEndEvent, "[CRASH PREVENTION] VoteEndEvent est nil")
assert(GameEndEvent, "[CRASH PREVENTION] GameEndEvent est nil")
assert(GameStateUpdateEvent, "[CRASH PREVENTION] GameStateUpdateEvent est nil")
assert(CollectResourceEvent, "[CRASH PREVENTION] CollectResourceEvent est nil")

print("[GameManager] ✅ Tous les RemoteEvents validés (incluant CollectResourceEvent)")

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

-- 🔧 FIX #3 : Variable pour tracker si la première nuit est passée
local firstNightCompleted = false

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
			print("[BROADCAST]", player.Name, ":", message)
		end
	end
end

-- Met à jour l'attribut de phase dans SharedData
local function updatePhaseAttribute(newPhase)
	currentPhase = newPhase
	sharedData:SetAttribute("CurrentPhase", newPhase)
	PhaseChangeEvent:FireAllClients(newPhase)
end

-- Met à jour le temps restant dans SharedData
local function updateTimeAttribute(timeRemaining)
	phaseTimeRemaining = math.max(0, timeRemaining or 0)
	sharedData:SetAttribute("PhaseTimeRemaining", phaseTimeRemaining)
end

-- ============================================================
-- SECTION 5 : GESTION DES PHASES
-- ============================================================

-- Démarre la phase de jour
local startDayPhase, startVotingPhase, startNightPhase
function startDayPhase()
	setDayLighting()
	updatePhaseAttribute("DAY_PHASE")
	
	local dayDuration = PHASE_DURATION.Day or 120
	updateTimeAttribute(dayDuration)
	
	-- 🔧 FIX #3 : Message différent selon si c'est le premier jour
	if not firstNightCompleted then
		broadcastMessage("☀️ Premier jour ! Préparez-vous pour la nuit à venir...", Color3.fromRGB(255, 200, 100))
	else
		broadcastMessage("☀️ Le jour se lève ! Discutez pour trouver les traîtres.", Color3.fromRGB(255, 200, 100))
	end
	
	-- FIX CRITIQUE : Vérification avant appel
	if DayStartEvent then
		DayStartEvent:FireAllClients(dayDuration)
	else
		warn("[CRASH PREVENTED] DayStartEvent est nil à la ligne 172")
	end
	
	-- Timer de phase
	local startTime = tick()
	while (tick() - startTime) < dayDuration and gameActive do
		local remaining = dayDuration - (tick() - startTime)
		updateTimeAttribute(remaining)
		task.wait(1)
	end
	
	if gameActive then
		-- 🔧 FIX #3 : Ne lance le vote QUE si la première nuit est terminée
		if firstNightCompleted then
			startVotingPhase()
		else
			-- Passe directement à la nuit si c'est le premier jour
			startNightPhase()
		end
	end
end

-- Démarre la phase de vote
function startVotingPhase()
	updatePhaseAttribute("VOTE_PHASE")
	
	local voteDuration = PHASE_DURATION.Voting or 60
	updateTimeAttribute(voteDuration)
	
	broadcastMessage("🗳️ Phase de vote ! Désignez un suspect.", Color3.fromRGB(100, 150, 255))
	
	-- FIX CRITIQUE : Vérification avant appel
	if VoteStartEvent then
		VoteStartEvent:FireAllClients(voteDuration)
	else
		warn("[CRASH PREVENTED] VoteStartEvent est nil")
	end
	
	task.wait(voteDuration)
	
	if gameActive then
		if VoteEndEvent then
			VoteEndEvent:FireAllClients()
		end
		task.wait(5)
		startNightPhase()
	end
end

-- Démarre la phase de nuit
function startNightPhase()
	setNightLighting()
	updatePhaseAttribute("NIGHT_PHASE")
	
	nightCount = nightCount + 1
	sharedData:SetAttribute("NightCount", nightCount)
	
	local nightDuration = PHASE_DURATION.Night or 90
	updateTimeAttribute(nightDuration)
	
	-- 🔧 FIX #3 : Message différent pour la première nuit
	if not firstNightCompleted then
		broadcastMessage("🌙 Première nuit... Les traîtres découvrent leur pouvoir.", Color3.fromRGB(50, 50, 150))
	else
		broadcastMessage("🌙 La nuit tombe... Les traîtres agissent dans l'ombre.", Color3.fromRGB(50, 50, 150))
	end
	
	-- FIX CRITIQUE : Vérification avant appel
	if NightStartEvent then
		NightStartEvent:FireAllClients(nightDuration)
	else
		warn("[CRASH PREVENTED] NightStartEvent est nil")
	end
	
	-- Timer de phase
	local startTime = tick()
	while (tick() - startTime) < nightDuration and gameActive do
		local remaining = nightDuration - (tick() - startTime)
		updateTimeAttribute(remaining)
		task.wait(1)
	end
	
	-- 🔧 FIX #3 : Marquer la première nuit comme terminée
	if not firstNightCompleted then
		firstNightCompleted = true
		print("[GameManager] 🌙 Première nuit terminée, votes activés pour les prochains jours")
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
	
	aliveCount = aliveCount or 0
	traitorCount = traitorCount or 0
	innocentCount = innocentCount or 0
	
	if traitorCount <= 0 then
		endGame("Innocents")
		return
	end
	
	if traitorCount >= innocentCount then
		endGame("Traitors")
		return
	end
	
	if gameActive then
		startDayPhase()
	end
end

-- Termine le jeu
function endGame(winner)
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
	
	if GameEndEvent then
		GameEndEvent:FireAllClients(winner)
	end
	
	task.wait(10)
	resetGame()
end

-- ============================================================
-- SECTION 7 : DÉMARRAGE ET RÉINITIALISATION
-- ============================================================

local function initializePlayers()
	alivePlayers = {}
	playerRoles = {}
	
	local playerList = Players:GetPlayers()
	local playerCount = #playerList
	
	if playerCount < (MIN_PLAYERS or 3) then
		warn("[GameManager] Pas assez de joueurs pour démarrer")
		return false
	end
	
	local traitorCount = math.max(1, math.floor(playerCount * 0.25))
	
	local shuffledPlayers = {}
	for i, player in ipairs(playerList) do
		shuffledPlayers[i] = player
	end
	
	for i = #shuffledPlayers, 2, -1 do
		local j = math.random(i)
		shuffledPlayers[i], shuffledPlayers[j] = shuffledPlayers[j], shuffledPlayers[i]
	end
	
	for i, player in ipairs(shuffledPlayers) do
		local role = (i <= traitorCount) and "Traitor" or "Innocent"
		playerRoles[player] = role
		alivePlayers[player] = true
		player:SetAttribute("IsAlive", true)
		
		if AssignRoleEvent then
			AssignRoleEvent:FireClient(player, role)
		end
		print("[GameManager] Rôle assigné :", player.Name, "=", role)
	end
	
	return true
end

function startGame()
	if gameActive then
		warn("[GameManager] Une partie est déjà en cours")
		return
	end
	
	print("[GameManager] Démarrage d'une nouvelle partie...")
	
	nightCount = 0
	firstNightCompleted = false -- 🔧 FIX #3 : Reset du flag
	sharedData:SetAttribute("NightCount", 0)
	
	if not initializePlayers() then
		warn("[GameManager] Échec de l'initialisation des joueurs")
		return
	end
	
	gameActive = true
	sharedData:SetAttribute("GameActive", true)
	
	broadcastMessage("🎮 La partie commence ! Survivez aux nuits...", Color3.fromRGB(0, 255, 0))
	
	task.wait(5)
	
	-- 🔧 FIX #3 : Commencer par un JOUR (sans vote possible)
	startDayPhase()
end

function resetGame()
	gameActive = false
	currentPhase = "Waiting"
	nightCount = 0
	phaseTimeRemaining = 0
	alivePlayers = {}
	playerRoles = {}
	firstNightCompleted = false -- 🔧 FIX #3 : Reset du flag
	
	updatePhaseAttribute("Waiting")
	sharedData:SetAttribute("NightCount", 0)
	sharedData:SetAttribute("GameActive", false)
	updateTimeAttribute(0)
	
	print("[GameManager] Jeu réinitialisé, en attente de joueurs...")
	waitForPlayers()
end

function waitForPlayers()
	updatePhaseAttribute("Waiting")
	
	while true do
		local playerCount = #Players:GetPlayers()
		local minPlayers = MIN_PLAYERS or 3
		
		playerCount = playerCount or 0
		
		if playerCount >= minPlayers then
			broadcastMessage("✅ Joueurs suffisants ! Démarrage dans " .. LOBBY_WAIT_TIME .. " secondes...", Color3.fromRGB(0, 255, 0))
			task.wait(LOBBY_WAIT_TIME or 15)
			
			if #Players:GetPlayers() >= minPlayers then
				startGame()
				break
			else
				broadcastMessage("⚠️ Pas assez de joueurs, attente...", Color3.fromRGB(255, 100, 0))
			end
		else
			task.wait(5)
		end
	end
end

-- ============================================================
-- SECTION 8 : GESTION DES JOUEURS (CONNEXION/DÉCONNEXION)
-- ============================================================

Players.PlayerAdded:Connect(function(player)
	print("[GameManager] Joueur connecté :", player.Name)
	
	if gameActive then
		alivePlayers[player] = false
		playerRoles[player] = "Spectator"
	end
	
	if GameStateUpdateEvent then
		GameStateUpdateEvent:FireClient(player, {
			Phase = currentPhase,
			NightCount = nightCount,
			TimeRemaining = phaseTimeRemaining or 0,
			IsAlive = alivePlayers[player] or false
		})
	end
end)

Players.PlayerRemoving:Connect(function(player)
	print("[GameManager] Joueur déconnecté :", player.Name)
	
	if alivePlayers[player] then
		alivePlayers[player] = false
	end
	playerRoles[player] = nil
	
	if gameActive then
		task.wait(1)
		local aliveCount = countAlivePlayers() or 0
		
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
print("[GameManager] 🔧 Cycle de jeu : Jour → Nuit (1ère) → Jour → Vote → Nuit → Jour → Vote...")

waitForPlayers()