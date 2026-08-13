-- GameConfig.luau
-- Constantes centrales du jeu "Village Maudit"
-- ModuleScript : accessible via require(ReplicatedStorage.Shared.GameConfig)

local GameConfig = {}

-- Durées des phases (en secondes)
GameConfig.DAY_DURATION = 180
GameConfig.VOTE_DURATION = 5
GameConfig.NIGHT_DURATION = 45

-- Joueurs
GameConfig.MIN_PLAYERS = 1

-- Rôles
GameConfig.TRAITOR_RATIO = 0.25

-- Monstres
GameConfig.BASE_MONSTER_COUNT = 2
GameConfig.MONSTER_COUNT_INCREASE_PER_NIGHT = 1
GameConfig.MONSTER_MAX_COUNT = 8

-- Victoire
GameConfig.NIGHTS_TO_SURVIVE = 5


-- Audio
GameConfig.SOUNDS = {
	DayAmbient = "rbxassetid://110778299733422",    -- Broken Generator Hum
	NightAmbient = "rbxassetid://140226003563104",  -- Scary Spooky Dark Horror Thriller
	MonsterGrowl = "rbxassetid://71374905925238",   -- The Chase Protocol
	VoteStart = "rbxassetid://140115427069802",     -- Tension
	CraftSuccess = "rbxassetid://101967493171799",  -- Minecraft-style crafting sound
	TraitorWhisper = "rbxassetid://140440238391729", -- Horror Sound Effect - Voices (Whispers), pas encore cable
	VoteCast = "rbxassetid://18908611063",          -- Confirmation sonore au moment de voter
}

return GameConfig
