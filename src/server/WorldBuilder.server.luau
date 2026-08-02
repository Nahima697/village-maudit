--[[
    WorldBuilder.server.luau
    Génère le monde et tague automatiquement les arbres et rochers pour la récolte
]]

local WorldBuilder = {}
local CollectionService = game:GetService("CollectionService")

local TERRAIN_SIZE = 350
local FOREST_RADIUS = 160
local VILLAGE_RADIUS = 65
local TREE_COUNT = 220
local ROCK_COUNT = 30
local BUILDING_COUNT = 6
local MONSTER_SPAWN_COUNT = 6

local function createBasePlate()
	local basePlate = Instance.new("Part")
	basePlate.Name = "BasePlate"
	basePlate.Size = Vector3.new(TERRAIN_SIZE, 1, TERRAIN_SIZE)
	basePlate.Position = Vector3.new(0, 0, 0)
	basePlate.Anchored = true
	basePlate.Color = Color3.fromRGB(95, 115, 55)
	basePlate.Material = Enum.Material.Grass
	basePlate.TopSurface = Enum.SurfaceType.Smooth
	basePlate.BottomSurface = Enum.SurfaceType.Smooth
	basePlate.Parent = workspace
	return basePlate
end

local function createTree(position)
	local trunk = Instance.new("Part")
	trunk.Name = "TreeTrunk"
	trunk.Size = Vector3.new(3, 10, 3)
	trunk.Position = position + Vector3.new(0, trunk.Size.Y / 2, 0)
	trunk.Anchored = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = Color3.fromRGB(85, 55, 35)
	trunk.Parent = workspace.Trees
	CollectionService:AddTag(trunk, "Collectable")
	
	local leaves = Instance.new("Part")
	leaves.Name = "TreeLeaves"
	leaves.Size = Vector3.new(10, 10, 10)
	leaves.Position = trunk.Position + Vector3.new(0, trunk.Size.Y / 2, 0)
	leaves.Anchored = true
	leaves.Material = Enum.Material.LeafyGrass
	leaves.Color = Color3.fromRGB(40, 75, 45)
	leaves.Shape = Enum.PartType.Ball
	leaves.Parent = workspace.Trees
	CollectionService:AddTag(leaves, "Collectable")
end

local function generateForest()
	local treesFolder = workspace:FindFirstChild("Trees")
	if not treesFolder then
		treesFolder = Instance.new("Folder")
		treesFolder.Name = "Trees"
		treesFolder.Parent = workspace
	else
		treesFolder:ClearAllChildren()
	end
	
	for i = 1, TREE_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = VILLAGE_RADIUS + 15 + math.random() * (FOREST_RADIUS - VILLAGE_RADIUS - 15)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		createTree(Vector3.new(x, 0.5, z))
	end
end

local function generateRocks()
	local rocksFolder = workspace:FindFirstChild("Rocks")
	if not rocksFolder then
		rocksFolder = Instance.new("Folder")
		rocksFolder.Name = "Rocks"
		rocksFolder.Parent = workspace
	else
		rocksFolder:ClearAllChildren()
	end
	
	for i = 1, ROCK_COUNT do
		local angle = math.random() * math.pi * 2
		local distance = VILLAGE_RADIUS + 5 + math.random() * (FOREST_RADIUS - VILLAGE_RADIUS - 10)
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local rock = Instance.new("Part")
		rock.Name = "Rock"
		rock.Size = Vector3.new(6, 4, 6)
		rock.Position = Vector3.new(x, rock.Size.Y / 2, z)
		rock.Anchored = true
		rock.Material = Enum.Material.Slate
		rock.Color = Color3.fromRGB(120, 120, 125)
		rock.Shape = Enum.PartType.Ball
		rock.Parent = rocksFolder
		CollectionService:AddTag(rock, "Collectable")
	end
end

