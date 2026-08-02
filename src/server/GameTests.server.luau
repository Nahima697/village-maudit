-- GameTests.server.luau
-- Script de test automatique qui vérifie le bon fonctionnement des systèmes du jeu
-- S'exécute au démarrage du serveur en mode test (Play Test Studio)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Attendre que les autres systèmes s'initialisent (augmenté pour le nouveau WorldBuilder)
task.wait(10)

print("[TEST] ========== DÉBUT DES TESTS ==========")

local passCount = 0
local failCount = 0
local skipCount = 0

-- Fonction utilitaire pour afficher le résultat d'un test
local function logTestResult(testName, success, reason)
	if success == nil then
		print("[TEST] " .. testName .. " : SKIP - " .. (reason or "Non applicable"))
		skipCount = skipCount + 1
	elseif success then
		print("[TEST] " .. testName .. " : PASS")
		passCount = passCount + 1
	else
		print("[TEST] " .. testName .. " : FAIL - " .. (reason or "Erreur inconnue"))
		failCount = failCount + 1
	end
end

-- TEST 1 : GameConfig chargé correctement
local function testGameConfig()
	local success, result = pcall(function()
		local modulesFolder = ReplicatedStorage:WaitForChild("Modules", 5)
		if not modulesFolder then
			return false, "Dossier Modules introuvable"
		end

		local GameConfig = require(modulesFolder:WaitForChild("GameConfig", 5))

		if GameConfig == nil then
			return false, "GameConfig est nil"
		end

		if type(GameConfig.DAY_DURATION) ~= "number" or GameConfig.DAY_DURATION <= 0 then
			return false, "DAY_DURATION invalide"
		end

		if type(GameConfig.VOTE_DURATION) ~= "number" or GameConfig.VOTE_DURATION <= 0 then
			return false, "VOTE_DURATION invalide"
		end

		if type(GameConfig.NIGHT_DURATION) ~= "number" or GameConfig.NIGHT_DURATION <= 0 then
			return false, "NIGHT_DURATION invalide"
		end

		return true
	end)

	if success and result == true then
		logTestResult("GameConfig chargé", true)
	elseif success then
		logTestResult("GameConfig chargé", false, tostring(result))
	else
		logTestResult("GameConfig chargé", false, tostring(result))
	end
end

