-- GameConfig.luau
-- Constantes centrales du jeu "Village Maudit"
-- ModuleScript : accessible via require(ReplicatedStorage.Shared.GameConfig)

local GameConfig = {}

-- Durées des phases (en secondes)
GameConfig.DAY_DURATION = 15      -- TEST
GameConfig.VOTE_DURATION = 10      -- TEST
GameConfig.NIGHT_DURATION = 30    -- TEST

-- Joueurs
GameConfig.MIN_PLAYERS = 4

-- Monstres
GameConfig.BASE_MONSTER_COUNT = 2
GameConfig.MONSTER_COUNT_INCREASE_PER_NIGHT = 1
GameConfig.MONSTER_MAX_COUNT = 8

-- Victoire
GameConfig.NIGHTS_TO_SURVIVE = 5

return GameConfig
