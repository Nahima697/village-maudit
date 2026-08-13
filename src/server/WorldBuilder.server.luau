--[[
	WorldBuilder.server.luau
	Génère la map complète de Village Maudit en GRAYBOX (blocs simples).
	Utilise MapConfig pour toutes les positions/tailles.
	Maintient la compatibilité avec MonsterSpawner et VotingSystem (workspace:SetAttribute("WorldReady", true)).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Charger la configuration de la map
local MapConfig = require(script.Parent.WorldGen.MapConfig)

-- ============================================================================
-- UTILITAIRES
-- ============================================================================

local function clearExistingWorld()
	local foldersToClean = {
		"River", "OldBridge", "CentralSquare", "SacredFire", 
		"Houses", "Workshop", "Cemetery", "CursedForest", "MonsterSpawns"
	}
	for _, folderName in ipairs(foldersToClean) do
		local existing = workspace:FindFirstChild(folderName)
		if existing then
			existing:Destroy()
		end
	end
end

-- ============================================================================
-- SOL
-- ============================================================================

local function ensureBaseplate()
	if workspace:FindFirstChild("BasePlate") or workspace:FindFirstChild("Baseplate") then
		return
	end
	local bp = Instance.new("Part")
	bp.Name = "BasePlate"
	bp.Size = Vector3.new(400, 1, 400)
	bp.Position = Vector3.new(0, -0.5, 0)
	bp.Anchored = true
	bp.Color = Color3.fromRGB(95, 115, 55)
	bp.Material = Enum.Material.Grass
	bp.Parent = workspace
	print("[WorldBuilder] BasePlate créé.")
end

-- ============================================================================
-- RIVIÈRE
-- ============================================================================

local function generateRiver()
	local riverFolder = Instance.new("Folder")
	riverFolder.Name = "River"
	riverFolder.Parent = workspace

	for i = 1, #MapConfig.RIVER_PATH - 1 do
		local p1 = MapConfig.RIVER_PATH[i]
		local p2 = MapConfig.RIVER_PATH[i + 1]
		local midpoint = (p1 + p2) / 2
		local distance = (p2 - p1).Magnitude

		local segment = Instance.new("Part")
		segment.Name = "RiverSegment_" .. i
		segment.Size = Vector3.new(MapConfig.RIVER_WIDTH, 0.5, distance)
		segment.Position = midpoint
		segment.CFrame = CFrame.lookAt(midpoint, p2) * CFrame.Angles(math.rad(90), 0, 0)
		segment.Anchored = true
		segment.CanCollide = false
		segment.Material = Enum.Material.Water
		segment.Color = Color3.fromRGB(30, 50, 100)
		segment.Transparency = 0.3
		segment.Parent = riverFolder
	end

	print("[WorldBuilder] Rivière générée avec " .. (#MapConfig.RIVER_PATH - 1) .. " segments.")
end

-- ============================================================================
-- PONT + PORTE
-- ============================================================================

local function generateBridge()
	local bridgeFolder = Instance.new("Folder")
	bridgeFolder.Name = "OldBridge"
	bridgeFolder.Parent = workspace

	-- Pont principal
	local bridge = Instance.new("Part")
	bridge.Name = "BridgeDeck"
	bridge.Size = Vector3.new(MapConfig.BRIDGE_WIDTH, 1, 20)
	bridge.Position = MapConfig.BRIDGE_POSITION
	bridge.Anchored = true
	bridge.CanCollide = true
	bridge.Material = Enum.Material.Wood
	bridge.Color = Color3.fromRGB(120, 80, 40)
	bridge.Parent = bridgeFolder

	-- Porte/barrière côté village (extrémité sud du pont)
	local doorPos = MapConfig.BRIDGE_POSITION + Vector3.new(0, 2, -10)
	local door = Instance.new("Part")
	door.Name = "Door"
	door.Size = Vector3.new(MapConfig.BRIDGE_WIDTH - 2, 4, 1)
	door.Position = doorPos
	door.Anchored = true
	door.CanCollide = true
	door.Material = Enum.Material.Wood
	door.Color = Color3.fromRGB(80, 50, 20)
	door.Parent = bridgeFolder

	-- Tagguer et attributs pour MonsterSpawner
	CollectionService:AddTag(door, "Door")
	door:SetAttribute("Health", 500)
	door:SetAttribute("MaxHealth", 500)

	print("[WorldBuilder] Pont et porte générés, porte taguée pour MonsterSpawner.")
end

-- ============================================================================
-- PLACE CENTRALE + BRASIER
-- ============================================================================

local function generateCentralSquare()
	local squareFolder = Instance.new("Folder")
	squareFolder.Name = "CentralSquare"
	squareFolder.Parent = workspace

	-- Sol de la place (cylindre plat)
	local square = Instance.new("Part")
	square.Name = "SquareFloor"
	square.Shape = Enum.PartType.Cylinder
	square.Size = Vector3.new(0.5, MapConfig.VILLAGE_RADIUS * 2, MapConfig.VILLAGE_RADIUS * 2)
	square.Position = MapConfig.VILLAGE_CENTER
	square.Orientation = Vector3.new(0, 0, 90)
	square.Anchored = true
	square.CanCollide = true
	square.Material = Enum.Material.Cobblestone
	square.Color = Color3.fromRGB(150, 140, 130)
	square.Parent = squareFolder

	print("[WorldBuilder] Place centrale générée.")
end

local function generateSacredFire()
	local fireFolder = Instance.new("Folder")
	fireFolder.Name = "SacredFire"
	fireFolder.Parent = workspace

	-- Brasier (cylindre)
	local fire = Instance.new("Part")
	fire.Name = "FirePit"
	fire.Shape = Enum.PartType.Cylinder
	fire.Size = Vector3.new(2, 3, 3)
	fire.Position = MapConfig.VILLAGE_CENTER + Vector3.new(0, 1, 0)
	fire.Orientation = Vector3.new(0, 0, 90)
	fire.Anchored = true
	fire.CanCollide = false
	fire.Material = Enum.Material.Neon
	fire.Color = Color3.fromRGB(255, 100, 0)
	fire.Parent = fireFolder

	-- Lumière
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 50)
	light.Brightness = 2
	light.Range = 30
	light.Parent = fire

	print("[WorldBuilder] Brasier sacré généré.")
end

-- ============================================================================
-- MAISONS
-- ============================================================================

local function generateHouses()
	local housesFolder = Instance.new("Folder")
	housesFolder.Name = "Houses"
	housesFolder.Parent = workspace

	for i, zone in ipairs(MapConfig.HOUSE_ZONES) do
		local house = Instance.new("Part")
		house.Name = "House_" .. i
		house.Size = zone.Size
		house.Position = zone.Position
		house.Orientation = Vector3.new(0, zone.Rotation or 0, 0)
		house.Anchored = true
		house.CanCollide = true
		house.Material = Enum.Material.Brick
		house.Color = Color3.fromRGB(120, 100, 80)
		house.Parent = housesFolder
	end

	print("[WorldBuilder] " .. #MapConfig.HOUSE_ZONES .. " maisons générées.")
end

-- ============================================================================
-- ATELIER
-- ============================================================================

local function generateWorkshop()
	local workshopFolder = Instance.new("Folder")
	workshopFolder.Name = "Workshop"
	workshopFolder.Parent = workspace

	local zone = MapConfig.WORKSHOP_ZONE
	local workshop = Instance.new("Part")
	workshop.Name = "WorkshopBuilding"
	workshop.Size = zone.Size
	workshop.Position = zone.Position
	workshop.Orientation = Vector3.new(0, zone.Rotation or 0, 0)
	workshop.Anchored = true
	workshop.CanCollide = true
	workshop.Material = Enum.Material.Wood
	workshop.Color = Color3.fromRGB(100, 70, 40)
	workshop.Parent = workshopFolder

	print("[WorldBuilder] Atelier généré.")
end

-- ============================================================================
-- CIMETIÈRE
-- ============================================================================

local function generateCemetery()
	local cemeteryFolder = Instance.new("Folder")
	cemeteryFolder.Name = "Cemetery"
	cemeteryFolder.Parent = workspace

	local zone = MapConfig.CEMETERY_ZONE
	local centerPos = zone.Position

	-- Générer 8 stèles simples
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local radius = 8
		local x = centerPos.X + math.cos(angle) * radius
		local z = centerPos.Z + math.sin(angle) * radius

		local tombstone = Instance.new("Part")
		tombstone.Name = "Tombstone_" .. i
		tombstone.Size = Vector3.new(2, 3, 0.3)
		tombstone.Position = Vector3.new(x, 1.5, z)
		tombstone.Orientation = Vector3.new(0, math.deg(angle + math.pi/2), 0)
		tombstone.Anchored = true
		tombstone.CanCollide = true
		tombstone.Material = Enum.Material.Slate
		tombstone.Color = Color3.fromRGB(60, 60, 60)
		tombstone.Parent = cemeteryFolder
	end

	print("[WorldBuilder] Cimetière généré avec 8 stèles.")
end

-- ============================================================================
-- FORÊT MAUDITE
-- ============================================================================

local function generateForest()
	local forestFolder = Instance.new("Folder")
	forestFolder.Name = "CursedForest"
	forestFolder.Parent = workspace

	local center = MapConfig.VILLAGE_CENTER
	local innerRadius = MapConfig.FOREST_INNER_RADIUS
	local outerRadius = MapConfig.FOREST_OUTER_RADIUS
	local treeCount = 60
	local minSpacing = 8

	local treePositions = {}

	for i = 1, treeCount do
		local attempts = 0
		local validPosition = false
		local x, z

		-- Trouver une position valide (pas trop proche des autres arbres)
		while not validPosition and attempts < 20 do
			attempts = attempts + 1
			local angle = math.random() * math.pi * 2
			local dist = innerRadius + math.random() * (outerRadius - innerRadius)
			x = center.X + math.cos(angle) * dist
			z = center.Z + math.sin(angle) * dist

			validPosition = true
			for _, pos in ipairs(treePositions) do
				if (Vector3.new(x, 0, z) - pos).Magnitude < minSpacing then
					validPosition = false
					break
				end
			end
		end

		if not validPosition then
			continue
		end

		table.insert(treePositions, Vector3.new(x, 0, z))

		-- Tronc
		local trunk = Instance.new("Part")
		trunk.Name = "TreeTrunk_" .. i
		trunk.Size = Vector3.new(2, 8, 2)
		trunk.Position = Vector3.new(x, 4, z)
		trunk.Anchored = true
		trunk.CanCollide = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(70, 50, 30)
		trunk.Parent = forestFolder

		-- Feuillage
		local foliage = Instance.new("Part")
		foliage.Name = "TreeFoliage_" .. i
		foliage.Shape = Enum.PartType.Ball
		foliage.Size = Vector3.new(6, 6, 6)
		foliage.Position = Vector3.new(x, 9, z)
		foliage.Anchored = true
		foliage.CanCollide = false
		foliage.Material = Enum.Material.Grass
		foliage.Color = Color3.fromRGB(40, 60, 30)
		foliage.Parent = forestFolder
	end

	print("[WorldBuilder] Forêt maudite générée avec " .. #treePositions .. " arbres.")
end

-- ============================================================================
-- POINTS DE SPAWN DES MONSTRES
-- ============================================================================

local function generateMonsterSpawns()
	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "MonsterSpawns"
	spawnsFolder.Parent = workspace

	local center = MapConfig.VILLAGE_CENTER
	local spawnRadius = MapConfig.FOREST_INNER_RADIUS + 15

	for i = 1, 6 do
		local angle = (i - 1) * (math.pi * 2 / 6)
		local x = center.X + math.cos(angle) * spawnRadius
		local z = center.Z + math.sin(angle) * spawnRadius

		local spawn = Instance.new("Part")
		spawn.Name = "MonsterSpawn_" .. i
		spawn.Size = Vector3.new(4, 1, 4)
		spawn.Position = Vector3.new(x, 0.5, z)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = spawnsFolder

		CollectionService:AddTag(spawn, "MonsterSpawnPoint")
	end

	print("[WorldBuilder] 6 points de spawn de monstres générés dans la forêt.")
end

-- ============================================================================
-- SÉQUENCE DE GÉNÉRATION PRINCIPALE
-- ============================================================================

print("[WorldBuilder] Début de la génération de la map...")

clearExistingWorld()
ensureBaseplate()
generateRiver()
generateBridge()
generateCentralSquare()
generateSacredFire()
generateHouses()
generateWorkshop()
generateCemetery()
generateForest()
generateMonsterSpawns()

-- Signal de fin pour MonsterSpawner et VotingSystem
workspace:SetAttribute("WorldReady", true)

print("[WorldBuilder] Génération GRAYBOX terminée. Map prête. WorldReady = true.")