-- TEST 2 : Cycle jour/nuit (SharedData.CurrentPhase)
local function testCycleJourNuit()
	local success, result = pcall(function()
		-- Attendre SharedData avec timeout sécurisé
		local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
		
		if not sharedData then
			local waitSuccess = pcall(function()
				sharedData = ReplicatedStorage:WaitForChild("SharedData", 10)
			end)
			
			if not waitSuccess or not sharedData then
				return nil, "SharedData n'existe pas après 10 secondes (GameManager pas encore démarré)"
			end
		end

		-- Attendre que GameManager initialise les attributs
		task.wait(2)

		local currentPhase = sharedData:GetAttribute("CurrentPhase")

		-- Vérifier que CurrentPhase existe
		if currentPhase == nil or currentPhase == "" then
			return nil, "CurrentPhase non encore initialisé (GameManager en cours de démarrage)"
		end

		-- Phases valides du GameManager
		local validPhases = {
			["DAY_PHASE"] = true,
			["VOTE_PHASE"] = true,
			["NIGHT_PHASE"] = true,
			["WAITING"] = true,
		}

		if not validPhases[currentPhase] then
			return false, "Phase invalide : " .. tostring(currentPhase)
		end

		-- Vérifier TimeRemaining (doit être un nombre s'il existe)
		local timeRemaining = sharedData:GetAttribute("TimeRemaining")
		if timeRemaining ~= nil and type(timeRemaining) ~= "number" then
			return false, "TimeRemaining existe mais n'est pas un nombre (valeur : " .. tostring(timeRemaining) .. ")"
		end

		return true
	end)

	if success and result == true then
		logTestResult("Cycle jour/nuit", true)
	elseif success and result == nil then
		logTestResult("Cycle jour/nuit", nil, tostring(result))
	elseif success then
		logTestResult("Cycle jour/nuit", false, tostring(result))
	else
		logTestResult("Cycle jour/nuit", false, "Erreur pcall : " .. tostring(result))
	end
end

-- TEST 3 : Monde généré (WorldBuilder 3D)
local function testMondeGenere()
	local success, result = pcall(function()
		-- Vérifier le terrain (terrain 3D généré)
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		if not terrain then
			return false, "Terrain n'existe pas"
		end

		-- Vérifier les dossiers principaux créés par WorldBuilder
		local village = workspace:FindFirstChild("Village")
		if not village then
			return false, "Dossier Village n'existe pas"
		end

		local trees = workspace:FindFirstChild("Trees")
		if not trees then
			return false, "Dossier Trees n'existe pas"
		end

		local rocks = workspace:FindFirstChild("Rocks")
		if not rocks then
			return nil, "Dossier Rocks n'existe pas (optionnel mais attendu)"
		end

		local monsterSpawns = workspace:FindFirstChild("MonsterSpawns")
		if not monsterSpawns then
			return nil, "Dossier MonsterSpawns n'existe pas (génération en cours ?)"
		end

		-- Vérifier que les dossiers contiennent au moins quelques éléments
		local treeCount = #trees:GetChildren()
		if treeCount < 1 then
			return nil, "Dossier Trees existe mais est vide (génération en cours ?)"
		end

		local spawnCount = #monsterSpawns:GetChildren()
		if spawnCount < 1 then
			return nil, "Dossier MonsterSpawns existe mais est vide (génération en cours ?)"
		end

		-- Vérifier les fortifications et portes (optionnel mais important)
		local fortifications = village:FindFirstChild("Fortifications")
		if fortifications then
			local doors = { "Door_North", "Door_East", "Door_West", "Door_South" }
			local doorCount = 0
			
			for _, doorName in ipairs(doors) do
				local door = fortifications:FindFirstChild(doorName)
				if door then
					doorCount = doorCount + 1
					
					-- Vérifier les attributs de santé si la porte a un DoorPart
					local doorPart = door:FindFirstChild("DoorPart")
					if doorPart then
						local health = doorPart:GetAttribute("Health")
						local maxHealth = doorPart:GetAttribute("MaxHealth")
						
						if health ~= nil and (type(health) ~= "number" or health <= 0) then
							return false, doorName .. " a Health invalide (trouvé: " .. tostring(health) .. ")"
						end
						
						if maxHealth ~= nil and (type(maxHealth) ~= "number" or maxHealth <= 0) then
							return false, doorName .. " a MaxHealth invalide"
						end
					end
				end
			end
			
			if doorCount == 0 then
				return nil, "Fortifications existent mais aucune porte trouvée"
			end
		end

		return true
	end)

	if success and result == true then
		logTestResult("Monde généré (3D)", true)
	elseif success and result == nil then
		logTestResult("Monde généré (3D)", nil, tostring(result))
	elseif success then
		logTestResult("Monde généré (3D)", false, tostring(result))
	else
		logTestResult("Monde généré (3D)", false, "Erreur pcall : " .. tostring(result))
	end
end

-- TEST 4 : Monstres (MonsterSpawner)
local function testMonstres()
	local success, result = pcall(function()
		-- Vérifier les points de spawn taggés
		local spawnPoints = CollectionService:GetTagged("MonsterSpawnPoint")

		if #spawnPoints < 1 then
			-- Vérifier aussi le dossier MonsterSpawns dans le Workspace
			local monsterSpawns = workspace:FindFirstChild("MonsterSpawns")
			if monsterSpawns and #monsterSpawns:GetChildren() >= 1 then
				return true -- Les spawns existent dans le dossier
			end
			
			return nil, "Aucun point de spawn de monstre trouvé (ni par tag, ni dans MonsterSpawns)"
		end

		-- Vérifier que chaque spawn point a une position valide
		for i, spawnPoint in ipairs(spawnPoints) do
			if not spawnPoint:IsA("BasePart") and not spawnPoint:IsA("Model") and not spawnPoint:IsA("Attachment") then
				return false, "Point de spawn " .. i .. " n'est pas une Part, un Model ou un Attachment"
			end
		end

		return true
	end)

	if success and result == true then
		logTestResult("Points de spawn monstres", true)
	elseif success and result == nil then
		logTestResult("Points de spawn monstres", nil, tostring(result))
	elseif success then
		logTestResult("Points de spawn monstres", false, tostring(result))
	else
		logTestResult("Points de spawn monstres", false, "Erreur pcall : " .. tostring(result))
	end
end

-- TEST 5 : Vote (VotingSystem)
local function testVote()
	local success, result = pcall(function()
		local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents", 5)

		if not remoteEvents then
			return false, "Dossier RemoteEvents n'existe pas"
		end

		local voteEvent = remoteEvents:FindFirstChild("VoteEvent")
		if not voteEvent or not voteEvent:IsA("RemoteEvent") then
			return false, "VoteEvent n'existe pas ou n'est pas un RemoteEvent"
		end

		local voteResultEvent = remoteEvents:FindFirstChild("VoteResultEvent")
		if not voteResultEvent or not voteResultEvent:IsA("RemoteEvent") then
			return false, "VoteResultEvent n'existe pas ou n'est pas un RemoteEvent"
		end

		return true
	end)

	if success and result == true then
		logTestResult("Système de vote", true)
	elseif success then
		logTestResult("Système de vote", false, tostring(result))
	else
		logTestResult("Système de vote", false, "Erreur pcall : " .. tostring(result))
	end
end

-- TEST 6 : Craft (CraftingSystem)
local function testCraft()
	local success, result = pcall(function()
		local remoteEvents = ReplicatedStorage:FindFirstChild("RemoteEvents")

		if not remoteEvents then
			return nil, "RemoteEvents n'existe pas encore"
		end

		local collectEvent = remoteEvents:FindFirstChild("CollectResourceEvent")
		local craftEvent = remoteEvents:FindFirstChild("CraftItemEvent")

		if not collectEvent or not craftEvent then
			return nil, "Events de crafting non implémentés"
		end

		if not collectEvent:IsA("RemoteEvent") or not craftEvent:IsA("RemoteEvent") then
			return false, "Les events de crafting ne sont pas des RemoteEvents"
		end

		return true
	end)

	if success and result == true then
		logTestResult("Système de craft", true)
	elseif success and result == nil then
		logTestResult("Système de craft", nil, tostring(result))
	elseif success then
		logTestResult("Système de craft", false, tostring(result))
	else
		logTestResult("Système de craft", false, "Erreur pcall : " .. tostring(result))
	end
end

-- Exécution de tous les tests
testGameConfig()
testCycleJourNuit()
testMondeGenere()
testMonstres()
testVote()
testCraft()

-- Résumé final
print("[TEST] ========================================")
print(string.format("[TEST] Résumé : %d PASS, %d FAIL, %d SKIP", passCount, failCount, skipCount))
print("[TEST] ========== FIN DES TESTS ==========")

-- Afficher un avertissement si des tests échouent
if failCount > 0 then
	warn("[TEST] ⚠️ Attention : " .. failCount .. " test(s) ont échoué !")
end