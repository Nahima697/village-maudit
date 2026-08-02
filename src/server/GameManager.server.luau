-- WorldBuilder.server.luau
-- Génération procédurale du monde avec raycasting pour le Smooth Terrain
-- RESPONSABILITÉ : Créer la map avant le spawn des joueurs

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldBuilder = {}

-- ============================================================
-- CONFIGURATION DE LA GÉNÉRATION
-- ============================================================

local CONFIG = {
	MAP_RADIUS = 300,
	VILLAGE_RADIUS = 60,
	VILLAGE_CENTER = Vector3.new(0, 0, 0),
	
	FOREST = {
		TREE_COUNT = 150,
		MIN_DISTANCE = 8,
		TRUNK_HEIGHT = {6, 12},
		CANOPY_SIZE = {4, 8}
	},
	
	RESOURCES = {
		ROCK_COUNT = 40,
		CAMPFIRE_COUNT = 8
	},
	
	WALLS = {
		HEIGHT = 8,
		THICKNESS = 2,
		SEGMENT_LENGTH = 10
	},
	
	RAYCAST_HEIGHT = 200,
	RAYCAST_DISTANCE = 300
}

-- ============================================================
-- UTILITAIRES DE RAYCASTING
-- ============================================================

-- Trouve la hauteur Y du terrain à une position XZ donnée
local function getTerrainHeight(x, z)
	local rayOrigin = Vector3.new(x, CONFIG.RAYCAST_HEIGHT, z)
	local rayDirection = Vector3.new(0, -CONFIG.RAYCAST_DISTANCE, 0)
	
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Whitelist
	raycastParams.FilterDescendantsInstances = {Workspace.Terrain}
	
	local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
	
	if result then
		return result.Position.Y
	else
		warn("[WorldBuilder] Aucun terrain trouvé à X=" .. x .. ", Z=" .. z .. " - Utilisation de Y=0")
		return 0
	end
end

-- Vérifie si une position est dans le village
local function isInVillage(position)
	local distance = (Vector3.new(position.X, 0, position.Z) - Vector3.new(CONFIG.VILLAGE_CENTER.X, 0, CONFIG.VILLAGE_CENTER.Z)).Magnitude
	return distance <= CONFIG.VILLAGE_RADIUS
end

-- Génère une position aléatoire dans la map
local function getRandomPosition()
	local angle = math.random() * math.pi * 2
	local distance = math.random() * CONFIG.MAP_RADIUS
	local x = CONFIG.VILLAGE_CENTER.X + math.cos(angle) * distance
	local z = CONFIG.VILLAGE_CENTER.Z + math.sin(angle) * distance
	local y = getTerrainHeight(x, z)
	
	return Vector3.new(x, y, z)
end

-- ============================================================
-- NETTOYAGE DE LA MAP
-- ============================================================

function WorldBuilder.CleanMap()
	print("[WorldBuilder] 🧹 Nettoyage de la map existante...")
	
	local foldersToClean = {"Campfires", "Hazards", "Rocks", "Trees", "Village", "WorldObjects"}
	
	for _, folderName in ipairs(foldersToClean) do
		local folder = Workspace:FindFirstChild(folderName)
		if folder then
			folder:Destroy()
			print("[WorldBuilder] ✅ Dossier supprimé :", folderName)
		end
	end
	
	task.wait(0.5) -- Attendre la suppression
end

-- ============================================================
-- GÉNÉRATION DES STRUCTURES
-- ============================================================

