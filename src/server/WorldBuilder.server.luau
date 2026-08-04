--[[
	WorldBuilder.server.luau
	Prend TOUS les prefabs du pack "Medieval Village" (tout ce qui n'est
	pas un arbre/rocher/buisson/herbe du pack KayKit) et les pose tels
	quels en grille au centre de la map, sans aucune correction d'échelle
	ni d'orientation - Roblox les a déjà bien importés (voir PivotOffset
	dans les Properties : Scale et Orientation sont déjà corrects).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Prefabs = ReplicatedStorage:FindFirstChild("Prefabs")
if not Prefabs then
	warn("[WorldBuilder] Dossier Prefabs introuvable dans ReplicatedStorage !")
	return
end

local EXCLUDED_PREFIXES = {"Tree_", "Rock_", "Bush_", "Grass_"}

local function isForestAsset(name)
	for _, prefix in ipairs(EXCLUDED_PREFIXES) do
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
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

local function generateVillageGrid()
	local existing = workspace:FindFirstChild("Village")
	if existing then existing:Destroy() end

	local villageFolder = Instance.new("Folder")
	villageFolder.Name = "Village"
	villageFolder.Parent = workspace

	local villagePrefabs = {}
	for _, child in ipairs(Prefabs:GetChildren()) do
		if not isForestAsset(child.Name) then
			table.insert(villagePrefabs, child)
		end
	end

	print("[WorldBuilder] " .. #villagePrefabs .. " prefabs de village à placer en grille.")

	local SPACING = 20
	local columns = math.ceil(math.sqrt(#villagePrefabs))

	for i, prefab in ipairs(villagePrefabs) do
		local clone = prefab:Clone()
		anchorAll(clone)

		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		local x = (col - columns / 2) * SPACING
		local z = (row - columns / 2) * SPACING

		if clone:IsA("Model") then
			if not clone.PrimaryPart then
				clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
			end
			if clone.PrimaryPart then
				local currentPivot = clone:GetPivot()
				clone:PivotTo(CFrame.new(x, 0, z) * (currentPivot - currentPivot.Position))
			end
		elseif clone:IsA("BasePart") then
			clone.Position = Vector3.new(x, clone.Position.Y, z)
		end

		clone.Parent = villageFolder

		if clone.Name:match("Door") then
			CollectionService:AddTag(clone, "Door")
		end
	end

	print("[WorldBuilder] Grille de village placée.")
end

ensureBaseplate()
generateVillageGrid()

print("[WorldBuilder] Prêt.")
