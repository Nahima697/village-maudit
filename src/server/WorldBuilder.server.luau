--[[
    WorldBuilder.server.luau
    Génère le monde en utilisant les prefabs de ReplicatedStorage
    et tague automatiquement les arbres et rochers pour la récolte
    
    VERSION 3 : Détection élargie des prefabs architecturaux + garantie visuelle maximale
    - Patterns de détection étendus pour murs/structures
    - Fallback automatique sur prefabs disponibles
    - Validation renforcée de la visibilité
    - Dimensionnement forcé des composants
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
	
	-- Tailles par défaut
	DEFAULT_TREE_SIZE = Vector3.new(4, 8, 4),
	DEFAULT_ROCK_SIZE = Vector3.new(3, 3, 3),
	DEFAULT_BUILDING_PART_SIZE = Vector3.new(4, 4, 4),
	DEFAULT_DECORATION_SIZE = Vector3.new(2, 2, 2),
	MIN_VALID_SIZE = 0.1,
	
	-- Architecture des bâtiments
	BUILDING_WIDTH = 16,
	BUILDING_DEPTH = 16,
	BUILDING_HEIGHT = 8,
	FLOOR_HEIGHT = 0.5,
	WALL_THICKNESS = 0.5,
	ROOF_HEIGHT = 3,
	DOOR_WIDTH = 3,
	WINDOW_SIZE = 2,
}

-- ========================================
-- SYSTÈME DE CATÉGORISATION ÉLARGI
-- ========================================

local PREFAB_PATTERNS = {
	-- Nature
	Trees = {"tree", "oak", "pine", "birch", "sapin", "arbre", "trunk"},
	Bushes = {"bush", "buisson", "shrub", "hedge"},
	Grass = {"grass", "herbe", "weed", "plant"},
	Rocks = {"rock", "stone", "boulder", "rocher", "pierre"},
	
	-- Bâtiments - Structure (DÉTECTION ÉLARGIE)
	Walls = {
		"wall", "mur", 
		"house", "building", "structure", 
		"pillar", "column", "colonne", "poteau",
		"corner", "angle", "side", "facade",
		"panel", "panneau", "plank", "planche"
	},
	Roofs = {"roof", "toit", "ceiling", "plafond", "top", "cover"},
	Floors = {"floor", "sol", "ground", "base", "platform", "plateforme"},
	Pillars = {"pillar", "column", "colonne", "poteau", "post", "support"},
	
	-- Bâtiments - Ouvertures
	Doors = {"door", "porte", "entry", "entree", "entrance"},
	Windows = {"window", "fenetre", "fenêtre", "opening"},
	Gates = {"gate", "portail", "entrance", "arch", "arche"},
	
	-- Décoration
	Barrels = {"barrel", "tonneau", "crate", "caisse", "box", "container"},
	Benches = {"bench", "banc", "seat", "chair", "chaise"},
	Lamps = {"lamp", "lampe", "lantern", "lanterne", "light", "lumiere", "torch"},
	Fences = {"fence", "barriere", "barrière", "railing", "guard"},
	
	-- Autres
	Signs = {"sign", "panneau", "board", "plaque"}
}

local PrefabCache = {}

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
	PrefabCache.AllPrefabs = {}  -- Nouvelle catégorie : TOUS les prefabs
	
	-- Parcours de tous les prefabs
	for _, prefab in ipairs(prefabsFolder:GetChildren()) do
		table.insert(PrefabCache.AllPrefabs, prefab)
		
		local categorized = false
		
		-- Tenter de catégoriser le prefab
		for category, patterns in pairs(PREFAB_PATTERNS) do
			if matchesPattern(prefab.Name, patterns) then
				table.insert(PrefabCache[category], prefab)
				categorized = true
				-- Ne pas break : un prefab peut appartenir à plusieurs catégories
			end
		end
		
		-- Si aucune catégorie trouvée
		if not categorized then
			table.insert(PrefabCache.Uncategorized, prefab)
		end
	end
	
	-- Rapport de catégorisation
	print("========================================")
	print("WorldBuilder: CATÉGORISATION DES PREFABS (ÉLARGIE)")
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

-- NOUVEAU : Fallback intelligent sur prefabs disponibles
local function getRandomPrefabWithFallback(preferredCategory, fallbackCategories)
	-- Essayer la catégorie préférée d'abord
	local prefab = getRandomPrefabFromCategory(preferredCategory)
	if prefab then
		return prefab, preferredCategory
	end
	
	-- Essayer les catégories de fallback
	for _, fallbackCategory in ipairs(fallbackCategories) do
		prefab = getRandomPrefabFromCategory(fallbackCategory)
		if prefab then
			warn(string.format("WorldBuilder: Utilisation de %s comme fallback pour %s", fallbackCategory, preferredCategory))
			return prefab, fallbackCategory
		end
	end
	
	-- Dernier recours : prendre n'importe quel prefab
	if #PrefabCache.AllPrefabs > 0 then
		prefab = PrefabCache.AllPrefabs[math.random(1, #PrefabCache.AllPrefabs)]
		warn(string.format("WorldBuilder: Utilisation de prefab aléatoire '%s' comme fallback pour %s", prefab.Name, preferredCategory))
		return prefab, "Random"
	end
	
	return nil, nil
end

-- ========================================
-- VALIDATION ET CORRECTION
-- ========================================

local function isValidSize(size)
	if not size then return false end
	if size.X < CONFIG.MIN_VALID_SIZE or size.Y < CONFIG.MIN_VALID_SIZE or size.Z < CONFIG.MIN_VALID_SIZE then
		return false
	end
	if size.X ~= size.X or size.Y ~= size.Y or size.Z ~= size.Z then
		return false
	end
	return true
end

local function getDefaultSizeForCategory(category)
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
-- CLONAGE AMÉLIORÉ AVEC GARANTIE VISUELLE
-- ========================================

local function forceVisibility(part)
	-- Force TOUS les paramètres de visibilité
	if not part:IsA("BasePart") then return end
	
	part.Transparency = 0
	part.CanCollide = true
	part.Anchored = true
	part.CastShadow = true
	
	-- Forcer un matériau visible
	if part.Material == Enum.Material.Plastic then
		part.Material = Enum.Material.SmoothPlastic
	end
	
	-- Forcer une couleur visible si trop transparente
	if part.Color == Color3.new(1, 1, 1) then
		part.Color = Color3.fromRGB(200, 200, 200)
	end
	
	-- Pour les MeshParts, vérifier le MeshId
	if part:IsA("MeshPart") then
		if part.MeshId == "" or part.MeshId == "rbxasset://fonts/leftarm.mesh" then
			warn(string.format("WorldBuilder: MeshPart %s a un MeshId invalide/vide", part.Name))
		end
	end
end

local function clonePrefabDeep(prefab, category)
	if not prefab then return nil end
	
	local clone = prefab:Clone()
	
	if clone:IsA("BasePart") then
		validateAndFixSize(clone, category or "Uncategorized")
		forceVisibility(clone)
		
		print(string.format("✓ BasePart cloné: %s | Size: %s | Material: %s", 
			clone.Name, 
			tostring(clone.Size), 
			tostring(clone.Material)))
		
	elseif clone:IsA("Model") then
		local partCount = 0
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				validateAndFixSize(descendant, category or "Uncategorized")
				forceVisibility(descendant)
				partCount = partCount + 1
			end
		end
		
		print(string.format("✓ Model cloné: %s avec %d BaseParts", clone.Name, partCount))
		
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

local function setModelCFrame(model, cframe)
	if model:IsA("BasePart") then
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

local function setModelPosition(model, position)
	setModelCFrame(model, CFrame.new(position))
end

local function tagModelAsCollectable(model, resourceType)
	if model:IsA("BasePart") then
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
-- GÉNÉRATION FORÊT
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
		
		local treePrefab = getRandomPrefabFromCategory("Trees")
		if treePrefab then
			local tree = clonePrefabDeep(treePrefab, "Trees")
			
			if tree then
				tree.Name = "Tree_" .. i
				
				local treeSize = getModelSize(tree)
				local yPosition = 0.5 + (treeSize.Y / 2)
				local position = Vector3.new(x, yPosition, z)
				
				anchorModel(tree)
				setModelPosition(tree, position)
				tagModelAsCollectable(tree, "Wood")
				
				tree.Parent = treesFolder
				
				successCount = successCount + 1
			else
				failCount = failCount + 1
			end
		end
		
		if math.random() < CONFIG.DECORATION_DENSITY then
			local bushPrefab = getRandomPrefabFromCategory("Bushes")
			if bushPrefab then
				local bush = clonePrefabDeep(bushPrefab, "Bushes")
				
				if bush then
					bush.Name = "Bush_" .. i
					
					local bushSize = getModelSize(bush)
					local offsetX = math.random(-8, 8)
					local offsetZ = math.random(-8, 8)
					local yPosition = 0.5 + (bushSize.Y / 2)
					
					anchorModel(bush)
					setModelPosition(bush, Vector3.new(x + offsetX, yPosition, z + offsetZ))
					
					bush.Parent = treesFolder
				end
			end
		end
		
		if math.random() < CONFIG.DECORATION_DENSITY * 0.5 then
			local grassPrefab = getRandomPrefabFromCategory("Grass")
			if grassPrefab then
				local grass = clonePrefabDeep(grassPrefab, "Grass")
				
				if grass then
					grass.Name = "Grass_" .. i
					
					local grassSize = getModelSize(grass)
					local offsetX = math.random(-5, 5)
					local offsetZ = math.random(-5, 5)
					local yPosition = 0.5 + (grassSize.Y / 2)
					
					anchorModel(grass)
					setModelPosition(grass, Vector3.new(x + offsetX, yPosition, z + offsetZ))
					
					grass.Parent = treesFolder
				end
			end
		end
	end
	
	print(string.format("WorldBuilder: Forêt générée - %d/%d arbres instanciés avec succès (%d échecs)", 
		successCount, CONFIG.TREE_COUNT, failCount))
end

-- ========================================
-- GÉNÉRATION ROCHERS
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
			local rock = clonePrefabDeep(rockPrefab, "Rocks")
			
			if rock then
				rock.Name = "Rock_" .. i
				
				local rockSize = getModelSize(rock)
				local yPosition = 0.5 + (rockSize.Y / 2)
				local randomRotation = math.random() * math.pi * 2
				
				anchorModel(rock)
				setModelCFrame(rock, CFrame.new(x, yPosition, z) * CFrame.Angles(0, randomRotation, 0))
				tagModelAsCollectable(rock, "Stone")
				
				rock.Parent = rocksFolder
				
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
-- GÉNÉRATION VILLAGE AVEC FALLBACKS
-- ========================================

local function createBuildingComponent(prefabCategory, componentName, relativeCFrame, parent, buildingIndex, forcedSize)
	-- Utilisation du système de fallback
	local fallbacks = {
		Walls = {"Pillars", "Floors", "Uncategorized", "AllPrefabs"},
		Roofs = {"Floors", "Walls", "Uncategorized", "AllPrefabs"},
		Floors = {"Roofs", "Walls", "Uncategorized", "AllPrefabs"},
		Pillars = {"Walls", "Uncategorized", "AllPrefabs"},
		Doors = {"Windows", "Walls", "Uncategorized", "AllPrefabs"},
		Windows = {"Doors", "Walls", "Uncategorized", "AllPrefabs"},
		Gates = {"Doors", "Pillars", "Uncategorized", "AllPrefabs"}
	}
	
	local prefab, actualCategory = getRandomPrefabWithFallback(prefabCategory, fallbacks[prefabCategory] or {"AllPrefabs"})
	
	if not prefab then
		warn(string.format("  ✗ Aucun prefab disponible pour %s (même avec fallback)", prefabCategory))
		return nil
	end
	
	local component = clonePrefabDeep(prefab, actualCategory)
	if not component then
		warn(string.format("  ✗ Échec clonage %s", componentName))
		return nil
	end
	
	component.Name = componentName
	
	-- Configuration des propriétés AVANT positionnement
	anchorModel(component)
	
	-- FORCER la taille si spécifiée
	if forcedSize and component:IsA("BasePart") then
		component.Size = forcedSize
	elseif forcedSize and component:IsA("Model") then
		-- Pour les modèles, redimensionner la PrimaryPart
		if component.PrimaryPart then
			component.PrimaryPart.Size = forcedSize
		end
	end
	
	-- Appliquer la CFrame relative
	setModelCFrame(component, relativeCFrame)
	
	-- DOUBLE VÉRIFICATION de la visibilité
	if component:IsA("BasePart") then
		forceVisibility(component)
	elseif component:IsA("Model") then
		for _, part in ipairs(component:GetDescendants()) do
			if part:IsA("BasePart") then
				forceVisibility(part)
			end
		end
	end
	
	-- Parenting
	component.Parent = parent
	
	print(string.format("  ✓ %s ajouté (catégorie: %s) | Position: %s | Size: %s", 
		componentName, 
		actualCategory,
		tostring(relativeCFrame.Position),
		forcedSize and tostring(forcedSize) or "Auto"))
	
	return component
end

local function createBuilding(position, angle, buildingIndex)
	print(string.format("========== Création Building_%d ==========", buildingIndex))
	
	local building = Instance.new("Model")
	building.Name = "Building_" .. buildingIndex
	
	local baseCFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	
	local partsCreated = 0
	
	-- ====== SOL ======
	local floorY = CONFIG.FLOOR_HEIGHT / 2
	local floorCFrame = baseCFrame * CFrame.new(0, floorY, 0)
	local floorSize = Vector3.new(CONFIG.BUILDING_WIDTH, CONFIG.FLOOR_HEIGHT, CONFIG.BUILDING_DEPTH)
	
	local floor = createBuildingComponent("Floors", "Floor", floorCFrame, building, buildingIndex, floorSize)
	if floor then
		partsCreated = partsCreated + 1
	end
	
	-- ====== MURS (4 côtés) ======
	local wallCenterY = CONFIG.FLOOR_HEIGHT + (CONFIG.BUILDING_HEIGHT / 2)
	
	-- Mur Nord
	local wallNorthCFrame = baseCFrame * CFrame.new(0, wallCenterY, -CONFIG.BUILDING_DEPTH / 2)
	local wallNorthSize = Vector3.new(CONFIG.BUILDING_WIDTH, CONFIG.BUILDING_HEIGHT, CONFIG.WALL_THICKNESS)
	local wallNorth = createBuildingComponent("Walls", "Wall_North", wallNorthCFrame, building, buildingIndex, wallNorthSize)
	if wallNorth then partsCreated = partsCreated + 1 end
	
	-- Mur Sud
	local wallSouthCFrame = baseCFrame * CFrame.new(0, wallCenterY, CONFIG.BUILDING_DEPTH / 2)
	local wallSouthSize = Vector3.new(CONFIG.BUILDING_WIDTH, CONFIG.BUILDING_HEIGHT, CONFIG.WALL_THICKNESS)
	local wallSouth = createBuildingComponent("Walls", "Wall_South", wallSouthCFrame, building, buildingIndex, wallSouthSize)
	if wallSouth then partsCreated = partsCreated + 1 end
	
	-- Mur Est
	local wallEastCFrame = baseCFrame * CFrame.new(CONFIG.BUILDING_WIDTH / 2, wallCenterY, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local wallEastSize = Vector3.new(CONFIG.BUILDING_DEPTH, CONFIG.BUILDING_HEIGHT, CONFIG.WALL_THICKNESS)
	local wallEast = createBuildingComponent("Walls", "Wall_East", wallEastCFrame, building, buildingIndex, wallEastSize)
	if wallEast then partsCreated = partsCreated + 1 end
	
	-- Mur Ouest
	local wallWestCFrame = baseCFrame * CFrame.new(-CONFIG.BUILDING_WIDTH / 2, wallCenterY, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local wallWestSize = Vector3.new(CONFIG.BUILDING_DEPTH, CONFIG.BUILDING_HEIGHT, CONFIG.WALL_THICKNESS)
	local wallWest = createBuildingComponent("Walls", "Wall_West", wallWestCFrame, building, buildingIndex, wallWestSize)
	if wallWest then partsCreated = partsCreated + 1 end
	
	-- ====== TOIT ======
	local roofY = CONFIG.FLOOR_HEIGHT + CONFIG.BUILDING_HEIGHT + (CONFIG.ROOF_HEIGHT / 2)
	local roofCFrame = baseCFrame * CFrame.new(0, roofY, 0)
	local roofSize = Vector3.new(CONFIG.BUILDING_WIDTH + 2, CONFIG.ROOF_HEIGHT, CONFIG.BUILDING_DEPTH + 2)
	
	local roof = createBuildingComponent("Roofs", "Roof", roofCFrame, building, buildingIndex, roofSize)
	if roof then partsCreated = partsCreated + 1 end
	
	-- ====== PORTE ======
	local doorY = CONFIG.FLOOR_HEIGHT + (CONFIG.DOOR_WIDTH / 2)
	local doorCFrame = baseCFrame * CFrame.new(0, doorY, -(CONFIG.BUILDING_DEPTH / 2 + 0.6))
	local doorSize = Vector3.new(CONFIG.DOOR_WIDTH, CONFIG.DOOR_WIDTH * 1.5, CONFIG.WALL_THICKNESS)
	
	local door = createBuildingComponent("Doors", "Door", doorCFrame, building, buildingIndex, doorSize)
	if door then partsCreated = partsCreated + 1 end
	
	-- ====== FENÊTRES ======
	local windowY = CONFIG.FLOOR_HEIGHT + CONFIG.BUILDING_HEIGHT * 0.5
	local windowSize = Vector3.new(CONFIG.WINDOW_SIZE, CONFIG.WINDOW_SIZE, CONFIG.WALL_THICKNESS)
	
	for i = 1, 2 do
		local windowZOffset = (i - 1.5) * 5
		local windowCFrame = baseCFrame * CFrame.new(CONFIG.BUILDING_WIDTH / 2 + 0.6, windowY, windowZOffset) * CFrame.Angles(0, math.pi / 2, 0)
		
		local window = createBuildingComponent("Windows", "Window_" .. i, windowCFrame, building, buildingIndex, windowSize)
		if window then partsCreated = partsCreated + 1 end
	end
	
	print(string.format("========== ✓ Building_%d : %d éléments créés ==========", buildingIndex, partsCreated))
	
	-- Définir la PrimaryPart
	if floor and floor:IsA("BasePart") then
		building.PrimaryPart = floor
	elseif floor and floor:IsA("Model") and floor.PrimaryPart then
		building.PrimaryPart = floor.PrimaryPart
	else
		local primaryPart = building:FindFirstChildWhichIsA("BasePart", true)
		if primaryPart then
			building.PrimaryPart = primaryPart
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
	
	print("========================================")
	print("WorldBuilder: Génération du village avec " .. CONFIG.BUILDING_COUNT .. " bâtiments...")
	print("========================================")
	
	for i = 1, CONFIG.BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.BUILDING_COUNT)
		local distance = 45
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local building = createBuilding(Vector3.new(x, 0, z), angle - math.pi / 2, i)
		building.Parent = villageFolder
		
		task.wait(0.1)
		local childCount = #building:GetChildren()
		print(string.format("Building_%d parenté dans Village - %d enfants détectés", i, childCount))
	end
	
	print("========================================")
	print("WorldBuilder: Village généré!")
	print("========================================")
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
		
		local gatePrefab, _ = getRandomPrefabWithFallback("Gates", {"Doors", "Pillars", "AllPrefabs"})
		if gatePrefab then
			local gate = clonePrefabDeep(gatePrefab, "Gates")
			if gate then
				local gateSize = getModelSize(gate)
				local yPosition = 0.5 + (gateSize.Y / 2)
				
				anchorModel(gate)
				setModelCFrame(gate, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0))
				
				gate.Parent = gateModel
			end
		end
		
		local pillarPrefab, _ = getRandomPrefabWithFallback("Pillars", {"Walls", "AllPrefabs"})
		if pillarPrefab then
			local pillarSize = getModelSize(pillarPrefab)
			local yPosition = 0.5 + (pillarSize.Y / 2)
			
			local leftPillar = clonePrefabDeep(pillarPrefab, "Pillars")
			if leftPillar then
				leftPillar.Name = "LeftPillar"
				anchorModel(leftPillar)
				local leftOffset = CFrame.new(-10, 0, 0)
				setModelCFrame(leftPillar, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0) * leftOffset)
				
				leftPillar.Parent = gateModel
			end
			
			local rightPillar = clonePrefabDeep(pillarPrefab, "Pillars")
			if rightPillar then
				rightPillar.Name = "RightPillar"
				anchorModel(rightPillar)
				local rightOffset = CFrame.new(10, 0, 0)
				setModelCFrame(rightPillar, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0) * rightOffset)
				
				rightPillar.Parent = gateModel
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
		
		local benchPrefab, _ = getRandomPrefabWithFallback("Benches", {"Barrels", "AllPrefabs"})
		if benchPrefab then
			local bench = clonePrefabDeep(benchPrefab, "Benches")
			if bench then
				bench.Name = "Bench_" .. i
				
				local benchSize = getModelSize(bench)
				local yPosition = 0.5 + (benchSize.Y / 2)
				
				anchorModel(bench)
				setModelCFrame(bench, CFrame.new(x, yPosition, z) * CFrame.Angles(0, -angle, 0))
				
				bench.Parent = squareFolder
			end
		end
	end
	
	-- Décorations périphériques
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local distance = 25
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		if i % 2 == 1 then
			local barrelPrefab, _ = getRandomPrefabWithFallback("Barrels", {"Benches", "AllPrefabs"})
			if barrelPrefab then
				local barrel = clonePrefabDeep(barrelPrefab, "Barrels")
				if barrel then
					barrel.Name = "Barrel_" .. i
					
					local barrelSize = getModelSize(barrel)
					local yPosition = 0.5 + (barrelSize.Y / 2)
					
					anchorModel(barrel)
					setModelPosition(barrel, Vector3.new(x, yPosition, z))
					
					barrel.Parent = squareFolder
				end
			end
		end
		
		if i % 2 == 0 then
			local lampPrefab, _ = getRandomPrefabWithFallback("Lamps", {"Pillars", "AllPrefabs"})
			if lampPrefab then
				local lamp = clonePrefabDeep(lampPrefab, "Lamps")
				if lamp then
					lamp.Name = "Lamp_" .. i
					
					local lampSize = getModelSize(lamp)
					local yPosition = 0.5 + (lampSize.Y / 2)
					
					anchorModel(lamp)
					setModelPosition(lamp, Vector3.new(x, yPosition, z))
					
					lamp.Parent = squareFolder
					
					-- Ajout d'une lumière
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
	
	local prefabsFolder = getPrefabsFolder()
	if prefabsFolder then
		local prefabCount = #prefabsFolder:GetChildren()
		print("WorldBuilder: " .. prefabCount .. " prefabs détectés (dossier PLAT)")
		
		categorizePrefabs()
	else
		warn("WorldBuilder: AUCUN PREFAB DÉTECTÉ - Génération impossible")
	end
	
	createBasePlate()
	print("✓ BasePlate créée")
	
	generateForest()
	print("✓ Forêt générée")
	
	generateRocks()
	print("✓ Rochers générés")
	
	generateVillage()
	print("✓ Village généré")
	
	createFortifications()
	print("✓ Fortifications créées")
	
	createCentralSquare()
	print("✓ Place centrale créée")
	
	createMonsterSpawns()
	print("✓ Points de spawn créés")
	
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