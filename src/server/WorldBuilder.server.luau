--[[
	WorldBuilder.server.luau
	Génère le village en assemblant EXPLICITEMENT des prefabs nommés précisément
	(aucun scan/pattern-matching : les noms exacts ont été confirmés par l'utilisateur
	depuis ReplicatedStorage.Prefabs après import du pack "Medieval Village MegaKit"
	et "KayKit Forest Nature Pack").
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	VILLAGE_RADIUS = 45,
	BUILDING_COUNT = 6,
	FOREST_MIN_RADIUS = 60,
	FOREST_MAX_RADIUS = 150,
	TREE_COUNT = 100,
	ROCK_COUNT = 30,
}

local Prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
if not Prefabs then
	warn("[WorldBuilder] ❌ Dossier Prefabs introuvable dans ReplicatedStorage !")
	return
end

-- ========================================
-- NOMS EXACTS UTILISÉS (confirmés dans Prefabs le 04/08)
-- ========================================
local WALL_STRAIGHT = "Wall_Plaster_Straight"
local WALL_DOOR = "Wall_Plaster_Door_Flat"
local CORNER = "Corner_Exterior_Wood"
local ROOF = "Roof_RoundTiles_6x6"
local FLOOR = "Floor_WoodDark"

local TREE_NAMES = {"Tree_1_C_Color1", "Tree_2_E_Color1", "Tree_4_B_Color1", "Tree_Bare_1_A_Color1"}
local ROCK_NAMES = {"Rock_1_A_Color1", "Rock_1_Q_Color1", "Rock_2_A_Color1"}
local BUSH_NAMES = {"Bush_1_A_Color1", "Bush_1_B_Color1", "Bush_1_F_Color1"}

-- ========================================
-- UTILITAIRES
-- ========================================

local function getPrefab(name)
	local p = Prefabs:FindFirstChild(name)
	if not p then
		warn("[WorldBuilder] ⚠️ Prefab introuvable :", name)
	end
	return p
end

local function clonePrefab(name)
	local prefab = getPrefab(name)
	if not prefab then return nil end
	return prefab:Clone()
end

local function anchorModel(model)
	if model:IsA("BasePart") then
		model.Anchored = true
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

local function placeAt(model, cframe, parent)
	if not model then return nil end
	anchorModel(model)
	if model:IsA("Model") then
		if not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
		if model.PrimaryPart then
			model:PivotTo(cframe)
		end
	elseif model:IsA("BasePart") then
		model.CFrame = cframe
	end
	model.Parent = parent
	return model
end

-- Retourne la taille (Vector3) du prefab tel que stocké dans Prefabs,
-- pour pouvoir aligner les pièces bord à bord sans valeur codée en dur.
local function getPrefabSize(name)
	local prefab = getPrefab(name)
	if not prefab then return Vector3.new(4, 4, 4) end
	local ok, size = pcall(function()
		if prefab:IsA("Model") then
			local _, s = prefab:GetBoundingBox()
			return s
		elseif prefab:IsA("BasePart") then
			return prefab.Size
		end
	end)
	if ok and size then
		return size
	end
	return Vector3.new(4, 4, 4)
end

-- ========================================
-- CONSTRUCTION D'UN BÂTIMENT (4 murs, 1 porte, 4 coins, sol, toit)
-- ========================================

local wallSize = getPrefabSize(WALL_STRAIGHT)
local WALL_WIDTH = wallSize.X > 0 and wallSize.X or 8
local WALL_HEIGHT = wallSize.Y > 0 and wallSize.Y or 8

local function buildHouse(center, rotationY, parentFolder, buildingIndex)
	local houseFolder = Instance.new("Model")
	houseFolder.Name = "Building_" .. buildingIndex
	houseFolder.Parent = parentFolder

	local baseCFrame = CFrame.new(center) * CFrame.Angles(0, math.rad(rotationY), 0)
	local half = WALL_WIDTH / 2

	-- Sol
	local floor = clonePrefab(FLOOR)
	if floor then
		placeAt(floor, baseCFrame, houseFolder)
	end

	-- 4 murs (façade avant = porte, les 3 autres = pleins)
	local wallOffsets = {
		{name = WALL_DOOR,     offset = CFrame.new(0, 0, -half) * CFrame.Angles(0, 0, 0)},
		{name = WALL_STRAIGHT, offset = CFrame.new(0, 0, half) * CFrame.Angles(0, math.rad(180), 0)},
		{name = WALL_STRAIGHT, offset = CFrame.new(-half, 0, 0) * CFrame.Angles(0, math.rad(90), 0)},
		{name = WALL_STRAIGHT, offset = CFrame.new(half, 0, 0) * CFrame.Angles(0, math.rad(-90), 0)},
	}

	for _, w in ipairs(wallOffsets) do
		local wall = clonePrefab(w.name)
		if wall then
			placeAt(wall, baseCFrame * w.offset, houseFolder)
		end
	end

	-- 4 coins
	local cornerOffsets = {
		CFrame.new(-half, 0, -half),
		CFrame.new(half, 0, -half) * CFrame.Angles(0, math.rad(90), 0),
		CFrame.new(half, 0, half) * CFrame.Angles(0, math.rad(180), 0),
		CFrame.new(-half, 0, half) * CFrame.Angles(0, math.rad(-90), 0),
	}
	for _, offset in ipairs(cornerOffsets) do
		local corner = clonePrefab(CORNER)
		if corner then
			placeAt(corner, baseCFrame * offset, houseFolder)
		end
	end

	-- Toit
	local roof = clonePrefab(ROOF)
	if roof then
		placeAt(roof, baseCFrame * CFrame.new(0, WALL_HEIGHT, 0), houseFolder)
	end

	-- Tag "Door" sur le mur-porte pour que MonsterSpawner le retrouve
	local doorWall = houseFolder:FindFirstChild(WALL_DOOR)
	if doorWall then
		CollectionService:AddTag(doorWall, "Door")
		if doorWall:IsA("Model") then
			local part = doorWall.PrimaryPart or doorWall:FindFirstChildWhichIsA("BasePart", true)
			if part then
				part:SetAttribute("Health", 500)
				part:SetAttribute("MaxHealth", 500)
			end
		elseif doorWall:IsA("BasePart") then
			doorWall:SetAttribute("Health", 500)
			doorWall:SetAttribute("MaxHealth", 500)
		end
	end

	return houseFolder
end

-- ========================================
-- FORÊT & ROCHERS (KayKit, fonctionnait déjà bien)
-- ========================================

local function generateForest(parentFolder)
	for i = 1, CONFIG.TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local dist = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local treeName = TREE_NAMES[math.random(1, #TREE_NAMES)]
		local tree = clonePrefab(treeName)
		if tree then
			placeAt(tree, CFrame.new(x, 0, z), parentFolder)
			CollectionService:AddTag(tree, "Collectable")
			tree:SetAttribute("ResourceType", "Wood")
		end

		if math.random() < 0.3 then
			local bush = clonePrefab(BUSH_NAMES[math.random(1, #BUSH_NAMES)])
			if bush then
				placeAt(bush, CFrame.new(x + math.random(-6, 6), 0, z + math.random(-6, 6)), parentFolder)
			end
		end
	end
end

local function generateRocks(parentFolder)
	for i = 1, CONFIG.ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local dist = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local rock = clonePrefab(ROCK_NAMES[math.random(1, #ROCK_NAMES)])
		if rock then
			placeAt(rock, CFrame.new(x, 0, z), parentFolder)
			CollectionService:AddTag(rock, "Collectable")
			rock:SetAttribute("ResourceType", "Stone")
		end
	end
end

-- ========================================
-- POINTS DE SPAWN DE MONSTRES
-- ========================================

local function generateMonsterSpawns(parentFolder)
	for i = 1, 6 do
		local angle = (i - 1) * (math.pi * 2 / 6)
		local dist = CONFIG.VILLAGE_RADIUS + 20
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist

		local spawnPoint = Instance.new("Part")
		spawnPoint.Name = "MonsterSpawn_" .. i
		spawnPoint.Size = Vector3.new(4, 1, 4)
		spawnPoint.Position = Vector3.new(x, 0.5, z)
		spawnPoint.Anchored = true
		spawnPoint.Transparency = 1
		spawnPoint.CanCollide = false
		spawnPoint.Parent = parentFolder
		CollectionService:AddTag(spawnPoint, "MonsterSpawnPoint")
	end
end

-- ========================================
-- GÉNÉRATION COMPLÈTE
-- ========================================

local function cleanup()
	for _, name in ipairs({"Village", "Trees", "Rocks", "MonsterSpawns"}) do
		local folder = workspace:FindFirstChild(name)
		if folder then folder:Destroy() end
	end
end

local function generateWorld()
	cleanup()

	local baseplate = workspace:FindFirstChild("Baseplate") or workspace:FindFirstChild("BasePlate")
	if not baseplate then
		local bp = Instance.new("Part")
		bp.Name = "BasePlate"
		bp.Size = Vector3.new(400, 1, 400)
		bp.Position = Vector3.new(0, -0.5, 0)
		bp.Anchored = true
		bp.Color = Color3.fromRGB(95, 115, 55)
		bp.Material = Enum.Material.Grass
		bp.Parent = workspace
	end

	local villageFolder = Instance.new("Folder")
	villageFolder.Name = "Village"
	villageFolder.Parent = workspace

	for i = 1, CONFIG.BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.BUILDING_COUNT)
		local x = math.cos(angle) * CONFIG.VILLAGE_RADIUS
		local z = math.sin(angle) * CONFIG.VILLAGE_RADIUS
		-- Le bâtiment fait face au centre du village
		local facingAngle = math.deg(math.atan2(-x, -z))
		buildHouse(Vector3.new(x, 0, z), facingAngle, villageFolder, i)
	end

	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = workspace
	generateForest(treesFolder)

	local rocksFolder = Instance.new("Folder")
	rocksFolder.Name = "Rocks"
	rocksFolder.Parent = workspace
	generateRocks(rocksFolder)

	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "MonsterSpawns"
	spawnsFolder.Parent = workspace
	generateMonsterSpawns(spawnsFolder)

	print("[WorldBuilder] ✅ Village généré avec", CONFIG.BUILDING_COUNT, "bâtiments,", CONFIG.TREE_COUNT, "arbres,", CONFIG.ROCK_COUNT, "rochers")
end

generateWorld()