-- Crée un arbre procédural
local function createTree(position)
	local tree = Instance.new("Model")
	tree.Name = "Tree"
	
	-- Tronc
	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Size = Vector3.new(2, math.random(CONFIG.FOREST.TRUNK_HEIGHT[1], CONFIG.FOREST.TRUNK_HEIGHT[2]), 2)
	trunk.Position = position + Vector3.new(0, trunk.Size.Y / 2, 0)
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.BrickColor = BrickColor.new("Brown")
	trunk.Parent = tree
	
	-- Feuillage
	local canopySize = math.random(CONFIG.FOREST.CANOPY_SIZE[1], CONFIG.FOREST.CANOPY_SIZE[2])
	local canopy = Instance.new("Part")
	canopy.Name = "Canopy"
	canopy.Size = Vector3.new(canopySize, canopySize, canopySize)
	canopy.Shape = Enum.PartType.Ball
	canopy.Position = trunk.Position + Vector3.new(0, trunk.Size.Y / 2 + canopySize / 2, 0)
	canopy.Anchored = true
	canopy.Material = Enum.Material.Grass
	canopy.BrickColor = BrickColor.new("Dark green")
	canopy.Parent = tree
	
	tree.PrimaryPart = trunk
	return tree
end

-- Crée un rocher
local function createRock(position)
	local rock = Instance.new("Part")
	rock.Name = "Rock"
	rock.Size = Vector3.new(math.random(3, 6), math.random(2, 4), math.random(3, 6))
	rock.Position = position + Vector3.new(0, rock.Size.Y / 2, 0)
	rock.Anchored = true
	rock.Material = Enum.Material.Slate
	rock.BrickColor = BrickColor.new("Medium stone grey")
	rock.Shape = Enum.PartType.Ball
	
	-- Tag pour le système de craft
	rock:SetAttribute("ResourceType", "Stone")
	rock:SetAttribute("ResourceAmount", 5)
	
	return rock
end

-- Crée un feu de camp
local function createCampfire(position)
	local campfire = Instance.new("Model")
	campfire.Name = "Campfire"
	
	-- Base
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 0.5, 4)
	base.Position = position + Vector3.new(0, 0.25, 0)
	base.Anchored = true
	base.Material = Enum.Material.Cobblestone
	base.BrickColor = BrickColor.new("Black")
	base.Parent = campfire
	
	-- Feu
	local fire = Instance.new("Part")
	fire.Name = "Fire"
	fire.Size = Vector3.new(2, 3, 2)
	fire.Position = base.Position + Vector3.new(0, 2, 0)
	fire.Anchored = true
	fire.Material = Enum.Material.Neon
	fire.BrickColor = BrickColor.new("Deep orange")
	fire.Transparency = 0.3
	fire.Parent = campfire
	
	-- Lumière
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 30
	light.Color = Color3.fromRGB(255, 100, 0)
	light.Parent = fire
	
	campfire.PrimaryPart = base
	return campfire
end

-- ============================================================
-- GÉNÉRATION DE LA FORÊT
-- ============================================================

function WorldBuilder.GenerateForest()
	print("[WorldBuilder] 🌲 Génération de la forêt...")
	
	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = Workspace
	
	local treePositions = {}
	local treesPlaced = 0
	local maxAttempts = CONFIG.FOREST.TREE_COUNT * 5
	local attempts = 0
	
	while treesPlaced < CONFIG.FOREST.TREE_COUNT and attempts < maxAttempts do
		attempts = attempts + 1
		
		local position = getRandomPosition()
		
		-- Ne pas placer dans le village
		if isInVillage(position) then
			continue
		end
		
		-- Vérifier la distance minimale avec les autres arbres
		local tooClose = false
		for _, existingPos in ipairs(treePositions) do
			if (position - existingPos).Magnitude < CONFIG.FOREST.MIN_DISTANCE then
				tooClose = true
				break
			end
		end
		
		if not tooClose then
			local tree = createTree(position)
			tree.Parent = treesFolder
			table.insert(treePositions, position)
			treesPlaced = treesPlaced + 1
		end
	end
	
	print("[WorldBuilder] ✅ Forêt générée :", treesPlaced, "arbres")
end

-- ============================================================
-- GÉNÉRATION DES RESSOURCES
-- ============================================================

