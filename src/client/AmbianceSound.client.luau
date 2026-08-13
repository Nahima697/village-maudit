--[[
	AmbianceSound.client.luau
	Gère l'ambiance sonore jour/nuit en fonction de la phase de jeu.
	Écoute SharedData:GetAttribute("CurrentPhase") et fait des fondus entre les deux pistes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

-- Configuration
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SOUNDS = GameConfig.SOUNDS or {}

-- Références partagées
local SharedData = ReplicatedStorage:WaitForChild("SharedData")

-- Création des Sound
local daySound = Instance.new("Sound")
daySound.Name = "DayAmbient"
daySound.SoundId = SOUNDS.DayAmbient or ""
daySound.Looped = true
daySound.Volume = 0
daySound.Parent = SoundService

local nightSound = Instance.new("Sound")
nightSound.Name = "NightAmbient"
nightSound.SoundId = SOUNDS.NightAmbient or ""
nightSound.Looped = true
nightSound.Volume = 0
nightSound.Parent = SoundService

-- Paramètres de fondu
local FADE_DURATION = 2
local TARGET_VOLUME = 0.5
local tweenInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

-- Variables d'état pour éviter les appels redondants
local currentAmbiance = nil -- "DAY" | "NIGHT" | nil

--[[
	Fonction de transition d'ambiance
	@param soundToPlay Sound - Le son à démarrer/augmenter
	@param soundToStop Sound - Le son à diminuer/arrêter
	@param targetName string - Nom de la nouvelle ambiance (pour éviter les doublons)
]]
local function transitionAmbiance(soundToPlay, soundToStop, targetName)
	if currentAmbiance == targetName then
		-- Déjà sur cette ambiance, rien à faire
		return
	end
	
	currentAmbiance = targetName
	
	-- Démarre le son cible s'il n'est pas en cours
	if not soundToPlay.IsPlaying then
		soundToPlay:Play()
	end
	
	-- Fondu vers le volume cible pour le son à jouer
	local tweenIn = TweenService:Create(soundToPlay, tweenInfo, { Volume = TARGET_VOLUME })
	tweenIn:Play()
	
	-- Fondu vers 0 pour le son à arrêter
	local tweenOut = TweenService:Create(soundToStop, tweenInfo, { Volume = 0 })
	tweenOut:Play()
	
	-- Arrêt du son après le fondu
	tweenOut.Completed:Connect(function()
		if soundToStop.IsPlaying then
			soundToStop:Stop()
		end
	end)
end

--[[
	Gestion du changement de phase
]]
local function onPhaseChanged()
	local currentPhase = SharedData:GetAttribute("CurrentPhase")
	
	if currentPhase == "DAY_PHASE" then
		transitionAmbiance(daySound, nightSound, "DAY")
	elseif currentPhase == "NIGHT_PHASE" then
		transitionAmbiance(nightSound, daySound, "NIGHT")
	end
	-- Les autres phases (VOTE_PHASE, INTERMISSION, etc.) ne changent rien
end

-- Initialisation : lecture de la phase actuelle au démarrage
onPhaseChanged()

-- Écoute des changements de phase
SharedData:GetAttributeChangedSignal("CurrentPhase"):Connect(onPhaseChanged)

print("[AmbianceSound] Client initialisé - Écoute des phases pour gérer l'ambiance sonore")