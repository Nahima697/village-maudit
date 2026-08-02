--[[
    WorldBuilder.server.luau
    Génère le monde en utilisant les prefabs de ReplicatedStorage
    et tague automatiquement les arbres et rochers pour la récolte
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ========================================
-- CONFIGURATION
-- ========================================
local CONFIG = {
	TERRAIN_SIZE = 350,
	FOREST_RADIUS = 160,
	VILLAGE_RADIUS = 65,
	TREE_COUNT = 220,
	ROCK_COUNT = 30,
	BUILDING_COUNT = 6,
	MONSTER_SPAWN_COUNT = 6,
	DECORATION_DENSITY = 0.3
}

-- ========================================
-- UTILITAIRES PREFABS
-- ========================================

local function getPrefabsFolder()
	local prefabsFolder = ReplicatedStorage:FindFirstChild("Prefabs")
	if not prefabsFolder then
		warn("WorldBuilder: Dossier Prefabs introuvable dans ReplicatedStorage!")
		return nil
	end
	return prefabsFolder
end

local function findPrefabsByPattern(pattern)
	local prefabsFolder = getPrefabsFolder()
	if not prefabsFolder then return {} end
	
	local matches = {}
	for _, child in ipairs(prefabsFolder:GetChildren()) do
		if string.find(string.lower(child.Name), string.lower(pattern)) then
			table.insert(matches, child)
		end
	end
	return matches
end

local function clonePrefab(prefab)
	if not prefab then return nil end
	return prefab:Clone()
end

local function anchorModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
		end
	end
end

local function setModelPosition(model, position)
	if model:IsA("Model") then
		if model.PrimaryPart then
			model:SetPrimaryPartCFrame(CFrame.new(position))
		else
			local primaryPart = model:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				model.PrimaryPart = primaryPart
				model:SetPrimaryPartCFrame(CFrame.new(position))
			end
		end
	elseif model:IsA("BasePart") then
		model.Position = position
	end
end

local function setModelCFrame(model, cframe)
	if model:IsA("Model") then
		if model.PrimaryPart then
			model:SetPrimaryPartCFrame(cframe)
		else
			local primaryPart = model:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				model.PrimaryPart = primaryPart
				model:SetPrimaryPartCFrame(cframe)
			end
		end
	elseif model:IsA("BasePart") then
		model.CFrame = cframe
	end
end

local function tagModelAsCollectable(model, resourceType)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			CollectionService:AddTag(part, "Collectable")
			part:SetAttribute("ResourceType", resourceType or "Wood")
		end
	end
end

-- ========================================
-- GÉNÉRATION TERRAIN DE BASE
-- ========================================

local function createBasePlate()
	local basePlate = Instance.new("Part")
	basePlate.Name = "BasePlate"
	basePlate.Size = Vector3.new(CONFIG.TERRAIN_SIZE, 1, CONFIG.TERRAIN_SIZE)
	basePlate.Position = Vector3.new(0, 0, 0)
	basePlate.Anchored = true
	basePlate.Color = Color3.fromRGB(95, 115, 55)
	basePlate.Material = Enum.Material.Grass
	basePlate.TopSurface = Enum.SurfaceType.Smooth
	basePlate.BottomSurface = Enum.SurfaceType.Smooth
	basePlate.Parent = workspace
	return basePlate
end

-- ========================================
-- GÉNÉRATION FORÊT (PREFABS)
-- ========================================

local function generateForest()
	local treesFolder = workspace:FindFirstChild("Trees")
	if not treesFolder then
		treesFolder = Instance.new("Folder")
		treesFolder.Name = "Trees"
		treesFolder.Parent = workspace
	else
		treesFolder:ClearAllChildren()
	end
	
	-- Récupération des prefabs
	local treePrefabs = findPrefabsByPattern("tree")
	local bushPrefabs = findPrefabsByPattern("bush")
	local grassPrefabs = findPrefabsByPattern("grass")
	
	print("WorldBuilder: Trouvé " .. #treePrefabs .. " prefabs d'arbres")
	print("WorldBuilder: Trouvé " .. #bushPrefabs .. " prefabs de buissons")
	
	for i = 1, CONFIG.TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.VILLAGE_RADIUS + 15 + math.random() * (CONFIG.FOREST_RADIUS - CONFIG.VILLAGE_RADIUS - 15)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		local position = Vector3.new(x, 0.5, z)
		
		-- Placement d'un arbre
		if #treePrefabs > 0 then
			local randomTree = treePrefabs[math.random(1, #treePrefabs)]
			local tree = clonePrefab(randomTree)
			
			if tree then
				tree.Name = "Tree_" .. i
				tree.Parent = treesFolder
				anchorModel(tree)
				setModelPosition(tree, position + Vector3.new(0, 0, 0))
				tagModelAsCollectable(tree, "Wood")
			end
		end
		
		-- Décoration : buissons
		if math.random() < CONFIG.DECORATION_DENSITY and #bushPrefabs > 0 then
			local randomBush = bushPrefabs[math.random(1, #bushPrefabs)]
			local bush = clonePrefab(randomBush)
			
			if bush then
				bush.Name = "Bush_" .. i
				bush.Parent = treesFolder
				anchorModel(bush)
				local offsetX = math.random(-8, 8)
				local offsetZ = math.random(-8, 8)
				setModelPosition(bush, position + Vector3.new(offsetX, 0, offsetZ))
			end
		end
	end
	
	print("WorldBuilder: Forêt générée avec " .. CONFIG.TREE_COUNT .. " arbres")
end

-- ========================================
-- GÉNÉRATION ROCHERS (PREFABS)
-- ========================================

local function generateRocks()
	local rocksFolder = workspace:FindFirstChild("Rocks")
	if not rocksFolder then
		rocksFolder = Instance.new("Folder")
		rocksFolder.Name = "Rocks"
		rocksFolder.Parent = workspace
	else
		rocksFolder:ClearAllChildren()
	end
	
	local rockPrefabs = findPrefabsByPattern("rock")
	if #rockPrefabs == 0 then
		rockPrefabs = findPrefabsByPattern("stone")
	end
	
	print("WorldBuilder: Trouvé " .. #rockPrefabs .. " prefabs de rochers")
	
	for i = 1, CONFIG.ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.VILLAGE_RADIUS + 5 + math.random() * (CONFIG.FOREST_RADIUS - CONFIG.VILLAGE_RADIUS - 10)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		local position = Vector3.new(x, 0, z)
		
		if #rockPrefabs > 0 then
			local randomRock = rockPrefabs[math.random(1, #rockPrefabs)]
			local rock = clonePrefab(randomRock)
			
			if rock then
				rock.Name = "Rock_" .. i
				rock.Parent = rocksFolder
				anchorModel(rock)
				local randomRotation = math.random() * math.pi * 2
				setModelCFrame(rock, CFrame.new(position) * CFrame.Angles(0, randomRotation, 0))
				tagModelAsCollectable(rock, "Stone")
			end
		end
	end
	
	print("WorldBuilder: " .. CONFIG.ROCK_COUNT .. " rochers générés")
end

-- ========================================
-- GÉNÉRATION VILLAGE (PREFABS)
-- ========================================

local function createBuilding(position, angle, buildingIndex)
	local building = Instance.new("Model")
	building.Name = "Building_" .. buildingIndex
	
	-- Récupération des prefabs de construction
	local wallPrefabs = findPrefabsByPattern("wall")
	local roofPrefabs = findPrefabsByPattern("roof")
	local floorPrefabs = findPrefabsByPattern("floor")
	local doorPrefabs = findPrefabsByPattern("door")
	local windowPrefabs = findPrefabsByPattern("window")
	
	local baseCFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	
	-- Sol
	if #floorPrefabs > 0 then
		local floor = clonePrefab(floorPrefabs[1])
		if floor then
			floor.Name = "Floor"
			floor.Parent = building
			anchorModel(floor)
			setModelCFrame(floor, baseCFrame * CFrame.new(0, 0.5, 0))
		end
	end
	
	-- Murs (4 côtés)
	if #wallPrefabs > 0 then
		local wallPrefab = wallPrefabs[1]
		local wallPositions = {
			{offset = CFrame.new(0, 6, -8), rotation = 0},
			{offset = CFrame.new(8, 6, 0), rotation = math.pi/2},
			{offset = CFrame.new(0, 6, 8), rotation = math.pi},
			{offset = CFrame.new(-8, 6, 0), rotation = -math.pi/2}
		}
		
		for i, wallData in ipairs(wallPositions) do
			local wall = clonePrefab(wallPrefab)
			if wall then
				wall.Name = "Wall_" .. i
				wall.Parent = building
				anchorModel(wall)
				setModelCFrame(wall, baseCFrame * wallData.offset * CFrame.Angles(0, wallData.rotation, 0))
			end
		end
	end
	
	-- Toit
	if #roofPrefabs > 0 then
		local roof = clonePrefab(roofPrefabs[1])
		if roof then
			roof.Name = "Roof"
			roof.Parent = building
			anchorModel(roof)
			setModelCFrame(roof, baseCFrame * CFrame.new(0, 12, 0))
		end
	end
	
	-- Porte (sur le mur avant)
	if #doorPrefabs > 0 then
		local door = clonePrefab(doorPrefabs[1])
		if door then
			door.Name = "Door"
			door.Parent = building
			anchorModel(door)
			setModelCFrame(door, baseCFrame * CFrame.new(0, 3, -8.5))
		end
	end
	
	-- Fenêtres
	if #windowPrefabs > 0 then
		for i = 1, 3 do
			local window = clonePrefab(windowPrefabs[1])
			if window then
				window.Name = "Window_" .. i
				window.Parent = building
				anchorModel(window)
				local windowOffset = CFrame.new((i-2) * 5, 6, -8.5)
				setModelCFrame(window, baseCFrame * windowOffset)
			end
		end
	end
	
	return building
end

local function generateVillage()
	local villageFolder = workspace:FindFirstChild("Village")
	if not villageFolder then
		villageFolder = Instance.new("Folder")
		villageFolder.Name = "Village"
		villageFolder.Parent = workspace
	else
		villageFolder:ClearAllChildren()
	end
	
	print("WorldBuilder: Génération du village avec " .. CONFIG.BUILDING_COUNT .. " bâtiments...")
	
	for i = 1, CONFIG.BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.BUILDING_COUNT)
		local distance = 45
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local building = createBuilding(Vector3.new(x, 0, z), angle - math.pi / 2, i)
		building.Parent = villageFolder
	end
	
	print("WorldBuilder: Village généré!")
end

-- ========================================
-- FORTIFICATIONS & PORTES
-- ========================================

local function createFortifications()
	local villageFolder = workspace:WaitForChild("Village")
	local fortFolder = Instance.new("Folder")
	fortFolder.Name = "Fortifications"
	fortFolder.Parent = villageFolder
	
	local gatePrefabs = findPrefabsByPattern("gate")
	local pillarPrefabs = findPrefabsByPattern("pillar")
	
	local doorPositions = {
		{name = "Gate_North", pos = Vector3.new(0, 0, -75), rot = 0},
		{name = "Gate_East", pos = Vector3.new(75, 0, 0), rot = math.pi / 2},
		{name = "Gate_West", pos = Vector3.new(-75, 0, 0), rot = -math.pi / 2},
		{name = "Gate_South", pos = Vector3.new(0, 0, 75), rot = math.pi}
	}
	
	for _, doorData in ipairs(doorPositions) do
		local gateModel = Instance.new("Model")
		gateModel.Name = doorData.name
		gateModel.Parent = fortFolder
		
		if #gatePrefabs > 0 then
			local gate = clonePrefab(gatePrefabs[1])
			if gate then
				gate.Parent = gateModel
				anchorModel(gate)
				setModelCFrame(gate, CFrame.new(doorData.pos) * CFrame.Angles(0, doorData.rot, 0))
			end
		end
		
		-- Piliers de chaque côté
		if #pillarPrefabs > 0 then
			local pillarPrefab = pillarPrefabs[1]
			
			local leftPillar = clonePrefab(pillarPrefab)
			if leftPillar then
				leftPillar.Name = "LeftPillar"
				leftPillar.Parent = gateModel
				anchorModel(leftPillar)
				local leftOffset = CFrame.new(-8, 0, 0)
				setModelCFrame(leftPillar, CFrame.new(doorData.pos) * CFrame.Angles(0, doorData.rot, 0) * leftOffset)
			end
			
			local rightPillar = clonePrefab(pillarPrefab)
			if rightPillar then
				rightPillar.Name = "RightPillar"
				rightPillar.Parent = gateModel
				anchorModel(rightPillar)
				local rightOffset = CFrame.new(8, 0, 0)
				setModelCFrame(rightPillar, CFrame.new(doorData.pos) * CFrame.Angles(0, doorData.rot, 0) * rightOffset)
			end
		end
	end
	
	print("WorldBuilder: Fortifications créées")
end

-- ========================================
-- PLACE CENTRALE
-- ========================================

local function createCentralSquare()
	local villageFolder = workspace:WaitForChild("Village")
	local squareFolder = Instance.new("Folder")
	squareFolder.Name = "CentralSquare"
	squareFolder.Parent = villageFolder
	
	local barrelPrefabs = findPrefabsByPattern("barrel")
	local benchPrefabs = findPrefabsByPattern("bench")
	local lampPrefabs = findPrefabsByPattern("lamp")
	
	-- Feu de camp central
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
	
	-- Bancs autour du feu
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi * 2 / 4) + (math.pi / 4)
		local distance = 14
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		if #benchPrefabs > 0 then
			local bench = clonePrefab(benchPrefabs[1])
			if bench then
				bench.Name = "Bench_" .. i
				bench.Parent = squareFolder
				anchorModel(bench)
				setModelCFrame(bench, CFrame.new(x, 1, z) * CFrame.Angles(0, -angle, 0))
			end
		end
	end
	
	-- Décorations périphériques
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local distance = 25
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		-- Barils
		if #barrelPrefabs > 0 and i % 2 == 1 then
			local barrel = clonePrefab(barrelPrefabs[1])
			if barrel then
				barrel.Name = "Barrel_" .. i
				barrel.Parent = squareFolder
				anchorModel(barrel)
				setModelPosition(barrel, Vector3.new(x, 0, z))
			end
		end
		
		-- Lampadaires
		if #lampPrefabs > 0 and i % 2 == 0 then
			local lamp = clonePrefab(lampPrefabs[1])
			if lamp then
				lamp.Name = "Lamp_" .. i
				lamp.Parent = squareFolder
				anchorModel(lamp)
				setModelPosition(lamp, Vector3.new(x, 0, z))
				
				-- Ajout d'une lumière si pas déjà présente
				local hasLight = false
				for _, desc in ipairs(lamp:GetDescendants()) do
					if desc:IsA("PointLight") or desc:IsA("SpotLight") then
						hasLight = true
						break
					end
				end
				
				if not hasLight then
					local lampPart = lamp:FindFirstChildWhichIsA("BasePart")
					if lampPart then
						local lampLight = Instance.new("PointLight")
						lampLight.Brightness = 2
						lampLight.Range = 35
						lampLight.Color = Color3.fromRGB(255, 220, 150)
						lampLight.Parent = lampPart
					end
				end
			end
		end
	end
	
	print("WorldBuilder: Place centrale créée")
end

-- ========================================
-- POINTS DE SPAWN MONSTRES
-- ========================================

local function createMonsterSpawns()
	local spawnFolder = workspace:FindFirstChild("MonsterSpawns")
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name = "MonsterSpawns"
		spawnFolder.Parent = workspace
	else
		spawnFolder:ClearAllChildren()
	end
	
	for i = 1, CONFIG.MONSTER_SPAWN_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.MONSTER_SPAWN_COUNT)
		local distance = CONFIG.FOREST_RADIUS - 20
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
	
	print("WorldBuilder: " .. CONFIG.MONSTER_SPAWN_COUNT .. " points de spawn créés")
end

-- ========================================
-- CONFIGURATION ÉCLAIRAGE
-- ========================================

local function configureLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 12
	lighting.Brightness = 2.2
	lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
	lighting.Ambient = Color3.fromRGB(110, 110, 110)
	lighting.FogEnd = 600
	
	print("WorldBuilder: Éclairage configuré")
end

-- ========================================
-- FONCTION PRINCIPALE DE GÉNÉRATION
-- ========================================

local function generateWorld()
	print("========================================")
	print("WorldBuilder: DÉBUT DE LA GÉNÉRATION DU MONDE")
	print("========================================")
	
	-- Vérification des Prefabs
	local prefabsFolder = getPrefabsFolder()
	if prefabsFolder then
		local prefabCount = #prefabsFolder:GetChildren()
		print("WorldBuilder: " .. prefabCount .. " prefabs détectés")
	else
		warn("WorldBuilder: AUCUN PREFAB DÉTECTÉ - Génération impossible")
	end
	
	-- Génération du terrain
	createBasePlate()
	print("✓ BasePlate créée")
	
	-- Génération des ressources naturelles
	generateForest()
	print("✓ Forêt générée")
	
	generateRocks()
	print("✓ Rochers générés")
	
	-- Génération du village
	generateVillage()
	print("✓ Village généré")
	
	createFortifications()
	print("✓ Fortifications créées")
	
	createCentralSquare()
	print("✓ Place centrale créée")
	
	-- Génération des spawns
	createMonsterSpawns()
	print("✓ Points de spawn créés")
	
	-- Configuration finale
	configureLighting()
	print("✓ Éclairage configuré")
	
	print("========================================")
	print("WorldBuilder: MONDE GÉNÉRÉ AVEC SUCCÈS!")
	print("========================================")
end

-- ========================================
-- EXÉCUTION AUTOMATIQUE
-- ========================================

generateWorld()