function WorldBuilder.GenerateResources()
	print("[WorldBuilder] ⛏️ Génération des ressources...")
	
	-- Rochers
	local rocksFolder = Instance.new("Folder")
	rocksFolder.Name = "Rocks"
	rocksFolder.Parent = Workspace
	
	for i = 1, CONFIG.RESOURCES.ROCK_COUNT do
		local position = getRandomPosition()
		if not isInVillage(position) then
			local rock = createRock(position)
			rock.Parent = rocksFolder
		end
	end
	
	-- Feux de camp
	local campfiresFolder = Instance.new("Folder")
	campfiresFolder.Name = "Campfires"
	campfiresFolder.Parent = Workspace
	
	for i = 1, CONFIG.RESOURCES.CAMPFIRE_COUNT do
		local position = getRandomPosition()
		if not isInVillage(position) then
			local campfire = createCampfire(position)
			campfire.Parent = campfiresFolder
		end
	end
	
	print("[WorldBuilder] ✅ Ressources générées")
end

-- ============================================================
-- GÉNÉRATION DU VILLAGE
-- ============================================================

function WorldBuilder.GenerateVillage()
	print("[WorldBuilder] 🏘️ Génération du village...")
	
	local villageFolder = Instance.new("Folder")
	villageFolder.Name = "Village"
	villageFolder.Parent = Workspace
	
	-- Plateforme centrale
	local centerY = getTerrainHeight(CONFIG.VILLAGE_CENTER.X, CONFIG.VILLAGE_CENTER.Z)
	local platform = Instance.new("Part")
	platform.Name = "VillagePlatform"
	platform.Size = Vector3.new(CONFIG.VILLAGE_RADIUS * 2, 1, CONFIG.VILLAGE_RADIUS * 2)
	platform.Position = Vector3.new(CONFIG.VILLAGE_CENTER.X, centerY - 0.5, CONFIG.VILLAGE_CENTER.Z)
	platform.Anchored = true
	platform.Material = Enum.Material.Cobblestone
	platform.BrickColor = BrickColor.new("Medium stone grey")
	platform.Parent = villageFolder
	
	-- Murs du village (avec raycasting pour chaque segment)
	local wallsFolder = Instance.new("Folder")
	wallsFolder.Name = "Walls"
	wallsFolder.Parent = villageFolder
	
	local segments = math.ceil((2 * math.pi * CONFIG.VILLAGE_RADIUS) / CONFIG.WALLS.SEGMENT_LENGTH)
	
	for i = 0, segments do
		local angle = (i / segments) * math.pi * 2
		local x = CONFIG.VILLAGE_CENTER.X + math.cos(angle) * CONFIG.VILLAGE_RADIUS
		local z = CONFIG.VILLAGE_CENTER.Z + math.sin(angle) * CONFIG.VILLAGE_RADIUS
		local y = getTerrainHeight(x, z)
		
		local wall = Instance.new("Part")
		wall.Name = "WallSegment"
		wall.Size = Vector3.new(CONFIG.WALLS.THICKNESS, CONFIG.WALLS.HEIGHT, CONFIG.WALLS.SEGMENT_LENGTH)
		wall.Position = Vector3.new(x, y + CONFIG.WALLS.HEIGHT / 2, z)
		wall.Orientation = Vector3.new(0, math.deg(angle), 0)
		wall.Anchored = true
		wall.Material = Enum.Material.Brick
		wall.BrickColor = BrickColor.new("Brown")
		wall.Parent = wallsFolder
	end
	
	print("[WorldBuilder] ✅ Village généré")
end

-- ============================================================
-- GÉNÉRATION COMPLÈTE
-- ============================================================

function WorldBuilder.Generate()
	print("[WorldBuilder] 🌍 ===== GÉNÉRATION DU MONDE =====")
	
	-- Étape 1 : Nettoyage
	WorldBuilder.CleanMap()
	
	-- Étape 2 : Village (prioritaire car il définit la zone safe)
	WorldBuilder.GenerateVillage()
	task.wait(0.5)
	
	-- Étape 3 : Forêt
	WorldBuilder.GenerateForest()
	task.wait(0.5)
	
	-- Étape 4 : Ressources
	WorldBuilder.GenerateResources()
	
	print("[WorldBuilder] 🌍 ===== GÉNÉRATION TERMINÉE =====")
end

-- ============================================================
-- INITIALISATION AU DÉMARRAGE DU SERVEUR
-- ============================================================

print("[WorldBuilder] Module chargé ✅")