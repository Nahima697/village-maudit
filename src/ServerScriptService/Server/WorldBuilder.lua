--!strict
--[[
	WorldBuilder - Générateur procédural d'environnement
	
	Génère:
	- Zone de démarrage avec feu central
	- Barricades et défenses du village
	- Forêt dense environnante
	- Points d'interaction pour crafting/inventaire
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Configuration
local CONFIG = {
	-- Village
	VillageRadius = 80,
	VillageCenterHeight = 50,
	
	-- Spawning
	SpawnPoints = 8,
	SpawnRadius = 25,
	
	-- Barricades
	BarricadeWallHeight = 12,
	BarricadeWallThickness = 3,
	BarricadeSegments = 16,
	BarricadeGates = 4,
	
	-- Forêt
	ForestInnerRadius = 100,
	ForestOuterRadius = 500,
	TreeDensity = 0.015, -- arbres par unité carrée
	TreeHeightMin = 20,
	TreeHeightMax = 45,
	TreeTrunkRadius = 2.5,
	
	-- Ressources
	ResourceNodesPerType = {
		Wood = 30,
		Stone = 20,
		Metal = 10,
	},
	
	-- Éclairage
	AmbientDarkness = true,
}

-- Dossiers principaux
local WorldFolder: Folder
local VillageFolder: Folder
local ForestFolder: Folder
local ResourcesFolder: Folder
local SpawnsFolder: Folder

--[[ UTILITAIRES ]]

local function createFolder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function randomPointInRing(innerRadius: number, outerRadius: number): Vector3
	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * (outerRadius - innerRadius) + innerRadius
	
	return Vector3.new(
		math.cos(angle) * distance,
		0,
		math.sin(angle) * distance
	)
end

local function createPart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	
	return part
end

--[[ FEU CENTRAL ]]

local function createCentralFire(): Model
	local fireModel = Instance.new("Model")
	fireModel.Name = "CentralFire"
	
	-- Base en pierre
	local fireBase = createPart(
		"FireBase",
		Vector3.new(12, 2, 12),
		Vector3.new(0, CONFIG.VillageCenterHeight + 1, 0),
		Color3.fromRGB(80, 80, 80),
		Enum.Material.Cobblestone
	)
	fireBase.Parent = fireModel
	
	-- Bûches
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2
		local log = createPart(
			"Log" .. i,
			Vector3.new(2, 2, 6),
			Vector3.new(
				math.cos(angle) * 2,
				CONFIG.VillageCenterHeight + 2.5,
				math.sin(angle) * 2
			),
			Color3.fromRGB(101, 67, 33),
			Enum.Material.Wood
		)
		log.CFrame = log.CFrame * CFrame.Angles(0, angle, math.rad(45))
		log.Parent = fireModel
	end
	
	-- Feu
	local firePart = createPart(
		"FireCore",
		Vector3.new(4, 6, 4),
		Vector3.new(0, CONFIG.VillageCenterHeight + 5, 0),
		Color3.fromRGB(255, 100, 0),
		Enum.Material.Neon
	)
	firePart.Transparency = 0.3
	firePart.CanCollide = false
	
	local fire = Instance.new("Fire")
	fire.Size = 15
	fire.Heat = 15
	fire.Parent = firePart
	
	local pointLight = Instance.new("PointLight")
	pointLight.Brightness = 3
	pointLight.Range = 60
	pointLight.Color = Color3.fromRGB(255, 150, 50)
	pointLight.Parent = firePart
	
	firePart.Parent = fireModel
	
	-- Tag pour système de craft
	firePart:SetAttribute("IsCampfire", true)
	firePart:SetAttribute("HeatSource", true)
	
	fireModel.PrimaryPart = fireBase
	fireModel.Parent = VillageFolder
	
	return fireModel
end

--[[ POINTS DE SPAWN ]]

local function createSpawnPoints(): Folder
	local spawnsFolder = createFolder("SpawnPoints", VillageFolder)
	
	for i = 1, CONFIG.SpawnPoints do
		local angle = (i / CONFIG.SpawnPoints) * math.pi * 2
		
		local spawn = Instance.new("SpawnLocation")
		spawn.Name = "Spawn_" .. i
		spawn.Size = Vector3.new(6, 1, 6)
		spawn.Position = Vector3.new(
			math.cos(angle) * CONFIG.SpawnRadius,
			CONFIG.VillageCenterHeight + 0.5,
			math.sin(angle) * CONFIG.SpawnRadius
		)
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Anchored = true
		spawn.Duration = 0
		spawn.Parent = spawnsFolder
		
		-- Marqueur visuel subtil
		local marker = Instance.new("Part")
		marker.Name = "SpawnMarker"
		marker.Size = Vector3.new(5, 0.2, 5)
		marker.Position = spawn.Position - Vector3.new(0, 0.4, 0)
		marker.Color = Color3.fromRGB(100, 150, 100)
		marker.Material = Enum.Material.Grass
		marker.Transparency = 0.5
		marker.CanCollide = false
		marker.Anchored = true
		marker.Parent = spawnsFolder
	end
	
	return spawnsFolder
end

--[[ BARRICADES ]]

local function createBarricades(): Model
	local barricadesModel = Instance.new("Model")
	barricadesModel.Name = "Barricades"
	
	local segments = CONFIG.BarricadeSegments
	local gateIndices = {}
	
	-- Définir positions des portes
	for i = 1, CONFIG.BarricadeGates do
		table.insert(gateIndices, math.floor((i - 1) * segments / CONFIG.BarricadeGates) + 1)
	end
	
	for i = 1, segments do
		local angle1 = ((i - 1) / segments) * math.pi * 2
		local angle2 = (i / segments) * math.pi * 2
		
		local pos1 = Vector3.new(
			math.cos(angle1) * CONFIG.VillageRadius,
			CONFIG.VillageCenterHeight,
			math.sin(angle1) * CONFIG.VillageRadius
		)
		
		local pos2 = Vector3.new(
			math.cos(angle2) * CONFIG.VillageRadius,
			CONFIG.VillageCenterHeight,
			math.sin(angle2) * CONFIG.VillageRadius
		)
		
		local isGate = table.find(gateIndices, i) ~= nil
		
		if isGate then
			-- Porte
			local gateFrame = createPart(
				"GateFrame_" .. i,
				Vector3.new(CONFIG.BarricadeWallThickness, CONFIG.BarricadeWallHeight + 2, 2),
				pos1,
				Color3.fromRGB(70, 50, 40),
				Enum.Material.Wood
			)
			gateFrame.CFrame = CFrame.new(pos1, pos2) * CFrame.Angles(0, math.rad(90), 0)
			gateFrame.Parent = barricadesModel
			
			local gateDoor = createPart(
				"GateDoor_" .. i,
				Vector3.new(1, CONFIG.BarricadeWallHeight, (pos2 - pos1).Magnitude - 4),
				(pos1 + pos2) / 2 + Vector3.new(0, CONFIG.BarricadeWallHeight / 2, 0),
				Color3.fromRGB(90, 70, 50),
				Enum.Material.Wood
			)
			gateDoor.CFrame = CFrame.new((pos1 + pos2) / 2, pos2)
			gateDoor.Transparency = 0
			gateDoor.CanCollide = true
			gateDoor:SetAttribute("IsGate", true)
			gateDoor:SetAttribute("GateId", i)
			gateDoor:SetAttribute("IsOpen", false)
			gateDoor.Parent = barricadesModel
		else
			-- Mur
			local midpoint = (pos1 + pos2) / 2 + Vector3.new(0, CONFIG.BarricadeWallHeight / 2, 0)
			local wall = createPart(
				"Wall_" .. i,
				Vector3.new(CONFIG.BarricadeWallThickness, CONFIG.BarricadeWallHeight, (pos2 - pos1).Magnitude),
				midpoint,
				Color3.fromRGB(100, 80, 60),
				Enum.Material.WoodPlanks
			)
			wall.CFrame = CFrame.new(midpoint, pos2 + Vector3.new(0, CONFIG.BarricadeWallHeight / 2, 0))
			wall.Parent = barricadesModel
			
			-- Piquets défensifs
			for j = 1, 3 do
				local spike = createPart(
					"Spike_" .. i .. "_" .. j,
					Vector3.new(0.5, 3, 0.5),
					wall.Position + Vector3.new(0, CONFIG.BarricadeWallHeight / 2 + 1, 0),
					Color3.fromRGB(80, 60, 40),
					Enum.Material.Wood
				)
				spike.CFrame = wall.CFrame * CFrame.new((j - 2) * 3, CONFIG.BarricadeWallHeight / 2 + 1, 0)
				spike.Parent = barricadesModel
			end
		end
	end
	
	barricadesModel.Parent = VillageFolder
	return barricadesModel
end

--[[ FORÊT DENSE ]]

local function createTree(position: Vector3): Model
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	
	local height = math.random(CONFIG.TreeHeightMin, CONFIG.TreeHeightMax)
	local trunkRadius = CONFIG.TreeTrunkRadius + math.random() * 0.5
	
	-- Tronc
	local trunk = createPart(
		"Trunk",
		Vector3.new(trunkRadius * 2, height, trunkRadius * 2),
		position + Vector3.new(0, height / 2, 0),
		Color3.fromRGB(70 + math.random(-10, 10), 50, 30),
		Enum.Material.Wood
	)
	trunk:SetAttribute("ResourceType", "Wood")
	trunk:SetAttribute("ResourceAmount", math.random(3, 8))
	trunk:SetAttribute("IsHarvestable", true)
	trunk.Parent = tree
	
	-- Feuillage (plusieurs sphères)
	for i = 1, 4 do
		local foliage = createPart(
			"Foliage_" .. i,
			Vector3.new(
				trunkRadius * 6 + math.random() * 4,
				trunkRadius * 6 + math.random() * 4,
				trunkRadius * 6 + math.random() * 4
			),
			position + Vector3.new(
				math.random(-3, 3),
				height + 5 + i * 3,
				math.random(-3, 3)
			),
			Color3.fromRGB(20 + math.random(0, 30), 80 + math.random(-20, 20), 20),
			Enum.Material.Grass
		)
		foliage.Shape = Enum.PartType.Ball
		foliage.CanCollide = false
		foliage.Parent = tree
	end
	
	tree.PrimaryPart = trunk
	tree.Parent = ForestFolder
	
	return tree
end

local function createForest(): Folder
	local forestFolder = createFolder("Forest", WorldFolder)
	
	local area = math.pi * (CONFIG.ForestOuterRadius^2 - CONFIG.ForestInnerRadius^2)
	local treeCount = math.floor(area * CONFIG.TreeDensity)
	
	print("[WorldBuilder] Génération de", treeCount, "arbres...")
	
	for i = 1, treeCount do
		local position = randomPointInRing(CONFIG.ForestInnerRadius, CONFIG.ForestOuterRadius)
		position = position + Vector3.new(0, CONFIG.VillageCenterHeight, 0)
		
		createTree(position)
		
		if i % 100 == 0 then
			task.wait() -- Yield pour éviter timeout
		end
	end
	
	return forestFolder
end

--[[ NŒUDS DE RESSOURCES ]]

local function createResourceNode(resourceType: string, position: Vector3): BasePart
	local configs = {
		Wood = {
			Size = Vector3.new(4, 3, 4),
			Color = Color3.fromRGB(101, 67, 33),
			Material = Enum.Material.Wood,
			Amount = {5, 10}
		},
		Stone = {
			Size = Vector3.new(5, 4, 5),
			Color = Color3.fromRGB(120, 120, 120),
			Material = Enum.Material.Rock,
			Amount = {3, 7}
		},
		Metal = {
			Size = Vector3.new(3, 3, 3),
			Color = Color3.fromRGB(180, 180, 190),
			Material = Enum.Material.Metal,
			Amount = {1, 3}
		}
	}
	
	local config = configs[resourceType]
	if not config then return nil end
	
	local node = createPart(
		resourceType .. "Node",
		config.Size,
		position + Vector3.new(0, config.Size.Y / 2, 0),
		config.Color,
		config.Material
	)
	
	node:SetAttribute("ResourceType", resourceType)
	node:SetAttribute("ResourceAmount", math.random(config.Amount[1], config.Amount[2]))
	node:SetAttribute("IsHarvestable", true)
	node:SetAttribute("RespawnTime", 120) -- secondes
	
	node.Parent = ResourcesFolder
	
	return node
end

local function spawnResourceNodes()
	for resourceType, count in pairs(CONFIG.ResourceNodesPerType) do
		for i = 1, count do
			local position = randomPointInRing(CONFIG.ForestInnerRadius, CONFIG.ForestOuterRadius * 0.8)
			position = position + Vector3.new(0, CONFIG.VillageCenterHeight, 0)
			
			createResourceNode(resourceType, position)
		end
	end
end

--[[ SOL ET TERRAIN DE BASE ]]

local function createBaseTerrain()
	-- Sol du village
	local villageGround = createPart(
		"VillageGround",
		Vector3.new(CONFIG.VillageRadius * 2.5, 1, CONFIG.VillageRadius * 2.5),
		Vector3.new(0, CONFIG.VillageCenterHeight - 0.5, 0),
		Color3.fromRGB(100, 90, 70),
		Enum.Material.Ground
	)
	villageGround.Parent = VillageFolder
	
	-- Sol forestier (plus large)
	local forestGround = createPart(
		"ForestGround",
		Vector3.new(CONFIG.ForestOuterRadius * 2.5, 1, CONFIG.ForestOuterRadius * 2.5),
		Vector3.new(0, CONFIG.VillageCenterHeight - 1, 0),
		Color3.fromRGB(60, 50, 40),
		Enum.Material.Ground
	)
	forestGround.Parent = ForestFolder
end

--[[ AMBIANCE ]]

local function setupLighting()
	local lighting = game:GetService("Lighting")
	
	if CONFIG.AmbientDarkness then
		lighting.Brightness = 0.5
		lighting.Ambient = Color3.fromRGB(20, 20, 30)
		lighting.OutdoorAmbient = Color3.fromRGB(30, 30, 40)
		lighting.ClockTime = 0 -- Minuit
		lighting.FogEnd = 250
		lighting.FogColor = Color3.fromRGB(10, 10, 15)
	end
	
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.4
	atmosphere.Offset = 0.5
	atmosphere.Color = Color3.fromRGB(150, 150, 180)
	atmosphere.Glare = 0
	atmosphere.Haze = 2
	atmosphere.Parent = lighting
end

--[[ GÉNÉRATION PRINCIPALE ]]

local WorldBuilder = {}

function WorldBuilder.Generate()
	print("[WorldBuilder] 🌍 Début de la génération du monde...")
	
	-- Nettoyage
	local existingWorld = Workspace:FindFirstChild("World")
	if existingWorld then
		existingWorld:Destroy()
	end
	
	-- Structure de dossiers
	WorldFolder = createFolder("World", Workspace)
	VillageFolder = createFolder("Village", WorldFolder)
	ForestFolder = createFolder("Forest", WorldFolder)
	ResourcesFolder = createFolder("Resources", WorldFolder)
	
	-- Génération
	local startTime = tick()
	
	createBaseTerrain()
	print("[WorldBuilder] ✅ Terrain de base créé")
	
	createCentralFire()
	print("[WorldBuilder] ✅ Feu central créé")
	
	createSpawnPoints()
	print("[WorldBuilder] ✅ Points de spawn créés")
	
	createBarricades()
	print("[WorldBuilder] ✅ Barricades construites")
	
	createForest()
	print("[WorldBuilder] ✅ Forêt générée")
	
	spawnResourceNodes()
	print("[WorldBuilder] ✅ Nœuds de ressources placés")
	
	setupLighting()
	print("[WorldBuilder] ✅ Ambiance configurée")
	
	local elapsed = tick() - startTime
	print(string.format("[WorldBuilder] 🎉 Monde généré en %.2f secondes", elapsed))
	
	return WorldFolder
end

function WorldBuilder.GetVillageCenter(): Vector3
	return Vector3.new(0, CONFIG.VillageCenterHeight, 0)
end

function WorldBuilder.GetVillageRadius(): number
	return CONFIG.VillageRadius
end

-- Auto-génération au démarrage
WorldBuilder.Generate()

return WorldBuilder