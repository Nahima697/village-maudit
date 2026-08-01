local WorldBuilder = {}
local CollectionService = game:GetService("CollectionService")

local TERRAIN_SIZE = 300
local FOREST_RADIUS = 150
local VILLAGE_RADIUS = 60
local TREE_COUNT = 250
local BUILDING_COUNT = 6
local MONSTER_SPAWN_COUNT = 6

local function createBasePlate()
	local basePlate = Instance.new("Part")
	basePlate.Name = "BasePlate"
	basePlate.Size = Vector3.new(TERRAIN_SIZE, 1, TERRAIN_SIZE)
	basePlate.Position = Vector3.new(0, 0, 0)
	basePlate.Anchored = true
	basePlate.Color = Color3.fromRGB(106, 127, 63)
	basePlate.Material = Enum.Material.Grass
	basePlate.TopSurface = Enum.SurfaceType.Smooth
	basePlate.BottomSurface = Enum.SurfaceType.Smooth
	basePlate.Parent = workspace
	return basePlate
end

local function createTree(position)
	local trunk = Instance.new("Part")
	trunk.Name = "TreeTrunk"
	trunk.Size = Vector3.new(2 + math.random() * 1, 8 + math.random() * 6, 2 + math.random() * 1)
	trunk.Position = position + Vector3.new(0, trunk.Size.Y / 2, 0)
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(91, 60, 40)
	trunk.Parent = workspace.Trees
	
	local leaves = Instance.new("Part")
	leaves.Name = "TreeLeaves"
	leaves.Size = Vector3.new(8 + math.random() * 4, 10 + math.random() * 4, 8 + math.random() * 4)
	leaves.Position = trunk.Position + Vector3.new(0, trunk.Size.Y / 2 + leaves.Size.Y / 2 - 2, 0)
	leaves.Anchored = true
	leaves.Material = Enum.Material.Grass
	leaves.Color = Color3.fromRGB(39, 70, 45)
	leaves.Shape = Enum.PartType.Ball
	leaves.Parent = workspace.Trees
end

local function generateForest()
	local treesFolder = Instance.new("Folder")
	treesFolder.Name = "Trees"
	treesFolder.Parent = workspace
	
	for i = 1, TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = VILLAGE_RADIUS + 10 + math.random() * (FOREST_RADIUS - VILLAGE_RADIUS - 10)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		createTree(Vector3.new(x, 0.5, z))
	end
end

local function createBuilding(position, rotation)
	local building = Instance.new("Model")
	building.Name = "Building"
	building.Parent = workspace.Village
	
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(20, 1, 16)
	floor.Position = position
	floor.Anchored = true
	floor.Material = Enum.Material.Wood
	floor.Color = Color3.fromRGB(123, 93, 65)
	floor.Parent = building
	
	for i = 1, 4 do
		local wall = Instance.new("Part")
		wall.Name = "Wall" .. i
		wall.Size = Vector3.new(20, 12, 1)
		wall.Anchored = true
		wall.Material = Enum.Material.Cobblestone
		wall.Color = Color3.fromRGB(140, 140, 140)
		
		if i == 1 then
			wall.Position = position + Vector3.new(0, 6.5, -8)
		elseif i == 2 then
			wall.Position = position + Vector3.new(0, 6.5, 8)
		elseif i == 3 then
			wall.Size = Vector3.new(1, 12, 16)
			wall.Position = position + Vector3.new(-10, 6.5, 0)
		else
			wall.Size = Vector3.new(1, 12, 16)
			wall.Position = position + Vector3.new(10, 6.5, 0)
		end
		wall.Parent = building
	end
	
	for j = 1, 2 do
		for k = 1, 10 do
			local roofPart = Instance.new("WedgePart")
			roofPart.Name = "Roof"
			roofPart.Size = Vector3.new(2, 6, 18)
			roofPart.Anchored = true
			roofPart.Material = Enum.Material.Slate
			roofPart.Color = Color3.fromRGB(70, 50, 40)
			roofPart.Position = position + Vector3.new(-10 + (k - 1) * 2, 13, 0)
			
			if j == 1 then
				roofPart.Orientation = Vector3.new(0, 90, 0)
			else
				roofPart.Orientation = Vector3.new(0, -90, 0)
			end
			roofPart.Parent = building
		end
	end
	
end

local function createVillage()
	local villageFolder = Instance.new("Folder")
	villageFolder.Name = "Village"
	villageFolder.Parent = workspace
	
	for i = 1, BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / BUILDING_COUNT)
		local distance = 40
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		createBuilding(Vector3.new(x, 7, z), angle + math.pi / 2)
	end
end

