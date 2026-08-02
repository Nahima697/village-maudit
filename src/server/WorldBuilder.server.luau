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
	VILLAGE_BUILDING_COUNT = 12,
	
	FOREST_MIN_RADIUS = 65,
	FOREST_MAX_RADIUS = 180,
	TREE_COUNT = 250,
	TREE_CLUSTER_CHANCE = 0.3, -- 30% de chance de spawn en groupe
	
	ROCK_COUNT = 60,
	ROCK_MIN_RADIUS = 50,
	ROCK_MAX_RADIUS = 170,
	
	MONSTER_SPAWN_COUNT = 15,
	MONSTER_SPAWN_RADIUS = 160,
	
	RAYCAST_HEIGHT = 500,
	RAYCAST_DISTANCE = 1000,
	
	GENERATE_REPORT = true,
	VERBOSE_LOGGING = true,
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
		"cottage", "cabin", "chapel", "shop", "home", "dwelling", "structure"
	},
	Walls = {
		"wall", "pillar", "fence", "column", "post", "barrier", 
		"palisade", "stockade", "rampart", "panel"
	},
	Roofs = {
		"roof", "ceiling", "holecover", "top", "thatch", "shingle", "cover"
	},
	Floors = {
		"floor", "ground", "foundation", "path", "base", "platform",
		"tile", "paving", "cobble", "plank"
	},
	Doors = {
		"door", "gate", "window", "entrance", "portal", "hatch", "opening"
	},
	Trees = {
		"tree", "pine", "oak", "birch", "willow", "bush", "shrub",
		"plant", "fern", "grass", "foliage", "trunk", "branch", "leaves"
	},
	Rocks = {
		"rock", "stone", "boulder", "pebble", "cliff", "mountain", "outcrop"
	},
	Decorations = {
		"lantern", "torch", "banner", "flag", "carpet", "rug",
		"furniture", "table", "chair", "bench", "barrel", "crate", "pot"
	},
	Props = {
		"tool", "weapon", "item", "object", "prop", "misc", "detail"
	}
}

-- Scan récursif de tous les dossiers et sous-dossiers
local function scanFolderRecursive(folder, assetList)
	for _, child in ipairs(folder:GetChildren()) do
		-- Accepte Models, MeshParts, Parts et UnionOperations
		if child:IsA("Model") or child:IsA("MeshPart") or child:IsA("Part") or child:IsA("UnionOperation") then
			table.insert(assetList, child)
		elseif child:IsA("Folder") then
			-- Descend récursivement dans les sous-dossiers
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
		"# 📋 ASSET INVENTORY REPORT",
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
			
			-- Liste des assets avec détails
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
	table.insert(report, "## 📊 STATISTIQUES GLOBALES")
	table.insert(report, "")
	table.insert(report, string.format("- **Total Assets:** %d", totalAssets))
	
	local categoryCount = 0
	for category, assets in pairs(AssetInventory) do
		if #assets > 0 then categoryCount = categoryCount + 1 end
	end
	table.insert(report, string.format("- **Catégories actives:** %d/10", categoryCount))
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
	
	if CONFIG.VERBOSE_LOGGING then
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		print(reportText)
		print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	end
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
				
				-- Préservation de la transparence originale si c'est un élément décoratif
				if descendant.Transparency >= 0.95 then
					descendant.CanCollide = false
				else
					descendant.CanCollide = true
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
	
	-- Placement précis avec PivotTo pour Models et CFrame pour BaseParts
	if clone:IsA("Model") then
		-- Calcul du CFrame final avec rotation
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
	if not assets or #assets == 0 then return nil end
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
	local modularBuildings = 0
	
	for i = 1, CONFIG.VILLAGE_BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.VILLAGE_BUILDING_COUNT)
		local x = math.cos(angle) * CONFIG.VILLAGE_RADIUS
		local z = math.sin(angle) * CONFIG.VILLAGE_RADIUS
		
		-- Raycast pour placement précis
		local position, normal = getGroundPositionPrecise(x, z, 0)
		local rotation = angle + math.pi -- Face vers le centre du village
		
		-- Essai de placement d'un bâtiment complet
		local building = getRandomAsset("Buildings")
		if building then
			local placed = spawnAsset(building, position, rotation, villageFolder)
			if placed then
				placed.Name = "Building_" .. i
				buildingsPlaced = buildingsPlaced + 1
				
				if CONFIG.VERBOSE_LOGGING then
					print(string.format("  ✓ Bâtiment %d placé: %s", i, building.Name))
				end
			end
		else
			-- Construction modulaire si pas de bâtiment complet disponible
			local buildingModel = Instance.new("Model")
			buildingModel.Name = "ModularBuilding_" .. i
			buildingModel.Parent = villageFolder
			
			local floor = getRandomAsset("Floors")
			local wall = getRandomAsset("Walls")
			local roof = getRandomAsset("Roofs")
			local door = getRandomAsset("Doors")
			
			-- Placement du sol
			if floor then 
				spawnAsset(floor, position, rotation, buildingModel) 
			end
			
			-- Placement des murs (4 côtés)
			if wall then
				for side = 0, 3 do
					local wallAngle = rotation + (side * math.pi / 2)
					local wallOffset = Vector3.new(math.cos(wallAngle) * 3, 2, math.sin(wallAngle) * 3)
					spawnAsset(wall, position + wallOffset, wallAngle, buildingModel)
				end
			end
			
			-- Placement du toit
			if roof then 
				spawnAsset(roof, position + Vector3.new(0, 5, 0), rotation, buildingModel) 
			end
			
			-- Placement de la porte
			if door then
				spawnAsset(door, position + Vector3.new(0, 1, -3), rotation, buildingModel)
			end
			
			modularBuildings = modularBuildings + 1
			buildingsPlaced = buildingsPlaced + 1
			
			if CONFIG.VERBOSE_LOGGING then
				print(string.format("  ✓ Bâtiment modulaire %d construit", i))
			end
		end
	end
	
	print(string.format("[WorldBuilder] ✅ Village généré : %d bâtiments (%d modulaires)", 
		buildingsPlaced, modularBuildings))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRATION DE LA FORÊT
