-- GameTests.server.luau
-- Script de test automatique qui vérifie le bon fonctionnement des systèmes du jeu
-- S'exécute au démarrage du serveur en mode test (Play Test Studio)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Attendre que les autres systèmes s'initialisent
task.wait(8)

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
        local GameConfig = require(ReplicatedStorage:WaitForChild("Modules", 5):WaitForChild("GameConfig", 5))
        
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
        logTestResult("GameConfig chargé", false, result)
    else
        logTestResult("GameConfig chargé", false, tostring(result))
    end
end

-- TEST 2 : Cycle jour/nuit (SharedData.CurrentPhase)
local function testCycleJourNuit()
    local success, result = pcall(function()
        local sharedData = ReplicatedStorage:WaitForChild("SharedData", 5)
        
        if not sharedData then
            return false, "SharedData n'existe pas"
        end
        
        task.wait(3)
        
        local currentPhase = sharedData:GetAttribute("CurrentPhase")
        
        if currentPhase == nil then
            return false, "CurrentPhase est nil"
        end
        
        local validPhases = {
            ["DAY_PHASE"] = true,
            ["VOTE_PHASE"] = true,
            ["NIGHT_PHASE"] = true
        }
        
        if not validPhases[currentPhase] then
            return false, "Phase invalide : " .. tostring(currentPhase)
        end
        
        return true
    end)
    
    if success and result == true then
        logTestResult("Cycle jour/nuit", true)
    elseif success then
        logTestResult("Cycle jour/nuit", false, result)
    else
        logTestResult("Cycle jour/nuit", false, tostring(result))
    end
end

-- TEST 3 : Monde généré (WorldBuilder)
local function testMondeGenere()
    local success, result = pcall(function()
        local trees = workspace:FindFirstChild("Trees")
        if not trees then
            return false, "Dossier Trees n'existe pas"
        end
        
        if #trees:GetChildren() < 1 then
            return false, "Aucun arbre généré"
        end
        
        local village = workspace:FindFirstChild("Village")
        if not village then
            return false, "Dossier Village n'existe pas"
        end
        
        local fortifications = village:FindFirstChild("Fortifications")
        if not fortifications then
            return false, "Dossier Fortifications n'existe pas"
        end
        
        local doors = {"Door_North", "Door_East", "Door_West", "Door_South"}
        for _, doorName in ipairs(doors) do
            local door = fortifications:FindFirstChild(doorName)
            if not door then
                return false, "Porte " .. doorName .. " manquante"
            end
            
            local doorPart = door:FindFirstChild("DoorPart")
            if not doorPart then
                return false, doorName .. " n'a pas de DoorPart"
            end
            
            local health = doorPart:GetAttribute("Health")
            if type(health) ~= "number" then
                return false, doorName .. " n'a pas d'attribut Health valide"
            end
        end
        
        return true
    end)
    
    if success and result == true then
        logTestResult("Monde généré", true)
    elseif success then
        logTestResult("Monde généré", false, result)
    else
        logTestResult("Monde généré", false, tostring(result))
    end
end

-- TEST 4 : Monstres (MonsterSpawner)
local function testMonstres()
    local success, result = pcall(function()
        local spawnPoints = CollectionService:GetTagged("MonsterSpawnPoint")
        
        if #spawnPoints < 1 then
            return false, "Aucun point de spawn de monstre trouvé"
        end
        
        return true
    end)
    
    if success and result == true then
        logTestResult("Points de spawn monstres", true)
    elseif success then
        logTestResult("Points de spawn monstres", false, result)
    else
        logTestResult("Points de spawn monstres", false, tostring(result))
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
        if not voteEvent then
            return false, "VoteEvent n'existe pas"
        end
        
        local voteResultEvent = remoteEvents:FindFirstChild("VoteResultEvent")
        if not voteResultEvent then
            return false, "VoteResultEvent n'existe pas"
        end
        
        return true
    end)
    
    if success and result == true then
        logTestResult("Système de vote", true)
    elseif success then
        logTestResult("Système de vote", false, result)
    else
        logTestResult("Système de vote", false, tostring(result))
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
        
        return true
    end)
    
    if success and result == true then
        logTestResult("Système de craft", true)
    elseif success and result == nil then
        logTestResult("Système de craft", nil, "Système non encore branché")
    elseif success then
        logTestResult("Système de craft", false, result)
    else
        logTestResult("Système de craft", false, tostring(result))
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