local function createFortifications()
	local fortFolder = Instance.new("Folder")
	fortFolder.Name = "Fortifications"
	fortFolder.Parent = workspace.Village
	
	local doorPositions = {
		{name = "Door_North", pos = Vector3.new(0, 6, -70), rot = 0},
		{name = "Door_East", pos = Vector3.new(70, 6, 0), rot = math.pi / 2},
		{name = "Door_West", pos = Vector3.new(-70, 6, 0), rot = -math.pi / 2},
		{name = "Door_South", pos = Vector3.new(0, 6, 70), rot = math.pi}
	}
	
	for _, doorData in ipairs(doorPositions) do
		local doorFrame = Instance.new("Model")
		doorFrame.Name = doorData.name
		doorFrame.Parent = fortFolder
		
		local leftPillar = Instance.new("Part")
		leftPillar.Name = "LeftPillar"
		leftPillar.Size = Vector3.new(3, 12, 3)
		leftPillar.Anchored = true
		leftPillar.Material = Enum.Material.Cobblestone
		leftPillar.Color = Color3.fromRGB(100, 100, 100)
		leftPillar.Parent = doorFrame
		
		local rightPillar = leftPillar:Clone()
		rightPillar.Name = "RightPillar"
		rightPillar.Parent = doorFrame
		
		local archway = Instance.new("Part")
		archway.Name = "Archway"
		archway.Size = Vector3.new(12, 3, 3)
		archway.Anchored = true
		archway.Material = Enum.Material.Cobblestone
		archway.Color = Color3.fromRGB(100, 100, 100)
		archway.Parent = doorFrame
		
		local door = Instance.new("Part")
		door.Name = "DoorPart"
		door.Size = Vector3.new(10, 10, 1)
		door.Anchored = true
		door.Material = Enum.Material.Wood
		door.Color = Color3.fromRGB(70, 50, 30)
		door.Transparency = 0
		door.Parent = doorFrame
		
		leftPillar.Position = doorData.pos + Vector3.new(-6 * math.cos(doorData.rot + math.pi / 2), 0, -6 * math.sin(doorData.rot + math.pi / 2))
		rightPillar.Position = doorData.pos + Vector3.new(6 * math.cos(doorData.rot + math.pi / 2), 0, 6 * math.sin(doorData.rot + math.pi / 2))
		archway.Position = doorData.pos + Vector3.new(0, 10.5, 0)
		door.Position = doorData.pos
	end
end

local function createCentralSquare()
	local squareFolder = Instance.new("Folder")
	squareFolder.Name = "CentralSquare"
	squareFolder.Parent = workspace.Village
	
	local campfire = Instance.new("Part")
	campfire.Name = "Campfire"
	campfire.Size = Vector3.new(6, 2, 6)
	campfire.Position = Vector3.new(0, 1.5, 0)
	campfire.Anchored = true
	campfire.Material = Enum.Material.Cobblestone
	campfire.Color = Color3.fromRGB(60, 60, 60)
	campfire.Shape = Enum.PartType.Cylinder
	campfire.Orientation = Vector3.new(0, 0, 90)
	campfire.Parent = squareFolder
	
	local fire = Instance.new("Fire")
	fire.Size = 15
	fire.Heat = 15
	fire.Parent = campfire
	
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 40
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Parent = campfire
	
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local distance = 25
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local barrel = Instance.new("Part")
		barrel.Name = "Barrel"
		barrel.Size = Vector3.new(3, 4, 3)
		barrel.Position = Vector3.new(x, 2.5, z)
		barrel.Anchored = true
		barrel.Material = Enum.Material.Wood
		barrel.Color = Color3.fromRGB(90, 60, 40)
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Parent = squareFolder
		
		if i % 2 == 0 then
			local lampPost = Instance.new("Part")
			lampPost.Name = "LampPost"
			lampPost.Size = Vector3.new(1, 10, 1)
			lampPost.Position = Vector3.new(x, 5.5, z)
			lampPost.Anchored = true
			lampPost.Material = Enum.Material.Metal
			lampPost.Color = Color3.fromRGB(60, 60, 60)
			lampPost.Parent = squareFolder
			
			local lamp = Instance.new("Part")
			lamp.Name = "Lamp"
			lamp.Size = Vector3.new(2, 2, 2)
			lamp.Position = Vector3.new(x, 11, z)
			lamp.Anchored = true
			lamp.Material = Enum.Material.Neon
			lamp.Color = Color3.fromRGB(255, 220, 150)
			lamp.Shape = Enum.PartType.Ball
			lamp.Parent = squareFolder
			
			local lampLight = Instance.new("PointLight")
			lampLight.Brightness = 1.5
			lampLight.Range = 30
			lampLight.Color = Color3.fromRGB(255, 220, 150)
			lampLight.Parent = lamp
		end
	end
	
	for i = 1, 6 do
		local crate = Instance.new("Part")
		crate.Name = "Crate"
		crate.Size = Vector3.new(4, 4, 4)
		crate.Position = Vector3.new(math.random(-15, 15), 2.5, math.random(-15, 15))
		crate.Anchored = true
		crate.Material = Enum.Material.Wood
		crate.Color = Color3.fromRGB(120, 90, 60)
		crate.Parent = squareFolder
	end
end

local function createMonsterSpawns()
	local spawnFolder = Instance.new("Folder")
	spawnFolder.Name = "MonsterSpawns"
	spawnFolder.Parent = workspace
	
	for i = 1, MONSTER_SPAWN_COUNT do
		local angle = (i - 1) * (math.pi * 2 / MONSTER_SPAWN_COUNT)
		local distance = FOREST_RADIUS - 20
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local spawn = Instance.new("Part")
		spawn.Name = "MonsterSpawn_" .. i
		spawn.Size = Vector3.new(5, 1, 5)
		spawn.Position = Vector3.new(x, 1, z)
		spawn.Anchored = true
		spawn.Transparency = 1
		spawn.CanCollide = false
		spawn.Parent = spawnFolder
		
		CollectionService:AddTag(spawn, "MonsterSpawnPoint")
	end
end

local function configureLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime = 12
	lighting.Brightness = 2
	lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	lighting.Ambient = Color3.fromRGB(100, 100, 100)
	lighting.FogEnd = 500
end

function WorldBuilder.Generate()
	createBasePlate()
	generateForest()
	createVillage()
	createFortifications()
	createCentralSquare()
	createMonsterSpawns()
	configureLighting()
	print("WorldBuilder: Environment generated successfully")
end

WorldBuilder.Generate()

return WorldBuilder