-- ═══════════════════════════════════════════════════════════════════════════

local function generateForest()
	print("[WorldBuilder] 🌲 Génération de la forêt...")
	
	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = workspace
	
	if #AssetInventory.Trees == 0 then
		warn("[WorldBuilder] ⚠️ Aucun arbre trouvé dans l'inventaire!")
		return
	end
	
	local treesPlaced = 0
	local clusterCount = 0
	
	for i = 1, CONFIG.TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
		
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		-- Raycast pour placement précis sur le terrain
		local position, normal = getGroundPositionPrecise(x, z, 0)
		local rotation = math.random() * math.pi * 2
		
		local tree = getRandomAsset("Trees")
		if tree then
			local placed = spawnAsset(tree, position, rotation, treesFolder)
			if placed then
				placed.Name = "Tree_" .. i
				treesPlaced = treesPlaced + 1
				
				-- Génération de clusters (groupes d'arbres)
				if math.random() < CONFIG.TREE_CLUSTER_CHANCE then
					for j = 1, math.random(2, 4) do
						local clusterOffsetAngle = math.random() * math.pi * 2
						local clusterOffsetDistance = math.random(3, 8)
						
						local clusterX = x + math.cos(clusterOffsetAngle) * clusterOffsetDistance
						local clusterZ = z + math.sin(clusterOffsetAngle) * clusterOffsetDistance
						
						local clusterPos = getGroundPositionPrecise(clusterX, clusterZ, 0)
						local clusterTree = getRandomAsset("Trees")
						
						if clusterTree then
							local clusterPlaced = spawnAsset(clusterTree, clusterPos, math.random() * math.pi * 2, treesFolder)
							if clusterPlaced then
								clusterPlaced.Name = "Tree_Cluster_" .. i .. "_" .. j
								treesPlaced = treesPlaced + 1
							end
						end
					end
					clusterCount = clusterCount + 1
				end
			end
		end
	end
	
	print(string.format("[WorldBuilder] ✅ Forêt générée : %d arbres (%d clusters)", 
		treesPlaced, clusterCount))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRATION DES ROCHERS
-- ═══════════════════════════════════════════════════════════════════════════

local function generateRocks()
	print("[WorldBuilder] 🪨 Génération des rochers...")
	
	local rocksFolder = Instance.new("Folder")
	rocksFolder.Name = "Rocks"
	rocksFolder.Parent = workspace
	
	if #AssetInventory.Rocks == 0 then
		warn("[WorldBuilder] ⚠️ Aucun rocher trouvé dans l'inventaire!")
		return
	end
	
	local rocksPlaced = 0
	
	for i = 1, CONFIG.ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = CONFIG.ROCK_MIN_RADIUS + math.random() * (CONFIG.ROCK_MAX_RADIUS - CONFIG.ROCK_MIN_RADIUS)
		
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		-- Raycast pour placement précis sur le terrain
		local position, normal = getGroundPositionPrecise(x, z, 0)
		local rotation = math.random() * math.pi * 2
		
		local rock = getRandomAsset("Rocks")
		if rock then
			local placed = spawnAsset(rock, position, rotation, rocksFolder)
			if placed then
				placed.Name = "Rock_" .. i
				rocksPlaced = rocksPlaced + 1
				
				-- Variation d'échelle pour plus de réalisme
				if placed:IsA("Model") then
					local scale = 0.7 + math.random() * 0.6 -- 0.7 à 1.3
					placed:ScaleTo(scale)
				elseif placed:IsA("BasePart") then
					local scale = 0.7 + math.random() * 0.6
					placed.Size = placed.Size * scale
				end
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
		
		-- Raycast pour placement précis
		local position, normal = getGroundPositionPrecise(x, z, 0.5)
		
		local spawn = Instance.new("Part")
		spawn.Name = "MonsterSpawn_" .. i
		spawn.Size = Vector3.new(5, 1, 5)
		spawn.CFrame = CFrame.new(position)
		spawn.Anchored = true
		spawn.Transparency = 0.8
		spawn.CanCollide = false
		spawn.Color = Color3.fromRGB(150, 0, 0)
		spawn.Material = Enum.Material.Neon
		spawn.Parent = spawnFolder
		
		-- Tag pour identification par MonsterSpawner
		CollectionService:AddTag(spawn, "MonsterSpawnPoint")
		
		-- Ajout d'un attribut pour la configuration
		spawn:SetAttribute("SpawnRadius", 10)
		spawn:SetAttribute("MaxMonsters", 3)
	end
	
	print(string.format("[WorldBuilder] ✅ Spawns générés : %d points", CONFIG.MONSTER_SPAWN_COUNT))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NETTOYAGE ET GÉNÉRATION PRINCIPALE
-- ═══════════════════════════════════════════════════════════════════════════

local function cleanupPreviousWorld()
	print("[WorldBuilder] 🧹 Nettoyage du monde précédent...")
	
	local foldersToClean = {"Village", "Trees", "Rocks", "MonsterSpawns", "Decorations", "GiantTreeHub"}
	local cleanedCount = 0
	
	for _, folderName in ipairs(foldersToClean) do
		local existing = workspace:FindFirstChild(folderName)
		if existing then
			existing:Destroy()
			cleanedCount = cleanedCount + 1
		end
	end
	
	print(string.format("[WorldBuilder] ✅ %d dossiers nettoyés", cleanedCount))
end

local function generateWorld()
	local startTime = tick()
	
	print("════════════════════════════════════════════════════════════════")
	print("          🌍 WORLDBUILDER - GÉNÉRATION PROCÉDURALE 🌍")
	print("════════════════════════════════════════════════════════════════")
	
	-- Phase 1 : Scan et inventaire des assets
	local scanSuccess = buildAssetInventory()
	if not scanSuccess then
		error("[WorldBuilder] ❌ Échec du scan des assets, génération annulée.")
	end
	
	-- Phase 2 : Génération du rapport d'inventaire
	generateInventoryReport()
	
	-- Phase 3 : Nettoyage du monde existant
	cleanupPreviousWorld()
	
	-- Phase 4 : Génération du monde
	print("[WorldBuilder] 🏗️ Début de la génération du monde...")
	
	task.wait(0.5)
	generateVillage()
	
	task.wait(0.5)
	generateForest()
	
	task.wait(0.5)
	generateRocks()
	
	task.wait(0.5)
	generateMonsterSpawns()
	
	local elapsedTime = tick() - startTime
	
	print("════════════════════════════════════════════════════════════════")
	print(string.format("          ✅ MONDE GÉNÉRÉ AVEC SUCCÈS EN %.2fs !", elapsedTime))
	print("════════════════════════════════════════════════════════════════")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXÉCUTION AU DÉMARRAGE
-- ═══════════════════════════════════════════════════════════════════════════

generateWorld()