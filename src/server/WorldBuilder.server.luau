--[[
	WorldBuilder.server.luau
	Le village (bâtiments) est placé À LA MAIN dans Studio (modèles du Toolbox).
	Ce script gère : le sol, les points de spawn des monstres, ET repositionne
	automatiquement au démarrage tout objet "en vrac" posé dans le Workspace,
	en le classant par ZONE selon des mots-clés dans son nom :
	- Forêt (Tree/Bush/Rock/Portal) : anneau extérieur, lointain
	- Cimetière (Grave/Tomb/Cemetery) : zone groupée à part, pas en anneau
	- Décor proche (Barrel/Crate/Cart/Fence/Torch/Lamp/Wagon) : anneau proche du village
	- Tout le reste : anneau intermédiaire
]]

local CollectionService = game:GetService("CollectionService")

local CONFIG = {
	VILLAGE_RADIUS = 45,
	CENTER = Vector3.new(0, 0, 30),
}

local EXCLUDED_NAMES = {
	Terrain = true, Camera = true, MedievalHouse = true,
	BasePlate = true, Baseplate = true, MonsterSpawns = true,
	Campfires = true, Hazards = true,
}

local ZONES = {
	Forest = {
		keywords = {"tree", "bush", "rock", "portal", "log", "stump"},
		radiusMin = 70, radiusMax = 100,
		angleMin = 0, angleMax = 360,
	},
	Cemetery = {
		keywords = {"grave", "tomb", "cemetery", "pike", "spike"},
		radiusMin = 50, radiusMax = 60,
		angleMin = 200, angleMax = 260,
	},
	CloseDecor = {
		keywords = {"barrel", "crate", "cart", "fence", "torch", "lamp", "wagon"},
		radiusMin = 20, radiusMax = 35,
		angleMin = 0, angleMax = 360,
	},
	Default = {
		keywords = {},
		radiusMin = 55, radiusMax = 65,
		angleMin = 0, angleMax = 360,
	},
}

local function classify(name)
	local lower = name:lower()
	for zoneName, zone in pairs(ZONES) do
		if zoneName ~= "Default" then
			for _, kw in ipairs(zone.keywords) do
				if lower:match(kw) then
					return zoneName
				end
			end
		end
	end
	return "Default"
end

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
end

local function generateMonsterSpawns()
	local existing = workspace:FindFirstChild("MonsterSpawns")
	if existing then existing:Destroy() end

	local spawnsFolder = Instance.new("Folder")
	spawnsFolder.Name = "MonsterSpawns"
	spawnsFolder.Parent = workspace

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
		sp.Parent = spawnsFolder
		CollectionService:AddTag(sp, "MonsterSpawnPoint")
	end
end

local function placeOnGround(obj, x, z)
	if obj:IsA("Model") then
		for _, part in ipairs(obj:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		local cf, size = obj:GetBoundingBox()
		local bottomY = cf.Position.Y - size.Y / 2
		local pivot = obj:GetPivot()
		local deltaX = x - pivot.Position.X
		local deltaY = -bottomY
		local deltaZ = z - pivot.Position.Z
		obj:PivotTo(pivot + Vector3.new(deltaX, deltaY, deltaZ))
	elseif obj:IsA("BasePart") then
		obj.Anchored = true
		obj.Position = Vector3.new(x, obj.Size.Y / 2, z)
	end
end

local function arrangeLooseObjects()
	local grouped = {Forest = {}, Cemetery = {}, CloseDecor = {}, Default = {}}

	for _, obj in ipairs(workspace:GetChildren()) do
		if not EXCLUDED_NAMES[obj.Name] and (obj:IsA("Model") or obj:IsA("BasePart")) then
			local zoneName = classify(obj.Name)
			table.insert(grouped[zoneName], obj)
		end
	end

	local totalCount = 0

	for zoneName, objects in pairs(grouped) do
		local zone = ZONES[zoneName]
		local count = #objects
		if count > 0 then
			local angleSpan = math.rad(zone.angleMax - zone.angleMin)
			local angleStart = math.rad(zone.angleMin)

			for i, obj in ipairs(objects) do
				local angle = angleStart + (i - 1) * (angleSpan / math.max(count, 1))
				local radius = zone.radiusMin + math.random() * (zone.radiusMax - zone.radiusMin)
				local x = CONFIG.CENTER.X + math.cos(angle) * radius
				local z = CONFIG.CENTER.Z + math.sin(angle) * radius
				placeOnGround(obj, x, z)
			end

			print("[WorldBuilder] Zone '" .. zoneName .. "' : " .. count .. " objet(s) placé(s).")
			totalCount = totalCount + count
		end
	end

	print("[WorldBuilder] " .. totalCount .. " objet(s) rangé(s) au total, répartis par zone.")
end

ensureBaseplate()
generateMonsterSpawns()
arrangeLooseObjects()

print("[WorldBuilder] Sol + points de spawn prêts. Objets rangés par zone au démarrage.")
