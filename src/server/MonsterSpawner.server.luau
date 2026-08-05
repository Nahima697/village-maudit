--[[
	MonsterSpawner.server.luau
	Gère l'apparition et le comportement des monstres durant la phase de nuit.
	
	Fonctionnalités :
	- Spawn de monstres aux points taggés "MonsterSpawnPoint"
	- Augmentation du nombre de monstres chaque nuit
	- Pathfinding vers les portes fortifiées
	- Détection et attaque des joueurs proches
	- Attaque des portes si aucun joueur n'est à portée
	- Nettoyage automatique au lever du jour
	
	Version 2.0 : Compatible avec WorldBuilder 3D
]]

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

-- Modules
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

-- Configuration
local MONSTER_DETECT_RANGE = 200 -- Distance de détection des joueurs
local MONSTER_ATTACK_DAMAGE = 10 -- Dégâts aux joueurs
local MONSTER_DOOR_DAMAGE = 5 -- Dégâts aux portes
local MONSTER_ATTACK_COOLDOWN = 2 -- Secondes entre les attaques
local PATHFINDING_RECALCULATE_INTERVAL = 3 -- Recalculer le chemin toutes les N secondes
local DOOR_MAX_HEALTH = 500 -- Points de vie initiaux d'une porte
local MONSTER_HEALTH = 100 -- Points de vie d'un monstre
local MONSTER_WALK_SPEED = 80 -- Vitesse de déplacement

-- État global
local activeMonsters = {}
local currentNightCount = 0
local isNightPhase = false
local monsterFolder = nil

-- Références aux portes
local doors = {}

--[[
	Crée un modèle de monstre basique en primitives
	@return Model - Le monstre créé
]]
local function createMonster()
	local monster = Instance.new("Model")
	monster.Name = "Monster"
	
	-- Corps (torse)
	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2, 2, 1)
	torso.BrickColor = BrickColor.new("Really black")
	torso.Material = Enum.Material.SmoothPlastic
	torso.CanCollide = true
	torso.Parent = monster
	
	-- Tête
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.5, 1.5, 1.5)
	head.BrickColor = BrickColor.new("Dark stone grey")
	head.Material = Enum.Material.SmoothPlastic
	head.Shape = Enum.PartType.Ball
	head.CanCollide = true
	head.Parent = monster
	
	-- Yeux rouges
	local leftEye = Instance.new("Part")
	leftEye.Name = "LeftEye"
	leftEye.Size = Vector3.new(0.3, 0.3, 0.3)
	leftEye.BrickColor = BrickColor.new("Really red")
	leftEye.Material = Enum.Material.Neon
	leftEye.Shape = Enum.PartType.Ball
	leftEye.CanCollide = false
	leftEye.Parent = head
	
	local rightEye = leftEye:Clone()
	rightEye.Name = "RightEye"
	rightEye.Parent = head
	
	-- Welds pour les yeux
	local leftEyeWeld = Instance.new("WeldConstraint")
	leftEyeWeld.Part0 = head
	leftEyeWeld.Part1 = leftEye
	leftEyeWeld.Parent = leftEye
	leftEye.CFrame = head.CFrame * CFrame.new(-0.4, 0.2, -0.6)
	
	local rightEyeWeld = Instance.new("WeldConstraint")
	rightEyeWeld.Part0 = head
	rightEyeWeld.Part1 = rightEye
	rightEyeWeld.Parent = rightEye
	rightEye.CFrame = head.CFrame * CFrame.new(0.4, 0.2, -0.6)
	
	-- Bras gauche
	local leftArm = Instance.new("Part")
	leftArm.Name = "Left Arm"
	leftArm.Size = Vector3.new(1, 2, 1)
	leftArm.BrickColor = BrickColor.new("Really black")
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.CanCollide = false
	leftArm.Parent = monster
	
	-- Bras droit
	local rightArm = Instance.new("Part")
	rightArm.Name = "Right Arm"
	rightArm.Size = Vector3.new(1, 2, 1)
	rightArm.BrickColor = BrickColor.new("Really black")
	rightArm.Material = Enum.Material.SmoothPlastic
	rightArm.CanCollide = false
	rightArm.Parent = monster
	
	-- Jambe gauche
	local leftLeg = Instance.new("Part")
	leftLeg.Name = "Left Leg"
	leftLeg.Size = Vector3.new(1, 2, 1)
	leftLeg.BrickColor = BrickColor.new("Really black")
	leftLeg.Material = Enum.Material.SmoothPlastic
	leftLeg.CanCollide = false
	leftLeg.Parent = monster
	
	-- Jambe droite
	local rightLeg = Instance.new("Part")
	rightLeg.Name = "Right Leg"
	rightLeg.Size = Vector3.new(1, 2, 1)
	rightLeg.BrickColor = BrickColor.new("Really black")
	rightLeg.Material = Enum.Material.SmoothPlastic
	rightLeg.CanCollide = false
	rightLeg.Parent = monster
	
	-- Humanoid
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = MONSTER_HEALTH
	humanoid.Health = MONSTER_HEALTH
	humanoid.WalkSpeed = MONSTER_WALK_SPEED
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = monster
	
	-- HumanoidRootPart
	local rootPart = Instance.new("Part")
	rootPart.Name = "HumanoidRootPart"
	rootPart.Size = Vector3.new(2, 2, 1)
	rootPart.Transparency = 1
	rootPart.CanCollide = false
	rootPart.Parent = monster
	
	monster.PrimaryPart = rootPart
	
	-- Welds pour attacher les parties au RootPart
	local function weldTo(part, offset)
		local weld = Instance.new("Motor6D")
		weld.Part0 = rootPart
		weld.Part1 = part
		weld.C0 = offset
		weld.Parent = rootPart
	end
	
	weldTo(torso, CFrame.new(0, 0, 0))
	weldTo(head, CFrame.new(0, 1.75, 0))
	weldTo(leftArm, CFrame.new(-1.5, 0, 0))
	weldTo(rightArm, CFrame.new(1.5, 0, 0))
	weldTo(leftLeg, CFrame.new(-0.5, -2, 0))
	weldTo(rightLeg, CFrame.new(0.5, -2, 0))
	
	return monster
