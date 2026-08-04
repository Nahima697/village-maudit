--[[
	WorldBuilder.server.luau (version minimale)
	Sol + forêt + rochers + points de spawn. Chaque prefab est remis à une
	taille cible en studs (mesurée individuellement), avec une rotation
	correctrice car le pack a été exporté avec Z comme axe "haut" au lieu
	de Y (convention Blender vs Roblox) - sans ça, tout apparaît couché.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CONFIG = {
	VILLAGE_RADIUS = 45,
	FOREST_MIN_RADIUS = 60,
	FOREST_MAX_RADIUS = 150,
	TREE_COUNT = 100,
	ROCK_COUNT = 30,
	TARGET_TREE_HEIGHT = 20,
	TARGET_ROCK_HEIGHT = 5,
}

local Prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
if not Prefabs then
	warn("[WorldBuilder] Dossier Prefabs introuvable dans ReplicatedStorage !")
	return
end

local TREE_NAMES = {"Tree_1_C_Color1", "Tree_2_E_Color1", "Tree_4_B_Color1", "Tree_Bare_1_A_Color1"}
local ROCK_NAMES = {"Rock_1_A_Color1", "Rock_1_Q_Color1", "Rock_2_A_Color1"}

-- Rotation correctrice : le pack a été exporté avec Z comme axe "haut"
-- (convention Blender), Roblox utilise Y. Sans ceci, tout est couché.
local UP_AXIS_CORRECTION = CFrame.Angles(math.rad(-90), 0, 0)

local function clonePrefab(name)
	local p = Prefabs:FindFirstChild(name)
	if not p then
		warn("[WorldBuilder] Prefab introuvable :", name)
		return nil
	end
	return p:Clone()
end

local function scaleToHeight(model, targetHeight)
	if not model:IsA("Model") then return end
	local ok, size = pcall(function()
		local _, s = model:GetBoundingBox()
		return s
	end)
	if ok and size and size.Y > 0 then
		local factor = targetHeight / size.Y
		pcall(function()
			model:ScaleTo(factor)
		end)
	end
end

local function anchorAll(model)
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
	if not model then return end
	anchorAll(model)
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
end

local function cleanup()
	for _, name in ipairs({"Village", "Trees", "Rocks", "MonsterSpawns"}) do
		local f = workspace:FindFirstChild(name)
		if f then f:Destroy() end
	end
end

local function generateForest(parentFolder)
	for i = 1, CONFIG.TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local dist = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local nameIndex = math.random(1, #TREE_NAMES)
		local tree = clonePrefab(TREE_NAMES[nameIndex])
		if tree then
			scaleToHeight(tree, CONFIG.TARGET_TREE_HEIGHT)
			local randomYaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
			placeAt(tree, CFrame.new(x, 0, z) * randomYaw * UP_AXIS_CORRECTION, parentFolder)
			CollectionService:AddTag(tree, "Collectable")
			tree:SetAttribute("ResourceType", "Wood")
		end
	end
end

local function generateRocks(parentFolder)
	for i = 1, CONFIG.ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local dist = CONFIG.FOREST_MIN_RADIUS + math.random() * (CONFIG.FOREST_MAX_RADIUS - CONFIG.FOREST_MIN_RADIUS)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist
		local nameIndex = math.random(1, #ROCK_NAMES)
		local rock = clonePrefab(ROCK_NAMES[nameIndex])
		if rock then
			scaleToHeight(rock, CONFIG.TARGET_ROCK_HEIGHT)
			local randomYaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
			placeAt(rock, CFrame.new(x, 0, z) * randomYaw * UP_AXIS_CORRECTION, parentFolder)
			CollectionService:AddTag(rock, "Collectable")
			rock:SetAttribute("ResourceType", "Stone")
		end
	end
end

local function generateMonsterSpawns(parentFolder)
	for i = 1, 6 do
		local angle = (i - 1) * (math.pi * 2 / 6)
		local dist = CONFIG.VILLAGE_RADIUS + 20
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist

		local sp = Instance.new("Part")
		sp.Name = "MonsterSpawn_" .. i
		sp.Size = Vector3.new(4, 1, 4)
		sp.Position = Vector3.new(x, 0.5, z)
		sp.Anchored = true
		sp.Transparency = 1
		sp.CanCollide = false
		sp.Parent = parentFolder
		CollectionService:AddTag(sp, "MonsterSpawnPoint")
	end
end

local function generateWorld()
	cleanup()

	if not workspace:FindFirstChild("BasePlate") and not workspace:FindFirstChild("Baseplate") then
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

	print("[WorldBuilder] Terrain, forêt (" .. CONFIG.TREE_COUNT .. " arbres), rochers (" .. CONFIG.ROCK_COUNT .. ") générés, orientation corrigée.")
end

generateWorld()
