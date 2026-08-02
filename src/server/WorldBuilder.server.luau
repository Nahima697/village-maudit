--[[
    WorldBuilder.server.luau
    Génère le monde en utilisant les prefabs de ReplicatedStorage
    et tague automatiquement les arbres et rochers pour la récolte
    
    ADAPTATION : Fonctionne avec des MeshParts/BaseParts directs (dossier plat)
    CORRECTION : Validation des tailles et positionnement explicite
    FIX : Instanciation profonde des bâtiments avec MeshParts visibles
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
-- CLONAGE ET CONFIGURATION DES PREFABS AMÉLIORÉ
-- ========================================

local function clonePrefabDeep(prefab, category)
	if not prefab then return nil end
	
	local clone = prefab:Clone()
	
	-- GESTION DIRECTE DES MESHPARTS / BASEPARTS
	if clone:IsA("BasePart") then
		-- VALIDATION ET CORRECTION DE LA TAILLE
		validateAndFixSize(clone, category or "Uncategorized")
		
		-- Configuration des propriétés de rendu CRITIQUES
		clone.Anchored = true
		clone.CanCollide = true
		clone.Transparency = 0  -- FORCE la visibilité
		
		-- Forcer les propriétés de surface pour le rendu
		if clone:IsA("MeshPart") then
			-- S'assurer que le MeshId existe
			if clone.MeshId == "" or clone.MeshId == "rbxasset://fonts/leftarm.mesh" then
				warn(string.format("WorldBuilder: MeshPart %s a un MeshId invalide", clone.Name))
			end
			
			-- Forcer le matériau pour meilleure visibilité
			if clone.Material == Enum.Material.Plastic then
				clone.Material = Enum.Material.SmoothPlastic
			end
		end
		
		-- Vérification finale de visibilité
		print(string.format("✓ MeshPart cloné: %s | Size: %s | Transparency: %s | Material: %s", 
			clone.Name, 
			tostring(clone.Size), 
			tostring(clone.Transparency),
			tostring(clone.Material)))
		
	elseif clone:IsA("Model") then
		-- Ancrer et valider toutes les parts du modèle
		local partCount = 0
		for _, descendant in ipairs(clone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				validateAndFixSize(descendant, category or "Uncategorized")
				descendant.Anchored = true
				descendant.Transparency = 0  -- FORCE la visibilité
				
				if descendant:IsA("MeshPart") then
					if descendant.Material == Enum.Material.Plastic then
						descendant.Material = Enum.Material.SmoothPlastic
					end
				end
				
				partCount = partCount + 1
			end
		end
		
		print(string.format("✓ Model cloné: %s avec %d BaseParts", clone.Name, partCount))
		
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
-- GÉNÉRATION FORÊT (PREFABS) - AMÉLIORÉ
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
			local tree = clonePrefabDeep(treePrefab, "Trees")
			
			if tree then
				tree.Name = "Tree_" .. i
				
				-- Calculer la hauteur pour placer correctement
				local treeSize = getModelSize(tree)
				local yPosition = 0.5 + (treeSize.Y / 2)
				local position = Vector3.new(x, yPosition, z)
				
				-- Configuration des propriétés AVANT parenting
				anchorModel(tree)
				setModelPosition(tree, position)
				tagModelAsCollectable(tree, "Wood")
				
				-- PARENTING EN DERNIER
				tree.Parent = treesFolder
				
				successCount = successCount + 1
			else
				failCount = failCount + 1
			end
		end
		
		-- Décoration : buissons
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
		
		-- Décoration : herbes
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
-- GÉNÉRATION ROCHERS (PREFABS) - AMÉLIORÉ
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
				
				-- PARENTING EN DERNIER
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
-- GÉNÉRATION VILLAGE (PREFABS) - COMPLÈTEMENT REFAIT
-- ========================================

local function createBuilding(position, angle, buildingIndex)
	print(string.format("--- Création Building_%d ---", buildingIndex))
	
	local building = Instance.new("Model")
	building.Name = "Building_" .. buildingIndex
	
	local baseCFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	
	local partsCreated = 0
	
	-- Sol
	local floorPrefab = getRandomPrefabFromCategory("Floors")
	if floorPrefab then
		local floor = clonePrefabDeep(floorPrefab, "Floors")
		if floor then
			floor.Name = "Floor"
			
			local floorSize = getModelSize(floor)
			local yOffset = 0.5 + (floorSize.Y / 2)
			
			anchorModel(floor)
			setModelCFrame(floor, baseCFrame * CFrame.new(0, yOffset, 0))
			
			floor.Parent = building
			partsCreated = partsCreated + 1
			print(string.format("  ✓ Floor ajouté (Size: %s)", tostring(floorSize)))
		else
			warn("  ✗ Échec clonage Floor")
		end
	else
		warn("  ✗ Aucun prefab Floor trouvé")
	end
	
	-- Murs (4 côtés)
	local wallPrefab = getRandomPrefabFromCategory("Walls")
	if wallPrefab then
		local wallSize = getModelSize(wallPrefab)
		local wallHeight = 0.5 + 3 + (wallSize.Y / 2)
		
		local wallPositions = {
			{offset = CFrame.new(0, wallHeight, -8), rotation = 0, name = "Wall_North"},
			{offset = CFrame.new(8, wallHeight, 0), rotation = math.pi/2, name = "Wall_East"},
			{offset = CFrame.new(0, wallHeight, 8), rotation = math.pi, name = "Wall_South"},
			{offset = CFrame.new(-8, wallHeight, 0), rotation = -math.pi/2, name = "Wall_West"}
		}
		
		for _, wallData in ipairs(wallPositions) do
			local wall = clonePrefabDeep(wallPrefab, "Walls")
			if wall then
				wall.Name = wallData.name
				anchorModel(wall)
				setModelCFrame(wall, baseCFrame * wallData.offset * CFrame.Angles(0, wallData.rotation, 0))
				
				wall.Parent = building
				partsCreated = partsCreated + 1
				print(string.format("  ✓ %s ajouté", wallData.name))
			else
				warn(string.format("  ✗ Échec clonage %s", wallData.name))
			end
		end
	else
		warn("  ✗ Aucun prefab Wall trouvé")
	end
	
	-- Toit
	local roofPrefab = getRandomPrefabFromCategory("Roofs")
	if roofPrefab then
		local roof = clonePrefabDeep(roofPrefab, "Roofs")
		if roof then
			roof.Name = "Roof"
			
			local roofSize = getModelSize(roof)
			local roofHeight = 0.5 + 8 + (roofSize.Y / 2)
			
			anchorModel(roof)
			setModelCFrame(roof, baseCFrame * CFrame.new(0, roofHeight, 0))
			
			roof.Parent = building
			partsCreated = partsCreated + 1
			print(string.format("  ✓ Roof ajouté (Size: %s)", tostring(roofSize)))
		else
			warn("  ✗ Échec clonage Roof")
		end
	else
		warn("  ✗ Aucun prefab Roof trouvé")
	end
	
	-- Porte (sur le mur avant)
	local doorPrefab = getRandomPrefabFromCategory("Doors")
	if doorPrefab then
		local door = clonePrefabDeep(doorPrefab, "Doors")
		if door then
			door.Name = "Door"
			
			local doorSize = getModelSize(door)
			local doorHeight = 0.5 + (doorSize.Y / 2)
			
			anchorModel(door)
			setModelCFrame(door, baseCFrame * CFrame.new(0, doorHeight, -8.5))
			
			door.Parent = building
			partsCreated = partsCreated + 1
			print(string.format("  ✓ Door ajouté"))
		end
	end
	
	-- Fenêtres
	local windowPrefab = getRandomPrefabFromCategory("Windows")
	if windowPrefab then
		local windowSize = getModelSize(windowPrefab)
		local windowHeight = 0.5 + 3 + (windowSize.Y / 2)
		
		for i = 1, 3 do
			local window = clonePrefabDeep(windowPrefab, "Windows")
			if window then
				window.Name = "Window_" .. i
				anchorModel(window)
				local windowOffset = CFrame.new((i-2) * 5, windowHeight, -8.5)
				setModelCFrame(window, baseCFrame * windowOffset)
				
				window.Parent = building
				partsCreated = partsCreated + 1
			end
		end
		
		print(string.format("  ✓ 3 Windows ajoutées"))
	end
	
	print(string.format("✓ Building_%d créé avec %d éléments", buildingIndex, partsCreated))
	
	-- Définir la PrimaryPart du bâtiment
	local primaryPart = building:FindFirstChildWhichIsA("BasePart", true)
	if primaryPart then
		building.PrimaryPart = primaryPart
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
		
		-- Vérification post-parenting
		task.wait(0.1)
		local childCount = #building:GetChildren()
		print(string.format("Building_%d parent dans Village - %d enfants détectés", i, childCount))
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
		
		-- Portail central
		local gatePrefab = getRandomPrefabFromCategory("Gates")
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
		
		-- Piliers de chaque côté
		local pillarPrefab = getRandomPrefabFromCategory("Pillars")
		if pillarPrefab then
			local pillarSize = getModelSize(pillarPrefab)
			local yPosition = 0.5 + (pillarSize.Y / 2)
			
			local leftPillar = clonePrefabDeep(pillarPrefab, "Pillars")
			if leftPillar then
				leftPillar.Name = "LeftPillar"
				anchorModel(leftPillar)
				local leftOffset = CFrame.new(-8, 0, 0)
				setModelCFrame(leftPillar, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0) * leftOffset)
				
				leftPillar.Parent = gateModel
			end
			
			local rightPillar = clonePrefabDeep(pillarPrefab, "Pillars")
			if rightPillar then
				rightPillar.Name = "RightPillar"
				anchorModel(rightPillar)
				local rightOffset = CFrame.new(8, 0, 0)
				setModelCFrame(rightPillar, CFrame.new(doorData.pos.X, yPosition, doorData.pos.Z) * CFrame.Angles(0, doorData.rot, 0) * rightOffset)
				
				rightPillar.Parent = gateModel
			end
		end
	end
	
	print("WorldBuilder: Fortifications créées")
end

-- ========================================
-- PLACE CENTRALE - AMÉLIORÉ
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
		
		-- Barils
		if i % 2 == 1 then
			local barrelPrefab = getRandomPrefabFromCategory("Barrels")
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
		
		-- Lampadaires
		if i % 2 == 0 then
			local lampPrefab = getRandomPrefabFromCategory("Lamps")
			if lampPrefab then
				local lamp = clonePrefabDeep(lampPrefab, "Lamps")
				if lamp then
					lamp.Name = "Lamp_" .. i
					
					local lampSize = getModelSize(lamp)
					local yPosition = 0.5 + (lampSize.Y / 2)
					
					anchorModel(lamp)
					setModelPosition(lamp, Vector3.new(x, yPosition, z))
					
					lamp.Parent = squareFolder
					
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