end

--[[
	Trouve toutes les portes dans le monde via CollectionService ou recherche récursive
	Compatible avec le nouveau WorldBuilder 3D
	@return table - Liste des parts de porte trouvées
]]
local function findAllDoors()
	local foundDoors = {}
	
	-- Méthode 1 : Via CollectionService (si les portes sont taggées "Door" ou "VillageDoor")
	local taggedDoors = CollectionService:GetTagged("Door")
	for _, door in ipairs(taggedDoors) do
		if door:IsA("BasePart") then
			table.insert(foundDoors, door)
		elseif door:IsA("Model") then
			-- Si c'est un modèle, chercher la part principale
			local doorPart = door:FindFirstChild("DoorPart") or door:FindFirstChild("Door") or door.PrimaryPart
			if doorPart and doorPart:IsA("BasePart") then
				table.insert(foundDoors, doorPart)
			end
		end
	end
	
	-- Méthode 2 : Recherche dans workspace.Village
	local village = workspace:FindFirstChild("Village")
	if village then
		-- Chercher dans Fortifications si existe
		local fortifications = village:FindFirstChild("Fortifications")
		if fortifications then
			for _, child in ipairs(fortifications:GetChildren()) do
				if child.Name:match("Door") or child.Name:match("Gate") then
					local doorPart = nil
					if child:IsA("BasePart") then
						doorPart = child
					elseif child:IsA("Model") then
						doorPart = child:FindFirstChild("DoorPart") or child:FindFirstChild("Door") or child.PrimaryPart
					end
					
					if doorPart and doorPart:IsA("BasePart") then
						-- Éviter les doublons
						local alreadyAdded = false
						for _, existing in ipairs(foundDoors) do
							if existing == doorPart then
								alreadyAdded = true
								break
							end
						end
						if not alreadyAdded then
							table.insert(foundDoors, doorPart)
						end
					end
				end
			end
		end
		
		-- Chercher directement dans Village aussi
		for _, child in ipairs(village:GetChildren()) do
			if child.Name:match("Door") or child.Name:match("Gate") then
				local doorPart = nil
				if child:IsA("BasePart") then
					doorPart = child
				elseif child:IsA("Model") then
					doorPart = child:FindFirstChild("DoorPart") or child:FindFirstChild("Door") or child.PrimaryPart
				end
				
				if doorPart and doorPart:IsA("BasePart") then
					local alreadyAdded = false
					for _, existing in ipairs(foundDoors) do
						if existing == doorPart then
							alreadyAdded = true
							break
						end
					end
					if not alreadyAdded then
						table.insert(foundDoors, doorPart)
					end
				end
			end
		end
	end
	
	-- Méthode 3 : Recherche globale par nom (fallback)
	if #foundDoors == 0 then
		local function searchRecursive(parent)
			for _, child in ipairs(parent:GetChildren()) do
				if child.Name:match("Door") or child.Name:match("Gate") then
					local doorPart = nil
					if child:IsA("BasePart") then
						doorPart = child
					elseif child:IsA("Model") then
						doorPart = child:FindFirstChild("DoorPart") or child:FindFirstChild("Door") or child.PrimaryPart
					end
					
					if doorPart and doorPart:IsA("BasePart") then
						table.insert(foundDoors, doorPart)
					end
				end
				
				if child:IsA("Folder") or child:IsA("Model") then
					searchRecursive(child)
				end
			end
		end
		
		searchRecursive(workspace)
	end
	
	return foundDoors