local function createBuilding(position, angle)
	local building = Instance.new("Model")
	building.Name = "Building"
	building.Parent = workspace.Village
	
	local cframe = CFrame.new(position) * CFrame.Angles(0, angle, 0)
	
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Size = Vector3.new(20, 1, 16)
	floor.CFrame = cframe + Vector3.new(0, 0.5, 0)
	floor.Anchored = true
	floor.Material = Enum.Material.WoodPlanks
	floor.Color = Color3.fromRGB(110, 80, 55)
	floor.Parent = building
	
	local stair = Instance.new("Part")
	stair.Name = "Stair"
	stair.Size = Vector3.new(6, 0.6, 3)
	stair.CFrame = cframe * CFrame.new(0, 0.3, -9.5)
	stair.Anchored = true
	stair.Material = Enum.Material.Granite
	stair.Color = Color3.fromRGB(130, 130, 130)
	stair.Parent = building

	local wallFrontLeft = Instance.new("Part")
	wallFrontLeft.Name = "Wall1_Left"
	wallFrontLeft.Size = Vector3.new(6, 12, 1)
	wallFrontLeft.CFrame = cframe * CFrame.new(-7, 6.5, -8)
	wallFrontLeft.Anchored = true
	wallFrontLeft.Material = Enum.Material.Cobblestone
	wallFrontLeft.Color = Color3.fromRGB(125, 125, 125)
	wallFrontLeft.Parent = building

	local wallFrontRight = Instance.new("Part")
	wallFrontRight.Name = "Wall1_Right"
	wallFrontRight.Size = Vector3.new(6, 12, 1)
	wallFrontRight.CFrame = cframe * CFrame.new(7, 6.5, -8)
	wallFrontRight.Anchored = true
	wallFrontRight.Material = Enum.Material.Cobblestone
	wallFrontRight.Color = Color3.fromRGB(125, 125, 125)
	wallFrontRight.Parent = building

	local lintel = Instance.new("Part")
	lintel.Name = "Lintel"
	lintel.Size = Vector3.new(8, 4, 1)
	lintel.CFrame = cframe * CFrame.new(0, 10, -8)
	lintel.Anchored = true
	lintel.Material = Enum.Material.Cobblestone
	lintel.Color = Color3.fromRGB(125, 125, 125)
	lintel.Parent = building

	local wallBack = Instance.new("Part")
	wallBack.Name = "Wall2"
	wallBack.Size = Vector3.new(20, 12, 1)
	wallBack.CFrame = cframe * CFrame.new(0, 6.5, 8)
	wallBack.Anchored = true
	wallBack.Material = Enum.Material.Cobblestone
	wallBack.Color = Color3.fromRGB(125, 125, 125)
	wallBack.Parent = building

	local wallLeft = Instance.new("Part")
	wallLeft.Name = "Wall3"
	wallLeft.Size = Vector3.new(1, 12, 16)
	wallLeft.CFrame = cframe * CFrame.new(-10, 6.5, 0)
	wallLeft.Anchored = true
	wallLeft.Material = Enum.Material.Cobblestone
	wallLeft.Color = Color3.fromRGB(125, 125, 125)
	wallLeft.Parent = building

	local wallRight = Instance.new("Part")
	wallRight.Name = "Wall4"
	wallRight.Size = Vector3.new(1, 12, 16)
	wallRight.CFrame = cframe * CFrame.new(10, 6.5, 0)
	wallRight.Anchored = true
	wallRight.Material = Enum.Material.Cobblestone
	wallRight.Color = Color3.fromRGB(125, 125, 125)
	wallRight.Parent = building
	
	for j = 1, 2 do
		for k = 1, 10 do
			local roofPart = Instance.new("WedgePart")
			roofPart.Name = "Roof"
			roofPart.Size = Vector3.new(2, 6, 18)
			roofPart.Anchored = true
			roofPart.Material = Enum.Material.Slate
			roofPart.Color = Color3.fromRGB(65, 45, 35)
			
			local offsetZ = -10 + (k - 1) * 2
			if j == 1 then
				roofPart.CFrame = cframe * CFrame.new(-5, 13, offsetZ) * CFrame.Angles(0, math.rad(90), 0)
			else
				roofPart.CFrame = cframe * CFrame.new(5, 13, offsetZ) * CFrame.Angles(0, math.rad(-90), 0)
			end
			roofPart.Parent = building
		end
	end
end

local function createVillage()
	local villageFolder = workspace:FindFirstChild("Village")
	if not villageFolder then
		villageFolder = Instance.new("Folder")
		villageFolder.Name = "Village"
		villageFolder.Parent = workspace
	else
		villageFolder:ClearAllChildren()
	end
	
	for i = 1, BUILDING_COUNT do
		local angle = (i - 1) * (math.pi * 2 / BUILDING_COUNT)
		local distance = 45
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		createBuilding(Vector3.new(x, 0, z), angle - math.pi / 2)
	end
end

local function createFortifications()
	local villageFolder = workspace:WaitForChild("Village")
	local fortFolder = Instance.new("Folder")
	fortFolder.Name = "Fortifications"
	fortFolder.Parent = villageFolder
	
	local doorPositions = {
		{name = "Door_North", pos = Vector3.new(0, 6, -75), rot = 0},
		{name = "Door_East", pos = Vector3.new(75, 6, 0), rot = math.pi / 2},
		{name = "Door_West", pos = Vector3.new(-75, 6, 0), rot = -math.pi / 2},
		{name = "Door_South", pos = Vector3.new(0, 6, 75), rot = math.pi}
	}
	
	for _, doorData in ipairs(doorPositions) do
		local doorFrame = Instance.new("Model")
		doorFrame.Name = doorData.name
		doorFrame.Parent = fortFolder
		
		local leftPillar = Instance.new("Part")
		leftPillar.Name = "LeftPillar"
		leftPillar.Size = Vector3.new(4, 12, 4)
		leftPillar.Anchored = true
		leftPillar.Material = Enum.Material.Cobblestone
		leftPillar.Color = Color3.fromRGB(90, 90, 90)
		leftPillar.Parent = doorFrame
		
		local rightPillar = leftPillar:Clone()
		rightPillar.Name = "RightPillar"
		rightPillar.Parent = doorFrame
		
		local archway = Instance.new("Part")
		archway.Name = "Archway"
		archway.Size = Vector3.new(14, 4, 4)
		archway.Anchored = true
		archway.Material = Enum.Material.Cobblestone
		archway.Color = Color3.fromRGB(90, 90, 90)
		archway.Parent = doorFrame
		
		local door = Instance.new("Part")
		door.Name = "DoorPart"
		door.Size = Vector3.new(10, 10, 1.5)
		door.Anchored = true
		door.Material = Enum.Material.WoodPlanks
		door.Color = Color3.fromRGB(60, 40, 25)
		door.Parent = doorFrame
		
		leftPillar.Position = doorData.pos + Vector3.new(-6 * math.cos(doorData.rot + math.pi / 2), 0, -6 * math.sin(doorData.rot + math.pi / 2))
		rightPillar.Position = doorData.pos + Vector3.new(6 * math.cos(doorData.rot + math.pi / 2), 0, 6 * math.sin(doorData.rot + math.pi / 2))
		archway.Position = doorData.pos + Vector3.new(0, 11, 0)
		door.Position = doorData.pos
	end
