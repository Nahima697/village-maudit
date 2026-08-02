--[[
    WorldBuilder.server.luau
    Génère le monde en utilisant les prefabs de ReplicatedStorage
    et tague automatiquement les arbres et rochers pour la récolte
]]

local WorldBuilder = {}
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TERRAIN_SIZE = 350
local FOREST_RADIUS = 160
local VILLAGE_RADIUS = 65
local TREE_COUNT = 220
local ROCK_COUNT = 30
local BUILDING_COUNT = 6
local MONSTER_SPAWN_COUNT = 6

-- Fonction pour cloner un prefab de manière sécurisée
local function clonePrefab(prefabName)
	local prefabsFolder = ReplicatedStorage:FindFirstChild("Prefabs")
	if not prefabsFolder then
		warn("WorldBuilder: Dossier Prefabs introuvable dans ReplicatedStorage!")
		return nil
	end
	
	local prefab = prefabsFolder:FindFirstChild(prefabName)
	if prefab then
		return prefab:Clone()
	end
	return nil
end

-- Fonction pour trouver des prefabs par pattern dans leur nom
local function findPrefabsByPattern(pattern)
	local prefabsFolder = ReplicatedStorage:FindFirstChild("Prefabs")
	if not prefabsFolder then return {} end
	
	local matches = {}
	for _, child in ipairs(prefabsFolder:GetChildren()) do
		if string.find(string.lower(child.Name), string.lower(pattern)) then
			table.insert(matches, child.Name)
		end
	end
	return matches
end

local function createBasePlate()
	local basePlate = Instance.new("Part")
	basePlate.Name = "BasePlate"
	basePlate.Size = Vector3.new(TERRAIN_SIZE, 1, TERRAIN_SIZE)
	basePlate.Position = Vector3.new(0, 0, 0)
	basePlate.Anchored = true
	basePlate.Color = Color3.fromRGB(95, 115, 55)
	basePlate.Material = Enum.Material.Grass
	basePlate.TopSurface = Enum.SurfaceType.Smooth
	basePlate.BottomSurface = Enum.SurfaceType.Smooth
	basePlate.Parent = workspace
	return basePlate
end

-- Fonction pour ancrer récursivement tous les parts d'un modèle
local function anchorModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

-- Fonction pour positionner un modèle avec CFrame
local function setModelCFrame(model, cframe)
	if model.PrimaryPart then
		model:SetPrimaryPartCFrame(cframe)
	elseif model:IsA("Model") and model:FindFirstChildWhichIsA("BasePart") then
		local primaryPart = model:FindFirstChildWhichIsA("BasePart")
		model.PrimaryPart = primaryPart
		model:SetPrimaryPartCFrame(cframe)
	end
end

