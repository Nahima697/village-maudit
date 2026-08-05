--[[
	WorldBuilder.server.luau
	Le village entier (maisons, cimetière, décor, stèles) est placé À LA MAIN
	dans Studio par l'utilisateur. Ce script ne fait plus AUCUN repositionnement
	automatique - il se contente de : créer le sol s'il n'existe pas, générer
	les points de spawn des monstres, et taguer la porte du village pour que
	MonsterSpawner la trouve.
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

local function tagVillageDoor()
	local door = workspace:FindFirstChild("Door")
	if door then
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
tagVillageDoor()

print("[WorldBuilder] Sol + points de spawn + tag Door prêts. Aucun objet du village n'est déplacé - placement 100% manuel.")
workspace:SetAttribute("WorldReady", true)
