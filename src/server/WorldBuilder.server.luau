--[[
	WorldBuilder.server.luau
	Système de génération procédurale intelligent exploitant l'inventaire complet des assets
	avec placement automatique sur le relief par Raycast et génération de rapport.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
	VILLAGE_RADIUS = 45,
	VILLAGE_BUILDING_COUNT = 8,
	
	FOREST_MIN_RADIUS = 60,
	FOREST_MAX_RADIUS = 180,
	TREE_COUNT = 200,
	
	ROCK_COUNT = 50,
	ROCK_MIN_RADIUS = 50,
	ROCK_MAX_RADIUS = 170,
	
	MONSTER_SPAWN_COUNT = 12,
	MONSTER_SPAWN_RADIUS = 160,
	
	RAYCAST_HEIGHT = 500,
	RAYCAST_DISTANCE = 1000,
	
	GENERATE_REPORT = true,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE SCANNING ET CATÉGORISATION
-- ═══════════════════════════════════════════════════════════════════════════

local AssetInventory = {
	Buildings = {},      -- Structures complètes
	Walls = {},          -- Murs, piliers, clôtures
	Roofs = {},          -- Toits, plafonds
	Floors = {},         -- Sols, fondations, chemins
	Doors = {},          -- Portes, fenêtres
	Trees = {},          -- Arbres, végétation
	Rocks = {},          -- Rochers, pierres
	Decorations = {},    -- Éléments décoratifs
	Props = {},          -- Objets divers
	Unknown = {},        -- Non catégorisé
}

local CategoryPatterns = {
	Buildings = {
		"house", "building", "tower", "tavern", "hut", "shed", "barn", 
		"cottage", "cabin", "chapel", "shop", "home", "dwelling"
	},
	Walls = {
		"wall", "pillar", "fence", "column", "post", "barrier", 
		"palisade", "stockade", "rampart"
	},
	Roofs = {
		"roof", "ceiling", "holecover", "top", "thatch", "shingle"
	},
	Floors = {
		"floor", "ground", "foundation", "path", "base", "platform",
		"tile", "paving", "cobble"
	},
	Doors = {
		"door", "gate", "window", "entrance", "portal", "hatch"
	},
	Trees = {
		"tree", "pine", "oak", "birch", "willow", "bush", "shrub",
		"plant", "fern", "grass", "foliage", "trunk", "branch"
	},
	Rocks = {
		"rock", "stone", "boulder", "pebble", "cliff", "mountain"
	},
	Decorations = {
		"lantern", "torch", "banner", "flag", "carpet", "rug",
		"furniture", "table", "chair", "bench", "barrel", "crate"
	},
	Props = {
		"tool", "weapon", "item", "object", "prop", "misc"
	}
}

-- Scan récursif de tous les dossiers
local function scanFolderRecursive(folder, assetList)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") or child:IsA("MeshPart") or child:IsA("Part") or child:IsA("UnionOperation") then
			table.insert(assetList, child)
		elseif child:IsA("Folder") then
			scanFolderRecursive(child, assetList)
		end
	end
end

-- Catégorisation intelligente par analyse du nom
local function categorizeAsset(assetName)
	local nameLower = string.lower(assetName)
	
	-- Parcours des catégories par ordre de priorité
	for category, patterns in pairs(CategoryPatterns) do
		for _, pattern in ipairs(patterns) do
			if string.find(nameLower, pattern) then
				return category
			end
		end
	end
	
	return "Unknown"
end

-- Construction de l'inventaire complet
local function buildAssetInventory()
	print("[WorldBuilder] 🔍 Démarrage du scan des assets...")
	
	local prefabsFolder = ReplicatedStorage:FindFirstChild("Prefabs")
	if not prefabsFolder then
		warn("[WorldBuilder] ❌ Aucun dossier Prefabs trouvé dans ReplicatedStorage!")
		return false
	end
	
	local allAssets = {}
	scanFolderRecursive(prefabsFolder, allAssets)
	
	print(string.format("[WorldBuilder] 📦 %d assets détectés, catégorisation en cours...", #allAssets))
	
	-- Catégorisation
	for _, asset in ipairs(allAssets) do
		local category = categorizeAsset(asset.Name)
		table.insert(AssetInventory[category], asset)
	end
	
	-- Statistiques
	local totalCategorized = 0
	for category, assets in pairs(AssetInventory) do
		local count = #assets
		totalCategorized = totalCategorized + count
		if count > 0 then
			print(string.format("  ✓ %s : %d assets", category, count))
		end
	end
	
	print(string.format("[WorldBuilder] ✅ Inventaire terminé : %d assets catégorisés", totalCategorized))
	return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRATION DE RAPPORT
-- ═══════════════════════════════════════════════════════════════════════════

local function generateInventoryReport()
	if not CONFIG.GENERATE_REPORT then return end
	
	print("[WorldBuilder] 📝 Génération du rapport d'inventaire...")
	
	local report = {
		"# 📋 Asset Inventory Report",
		"",
		"**Generated:** " .. os.date("%Y-%m-%d %H:%M:%S"),
		"**Source:** ReplicatedStorage.Prefabs",
		"",
		"---",
		""
	}
	
	local totalAssets = 0
	
	for category, assets in pairs(AssetInventory) do
		if #assets > 0 then
			totalAssets = totalAssets + #assets
			table.insert(report, string.format("## %s (%d)", category, #assets))
			table.insert(report, "")
			
			-- Liste des assets
			for i, asset in ipairs(assets) do
				local assetType = asset.ClassName
				local path = asset:GetFullName():gsub("%.ReplicatedStorage%.Prefabs%.", "")
				table.insert(report, string.format("%d. **%s** `[%s]` - `%s`", 
					i, asset.Name, assetType, path))
			end
			table.insert(report, "")
		end
	end
	
	-- Statistiques globales
	table.insert(report, "---")
	table.insert(report, "")
	table.insert(report, "## 📊 Statistiques Globales")
	table.insert(report, "")
	table.insert(report, string.format("- **Total Assets:** %d", totalAssets))
	table.insert(report, string.format("- **Catégories:** %d", 10))
	table.insert(report, "")
	
	local reportText = table.concat(report, "\n")
	
	-- Sauvegarde dans ServerStorage pour consultation
	local reportFolder = ServerStorage:FindFirstChild("Reports") or Instance.new("Folder")
	reportFolder.Name = "Reports"
	reportFolder.Parent = ServerStorage
	
	local reportValue = reportFolder:FindFirstChild("AssetInventory") or Instance.new("StringValue")
	reportValue.Name = "AssetInventory"
	reportValue.Value = reportText
	reportValue.Parent = reportFolder
	
	print("[WorldBuilder] ✅ Rapport sauvegardé dans ServerStorage.Reports.AssetInventory")
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	print(reportText)
	print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE PLACEMENT PAR RAYCAST
-- ═══════════════════════════════════════════════════════════════════════════

local function getGroundPositionPrecise(x, z, heightOffset)
	heightOffset = heightOffset or 0
	
	local origin = Vector3.new(x, CONFIG.RAYCAST_HEIGHT, z)
	local direction = Vector3.new(0, -CONFIG.RAYCAST_DISTANCE, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true
	
	-- Exclusion des dossiers de génération pour éviter les collisions
	local ignoreList = {}
	for _, name in ipairs({"Village", "Trees", "Rocks", "MonsterSpawns", "Decorations"}) do
		local folder = workspace:FindFirstChild(name)
		if folder then table.insert(ignoreList, folder) end
	end
	raycastParams.FilterDescendantsInstances = ignoreList
	
	local result = workspace:Raycast(origin, direction, raycastParams)
	
	if result then
		return result.Position + Vector3.new(0, heightOffset, 0), result.Normal
	else
		-- Fallback sur la hauteur du terrain Roblox
		local terrainPos = workspace.Terrain:WorldToCell(Vector3.new(x, 0, z))
		local region = Region3.new(
			Vector3.new(x - 2, -100, z - 2),
			Vector3.new(x + 2, 100, z + 2)
		):ExpandToGrid(4)
		
		local materials, sizes = workspace.Terrain:ReadVoxels(region, 4)
		local size = materials.Size
		
		for y = size.Y, 1, -1 do
			if materials[1][y][1] ~= Enum.Material.Air then
				return Vector3.new(x, (y - size.Y/2) * 4 + heightOffset, z), Vector3.new(0, 1, 0)
			end
		end
		
		return Vector3.new(x, heightOffset, z), Vector3.new(0, 1, 0)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SYSTÈME DE CLONAGE ET PLACEMENT SÉCURISÉ
-- ═══════════════════════════════════════════════════════════════════════════

local function prepareAssetForWorld(asset)
	if asset:IsA("Model") then
		-- Sécurisation de tous les descendants
		for _, descendant in ipairs(asset:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = true
				
				-- Préservation de la transparence originale si c'est un élément décoratif
				if descendant.Transparency >= 0.95 then
					descendant.CanCollide = false
				end
			end
		end
	elseif asset:IsA("BasePart") then
		asset.Anchored = true
		asset.CanCollide = true
	end
end

local function spawnAsset(prefab, position, rotation, parentFolder)
	if not prefab then 
		warn("[WorldBuilder] ⚠️ Tentative de spawn d'un prefab nil")
		return nil 
	end
	
	local clone = prefab:Clone()
	prepareAssetForWorld(clone)
	
	-- Placement précis
	if clone:IsA("Model") then
		local pivot = clone:GetPivot()
		local newCFrame = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
		clone:PivotTo(newCFrame)
	elseif clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(position) * CFrame.Angles(0, rotation, 0)
	end
	
	clone.Parent = parentFolder
	return clone
end

local function getRandomAsset(category)
	local assets = AssetInventory[category]
	if #assets == 0 then return nil end
	return assets[math.random(1, #assets)]
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRATION DU VILLAGE
-- ═══════════════════════════════════════════════════════════════════════════

local function generateVillage()
	print("[WorldBuilder] 🏘️ Génération du village...")
	
	local villageFolder = Instance.new("Folder")
	villageFolder.Name = "Village"
	villageFolder.Parent = workspace
	
	local buildingsPlaced = 0
	
	for i = 1, CONFIG.VILLAGE_BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.VILLAGE_BUILDING_COUNT)
		local x = math.cos(angle) * CONFIG.VILLAGE_RADIUS
		local z = math.sin(angle) * CONFIG.VILLAGE_RADIUS
		
		local position, normal = getGroundPositionPrecise(x, z, 0)
		local rotation = angle + math.pi -- Face vers le centre
		
		-- Essai de placement d'un bâtiment complet
		local building = getRandomAsset("Buildings")
		if building then
			local placed = spawnAsset(building, position, rotation, villageFolder)
			if placed then
				placed.Name = "Building_" .. i
				buildingsPlaced = buildingsPlaced + 1
			end
		else
			-- Construction modulaire si pas de bâtiment complet
			local buildingModel = Instance.new("Model")
			buildingModel.Name = "ModularBuilding_" .. i
			buildingModel.Parent = villageFolder
			
			local floor = getRandomAsset("Floors")
			local wall = getRandomAsset("Walls")
			local roof = getRandomAsset("Roofs")
			
			if floor then spawnAsset(floor, position, rotation, buildingModel) end
			if wall then spawnAsset(wall, position + Vector3.new(0, 2, 0), rotation, buildingModel) end
			if roof then spawnAsset(roof, position + Vector3.new(0, 5, 0), rotation, buildingModel) end
			
			buildingsPlaced = buildingsPlaced + 1
		end
	end
	
	print(string.format("[WorldBuilder] ✅ Village généré : %d bâtiments", buildingsPlaced))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRATION DE LA FORÊT
-- ═══════════════════════════════════════════════════════════════════════════

local function generateForest()
	print("[WorldBuilder] 🌲 Génération de la forêt...")
	
	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = workspace
	
	local treesPlaced = 0
	
	if #AssetInventory.Trees == 0 then
		warn("[WorldBuilder] ⚠️ Aucun arbre trouvé dans l'inventaire!")
		return
	end
	
	for i = 1, CONFIG.TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
		
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local position = getGroundPositionPrecise(x, z, 0)
		local rotation = math.random() * math.pi * 2
		
		local tree = getRandomAsset("Trees")
		if tree then
			local placed = spawnAsset(tree, position, rotation, treesFolder)
			if placed then
				placed.Name = "Tree_" .. i
				treesPlaced = treesPlaced + 1
			end
		end
	end
	
	print(string.format("[WorldBuilder] ✅ Forêt générée : %d arbres", treesPlaced))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRATION DES ROCHERS
-- ═══════════════════════════════════════════════════════════════════════════

local function generateRocks()
	print("[WorldBuilder] 🪨 Génération des rochers...")
	
	local rocksFolder = Instance.new("Folder")
	rocksFolder.Name = "Rocks"
	rocksFolder.Parent = workspace
	
	local rocksPlaced = 0
	
	if #AssetInventory.Rocks == 0 then
		warn("[WorldBuilder] ⚠️ Aucun rocher trouvé dans l'inventaire!")
		return
	end
	
	for i = 1, CONFIG.ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.ROCK_MIN_RADIUS + math.random() * (CONFIG.ROCK_MAX_RADIUS - CONFIG.ROCK_MIN_RADIUS)
		
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local position = getGroundPositionPrecise(x, z, 0)
		local rotation = math.random() * math.pi * 2
		
		local rock = getRandomAsset("Rocks")
		if rock then
			local placed = spawnAsset(rock, position, rotation, rocksFolder)
			if placed then
				placed.Name = "Rock_" .. i
				rocksPlaced = rocksPlaced + 1
			end
		end
	end
	
	print(string.format("[WorldBuilder] ✅ Rochers générés : %d", rocksPlaced))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRATION DES SPAWNS DE MONSTRES
-- ═══════════════════════════════════════════════════════════════════════════

local function generateMonsterSpawns()
	print("[WorldBuilder] 👹 Génération des spawns de monstres...")
	
	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "MonsterSpawns"
	spawnFolder.Parent = workspace
	
	for i = 1, CONFIG.MONSTER_SPAWN_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.MONSTER_SPAWN_COUNT)
		local x = math.cos(angle) * CONFIG.MONSTER_SPAWN_RADIUS
		local z = math.sin(angle) * CONFIG.MONSTER_SPAWN_RADIUS
		
		local position = getGroundPositionPrecise(x, z, 0.5)
		
		local spawn = Instance.new("Part")
		spawn.Name = "MonsterSpawn_" .. i
		spawn.Size = Vector3.new(5, 1, 5)
		spawn.Position = position
		spawn.Anchored = true
		spawn.Transparency = 0.8
		spawn.CanCollide = false
		spawn.Color = Color3.fromRGB(150, 0, 0)
		spawn.Material = Enum.Material.Neon
		spawn.Parent = spawnFolder
		
		CollectionService:AddTag(spawn, "MonsterSpawnPoint")
	end
	
	print(string.format("[WorldBuilder] ✅ Spawns générés : %d", CONFIG.MONSTER_SPAWN_COUNT))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE ET GÉNÉRATION PRINCIPALE
-- ═══════════════════════════════════════════════════════════════════════════

local function cleanupPreviousWorld()
	print("[WorldBuilder] 🧹 Nettoyage du monde précédent...")
	
	local foldersToClean = {"Village", "Trees", "Rocks", "MonsterSpawns", "Decorations", "GiantTreeHub"}
	for _, folderName in ipairs(foldersToClean) do
		local existing = workspace:FindFirstChild(folderName)
		if existing then
			existing:Destroy()
		end
	end
end

local function generateWorld()
	print("════════════════════════════════════════════════════════════════")
	print("          🌍 WORLDBUILDER - GÉNÉRATION PROCÉDURALE 🌍")
	print("════════════════════════════════════════════════════════════════")
	
	-- Phase 1 : Scan et inventaire
	local scanSuccess = buildAssetInventory()
	if not scanSuccess then
		error("[WorldBuilder] ❌ Échec du scan des assets, génération annulée.")
	end
	
	-- Phase 2 : Génération du rapport
	generateInventoryReport()
	
	-- Phase 3 : Nettoyage
	cleanupPreviousWorld()
	
	-- Phase 4 : Génération du monde
	wait(0.5)
	generateVillage()
	wait(0.5)
	generateForest()
	wait(0.5)
	generateRocks()
	wait(0.5)
	generateMonsterSpawns()
	
	print("════════════════════════════════════════════════════════════════")
	print("          ✅ MONDE GÉNÉRÉ AVEC SUCCÈS !")
	print("════════════════════════════════════════════════════════════════")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXÉCUTION
-- ═══════════════════════════════════════════════════════════════════════════

generateWorld()