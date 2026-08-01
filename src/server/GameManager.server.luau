-- GameManager.server.luau
-- Script central gérant le cycle complet de la partie : phases, éclairage, conditions de victoire

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

-- Récupération de la configuration
local GameConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConfig"))

-- Constantes de phases
local PHASE_DAY = "DAY_PHASE"
local PHASE_VOTE = "VOTE_PHASE"
local PHASE_NIGHT = "NIGHT_PHASE"

-- Création ou récupération de SharedData
local SharedData = ReplicatedStorage:FindFirstChild("SharedData")
if not SharedData then
    SharedData = Instance.new("Folder")
    SharedData.Name = "SharedData"
    SharedData.Parent = ReplicatedStorage
end

-- Création du dossier RemoteEvents et des événements
local RemoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not RemoteEvents then
    RemoteEvents = Instance.new("Folder")
    RemoteEvents.Name = "RemoteEvents"
    RemoteEvents.Parent = ReplicatedStorage
end

local AssignRoleEvent = RemoteEvents:FindFirstChild("AssignRole")
if not AssignRoleEvent then
    AssignRoleEvent = Instance.new("RemoteEvent")
    AssignRoleEvent.Name = "AssignRole"
    AssignRoleEvent.Parent = RemoteEvents
end

local TraitorSabotageEvent = RemoteEvents:FindFirstChild("TraitorSabotage")
if not TraitorSabotageEvent then
    TraitorSabotageEvent = Instance.new("RemoteEvent")
    TraitorSabotageEvent.Name = "TraitorSabotage"
    TraitorSabotageEvent.Parent = RemoteEvents
end

-- Création des signaux de communication
local StartGameSignal = ReplicatedStorage:FindFirstChild("StartGameSignal")
if not StartGameSignal then
    StartGameSignal = Instance.new("BindableEvent")
    StartGameSignal.Name = "StartGameSignal"
    StartGameSignal.Parent = ReplicatedStorage
end

local RemovePlayerFromGame = ReplicatedStorage:FindFirstChild("RemovePlayerFromGame")
if not RemovePlayerFromGame then
    RemovePlayerFromGame = Instance.new("BindableEvent")
    RemovePlayerFromGame.Name = "RemovePlayerFromGame"
    RemovePlayerFromGame.Parent = ReplicatedStorage
end

-- État du jeu
local gameActive = false
local nightCount = 0

-- Paramètres d'éclairage (Avec le mouvement du soleil !)
local DAY_LIGHTING = {
    Brightness = 2,
    OutdoorAmbient = Color3.fromRGB(128, 128, 128),
    Ambient = Color3.fromRGB(180, 180, 180),
    FogEnd = 1000,
    FogColor = Color3.fromRGB(191, 191, 191),
    ClockTime = 14,
    ClockTime = 14
}

local NIGHT_LIGHTING = {
    Brightness = 0.5,
    OutdoorAmbient = Color3.fromRGB(25, 15, 40),
    Ambient = Color3.fromRGB(40, 30, 60),
    FogEnd = 300,
    FogColor = Color3.fromRGB(30, 20, 50),
    ClockTime = 0,
    ClockTime = 0
}

-- Fonction de transition d'éclairage
local function transitionLighting(targetSettings)
    local tweenInfo = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    
    local brightnessGoal = {Brightness = targetSettings.Brightness}
    local outdoorAmbientGoal = {OutdoorAmbient = targetSettings.OutdoorAmbient}
    local ambientGoal = {Ambient = targetSettings.Ambient}
    local fogEndGoal = {FogEnd = targetSettings.FogEnd}
    local fogColorGoal = {FogColor = targetSettings.FogColor}
    local clockTimeGoal = {ClockTime = targetSettings.ClockTime}
    local clockTimeGoal = {ClockTime = targetSettings.ClockTime}
    
    TweenService:Create(Lighting, tweenInfo, brightnessGoal):Play()
    TweenService:Create(Lighting, tweenInfo, outdoorAmbientGoal):Play()
    TweenService:Create(Lighting, tweenInfo, ambientGoal):Play()
    TweenService:Create(Lighting, tweenInfo, fogEndGoal):Play()
    TweenService:Create(Lighting, tweenInfo, fogColorGoal):Play()
    TweenService:Create(Lighting, tweenInfo, clockTimeGoal):Play()
end

-- Fonction de mise à jour de la phase
local function setCurrentPhase(phase)
    SharedData:SetAttribute("CurrentPhase", phase)
    
    local isNight = (phase == PHASE_NIGHT)
    workspace:SetAttribute("IsNight", isNight)
    
    if phase == PHASE_DAY or phase == PHASE_VOTE then
        transitionLighting(DAY_LIGHTING)
    elseif phase == PHASE_NIGHT then
        transitionLighting(NIGHT_LIGHTING)
    end
    
    print("[GameManager] Phase changée :", phase)
end