end

local function createCentralSquare()
	local villageFolder = workspace:WaitForChild("Village")
	local squareFolder = Instance.new("Folder")
	squareFolder.Name = "CentralSquare"
	squareFolder.Parent = villageFolder
	
	local campfire = Instance.new("Part")
	campfire.Name = "Campfire"
	campfire.Size = Vector3.new(7, 2, 7)
	campfire.Position = Vector3.new(0, 1, 0)
	campfire.Anchored = true
	campfire.Material = Enum.Material.Cobblestone
	campfire.Color = Color3.fromRGB(50, 50, 50)
	campfire.Shape = Enum.PartType.Cylinder
	campfire.Orientation = Vector3.new(0, 0, 90)
	campfire.Parent = squareFolder
	
	local fire = Instance.new("Fire")
	fire.Size = 18
	fire.Heat = 15
	fire.Parent = campfire
	
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range = 50
	light.Color = Color3.fromRGB(255, 140, 40)
	light.Parent = campfire
	
	for i = 1, 4 do
		local angle = (i - 1) * (math.pi * 2 / 4) + (math.pi / 4)
		local distance = 14
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local bench = Instance.new("Part")
		bench.Name = "Bench"
		bench.Size = Vector3.new(6, 1.2, 2)
		bench.Position = Vector3.new(x, 1.2, z)
		bench.Orientation = Vector3.new(0, math.deg(-angle), 0)
		bench.Anchored = true
		bench.Material = Enum.Material.Wood
		bench.Color = Color3.fromRGB(100, 70, 45)
		bench.Parent = squareFolder
	end
	
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local distance = 25
		local x = math.cos(angle) * distance
		local z = math.sin(angle) * distance
		
		local barrel = Instance.new("Part")
		barrel.Name = "Barrel"
		barrel.Size = Vector3.new(3.5, 4.5, 3.5)
		barrel.Position = Vector3.new(x, 2.25, z)
		barrel.Anchored = true
		barrel.Material = Enum.Material.Wood
		barrel.Color = Color3.fromRGB(80, 55, 35)
		barrel.Shape = Enum.PartType.Cylinder
		barrel.Parent = squareFolder
		
		if i % 2 == 0 then
			local lampPost = Instance.new("Part")
			lampPost.Name = "LampPost"
			lampPost.Size = Vector3.new(1.2, 12, 1.2)
			lampPost.Position = Vector3.new(x, 6.5, z)
			lampPost.Anchored = true
			lampPost.Material = Enum.Material.Metal
			lampPost.Color = Color3.fromRGB(45, 45, 45)
			lampPost.Parent = squareFolder
			
			local lamp = Instance.new("Part")
			lamp.Name = "Lamp"
			lamp.Size = Vector3.new(2.5, 2.5, 2.5)
			lamp.Position = Vector3.new(x, 13, z)
			lamp.Anchored = true
			lamp.Material = Enum.Material.Neon
			lamp.Color = Color3.fromRGB(255, 220, 150)
			lamp.Shape = Enum.PartType.Ball
			lamp.Parent = squareFolder
			
			local lampLight = Instance.new("PointLight")
			lampLight.Brightness = 2
			lampLight.Range = 35
			lampLight.Color = Color3.fromRGB(255, 220, 150)
			lampLight.Parent = lamp
		end
	end
end

local function createMonsterSpawns()
	local spawnFolder = workspace:FindFirstChild("MonsterSpawns")
	if not spawnFolder then
		spawnFolder = Instance.new("Folder")
		spawnFolder.Name = "MonsterSpawns"
		spawnFolder.Parent = workspace
	else
		spawnFolder:ClearAllChildren()
	end
	
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
	lighting.Brightness = 2.2
	lighting.OutdoorAmbient = Color3.fromRGB(130, 130, 130)
	lighting.Ambient = Color3.fromRGB(110, 110, 110)
	lighting.FogEnd = 600
end

function WorldBuilder.Generate()
	createBasePlate()
	generateForest()
	generateRocks()
	createVillage()
	createFortifications()
	createCentralSquare()
	createMonsterSpawns()
	configureLighting()
	print("WorldBuilder: Taggé avec succès pour la récolte !")
end

WorldBuilder.Generate()

