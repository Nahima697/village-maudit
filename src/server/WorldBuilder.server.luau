--[[
	WorldBuilder.server.luau
	Le village entier (maisons, cimetière, décor, stèles) est placé À LA MAIN
	dans Studio par l'utilisateur. Ce script ne fait plus AUCUN repositionnement
	automatique - il se contente de : créer le sol s'il n'existe pas, générer
	les points de spawn des monstres, taguer la porte du village pour que
	MonsterSpawner la trouve, et générer les nœuds de ressources (arbres/rochers).
]]

local CollectionService = game:GetService("CollectionService")

local CONFIG = {
	VILLAGE_RADIUS = 45,
}

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

local function generateResourceNodes()
	local existing = workspace:FindFirstChild("ResourceNodes")
	if existing then existing:Destroy() end

	local nodesFolder = Instance.new("Folder")
	nodesFolder.Name = "ResourceNodes"
	nodesFolder.Parent = workspace

	-- Génération des 10 arbres
	for i = 1, 10 do
		local angle = math.random() * math.pi * 2
		local dist = CONFIG.VILLAGE_RADIUS + math.random(0, 60)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist

		local tree = Instance.new("Part")
		tree.Name = "Tree_" .. i
		tree.Size = Vector3.new(2, 8, 2)
		tree.Position = Vector3.new(x, 4, z)
		tree.Anchored = true
		tree.CanCollide = true
		tree.Material = Enum.Material.Wood
		tree.BrickColor = BrickColor.new("Brown")
		tree.Parent = nodesFolder
		CollectionService:AddTag(tree, "ResourceNode")
		tree:SetAttribute("ResourceType", "Wood")
	end

	-- Génération des 6 rochers
	for i = 1, 6 do
		local angle = math.random() * math.pi * 2
		local dist = CONFIG.VILLAGE_RADIUS + math.random(0, 60)
		local x = math.cos(angle) * dist
		local z = math.sin(angle) * dist

		local rock = Instance.new("Part")
		rock.Name = "Rock_" .. i
		rock.Size = Vector3.new(3, 2, 3)
		rock.Position = Vector3.new(x, 1, z)
		rock.Anchored = true
		rock.CanCollide = true
		rock.Material = Enum.Material.Slate
		rock.BrickColor = BrickColor.new("Dark stone grey")
		rock.Parent = nodesFolder
		CollectionService:AddTag(rock, "ResourceNode")
		rock:SetAttribute("ResourceType", "Stone")
	end

	print("[WorldBuilder] " .. #nodesFolder:GetChildren() .. " nœuds de ressources générés (arbres + rochers).")
end

local function tagVillageDoor()
	local door = workspace:FindFirstChild("Door")
	if door then
		if door:IsA("Model") and not door.PrimaryPart then
			door.PrimaryPart = door:FindFirstChild("Planks") or door:FindFirstChildWhichIsA("BasePart", true)
		end
		CollectionService:AddTag(door, "Door")
		local part = door:IsA("Model") and (door.PrimaryPart or door:FindFirstChildWhichIsA("BasePart", true)) or door
		if part then
			part:SetAttribute("Health", 500)
			part:SetAttribute("MaxHealth", 500)
		end
		print("[WorldBuilder] Door taguée pour MonsterSpawner.")
	end
end

ensureBaseplate()
generateMonsterSpawns()
generateResourceNodes()
tagVillageDoor()

print("[WorldBuilder] Sol + points de spawn + nœuds de ressources + tag Door prêts. Aucun objet du village n'est déplacé - placement 100% manuel.")
workspace:SetAttribute("WorldReady", true)