end

--[[
	Initialise les références aux portes et leur santé
	Version 2.0 : Compatible avec WorldBuilder 3D
]]
local function initializeDoors()
	doors = {}
	
	print("[MonsterSpawner] Recherche des portes...")
	
	-- Attendre que le monde soit généré
	local maxWaitTime = 30
	local waited = 0
	while not workspace:GetAttribute("WorldReady") and waited < maxWaitTime do
		task.wait(0.5)
		waited = waited + 0.5
	end
	
	if not workspace:GetAttribute("WorldReady") then
		warn("[MonsterSpawner] WorldReady non reçu après", maxWaitTime, "secondes, on cherche quand même les portes")
	end
	
	-- Trouver toutes les portes
	local foundDoors = findAllDoors()
	
	-- Initialiser chaque porte
	for _, doorPart in ipairs(foundDoors) do
		if doorPart:IsA("BasePart") then
			-- Initialiser les attributs de santé si pas déjà fait
			if not doorPart:GetAttribute("Health") then
				doorPart:SetAttribute("Health", DOOR_MAX_HEALTH)
			end
			if not doorPart:GetAttribute("MaxHealth") then
				doorPart:SetAttribute("MaxHealth", DOOR_MAX_HEALTH)
			end
			
			table.insert(doors, doorPart)
			print("[MonsterSpawner] Porte initialisée:", doorPart:GetFullName())
		end
	end
	
	if #doors == 0 then
		warn("[MonsterSpawner] ATTENTION : Aucune porte trouvée ! Les monstres n'auront pas de cible.")
	else
		print("[MonsterSpawner] Total de portes initialisées:", #doors)
	end
end

--[[
	Trouve la porte la plus proche d'une position
	@param position Vector3 - Position de référence
	@return Part|nil - La porte la plus proche, ou nil
]]
local function findNearestDoor(position)
	local nearestDoor = nil
	local shortestDistance = math.huge
	
	for _, door in ipairs(doors) do
		if door and door.Parent and (door:GetAttribute("Health") or 0) > 0 then
			local distance = (door.Position - position).Magnitude
			if distance < shortestDistance then
				shortestDistance = distance
				nearestDoor = door
			end
		end
	end
	
	return nearestDoor
end

--[[
	Trouve le joueur le plus proche d'un monstre
	@param monsterPosition Vector3 - Position du monstre
	@return Player|nil, number - Le joueur le plus proche et la distance, ou nil
]]
local function findNearestPlayer(monsterPosition)
	local nearestPlayer = nil
	local shortestDistance = MONSTER_DETECT_RANGE
	
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player.Character then
			local humanoid = player.Character:FindFirstChild("Humanoid")
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
			
			if humanoid and humanoid.Health > 0 and rootPart then
				-- Vérifier si le joueur est dans la SafeZone
				local inSafeZone = false
				local safeZoneValue = rootPart:FindFirstChild("InSafeZone")
				if safeZoneValue and safeZoneValue:IsA("BoolValue") then
					inSafeZone = safeZoneValue.Value
				end
				
				if not inSafeZone then
					local distance = (rootPart.Position - monsterPosition).Magnitude
					if distance < shortestDistance then
						shortestDistance = distance
						nearestPlayer = player
					end
				end
			end
		end
	end
	
	return nearestPlayer, shortestDistance
end

--[[
	Attaque une cible (joueur ou porte)
	@param monster Model - Le monstre qui attaque
	@param target Instance - La cible à attaquer
	@param monsterData table - Les données du monstre
]]
local function attackTarget(monster, target, monsterData)
	local currentTime = tick()
	if currentTime - monsterData.lastAttackTime < MONSTER_ATTACK_COOLDOWN then
		return
	end
	
	monsterData.lastAttackTime = currentTime
	
	if target:IsA("BasePart") then
		-- Attaque de porte
		local currentHealth = target:GetAttribute("Health") or 0
		local newHealth = math.max(0, currentHealth - MONSTER_DOOR_DAMAGE)
		target:SetAttribute("Health", newHealth)
		
		print(string.format("[MonsterSpawner] Porte attaquée: %s (%d/%d HP)", 
			target.Name, newHealth, target:GetAttribute("MaxHealth") or DOOR_MAX_HEALTH))
		
		if newHealth <= 0 then
			-- Porte détruite
			target.CanCollide = false
			target.Transparency = 0.7
			warn("[MonsterSpawner] Porte détruite:", target:GetFullName())
		end
	elseif target:IsA("Model") then
		-- Attaque de joueur
		local humanoid = target:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(MONSTER_ATTACK_DAMAGE)
			print(string.format("[MonsterSpawner] Joueur attaqué: %s (%d HP)", 
				target.Name, humanoid.Health))
		end
	end
end

--[[
	Gère le comportement d'un monstre individuel
	@param monster Model - Le monstre à gérer
	@param spawnPosition Vector3 - Position de spawn initiale
]]
local function setupMonsterBehavior(monster, spawnPosition)
	local humanoid = monster:FindFirstChild("Humanoid")
	local rootPart = monster:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then
		monster:Destroy()
		return
	end
	
	-- Données du monstre
	local monsterData = {
		model = monster,
		currentTarget = nil,
		lastPathfindTime = 0,
		lastAttackTime = 0,
		isActive = true,
		path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 4,
			Costs = {
				Water = math.huge
			}
		})
	}
	
	table.insert(activeMonsters, monsterData)
	
	-- Connexion à la mort du monstre
	humanoid.Died:Connect(function()
		monsterData.isActive = false
		Debris:AddItem(monster, 3)
	end)
	
	-- Boucle de comportement
	task.spawn(function()
		while monsterData.isActive and monster.Parent and humanoid.Health > 0 do
			if not isNightPhase then
				break
			end
			
			local currentTime = tick()
			
			-- Vérifier si un joueur est à portée
			local nearestPlayer, playerDistance = findNearestPlayer(rootPart.Position)
			
			if nearestPlayer and nearestPlayer.Character then
				-- Cibler le joueur
				monsterData.currentTarget = nearestPlayer.Character
			else
				-- Cibler la porte la plus proche
				local nearestDoor = findNearestDoor(rootPart.Position)
				if nearestDoor then
					monsterData.currentTarget = nearestDoor
				else
					monsterData.currentTarget = nil
				end
			end
			
			-- Déplacement et attaque
			if monsterData.currentTarget then
				local targetPosition
				if monsterData.currentTarget:IsA("Model") then
					local targetRoot = monsterData.currentTarget:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						targetPosition = targetRoot.Position
					end
				else
					targetPosition = monsterData.currentTarget.Position
				end
				
				if targetPosition then
					local distance = (rootPart.Position - targetPosition).Magnitude
					
					-- Attaquer si assez proche
					if distance < 5 then
						humanoid:MoveTo(rootPart.Position) -- Arrêter le mouvement
						attackTarget(monster, monsterData.currentTarget, monsterData)
					else
						-- Recalculer le chemin périodiquement
						if currentTime - monsterData.lastPathfindTime > PATHFINDING_RECALCULATE_INTERVAL then
							monsterData.lastPathfindTime = currentTime
							
							local success, errorMsg = pcall(function()
								monsterData.path:ComputeAsync(rootPart.Position, targetPosition)
							end)
							
							if success and monsterData.path.Status == Enum.PathStatus.Success then
								local waypoints = monsterData.path:GetWaypoints()
								
								if #waypoints > 0 then
									-- Suivre le chemin
									for i = 2, math.min(#waypoints, 5) do
										if not monsterData.isActive or not isNightPhase then
											break
										end
										
										local waypoint = waypoints[i]
										humanoid:MoveTo(waypoint.Position)
										
										if waypoint.Action == Enum.PathWaypointAction.Jump then
											humanoid.Jump = true
										end
										
										task.wait(0.5)
									end
								end
							else
								-- Fallback : déplacement direct
								humanoid:MoveTo(targetPosition)
							end
						end
					end
				end
			end
			
			task.wait(0.5)
		end
		
		monsterData.isActive = false
	end)
end

--[[
	Fait apparaître les monstres pour la nuit
]]
local function spawnMonsters()
	-- Calculer le nombre de monstres
	local monsterCount = GameConfig.BASE_MONSTER_COUNT + 
		(currentNightCount - 1) * GameConfig.MONSTER_COUNT_INCREASE_PER_NIGHT
	monsterCount = math.min(monsterCount, GameConfig.MONSTER_MAX_COUNT)
	
	print(string.format("[MonsterSpawner] Nuit %d : Spawn de %d monstres", currentNightCount, monsterCount))
	
	-- Récupérer les points de spawn
	local spawnPoints = CollectionService:GetTagged("MonsterSpawnPoint")
	
	if #spawnPoints == 0 then
		warn("[MonsterSpawner] Aucun point de spawn trouvé! Les monstres apparaîtront au hasard.")
		
		-- Créer des points de spawn temporaires autour du village
		local village = workspace:FindFirstChild("Village")
		if village then
			local villageCF = village:GetPivot()
			local spawnRadius = 100
			
			for angle = 0, 360, 45 do
				local rad = math.rad(angle)
				local x = villageCF.X + math.cos(rad) * spawnRadius
				local z = villageCF.Z + math.sin(rad) * spawnRadius
				
				local tempSpawn = Instance.new("Part")
				tempSpawn.Size = Vector3.new(1, 1, 1)
				tempSpawn.Position = Vector3.new(x, 50, z)
				tempSpawn.Transparency = 1
				tempSpawn.CanCollide = false
				tempSpawn.Anchored = true
				tempSpawn.Name = "TempMonsterSpawn"
				tempSpawn.Parent = workspace
				
				table.insert(spawnPoints, tempSpawn)
			end
		end
	end
	
	if #spawnPoints == 0 then
		warn("[MonsterSpawner] Impossible de créer des points de spawn!")
		return
	end
	
	-- Créer le dossier pour les monstres
	monsterFolder = Instance.new("Folder")
	monsterFolder.Name = "Monsters"
	monsterFolder.Parent = workspace
	
	-- Spawner les monstres
	for i = 1, monsterCount do
		-- Sélectionner un point de spawn aléatoire
		local spawnPoint = spawnPoints[math.random(1, #spawnPoints)]
		
		-- Créer le monstre
		local monster = createMonster()
		local spawnPosition = spawnPoint.Position + Vector3.new(
			math.random(-5, 5),
			3,
			math.random(-5, 5)
		)
		
		monster:SetPrimaryPartCFrame(CFrame.new(spawnPosition))
		monster.Parent = monsterFolder
		
		-- Configurer le comportement
		setupMonsterBehavior(monster, spawnPosition)
		
		task.wait(0.1)
	end
	
	print("[MonsterSpawner] Spawn terminé:", monsterCount, "monstres actifs")
end

--[[
	Nettoie tous les monstres actifs
]]
local function cleanupMonsters()
	print("[MonsterSpawner] Nettoyage des monstres...")
	
	-- Désactiver tous les monstres
	for _, monsterData in ipairs(activeMonsters) do
		monsterData.isActive = false
		if monsterData.model and monsterData.model.Parent then
			monsterData.model:Destroy()
		end
	end
	
	-- Vider la table
	table.clear(activeMonsters)
	
	-- Détruire le dossier
	if monsterFolder and monsterFolder.Parent then
		monsterFolder:Destroy()
	end
	monsterFolder = nil
	
	print("[MonsterSpawner] Nettoyage terminé")
end

--[[
	Gère le changement de phase jour/nuit
	Surveille l'attribut "CurrentPhase" dans ReplicatedStorage
]]
local function setupPhaseListener()
	-- Créer ou récupérer un dossier pour les attributs partagés
	local sharedData = ReplicatedStorage:FindFirstChild("SharedData")
	if not sharedData then
		sharedData = Instance.new("Folder")
		sharedData.Name = "SharedData"
		sharedData.Parent = ReplicatedStorage
	end
	
	-- Initialiser l'attribut si nécessaire
	if not sharedData:GetAttribute("CurrentPhase") then
		sharedData:SetAttribute("CurrentPhase", "DAY_PHASE")
	end
	
	if not sharedData:GetAttribute("NightCount") then
		sharedData:SetAttribute("NightCount", 0)
	end
	
	-- Écouter les changements de phase
	sharedData:GetAttributeChangedSignal("CurrentPhase"):Connect(function()
		local currentPhase = sharedData:GetAttribute("CurrentPhase")
		
		if currentPhase == "NIGHT_PHASE" then
			isNightPhase = true
			currentNightCount = sharedData:GetAttribute("NightCount") or 1
			spawnMonsters()
		elseif currentPhase == "DAY_PHASE" then
			isNightPhase = false
			cleanupMonsters()
		end
	end)
	
	print("[MonsterSpawner] Listener de phase initialisé")
end

--[[
	Initialisation du script
]]
local function initialize()
	print("[MonsterSpawner] Initialisation v2.0 (Compatible WorldBuilder 3D)...")
	
	-- Initialiser les portes
	initializeDoors()
	
	-- Configurer l'écoute des phases
	setupPhaseListener()
	
	print("[MonsterSpawner] Prêt!")
end

-- Démarrage
initialize()