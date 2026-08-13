local function generateRuins()
	local ruinsFolder = Instance.new("Folder")
	ruinsFolder.Name = "Ruins"
	ruinsFolder.Parent = workspace

	-- Position proche du cimetière
	local cemeteryCenter = MapConfig.CEMETERY_ZONE.Center
	local ruinsCenter = Vector3.new(
		cemeteryCenter.X + math.random(-15, -10),
		0,
		cemeteryCenter.Z + math.random(-15, 15)
	)

	local ruinElements = {}

	-- Génération de 4-6 murs effondrés
	local wallCount = math.random(4, 6)
	for i = 1, wallCount do
		local offsetX = math.random(-8, 8)
		local offsetZ = math.random(-8, 8)
		local wallWidth = math.random(4, 8)
		local wallHeight = math.random(2, 4)
		local wallThickness = 0.5

		local wall = Instance.new("Part")
		wall.Name = "RuinWall_" .. i
		wall.Size = Vector3.new(wallWidth, wallHeight, wallThickness)
		wall.Position = Vector3.new(
			ruinsCenter.X + offsetX,
			wallHeight / 2,
			ruinsCenter.Z + offsetZ
		)
		wall.Anchored = true
		wall.CanCollide = true
		wall.Material = Enum.Material.Slate
		wall.Color = Color3.fromRGB(60, 60, 65)

		-- Certains murs sont inclinés ou couchés
		if math.random() < 0.5 then
			wall.Orientation = Vector3.new(
				math.random(-45, 45),
				math.random(0, 360),
				math.random(-30, 30)
			)
		else
			wall.Orientation = Vector3.new(0, math.random(0, 360), 0)
		end

		wall.Parent = ruinsFolder
		table.insert(ruinElements, wall.Position)
	end

	-- Génération de 1-2 arbres morts
	local deadTreeCount = math.random(1, 2)
	for i = 1, deadTreeCount do
		local offsetX = math.random(-10, 10)
		local offsetZ = math.random(-10, 10)
		local treePos = Vector3.new(
			ruinsCenter.X + offsetX,
			0,
			ruinsCenter.Z + offsetZ
		)

		-- Tronc mort (fin et haut)
		local trunkHeight = math.random(6, 10)
		local trunkThickness = math.random(8, 12) / 10

		local trunk = Instance.new("Part")
		trunk.Name = "DeadTree_" .. i
		trunk.Size = Vector3.new(trunkThickness, trunkHeight, trunkThickness)
		trunk.Position = Vector3.new(treePos.X, trunkHeight / 2, treePos.Z)
		trunk.Anchored = true
		trunk.CanCollide = true
		trunk.Material = Enum.Material.Wood
		trunk.Color = Color3.fromRGB(80, 75, 70)
		trunk.Parent = ruinsFolder

		-- Quelques branches mortes (2-4 par arbre)
		local branchCount = math.random(2, 4)
		for j = 1, branchCount do
			local branchLength = math.random(2, 4)
			local branchThickness = math.random(3, 6) / 10
			local branchHeight = math.random(trunkHeight * 0.4, trunkHeight * 0.8)

			local branch = Instance.new("Part")
			branch.Name = "DeadBranch_" .. i .. "_" .. j
			branch.Size = Vector3.new(branchThickness, branchThickness, branchLength)
			branch.Position = Vector3.new(
				treePos.X + math.random(-1, 1),
				branchHeight,
				treePos.Z + math.random(-1, 1)
			)
			branch.Orientation = Vector3.new(
				math.random(-60, 60),
				math.random(0, 360),
				math.random(-60, 60)
			)
			branch.Anchored = true
			branch.CanCollide = false
			branch.Material = Enum.Material.Wood
			branch.Color = Color3.fromRGB(70, 65, 60)
			branch.Parent = ruinsFolder
		end
	end

	-- Génération de 2-3 pierres tombales étranges
	local gravesCount = math.random(2, 3)
	for i = 1, gravesCount do
		local offsetX = math.random(-6, 6)
		local offsetZ = math.random(-6, 6)

		local graveHeight = math.random(2, 3)
		local graveWidth = math.random(12, 18) / 10
		local graveDepth = math.random(3, 5) / 10

		local grave = Instance.new("Part")
		grave.Name = "RuinGrave_" .. i
		grave.Size = Vector3.new(graveWidth, graveHeight, graveDepth)
		grave.Position = Vector3.new(
			ruinsCenter.X + offsetX,
			graveHeight / 2,
			ruinsCenter.Z + offsetZ
		)
		grave.Anchored = true
		grave.CanCollide = true
		grave.Material = Enum.Material.Slate
		grave.Color = Color3.fromRGB(50, 50, 55)

		-- Certaines pierres sont légèrement inclinées
		if math.random() < 0.4 then
			grave.Orientation = Vector3.new(
				math.random(-15, 15),
				math.random(0, 360),
				math.random(-10, 10)
			)
		else
			grave.Orientation = Vector3.new(0, math.random(0, 360), 0)
		end

		grave.Parent = ruinsFolder
	end

	print("[WorldBuilder] Ruines générées avec " .. wallCount .. " murs effondrés, " .. deadTreeCount .. " arbres morts et " .. gravesCount .. " pierres tombales étranges.")
end