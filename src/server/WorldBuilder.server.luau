--[[
	WorldBuilder.server.luau
	Générateur procédural basé sur le scan dynamique de ReplicatedStorage.Prefabs
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	VILLAGE_RADIUS = 35,
	BUILDING_COUNT = 6,
	FOREST_MIN_RADIUS = 45,
	FOREST_MAX_RADIUS = 120,
	TREE_COUNT = 100,
	ROCK_COUNT = 30,
}

local Prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
if not Prefabs then
	warn("[WorldBuilder] ❌ Dossier Prefabs introuvable dans ReplicatedStorage !")
	return
end

local categories = {
	Buildings = {},
	Walls = {},
	Roofs = {},
	Floors = {},
	Doors = {},
	Trees = {},
	Rocks = {},
	Decorations = {},
	Props = {},
	Other = {}
}

local function classifyAsset(assetName)
	local lower = assetName:lower()
	
	if lower:match("building") or lower:match("house") or lower:match("structure") or lower:match("tavern") or lower:match("tower") or lower:match("hut") then
		return "Buildings"
	elseif lower:match("wall") or lower:match("fence") or lower:match("pillar") or lower:match("column") then
		return "Walls"
	elseif lower:match("roof") or lower:match("ceiling") then
		return "Roofs"
	elseif lower:match("floor") or lower:match("ground") or lower:match("tile") or lower:match("foundation") or lower:match("path") then
		return "Floors"
	elseif lower:match("door") or lower:match("gate") or lower:match("window") then
		return "Doors"
	elseif lower:match("tree") or lower:match("plant") or lower:match("bush") or lower:match("pine") or lower:match("oak") then
		return "Trees"
	elseif lower:match("rock") or lower:match("stone") or lower:match("boulder") or lower:match("cliff") then
		return "Rocks"
	elseif lower:match("decor") or lower:match("decoration") or lower:match("barrel") or lower:match("crate") or lower:match("chest") then
		return "Decorations"
	elseif lower:match("prop") or lower:match("tool") or lower:match("weapon") then
		return "Props"
	else
		return "Other"
	end
end

local function scanFolder(folder)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Folder") then
			scanFolder(child)
		elseif child:IsA("Model") or child:IsA("Part") or child:IsA("MeshPart") or child:IsA("UnionOperation") then
			local category = classifyAsset(child.Name)
			table.insert(categories[category], child)
		end
	end
end

print("[WorldBuilder] 🔍 Démarrage du scan des prefabs...")
scanFolder(Prefabs)

print("📊 Résumé de l'inventaire des assets détectés :")
for cat, list in pairs(categories) do
	print(string.format("  - %s : %d asset(s)", cat, #list))
end

local function getGroundPosition(x, z, extraHeight)
	extraHeight = extraHeight or 0
	local origin = Vector3.new(x, 300, z)
	local direction = Vector3.new(0, -500, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.IgnoreWater = true
	
	local ignoreList = {}
	for _, name in ipairs({"Village", "Trees", "Rocks", "MonsterSpawns"}) do
		local folder = workspace:FindFirstChild(name)
		if folder then table.insert(ignoreList, folder) end
	end
	raycastParams.FilterDescendantsInstances = ignoreList
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local result = workspace:Raycast(origin, direction, raycastParams)
	if result then
		return result.Position + Vector3.new(0, extraHeight, 0)
	end
	
	return Vector3.new(x, extraHeight, z)
end

local function spawnAsset(prefab, x, z, parentFolder, extraHeight)
	if not prefab then return nil end
	local clone = prefab:Clone()

	if clone:IsA("Model") then
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = true
				desc.Transparency = 0
			end
		end
	elseif clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CanCollide = true
		clone.Transparency = 0
	end

	local targetPos = getGroundPosition(x, z, extraHeight or 0)

	if clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(targetPos)
	elseif clone:IsA("Model") then
		clone:PivotTo(CFrame.new(targetPos))
	end

	clone.Parent = parentFolder
	return clone
end

local function cleanup()
	for _, name in ipairs({"Village", "Trees", "Rocks", "MonsterSpawns"}) do
		local folder = workspace:FindFirstChild(name)
		if folder then folder:Destroy() end
	end
end

local function generateWorld()
	cleanup()
	
	local villageFolder = Instance.new("Folder")
	villageFolder.Name = "Village"
	villageFolder.Parent = workspace

	for i = 1, CONFIG.BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / CONFIG.BUILDING_COUNT)
		local x = math.cos(angle) * CONFIG.VILLAGE_RADIUS
		local z = math.sin(angle) * CONFIG.VILLAGE_RADIUS

		local bModel = Instance.new("Model")
		bModel.Name = "Building_" .. i
		bModel.Parent = villageFolder

		if #categories.Buildings > 0 then
			local buildingPrefab = categories.Buildings[math.random(1, #categories.Buildings)]
			spawnAsset(buildingPrefab, x, z, bModel, 0)
		elseif #categories.Other > 0 then
			local fallbackPrefab = categories.Other[math.random(1, #categories.Other)]
			spawnAsset(fallbackPrefab, x, z, bModel, 0)
		else
			if #categories.Floors > 0 then spawnAsset(categories.Floors[math.random(1, #categories.Floors)], x, z, bModel, 0) end
			if #categories.Walls > 0 then spawnAsset(categories.Walls[math.random(1, #categories.Walls)], x, z, bModel, 1) end
			if #categories.Roofs > 0 then spawnAsset(categories.Roofs[math.random(1, #categories.Roofs)], x, z, bModel, 4) end
		end
	end

	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = workspace

	if #categories.Trees > 0 then
		for i = 1, CONFIG.TREE_COUNT do
			local angle = math.random() * math.pi * 2
			local dist = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
			local x = math.cos(angle) * dist
			local z = math.sin(angle) * dist
			spawnAsset(categories.Trees[math.random(1, #categories.Trees)], x, z, treesFolder, 0)
		end
	end

	local rocksFolder = Instance.new("Folder")
	rocksFolder.Name = "Rocks"
	rocksFolder.Parent = workspace

	if #categories.Rocks > 0 then
		for i = 1, CONFIG.ROCK_COUNT do
			local angle = math.random() * math.pi * 2
			local dist = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
			local x = math.cos(angle) * dist
			local z = math.sin(angle) * dist
			spawnAsset(categories.Rocks[math.random(1, #categories.Rocks)], x, z, rocksFolder, 0)
		end
	end

	print("[WorldBuilder] ✅ Génération du monde terminée avec succès !")
end

generateWorld()
