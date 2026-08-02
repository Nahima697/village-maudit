--[[
    WorldBuilder.server.luau
    Génère le monde en utilisant les prefabs de ReplicatedStorage
    et tague automatiquement les arbres et rochers pour la récolte
    
    ADAPTATION : Fonctionne avec des MeshParts/BaseParts directs (dossier plat)
    CORRECTION : Validation des tailles et positionnement explicite
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
	DECORATION_DENSITY = 0.3,
	
	-- NOUVELLES CONSTANTES POUR TAILLES PAR DÉFAUT
	DEFAULT_TREE_SIZE = Vector3.new(4, 8, 4),
	DEFAULT_ROCK_SIZE = Vector3.new(3, 3, 3),
	DEFAULT_BUILDING_PART_SIZE = Vector3.new(4, 4, 4),
	DEFAULT_DECORATION_SIZE = Vector3.new(2, 2, 2),
	MIN_VALID_SIZE = 0.1  -- Taille minimum pour considérer un objet comme valide
}

-- ========================================
-- SYSTÈME DE CATÉGORISATION DES PREFABS
-- ========================================

-- Patterns de détection pour catégoriser les prefabs
local PREFAB_PATTERNS = {
	-- Nature
	Trees = {"tree", "oak", "pine", "birch", "sapin", "arbre"},
	Bushes = {"bush", "buisson", "shrub"},
	Grass = {"grass", "herbe", "weed"},
	Rocks = {"rock", "stone", "boulder", "rocher", "pierre"},
	
	-- Bâtiments - Structure
	Walls = {"wall", "mur"},
	Roofs = {"roof", "toit"},
	Floors = {"floor", "sol", "ground"},
	Pillars = {"pillar", "column", "colonne", "poteau"},
	
	-- Bâtiments - Ouvertures
	Doors = {"door", "porte"},
	Windows = {"window", "fenetre", "fenêtre"},
	Gates = {"gate", "portail", "entrance"},
	
	-- Décoration
	Barrels = {"barrel", "tonneau", "crate", "caisse"},
	Benches = {"bench", "banc", "seat"},
	Lamps = {"lamp", "lampe", "lantern", "lanterne", "light"},
	Fences = {"fence", "barriere", "barrière"},
	
	-- Autres
	Signs = {"sign", "panneau", "board"}
}

-- Cache des prefabs catégorisés
local PrefabCache = {}

-- ========================================
-- UTILITAIRES PREFABS - SYSTÈME PLAT
-- ========================================

local function getPrefabsFolder()
	local prefabsFolder = ReplicatedStorage:FindFirstChild("Prefabs")
	if not prefabsFolder then
		warn("WorldBuilder: Dossier Prefabs introuvable dans ReplicatedStorage!")
		return nil
	end
	return prefabsFolder
end

local function matchesPattern(name, patterns)
	local lowerName = string.lower(name)
	for _, pattern in ipairs(patterns) do
		if string.find(lowerName, pattern) then
			return true
		end
	end
	return false
end

local function categorizePrefabs()
	local prefabsFolder = getPrefabsFolder()
	if not prefabsFolder then return end
	
	-- Initialisation du cache
	for category, _ in pairs(PREFAB_PATTERNS) do
		PrefabCache[category] = {}
	end
	PrefabCache.Uncategorized = {}
	
	-- Parcours PLAT de tous les prefabs
	for _, prefab in ipairs(prefabsFolder:GetChildren()) do
		local categorized = false
		
		-- Tenter de catégoriser le prefab
		for category, patterns in pairs(PREFAB_PATTERNS) do
			if matchesPattern(prefab.Name, patterns) then
				table.insert(PrefabCache[category], prefab)
				categorized = true
				break
			end
		end
		
		-- Si aucune catégorie trouvée
		if not categorized then
			table.insert(PrefabCache.Uncategorized, prefab)
		end
	end
	
	-- Rapport de catégorisation
	print("========================================")
	print("WorldBuilder: CATÉGORISATION DES PREFABS")
	print("========================================")
	for category, prefabs in pairs(PrefabCache) do
		if #prefabs > 0 then
			print(string.format("  %s: %d prefab(s)", category, #prefabs))
			for _, prefab in ipairs(prefabs) do
				local prefabType = prefab.ClassName
				print(string.format("    - %s (%s)", prefab.Name, prefabType))
			end
		end
	end
	print("========================================")
end

local function getPrefabsByCategory(category)
	return PrefabCache[category] or {}
end

local function getRandomPrefabFromCategory(category)
	local prefabs = getPrefabsByCategory(category)
	if #prefabs == 0 then return nil end
	return prefabs[math.random(1, #prefabs)]
end

-- ========================================
-- VALIDATION ET CORRECTION DE TAILLE
-- ========================================

local function isValidSize(size)
	-- Vérifie si la taille est valide (non nulle, non NaN)
	if not size then return false end
	if size.X < CONFIG.MIN_VALID_SIZE or size.Y < CONFIG.MIN_VALID_SIZE or size.Z < CONFIG.MIN_VALID_SIZE then
		return false
	end
	-- Vérifie les valeurs NaN
	if size.X ~= size.X or size.Y ~= size.Y or size.Z ~= size.Z then
		return false
	end
	return true
end

local function getDefaultSizeForCategory(category)
	-- Retourne une taille par défaut selon la catégorie
	if category == "Trees" then
		return CONFIG.DEFAULT_TREE_SIZE
	elseif category == "Rocks" then
		return CONFIG.DEFAULT_ROCK_SIZE
	elseif category == "Walls" or category == "Roofs" or category == "Floors" or category == "Pillars" or category == "Doors" or category == "Windows" or category == "Gates" then
		return CONFIG.DEFAULT_BUILDING_PART_SIZE
	else
		return CONFIG.DEFAULT_DECORATION_SIZE
	end
end

local function validateAndFixSize(part, category)
	-- Valide et corrige la taille d'une BasePart si nécessaire
	if not part:IsA("BasePart") then return end
	
	local currentSize = part.Size
	
	if not isValidSize(currentSize) then
		local defaultSize = getDefaultSizeForCategory(category)
		part.Size = defaultSize
		warn(string.format("WorldBuilder: Taille invalide corrigée pour %s (%s) - Nouvelle taille: %s", 
			part.Name, category, tostring(defaultSize)))
	end
end

-- ========================================
-- CLONAGE ET CONFIGURATION DES PREFABS
-- ========================================

local function clonePrefab(prefab, category)
	if not prefab then return nil end
	local clone = prefab:Clone()
	
	-- GESTION DIRECTE DES MESHPARTS / BASEPARTS
	if clone:IsA("BasePart") then
		-- VALIDATION ET CORRECTION DE LA TAILLE
		validateAndFixSize(clone, category or "Uncategorized")
		
		-- Configuration des propriétés de rendu
		clone.Anchored = true
		clone.CanCollide = true
		
		-- S'assurer que la transparence est correcte
		if clone.Transparency >= 1 then
			clone.Transparency = 0
		end
		
	elseif clone:IsA("Model") then
		-- Ancrer et valider toutes les parts du modèle
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				validateAndFixSize(descendant, category or "Uncategorized")
				descendant.Anchored = true
				
				-- S'assurer que la transparence est correcte
				if descendant.Transparency >= 1 then
					descendant.Transparency = 0
				end
			end
		end
		
		-- Définir la PrimaryPart si absente
		if not clone.PrimaryPart then
			local primaryPart = clone:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				clone.PrimaryPart = primaryPart
			end
		end
	end
	
	return clone
end

local function anchorModel(model)
	if model:IsA("BasePart") then
		model.Anchored = true
		model.CanCollide = true
	elseif model:IsA("Model") then
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
	end
end

local function setModelPosition(model, position)
	-- GESTION SIMPLIFIÉE POUR MESHPARTS AVEC VALIDATION
	if model:IsA("BasePart") then
		-- Pour les MeshParts et autres BaseParts directs
		-- Utiliser CFrame pour un positionnement précis
		model.CFrame = CFrame.new(position)
	elseif model:IsA("Model") then
		if model.PrimaryPart then
			model:SetPrimaryPartCFrame(CFrame.new(position))
		else
			local primaryPart = model:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				model.PrimaryPart = primaryPart
				model:SetPrimaryPartCFrame(CFrame.new(position))
			else
				warn(string.format("WorldBuilder: Impossible de positionner %s - Aucune BasePart trouvée", model.Name))
			end
		end
	end
end

local function setModelCFrame(model, cframe)
	-- GESTION SIMPLIFIÉE POUR MESHPARTS AVEC VALIDATION
	if model:IsA("BasePart") then
		-- Pour les MeshParts et autres BaseParts directs
		model.CFrame = cframe
	elseif model:IsA("Model") then
		if model.PrimaryPart then
			model:SetPrimaryPartCFrame(cframe)
		else
			local primaryPart = model:FindFirstChildWhichIsA("BasePart")
			if primaryPart then
				model.PrimaryPart = primaryPart
				model:SetPrimaryPartCFrame(cframe)
			else
				warn(string.format("WorldBuilder: Impossible de positionner %s - Aucune BasePart trouvée", model.Name))
			end
		end
	end
end

local function tagModelAsCollectable(model, resourceType)
	if model:IsA("BasePart") then
		-- Pour les MeshParts directs
		CollectionService:AddTag(model, "Collectable")
		model:SetAttribute("ResourceType", resourceType or "Wood")
	elseif model:IsA("Model") then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				CollectionService:AddTag(part, "Collectable")
				part:SetAttribute("ResourceType", resourceType or "Wood")
			end
		end
	end
end

local function getModelSize(model)
	if model:IsA("BasePart") then
		local size = model.Size
		if isValidSize(size) then
			return size
		else
			warn(string.format("WorldBuilder: Taille invalide détectée pour %s, utilisation de la taille par défaut", model.Name))
			return Vector3.new(4, 4, 4)
		end
	elseif model:IsA("Model") then
		local _, size = model:GetBoundingBox()
		if isValidSize(size) then
			return size
		else
			warn(string.format("WorldBuilder: Taille de modèle invalide pour %s, utilisation de la taille par défaut", model.Name))
			return Vector3.new(4, 4, 4)
		end
	end
	return Vector3.new(4, 4, 4)
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
	
	local treePrefabs = getPrefabsByCategory("Trees")
	local bushPrefabs = getPrefabsByCategory("Bushes")
	local grassPrefabs = getPrefabsByCategory("Grass")
	
	print(string.format("WorldBuilder: Génération forêt avec %d types d'arbres", #treePrefabs))
	
	local successCount = 0
	local failCount = 0
	
	for i = 1, CONFIG.TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.VILLAGE_RADIUS + 15 + math.random() * (CONFIG.FOREST_RADIUS - CONFIG.VILLAGE_RADIUS - 15)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		-- Placement d'un arbre
		local treePrefab = getRandomPrefabFromCategory("Trees")
		if treePrefab then
			local tree = clonePrefab(treePrefab, "Trees")
			
			if tree then
				tree.Name = "Tree_" .. i
				
				-- PARENTING D'ABORD (critique pour MeshParts)
				tree.Parent = treesFolder
				
				-- Calculer la hauteur pour placer correctement
				local treeSize = getModelSize(tree)
				local yPosition = 0.5 + (treeSize.Y / 2)
				local position = Vector3.new(x, yPosition, z)
				
				-- Configuration des propriétés APRÈS parenting
				anchorModel(tree)
				setModelPosition(tree, position)
				tagModelAsCollectable(tree, "Wood")
				
				-- Vérification visuelle finale
				if tree:IsA("BasePart") then
					if tree.Transparency >= 1 then
						tree.Transparency = 0
					end
				end
				
				successCount = successCount + 1
			else
				failCount = failCount + 1
			end
		end
		
		-- Décoration : buissons
		if math.random() < CONFIG.DECORATION_DENSITY then
			local bushPrefab = getRandomPrefabFromCategory("Bushes")
			if bushPrefab then
				local bush = clonePrefab(bushPrefab, "Bushes")
				
				if bush then
					bush.Name = "Bush_" .. i
					
					bush.Parent = treesFolder
					
					local bushSize = getModelSize(bush)
					local offsetX = math.random(-8, 8)
					local offsetZ = math.random(-8, 8)
					local yPosition = 0.5 + (bushSize.Y / 2)
					
					anchorModel(bush)
					setModelPosition(bush, Vector3.new(x + offsetX, yPosition, z + offsetZ))
				end
			end
		end
		
		-- Décoration : herbes
		if math.random() < CONFIG.DECORATION_DENSITY * 0.5 then
			local grassPrefab = getRandomPrefabFromCategory("Grass")
			if grassPrefab then
				local grass = clonePrefab(grassPrefab, "Grass")
				
				if grass then
					grass.Name = "Grass_" .. i
					
					grass.Parent = treesFolder
					
					local grassSize = getModelSize(grass)
					local offsetX = math.random(-5, 5)
					local offsetZ = math.random(-5, 5)
					local yPosition = 0.5 + (grassSize.Y / 2)
					
					anchorModel(grass)
					setModelPosition(grass, Vector3.new(x + offsetX, yPosition, z + offsetZ))
				end
			end
		end
	end
	
	print(string.format("WorldBuilder: Forêt générée - %d/%d arbres instanciés avec succès (%d échecs)", 
		successCount, CONFIG.TREE_COUNT, failCount))
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
	
	local rockPrefabs = getPrefabsByCategory("Rocks")
	
	print(string.format("WorldBuilder: Génération rochers avec %d types", #rockPrefabs))
	
	local successCount = 0
	local failCount = 0
	
	for i = 1, CONFIG.ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.VILLAGE_RADIUS + 5 + math.random() * (CONFIG.FOREST_RADIUS - CONFIG.VILLAGE_RADIUS - 10)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local rockPrefab = getRandomPrefabFromCategory("Rocks")
		if rockPrefab then
			local rock = clonePrefab(rockPrefab, "Rocks")
			
			if rock then
				rock.Name = "Rock_" .. i
				
				-- PARENTING D'ABORD
				rock.Parent = rocksFolder
				
				local rockSize = getModelSize(rock)
				local yPosition = 0.5 + (rockSize.Y / 2)
				local randomRotation = math.random() * math.pi * 2
				
				anchorModel(rock)
				setModelCFrame(rock, CFrame.new(x, yPosition, z) * CFrame.Angles(0, randomRotation, 0))
				tagModelAsCollectable(rock, "Stone")
				
				-- Vérification visuelle finale
				if rock:IsA("BasePart") then
					if rock.Transparency >= 1 then
						rock.Transparency = 0
					end
				end
				
				successCount = successCount + 1
			else
				failCount = failCount + 1
			end
		end
	end
	
	print(string.format("WorldBuilder: %d/%d rochers générés avec succès (%d échecs)", 
		successCount, CONFIG.ROCK_COUNT, failCount))
end

-- ========================================
-- GÉNÉRATION VILLAGE (PREFABS)
-- ========================================

local function createBuilding(position, angle, buildingIndex)
	local building = Instance.new("Model")
	building.Name = "Building_" .. buildingIndex
	
	local baseCFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	
	-- Sol
	local floorPrefab = getRandomPrefabFromCategory("Floors")
	if floorPrefab then
		local floor = clonePrefab(floorPrefab, "Floors")
		if floor then
			floor.Name = "Floor"
			floor.Parent = building
			
			local floorSize = getModelSize(floor)
			local yOffset = 0.5 + (floorSize.Y / 2)
			
			anchorModel(floor)
			setModelCFrame(floor, baseCFrame * CFrame.new(0, yOffset, 0))
		end
	end
	
	-- Murs (4 côtés)
	local wallPrefab = getRandomPrefabFromCategory("Walls")
	if wallPrefab then
		local wallSize = getModelSize(wallPrefab)
		local wallHeight = 0.5 + 3 + (wallSize.Y / 2)
		
		local wallPositions = {
			{offset = CFrame.new(0, wallHeight, -8), rotation = 0},
			{offset = CFrame.new(8, wallHeight, 0), rotation = math.pi/2},
			{offset = CFrame.new(0, wallHeight, 8), rotation = math.pi},
			{offset = CFrame.new(-8, wallHeight, 0), rotation = -math.pi/2}
		}
		
		for i, wallData in ipairs(wallPositions) do
			local wall = clonePrefab(wallPrefab, "Walls")
			if wall then
				wall.Name = "Wall_" .. i
				wall.Parent = building
				anchorModel(wall)
				setModelCFrame(wall, baseCFrame * wallData.offset * CFrame.Angles(0, wallData.rotation, 0))
			end
		end
	end
	
	-- Toit
	local roofPrefab = getRandomPrefabFromCategory("Roofs")
	if roofPrefab then
		local roof = clonePrefab(roofPrefab, "Roofs")
		if roof then
			roof.Name = "Roof"
			roof.Parent = building
			
			local roofSize = getModelSize(roof)
			local roofHeight = 0.5 + 8 + (roofSize.Y / 2)
			
			anchorModel(roof)
			setModelCFrame(roof, baseCFrame * CFrame.new(0, roofHeight, 0))
		end
	end
	
	-- Porte (sur le mur avant)
	local doorPrefab = getRandomPrefabFromCategory("Doors")
	if doorPrefab then
		local door = clonePrefab(doorPrefab, "Doors")
		if door then
			door.Name = "Door"
			door.Parent = building
			
			local doorSize = getModelSize(door)
			local doorHeight = 0.5 + (doorSize.Y / 2)
			
			anchorModel(door)
			setModelCFrame(door, baseCFrame * CFrame.new(0, doorHeight, -8.5))
		end
	end
	
	-- Fenêtres
	local windowPrefab = getRandomPrefabFromCategory("Windows")
	if windowPrefab then
		local windowSize = getModelSize(windowPrefab)
		local windowHeight = 0.5 + 3 + (windowSize.Y / 2)
		
		for i = 1, 3 do
			local window = clonePrefab(windowPrefab, "Windows")
			if window then
				window.Name = "Window_" .. i
				window.Parent = building
				anchorModel(window)
				local windowOffset = CFrame.new((i-2) * 5, windowHeight, -8.5)
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
		
		-- Portail central
		local gatePrefab = getRandomPrefabFromCategory("Gates")
		if gatePrefab then
			local gate = clonePrefab(gatePrefab, "Gates")
			if gate then
				gate.Parent = gateModel
				
				local gateSize = getModelSize(gate)
				local yPosition = 0.5 + (gateSize.Y / 2)
				
				anchorModel(gate)
				setModelCFrame(gate, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0))
			end
		end
		
		-- Piliers de chaque côté
		local pillarPrefab = getRandomPrefabFromCategory("Pillars")
		if pillarPrefab then
			local pillarSize = getModelSize(pillarPrefab)
			local yPosition = 0.5 + (pillarSize.Y / 2)
			
			local leftPillar = clonePrefab(pillarPrefab, "Pillars")
			if leftPillar then
				leftPillar.Name = "LeftPillar"
				leftPillar.Parent = gateModel
				anchorModel(leftPillar)
				local leftOffset = CFrame.new(-8, 0, 0)
				setModelCFrame(leftPillar, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0) * leftOffset)
			end
			
			local rightPillar = clonePrefab(pillarPrefab, "Pillars")
			if rightPillar then
				rightPillar.Name = "RightPillar"
				rightPillar.Parent = gateModel
				anchorModel(rightPillar)
				local rightOffset = CFrame.new(8, 0, 0)
				setModelCFrame(rightPillar, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0) * rightOffset)
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
		
		local benchPrefab = getRandomPrefabFromCategory("Benches")
		if benchPrefab then
			local bench = clonePrefab(benchPrefab, "Benches")
			if bench then
				bench.Name = "Bench_" .. i
				bench.Parent = squareFolder
				
				local benchSize = getModelSize(bench)
				local yPosition = 0.5 + (benchSize.Y / 2)
				
				anchorModel(bench)
				setModelCFrame(bench, CFrame.new(x, yPosition, z) * CFrame.Angles(0, -angle, 0))
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
		if i % 2 == 1 then
			local barrelPrefab = getRandomPrefabFromCategory("Barrels")
			if barrelPrefab then
				local barrel = clonePrefab(barrelPrefab, "Barrels")
				if barrel then
					barrel.Name = "Barrel_" .. i
					barrel.Parent = squareFolder
					
					local barrelSize = getModelSize(barrel)
					local yPosition = 0.5 + (barrelSize.Y / 2)
					
					anchorModel(barrel)
					setModelPosition(barrel, Vector3.new(x, yPosition, z))
				end
			end
		end
		
		-- Lampadaires
		if i % 2 == 0 then
			local lampPrefab = getRandomPrefabFromCategory("Lamps")
			if lampPrefab then
				local lamp = clonePrefab(lampPrefab, "Lamps")
				if lamp then
					lamp.Name = "Lamp_" .. i
					lamp.Parent = squareFolder
					
					local lampSize = getModelSize(lamp)
					local yPosition = 0.5 + (lampSize.Y / 2)
					
					anchorModel(lamp)
					setModelPosition(lamp, Vector3.new(x, yPosition, z))
					
					-- Ajout d'une lumière si pas déjà présente
					local hasLight = false
					if lamp:IsA("BasePart") then
						for _, child in ipairs(lamp:GetChildren()) do
							if child:IsA("PointLight") or child:IsA("SpotLight") then
								hasLight = true
								break
							end
						end
						
						if not hasLight then
							local lampLight = Instance.new("PointLight")
							lampLight.Brightness = 2
							lampLight.Range = 35
							lampLight.Color = Color3.fromRGB(255, 220, 150)
							lampLight.Parent = lamp
						end
					elseif lamp:IsA("Model") then
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
	
	-- Vérification et catégorisation des Prefabs
	local prefabsFolder = getPrefabsFolder()
	if prefabsFolder then
		local prefabCount = #prefabsFolder:GetChildren()
		print("WorldBuilder: " .. prefabCount .. " prefabs détectés (dossier PLAT)")
		
		-- Catégorisation automatique
		categorizePrefabs()
	else
		warn("WorldBuilder: AUCUN PREFAB DÉTECTÉ - Génération impossible")
		-- Ne pas retourner, continuer avec les éléments procéduraux
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