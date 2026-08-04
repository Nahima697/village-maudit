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

-- Ces deux objets sont des environnements complets pré-construits
-- (sol + murs + décor intégrés sur 150-200 studs). Pas de calcul en
-- cercle pour eux (pensé pour des petits props) : position fixe dédiée
-- à côté du village, mais posés au sol comme les autres.
local FIXED_ENVIRONMENTS = {
	["Forest Portal Template"] = {x = 200, z = 30},
	["Graveyard Map"] = {x = -200, z = 30},
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
		local _, yaw, _ = pivot:ToEulerAnglesYXZ()
		obj:PivotTo(CFrame.new(x, pivot.Position.Y - bottomY, z) * CFrame.Angles(0, yaw, 0))
	elseif obj:IsA("BasePart") then
		obj.Anchored = true
		obj.Position = Vector3.new(x, obj.Size.Y / 2, z)
	end
end

local function placeFixedEnvironments()
	for name, coords in pairs(FIXED_ENVIRONMENTS) do
		local obj = workspace:FindFirstChild(name)
		if obj then
			placeOnGround(obj, coords.x, coords.z)
			print("[WorldBuilder] Environnement fixe '" .. name .. "' placé à (" .. coords.x .. ", " .. coords.z .. ").")
		end
	end
end

local function arrangeLooseObjects()
	local grouped = {Forest = {}, Cemetery = {}, CloseDecor = {}, Default = {}}

	for _, obj in ipairs(workspace:GetChildren()) do
		if not EXCLUDED_NAMES[obj.Name] and not FIXED_ENVIRONMENTS[obj.Name] and (obj:IsA("Model") or obj:IsA("BasePart")) then
			local zoneName = classify(obj.Name)
			table.insert(grouped[zoneName], obj)
		end
	end

	local totalCount = 0

	for zoneName, objects in pairs(grouped) do
		local zone = ZONES[zoneName]
		local count = #objects
		if count > 0 then
			-- Calcule un "diamètre" approximatif pour chaque objet, pour lui
			-- donner un espace angulaire proportionnel à sa taille réelle
			-- (évite qu'un gros objet chevauche son voisin).
			local diameters = {}
			local totalDiameter = 0
			for _, obj in ipairs(objects) do
				local d = 8
				if obj:IsA("Model") then
					local _, size = obj:GetBoundingBox()
					d = math.max(size.X, size.Z)
				elseif obj:IsA("BasePart") then
					d = math.max(obj.Size.X, obj.Size.Z)
				end
				d = math.max(d, 4) + 6 -- marge de sécurité entre objets
				table.insert(diameters, d)
				totalDiameter = totalDiameter + d
			end

			local radius = (zone.radiusMin + zone.radiusMax) / 2
			-- Si la somme des diamètres dépasse la circonférence disponible,
			-- on agrandit le rayon pour que tout tienne sans se chevaucher.
			local circumference = math.rad(zone.angleMax - zone.angleMin) * radius
			if totalDiameter > circumference and circumference > 0 then
				radius = totalDiameter / math.rad(zone.angleMax - zone.angleMin)
			end

			local angleStart = math.rad(zone.angleMin)
			local currentAngle = angleStart
			for i, obj in ipairs(objects) do
				local angleStep = diameters[i] / radius
				local angle = currentAngle + angleStep / 2
				local x = CONFIG.CENTER.X + math.cos(angle) * radius
				local z = CONFIG.CENTER.Z + math.sin(angle) * radius
				placeOnGround(obj, x, z)
				currentAngle = currentAngle + angleStep
			end

			print("[WorldBuilder] Zone '" .. zoneName .. "' : " .. count .. " objet(s) placé(s) (rayon ajusté: " .. math.floor(radius) .. ").")
			totalCount = totalCount + count
		end
	end

	print("[WorldBuilder] " .. totalCount .. " objet(s) rangé(s) au total, répartis par zone.")
end

local function duplicateHouses(count)
	local template = workspace:FindFirstChild("MedievalHouse")
	if not template then
		warn("[WorldBuilder] MedievalHouse introuvable, impossible de dupliquer")
		return
	end

	local _, size = template:GetBoundingBox()
	local spacing = math.max(size.X, size.Z) + 15

	for i = 1, count do
		local clone = template:Clone()
		clone.Name = "MedievalHouse_Copy" .. i
		local angle = (i / (count + 1)) * math.pi * 2
		local radius = 90
		local x = CONFIG.CENTER.X + math.cos(angle) * radius
		local z = CONFIG.CENTER.Z + math.sin(angle) * radius
		placeOnGround(clone, x, z)
		clone.Parent = workspace
		print("[WorldBuilder] Maison dupliquée : " .. clone.Name .. " à (" .. math.floor(x) .. ", " .. math.floor(z) .. ")")
	end
end

ensureBaseplate()
generateMonsterSpawns()
placeFixedEnvironments()
arrangeLooseObjects()
-- Décommente la ligne suivante et ajuste le nombre pour dupliquer des maisons :
-- duplicateHouses(3)

print("[WorldBuilder] Sol + points de spawn prêts. Objets rangés par zone au démarrage.")