local function createTree(position)
	-- Cherche des prefabs d'arbres
	local treePrefabs = findPrefabsByPattern("tree")
	
	if #treePrefabs > 0 then
		-- Utilise un prefab aléatoire
		local randomTree = treePrefabs[math.random(1, #treePrefabs)]
		local tree = clonePrefab(randomTree)
		
		if tree then
			tree.Parent = workspace.Trees
			anchorModel(tree)
			setModelCFrame(tree, CFrame.new(position + Vector3.new(0, 5, 0)))
			
			-- Tag tous les parts pour la récolte
			for _, part in ipairs(tree:GetDescendants()) do
				if part:IsA("BasePart") then
					CollectionService:AddTag(part, "Collectable")
				end
			end
			return
		end
	end
	
	-- Fallback : génération procédurale classique
	local trunk = Instance.new("Part")
	trunk.Name = "TreeTrunk"
	trunk.Size = Vector3.new(3, 10, 3)
	trunk.Position = position + Vector3.new(0, trunk.Size.Y / 2, 0)
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(85, 55, 35)
	trunk.Parent = workspace.Trees
	CollectionService:AddTag(trunk, "Collectable")
	
	local leaves = Instance.new("Part")
	leaves.Name = "TreeLeaves"
	leaves.Size = Vector3.new(10, 10, 10)
	leaves.Position = trunk.Position + Vector3.new(0, trunk.Size.Y / 2, 0)
	leaves.Anchored = true
	leaves.Material = Enum.Material.LeafyGrass
	leaves.Color = Color3.fromRGB(40, 75, 45)
	leaves.Shape = Enum.PartType.Ball
	leaves.Parent = workspace.Trees
	CollectionService:AddTag(leaves, "Collectable")
end

local function generateForest()
	local treesFolder = workspace:FindFirstChild("Trees")
	if not treesFolder then
		treesFolder = Instance.new("Folder")
		treesFolder.Name = "Trees"
		treesFolder.Parent = workspace
	else
		treesFolder:ClearAllChildren()
	end
	
	-- Cherche aussi des buissons et herbes
	local bushPrefabs = findPrefabsByPattern("bush")
	local grassPrefabs = findPrefabsByPattern("grass")
	
	for i = 1, TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = VILLAGE_RADIUS + 15 + math.random() * (FOREST_RADIUS - VILLAGE_RADIUS - 15)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		createTree(Vector3.new(x, 0.5, z))
		
		-- Ajoute parfois des buissons
		if math.random() < 0.3 and #bushPrefabs > 0 then
			local bush = clonePrefab(bushPrefabs[math.random(1, #bushPrefabs)])
			if bush then
				bush.Parent = treesFolder
				anchorModel(bush)
				setModelCFrame(bush, CFrame.new(x + math.random(-5, 5), 0.5, z + math.random(-5, 5)))
			end
		end
	end
end

local function generateRocks()
	local rocksFolder = workspace:FindFirstChild("Rocks")
	if not rocksFolder then
		rocksFolder = Instance.new("Folder")
		rocksFolder.Name = "Rocks"
		rocksFolder.Parent = workspace
	else
		rocksFolder:ClearAllChildren()
	end
	
	-- Cherche des prefabs de rochers
	local rockPrefabs = findPrefabsByPattern("rock")
	if #rockPrefabs == 0 then
		rockPrefabs = findPrefabsByPattern("stone")
	end
	
	for i = 1, ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = VILLAGE_RADIUS + 5 + math.random() * (FOREST_RADIUS - VILLAGE_RADIUS - 10)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		if #rockPrefabs > 0 then
			local rock = clonePrefab(rockPrefabs[math.random(1, #rockPrefabs)])
			if rock then
				rock.Parent = rocksFolder
				anchorModel(rock)
				setModelCFrame(rock, CFrame.new(x, 2, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
				
				-- Tag pour la récolte
				for _, part in ipairs(rock:GetDescendants()) do
					if part:IsA("BasePart") then
						CollectionService:AddTag(part, "Collectable")
					end
				end
			end
		else
			-- Fallback
			local rock = Instance.new("Part")
			rock.Name = "Rock"
			rock.Size = Vector3.new(6, 4, 6)
			rock.Position = Vector3.new(x, rock.Size.Y / 2, z)
			rock.Anchored = true
			rock.Material = Enum.Material.Slate
			rock.Color = Color3.fromRGB(120, 120, 125)
			rock.Shape = Enum.PartType.Ball
			rock.Parent = rocksFolder
			CollectionService:AddTag(rock, "Collectable")
		end
	end
end

local function createBuilding(position, angle)
	local building = Instance.new("Model")
	building.Name = "Building"
	building.Parent = workspace.Village
	
	local cframe = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	
	-- Cherche des prefabs de murs, toits, sols
	local wallPrefabs = findPrefabsByPattern("wall")
	local roofPrefabs = findPrefabsByPattern("roof")
	local floorPrefabs = findPrefabsByPattern("floor")
	local cornerPrefabs = findPrefabsByPattern("corner")
	
	-- Si on a des prefabs, construis avec eux
	if #wallPrefabs > 0 and #roofPrefabs > 0 then
		local wallPrefab = wallPrefabs[1]
		local roofPrefab = roofPrefabs[1]
		
		-- Sol
		if #floorPrefabs > 0 then
			local floor = clonePrefab(floorPrefabs[1])
			if floor then
				floor.Parent = building
				anchorModel(floor)
				setModelCFrame(floor, cframe * CFrame.new(0, 0.5, 0))
			end
		end
		
		-- Murs (4 côtés)
		for i = 0, 3 do
			local wallAngle = i * math.pi / 2
			local wall = clonePrefab(wallPrefab)
			if wall then
				wall.Parent = building
				anchorModel(wall)
				setModelCFrame(wall, cframe * CFrame.new(0, 6, -8) * CFrame.Angles(0, wallAngle, 0))
			end
		end
		
		-- Toit
		local roof = clonePrefab(roofPrefab)
		if roof then
			roof.Parent = building
			anchorModel(roof)
			setModelCFrame(roof, cframe * CFrame.new(0, 12, 0))
		end
		
		-- Coins si disponibles
		if #cornerPrefabs > 0 then
			for i = 0, 3 do
				local cornerAngle = i * math.pi / 2
				local corner = clonePrefab(cornerPrefabs[1])
				if corner then
					corner.Parent = building
					anchorModel(corner)
					setModelCFrame(corner, cframe * CFrame.new(8, 6, -8) * CFrame.Angles(0, cornerAngle, 0))
				end
			end
		end
		
		return
	end
	
	-- Fallback : génération procédurale classique
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(20, 1, 16)
	floor.CFrame = cframe + Vector3.new(0, 0.5, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(110, 80, 55)
	floor.Parent = building
	
	local wallFront = Instance.new("Part")
	wallFront.Name = "WallFront"
	wallFront.Size = Vector3.new(20, 12, 1)
	wallFront.CFrame = cframe * CFrame.new(0, 6.5, -8)
	wallFront.Anchored = true
	wallFront.Material = Enum.Material.Cobblestone
	wallFront.Color = Color3.fromRGB(125, 125, 125)
	wallFront.Parent = building

	local wallBack = Instance.new("Part")
	wallBack.Name = "WallBack"
	wallBack.Size = Vector3.new(20, 12, 1)
	wallBack.CFrame = cframe * CFrame.new(0, 6.5, 8)
	wallBack.Anchored = true
	wallBack.Material = Enum.Material.Cobblestone
	wallBack.Color = Color3.fromRGB(125, 125, 125)
	wallBack.Parent = building

	local wallLeft = Instance.new("Part")
	wallLeft.Name = "WallLeft"
	wallLeft.Size = Vector3.new(1, 12, 16)
	wallLeft.CFrame = cframe * CFrame.new(-10, 6.5, 0)
	wallLeft.Anchored = true
	wallLeft.Material = Enum.Material.Cobblestone
	wallLeft.Color = Color3.fromRGB(125, 125, 125)
	wallLeft.Parent = building

	local wallRight = Instance.new("Part")
	wallRight.Name = "WallRight"
	wallRight.Size = Vector3.new(1, 12, 16)
	wallRight.CFrame = cframe * CFrame.new(10, 6.5, 0)
	wallRight.Anchored = true
	wallRight.Material = Enum.Material.Cobblestone
	wallRight.Color = Color3.fromRGB(125, 125, 125)
	wallRight.Parent = building
	
	-- Toit simple
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Size = Vector3.new(22, 1, 18)
	roof.CFrame = cframe * CFrame.new(0, 13, 0)
	roof.Anchored = true
	roof.Material = Enum.Material.Slate
	roof.Color = Color3.fromRGB(65, 45, 35)
	roof.Parent = building
end

local function createVillage()
	local villageFolder = workspace:FindFirstChild("Village")
	if not villageFolder then
		villageFolder = Instance.new("Folder")
		villageFolder.Name = "Village"
		villageFolder.Parent = workspace
	else
		villageFolder:ClearAllChildren()
	end
	
	print("WorldBuilder: Génération du village avec " .. BUILDING_COUNT .. " bâtiments...")
	
	for i = 1, BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / BUILDING_COUNT)
		local distance = 45
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		createBuilding(Vector3.new(x, 0, z), angle - math.pi / 2)
	end
	
	print("WorldBuilder: Village généré!")
end

local function createFortifications()
	local villageFolder = workspace:WaitForChild("Village")
	local fortFolder = Instance.new("Folder")
	fortFolder.Name = "Fortifications"
	fortFolder.Parent = villageFolder
	
	-- Cherche des prefabs de portes ou piliers
	local gatePrefabs = findPrefabsByPattern("gate")
	local pillarPrefabs = findPrefabsByPattern("pillar")
	
	local doorPositions = {
		{name = "Door_North", pos = Vector3.new(0, 6, -75), rot = 0},
		{name = "Door_East", pos = Vector3.new(75, 6, 0), rot = math.pi / 2},
		{name = "Door_West", pos = Vector3.new(-75, 6, 0), rot = -math.pi / 2},
		{name = "Door_South", pos = Vector3.new(0, 6, 75), rot = math.pi}
	}
	
	for _, doorData in ipairs(doorPositions) do
		local doorFrame = Instance.new("Model")
		doorFrame.Name = doorData.name
		doorFrame.Parent = fortFolder
		
		if #gatePrefabs > 0 then
			local gate = clonePrefab(gatePrefabs[1])
			if gate then
				gate.Parent = doorFrame
				anchorModel(gate)
				setModelCFrame(gate, CFrame.new(doorData.pos) * CFrame.Angles(0, doorData.rot, 0))
			end
		else
			-- Fallback
			local leftPillar = Instance.new("Part")
			leftPillar.Name = "LeftPillar"
			leftPillar.Size = Vector3.new(4, 12, 4)
			leftPillar.Anchored = true
			leftPillar.Material = Enum.Material.Cobblestone
			leftPillar.Color = Color3.fromRGB(90, 90, 90)
			leftPillar.Parent = doorFrame
			
			local rightPillar = leftPillar:Clone()
			rightPillar.Name = "RightPillar"
			rightPillar.Parent = doorFrame
			
			local archway = Instance.new("Part")
			archway.Name = "Archway"
			archway.Size = Vector3.new(14, 4, 4)
			archway.Anchored = true
			archway.Material = Enum.Material.Cobblestone
			archway.Color = Color3.fromRGB(90, 90, 90)
			archway.Parent = doorFrame
			
			leftPillar.Position = doorData.pos + Vector3.new(-6 * math.cos(doorData.rot + math.pi / 2), 0, -6 * math.sin(doorData.rot + math.pi / 2))
			rightPillar.Position = doorData.pos + Vector3.new(6 * math.cos(doorData.rot + math.pi / 2), 0, 6 * math.sin(doorData.rot + math.pi / 2))
			archway.Position = doorData.pos + Vector3.new(0, 11, 0)
		end
	end
end

local function createCentralSquare()
	local villageFolder = workspace:WaitForChild("Village")
	local squareFolder = Instance.new("Folder")
	squareFolder.Name = "CentralSquare"
	squareFolder.Parent = villageFolder
	
	-- Cherche des prefabs de décorations
	local barrelPrefabs = findPrefabsByPattern("barrel")
	local benchPrefabs = findPrefabsByPattern("bench")
	
	local campfire = Instance.new("Part")
	campfire.Name = "Campfire"
	campfire.Size = Vector3.new(7, 2, 7)
	campfire.Position = Vector3.new(0, 1, 0)
	campfire.Anchored = true
	campfire.Material = Enum.Material.Cobblestone
	campfire.Color = Color3.fromRGB(50, 50, 50)
	campfire.Shape = Enum.PartType.Cylinder
	campfire.Orientation = Vector3.new(0, 0, 90)
	campfire.Parent = squareFolder
	
	local fire = Instance.new("Fire")
	fire.Size = 18
	fire.Heat = 15
	fire.Parent = campfire
	
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 50
	light.Color = Color3.fromRGB(255, 140, 40)
	light.Parent = campfire
	
	-- Bancs
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi * 2 / 4) + (math.pi / 4)
		local distance = 14
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		if #benchPrefabs > 0 then
			local bench = clonePrefab(benchPrefabs[1])
			if bench then
				bench.Parent = squareFolder
				anchorModel(bench)
				setModelCFrame(bench, CFrame.new(x, 1.2, z) * CFrame.Angles(0, -angle, 0))
			end
		else
			local bench = Instance.new("Part")
			bench.Name = "Bench"
			bench.Size = Vector3.new(6, 1.2, 2)
			bench.Position = Vector3.new(x, 1.2, z)
			bench.Orientation = Vector3.new(0, math.deg(-angle), 0)
			bench.Anchored = true
			bench.Material = Enum.Material.Wood
			bench.Color = Color3.fromRGB(100, 70, 45)
			bench.Parent = squareFolder
		end
	end
	
	-- Barils et lampadaires
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local distance = 25
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		if #barrelPrefabs > 0 then
			local barrel = clonePrefab(barrelPrefabs[1])
			if barrel then
				barrel.Parent = squareFolder
				anchorModel(barrel)
				setModelCFrame(barrel, CFrame.new(x, 2.25, z))
			end
		else
			local barrel = Instance.new("Part")
			barrel.Name = "Barrel"
			barrel.Size = Vector3.new(3.5, 4.5, 3.5)
			barrel.Position = Vector3.new(x, 2.25, z)
			barrel.Anchored = true
			barrel.Material = Enum.Material.Wood
			barrel.Color = Color3.fromRGB(80, 55, 35)
			barrel.Shape = Enum.PartType.Cylinder
			barrel.Parent = squareFolder
		end
		
		if i % 2 == 0 then
			local lampPost = Instance.new("Part")
			lampPost.Name = "LampPost"
			lampPost.Size = Vector3.new(1.2, 12, 1.2)
			lampPost.Position = Vector3.new(x, 6.5, z)
			lampPost.Anchored = true
			lampPost.Material = Enum.Material.Metal
			lampPost.Color = Color3.fromRGB(45, 45, 45)
			lampPost.Parent = squareFolder
			
			local lamp = Instance.new("Part")
			lamp.Name = "Lamp"
			lamp.Size = Vector3.new(2.5, 2.5, 2.5)
			lamp.Position = Vector3.new(x, 13, z)
			lamp.Anchored = true
			lamp.Material = Enum.Material.Neon
			lamp.Color = Color3.fromRGB(255, 220, 150)
			lamp.Shape = Enum.PartType.Ball
			lamp.Parent = squareFolder
			
			local lampLight = Instance.new("PointLight")
			lampLight.Brightness = 2
			lampLight.Range = 35
			lampLight.Color = Color3.fromRGB(255, 220, 150)
			lampLight.Parent = lamp
		end
	end
end

local function createMonsterSpawns()
	local spawnFolder = workspace:FindFirstChild("MonsterSpawns")
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name = "MonsterSpawns"
		spawnFolder.Parent = workspace
	else
		spawnFolder:ClearAllChildren()
	end
	
	for i = 1, MONSTER_SPAWN_COUNT do
		local angle = (i - 1) * (math.pi * 2 / MONSTER_SPAWN_COUNT)
		local distance = FOREST_RADIUS - 20
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local spawn = Instance.new("Part")
		spawn.Name = "MonsterSpawn_" .. i
		spawn.Size = Vector3.new(5, 1, 5)
		spawn.Position = Vector3.new(x, 1, z)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = spawnFolder
		
		CollectionService:AddTag(spawn, "MonsterSpawnPoint")
	end
end

local function configureLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 12
	lighting.Brightness = 2.2
	lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
	lighting.Ambient = Color3.fromRGB(110, 110, 110)
	lighting.FogEnd = 600
end

function WorldBuilder.Generate()
	print("WorldBuilder: Début de la génération du monde...")
	
	createBasePlate()
	print("WorldBuilder: BasePlate créée")
	
	generateForest()
	print("WorldBuilder: Forêt générée avec prefabs")
	
	generateRocks()
	print("WorldBuilder: Rochers générés avec prefabs")
	
	createVillage()
	createFortifications()
	createCentralSquare()
	createMonsterSpawns()
	configureLighting()
	
	print("WorldBuilder: Monde généré avec succès! Ressources taguées pour la récolte.")
end

-- Génération automatique au démarrage du serveur
WorldBuilder.Generate()