-- Fonction de comptage des joueurs vivants par rôle
local function countLivingPlayersByRole()
    local villagers = 0
    local traitors = 0
    
    for _, player in ipairs(Players:GetPlayers()) do
        local isAlive = player:GetAttribute("IsAlive")
        local role = player:GetAttribute("Role")
        
        if isAlive == true then
            if role == "Villager" then
                villagers = villagers + 1
            elseif role == "Traitor" then
                traitors = traitors + 1
            end
        end
    end
    
    return villagers, traitors
end

-- Fonction de vérification des conditions de victoire
local function checkVictoryConditions()
    local villagers, traitors = countLivingPlayersByRole()
    
    -- Victoire des villageois si tous les traîtres sont éliminés
    if traitors == 0 then
        SharedData:SetAttribute("GameResult", "Villagers")
        print("[GameManager] Victoire des Villageois ! Tous les traîtres sont éliminés.")
        return true
    end
    
    -- Victoire des traîtres si leur nombre >= nombre de villageois
    if traitors >= villagers then
        SharedData:SetAttribute("GameResult", "Traitors")
        print("[GameManager] Victoire des Traîtres ! Ils sont majoritaires.")
        return true
    end
    
    -- Victoire des villageois si nombre de nuits requis atteint
    if nightCount >= GameConfig.NIGHTS_TO_SURVIVE then
        SharedData:SetAttribute("GameResult", "Villagers")
        print("[GameManager] Victoire des Villageois ! Ils ont survécu", GameConfig.NIGHTS_TO_SURVIVE, "nuits.")
        return true
    end
    
    return false
end

-- Fonction de retrait d'un joueur de la partie
RemovePlayerFromGame.Event:Connect(function(player)
    if typeof(player) == "Instance" and player:IsA("Player") then
        player:SetAttribute("IsAlive", false)
        print("[GameManager] Joueur retiré de la partie :", player.Name)
    end
end)

-- Boucle de cycle de jeu
local function gameLoop()
    while gameActive do
        -- Phase JOUR
        setCurrentPhase(PHASE_DAY)
        task.wait(GameConfig.DAY_DURATION)
        
        if not gameActive then break end
        
        -- Phase VOTE
        setCurrentPhase(PHASE_VOTE)
        task.wait(GameConfig.VOTE_DURATION)
        
        if not gameActive then break end
        
        -- Phase NUIT
        nightCount = nightCount + 1
        SharedData:SetAttribute("NightCount", nightCount)
        setCurrentPhase(PHASE_NIGHT)
        print("[GameManager] Nuit", nightCount, "commence")
        task.wait(GameConfig.NIGHT_DURATION)
        
        if not gameActive then break end
        
        -- Vérification des conditions de victoire après chaque nuit
        if checkVictoryConditions() then
            gameActive = false
            print("[GameManager] Partie terminée.")
            break
        end
    end
end

-- Fonction de démarrage de partie
local function startGame()
    if gameActive then
        warn("[GameManager] Une partie est déjà en cours.")
        return
    end
    
    print("[GameManager] Démarrage de la partie...")
    
    -- Réinitialisation
    nightCount = 0
    SharedData:SetAttribute("NightCount", 0)
    SharedData:SetAttribute("GameResult", "")
    gameActive = true
    
    -- Signal au RoleManager pour assigner les rôles
    local success, err = pcall(function()
        StartGameSignal:Fire()
    end)
    
    if not success then
        warn("[GameManager] Erreur lors du signal StartGame :", err)
    end
    
    -- Attente courte pour laisser les rôles être assignés
    task.wait(2)
    
    -- Lancement de la boucle de jeu
    gameLoop()
end

-- Fonction de vérification du nombre minimum de joueurs
local function checkPlayerCount()
    local playerCount = #Players:GetPlayers()
    if playerCount >= GameConfig.MIN_PLAYERS and not gameActive then
        print("[GameManager] Nombre de joueurs suffisant (", playerCount, "/", GameConfig.MIN_PLAYERS, "). Démarrage dans 5 secondes...")
        task.wait(5)
        
        -- Vérification à nouveau au cas où des joueurs sont partis
        if #Players:GetPlayers() >= GameConfig.MIN_PLAYERS and not gameActive then
            startGame()
        else
            print("[GameManager] Pas assez de joueurs après le délai d'attente.")
        end
    end
end

-- Écoute des connexions/déconnexions de joueurs
Players.PlayerAdded:Connect(function()
    checkPlayerCount()
end)

Players.PlayerRemoving:Connect(function()
    -- Vérifier si la partie doit se terminer
    task.wait(1)
    if gameActive then
        local playerCount = #Players:GetPlayers()
        if playerCount < GameConfig.MIN_PLAYERS then
            print("[GameManager] Pas assez de joueurs, arrêt de la partie.")
            gameActive = false
        end
    end
end)

-- Vérification initiale au chargement du script
task.wait(1)
checkPlayerCount()
