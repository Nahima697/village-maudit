--!strict
-- WorldBuilder.luau
-- Module de génération procédurale 100% avec Instance.new()
-- Compatible avec terrains en relief via Raycast

local WorldBuilder = {}

--// CONFIGURATION
local CONFIG = {
	-- Centre du monde
	WorldCenter = Vector3.new(0, 0, 0),
	
	-- Feu central
	FireSize = Vector3.new(8, 8, 8),
	
	-- Village
	VillageRadius = 60,
	HouseCount = 8,
	HouseSize = Vector3.new(12, 10, 12),
	RoofHeight = 8,
	
	-- Muraille
	WallRadius = 90,
	WallHeight = 15,
	WallThickness = 3,
	WallSegments = 32,
	GateWidth = 20,
	
	-- Forêt
	ForestInnerRadius = 100,
	ForestOuterRadius = 250,
	TreeCount = 200,
	TreeTrunkHeight = {8, 15},
	TreeTrunkRadius = 1.5,
	TreeFoliageSize = {8, 12},
	
	-- Spawns
	SpawnRadius = 25,
	SpawnCount = 12,
	
	-- Raycast
	RaycastHeight = 300,
	RaycastMaxDistance = 500,
}

--// UTILITAIRES

--- Trouve la hauteur du terrain à une position XZ donnée
local function GetTerrainHeight(x: number, z: number): number?
	local origin = Vector3.new(x, CONFIG.RaycastHeight, z)
	local direction = Vector3.new(0, -CONFIG.RaycastMaxDistance, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Include
	raycastParams.FilterDescendantsInstances = {workspace.Terrain}
	
	local result = workspace:Raycast(origin, direction, raycastParams)
	
	if result then
		return result.Position.Y
	end
	
	-- Fallback si pas de terrain détecté
	return 0
end

--- Génère une position au sol avec raycast
local function GetGroundPosition(x: number, z: number, yOffset: number?): Vector3
	local groundY = GetTerrainHeight(x, z) or 0
	local offset = yOffset or 0
	return Vector3.new(x, groundY + offset, z)
end

--- Crée un dossier de conteneur
local function CreateContainer(name: string, parent: Instance): Folder
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

--- Génère une couleur aléatoire dans une palette
local function RandomColor(palette: {Color3}): Color3
	return palette[math.random(1, #palette)]
end

--// GÉNÉRATION DES ÉLÉMENTS

--- Génère le feu central
local function GenerateCentralFire(container: Folder)
	local firePos = GetGroundPosition(
		CONFIG.WorldCenter.X,
		CONFIG.WorldCenter.Z,
		CONFIG.FireSize.Y / 2
	)
	
	local firePit = Instance.new("Part")
	firePit.Name = "CentralFire"
	firePit.Size = CONFIG.FireSize
	firePit.Position = firePos
	firePit.Anchored = true
	firePit.Material = Enum.Material.Slate
	firePit.Color = Color3.fromRGB(50, 50, 50)
	firePit.Parent = container
	
	local fire = Instance.new("Fire")
	fire.Size = 15
	fire.Heat = 15
	fire.Parent = firePit
	
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 60
	light.Color = Color3.fromRGB(255, 120, 40)
	light.Parent = firePit
	
	print("✓ Feu central généré")
end

--- Génère une maison simple
local function GenerateHouse(position: Vector3, rotation: number, container: Folder)
	local model = Instance.new("Model")
	model.Name = "House"
	model.Parent = container
	
	-- Mur principal
	local wall = Instance.new("Part")
	wall.Name = "Wall"
	wall.Size = CONFIG.HouseSize
	wall.Position = position
	wall.Anchored = true
	wall.Material = Enum.Material.Wood
	wall.Color = Color3.fromRGB(120, 80, 50)
	wall.Parent = model
	
	-- Toit (WedgePart)
	local roof1 = Instance.new("WedgePart")
	roof1.Name = "Roof1"
	roof1.Size = Vector3.new(
		CONFIG.HouseSize.X,
		CONFIG.RoofHeight,
		CONFIG.HouseSize.Z / 2
	)
	roof1.Position = position + Vector3.new(
		0,
		CONFIG.HouseSize.Y / 2 + CONFIG.RoofHeight / 2,
		CONFIG.HouseSize.Z / 4
	)
	roof1.Anchored = true
	roof1.Material = Enum.Material.Slate
	roof1.Color = Color3.fromRGB(180, 100, 60)
	roof1.Parent = model
	
	local roof2 = Instance.new("WedgePart")
	roof2.Name = "Roof2"
	roof2.Size = roof1.Size
	roof2.Position = position + Vector3.new(
		0,
		CONFIG.HouseSize.Y / 2 + CONFIG.RoofHeight / 2,
		-CONFIG.HouseSize.Z / 4
	)
	roof2.Orientation = Vector3.new(0, 180, 0)
	roof2.Anchored = true
	roof2.Material = Enum.Material.Slate
	roof2.Color = roof1.Color
	roof2.Parent = model
	
	-- Rotation du modèle
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.rad(rotation), 0))
end

--- Génère les maisons du village
local function GenerateVillage(container: Folder)
	for i = 1, CONFIG.HouseCount do
		local angle = (i / CONFIG.HouseCount) * math.pi * 2
		local x = CONFIG.WorldCenter.X + math.cos(angle) * CONFIG.VillageRadius
		local z = CONFIG.WorldCenter.Z + math.sin(angle) * CONFIG.VillageRadius
		
		local position = GetGroundPosition(x, z, CONFIG.HouseSize.Y / 2)
		local rotation = math.deg(angle) + 180
		
		GenerateHouse(position, rotation, container)
	end
	
	print("✓ Village généré (" .. CONFIG.HouseCount .. " maisons)")
end

--- Génère la muraille avec portes
local function GenerateWall(container: Folder)
	local segmentAngle = (math.pi * 2) / CONFIG.WallSegments
	
	-- Positions des portes (Nord, Sud, Est, Ouest)
	local gates = {0, math.pi / 2, math.pi, 3 * math.pi / 2}
	
	for i = 0, CONFIG.WallSegments - 1 do
		local angle = i * segmentAngle
		
		-- Vérifie si c'est une porte
		local isGate = false
		for _, gateAngle in ipairs(gates) do
			if math.abs(angle - gateAngle) < segmentAngle * 1.5 then
				isGate = true
				break
			end
		end
		
		if not isGate then
			local x = CONFIG.WorldCenter.X + math.cos(angle) * CONFIG.WallRadius
			local z = CONFIG.WorldCenter.Z + math.sin(angle) * CONFIG.WallRadius
			
			local position = GetGroundPosition(x, z, CONFIG.WallHeight / 2)
			
			local wallPart = Instance.new("Part")
			wallPart.Name = "WallSegment"
			wallPart.Size = Vector3.new(
				CONFIG.WallThickness * 3,
				CONFIG.WallHeight,
				CONFIG.WallThickness
			)
			wallPart.Position = position
			wallPart.Anchored = true
			wallPart.Material = Enum.Material.Cobblestone
			wallPart.Color = Color3.fromRGB(100, 100, 100)
			wallPart.Parent = container
			
			wallPart.CFrame = CFrame.new(position) * CFrame.Angles(0, angle, 0)
		end
	end
	
	print("✓ Muraille générée avec 4 portes")
end

--- Génère un arbre procédural
local function GenerateTree(x: number, z: number, container: Folder)
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = container
	
	-- Tronc
	local trunkHeight = math.random(
		CONFIG.TreeTrunkHeight[1],
		CONFIG.TreeTrunkHeight[2]
	)
	
	local trunkPos = GetGroundPosition(x, z, trunkHeight / 2)
	
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(
		CONFIG.TreeTrunkRadius * 2,
		trunkHeight,
		CONFIG.TreeTrunkRadius * 2
	)
	trunk.Position = trunkPos
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(80, 50, 30)
	trunk.Parent = model
	
	-- Feuillage (sphère approximative)
	local foliageSize = math.random(
		CONFIG.TreeFoliageSize[1],
		CONFIG.TreeFoliageSize[2]
	)
	
	local foliage = Instance.new("Part")
	foliage.Name = "Foliage"
	foliage.Shape = Enum.PartType.Ball
	foliage.Size = Vector3.new(foliageSize, foliageSize, foliageSize)
	foliage.Position = trunkPos + Vector3.new(0, trunkHeight / 2 + foliageSize / 2, 0)
	foliage.Anchored = true
	foliage.Material = Enum.Material.Grass
	foliage.Color = Color3.fromRGB(
		math.random(40, 80),
		math.random(120, 180),
		math.random(40, 80)
	)
	foliage.Parent = model
end

--- Génère la forêt dense
local function GenerateForest(container: Folder)
	for _ = 1, CONFIG.TreeCount do
		local angle = math.random() * math.pi * 2
		local distance = math.random(
			CONFIG.ForestInnerRadius,
			CONFIG.ForestOuterRadius
		)
		
		local x = CONFIG.WorldCenter.X + math.cos(angle) * distance
		local z = CONFIG.WorldCenter.Z + math.sin(angle) * distance
		
		GenerateTree(x, z, container)
	end
	
	print("✓ Forêt générée (" .. CONFIG.TreeCount .. " arbres)")
end

--- Génère les points de spawn
local function GenerateSpawns(container: Folder)
	for i = 1, CONFIG.SpawnCount do
		local angle = (i / CONFIG.SpawnCount) * math.pi * 2
		local x = CONFIG.WorldCenter.X + math.cos(angle) * CONFIG.SpawnRadius
		local z = CONFIG.WorldCenter.Z + math.sin(angle) * CONFIG.SpawnRadius
		
		local position = GetGroundPosition(x, z, 2)
		
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn" .. i
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = position
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Enabled = false
		spawn.Parent = container
	end
	
	print("✓ Spawns générés (" .. CONFIG.SpawnCount .. " points)")
end

--// FONCTION PRINCIPALE

function WorldBuilder.Generate()
	print("🌍 Génération du monde procédural...")
	
	-- Containers
	local villageContainer = CreateContainer("Village", workspace)
	local wallContainer = CreateContainer("Wall", workspace)
	local forestContainer = CreateContainer("Trees", workspace)
	local spawnsContainer = CreateContainer("Spawns", workspace)
	local fireContainer = CreateContainer("Fire", workspace)
	
	-- Génération
	GenerateCentralFire(fireContainer)
	GenerateVillage(villageContainer)
	GenerateWall(wallContainer)
	GenerateForest(forestContainer)
	GenerateSpawns(spawnsContainer)
	
	print("✅ Monde généré avec succès!")
	return true
end

function WorldBuilder.CleanUp()
	local containers = {"Village", "Wall", "Trees", "Spawns", "Fire"}
	for _, name in ipairs(containers) do
		local container = workspace:FindFirstChild(name)
		if container then
			container:Destroy()
		end
	end
	print("🧹 Monde nettoyé")
end

return WorldBuilder