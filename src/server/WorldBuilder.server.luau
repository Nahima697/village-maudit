local function generateForest()
	local forestFolder = Instance.new("Folder")
	forestFolder.Name = "CursedForest"
	forestFolder.Parent = workspace

	local center = MapConfig.VILLAGE_CENTER
	local innerRadius = MapConfig.FOREST_INNER_RADIUS
	local outerRadius = MapConfig.FOREST_OUTER_RADIUS
	
	-- Découpage en 3 bandes concentriques
	local bandWidth = (outerRadius - innerRadius) / 3
	local bands = {
		{
			name = "Edge",
			innerR = innerRadius,
			outerR = innerRadius + bandWidth,
			treeCount = 20,
			minSpacing = 14,
			treeScale = 1.0,
			trunkColor = Color3.fromRGB(70, 50, 30),
			foliageColor = Color3.fromRGB(40, 60, 30),
			addGrass = true,
			grassCount = 15
		},
		{
			name = "Middle",
			innerR = innerRadius + bandWidth,
			outerR = innerRadius + 2 * bandWidth,
			treeCount = 30,
			minSpacing = 8,
			treeScale = 1.0,
			trunkColor = Color3.fromRGB(65, 45, 25),
			foliageColor = Color3.fromRGB(35, 55, 25),
			addRocks = true,
			rockCount = 12,
			addBushes = true,
			bushCount = 18
		},
		{
			name = "Deep",
			innerR = innerRadius + 2 * bandWidth,
			outerR = outerRadius,
			treeCount = 35,
			minSpacing = 5,
			treeScale = 1.3,
			trunkColor = Color3.fromRGB(50, 35, 20),
			foliageColor = Color3.fromRGB(30, 45, 20),
			darkTrunks = true,
			tiltTrunks = true
		}
	}

	-- Fonction utilitaire pour trouver une position valide
	local function findValidPosition(existingPositions, innerR, outerR, minSpacing, maxAttempts)
		for attempt = 1, maxAttempts do
			local angle = math.random() * math.pi * 2
			local dist = innerR + math.random() * (outerR - innerR)
			local x = center.X + math.cos(angle) * dist
			local z = center.Z + math.sin(angle) * dist
			local pos = Vector3.new(x, 0, z)

			local valid = true
			for _, existingPos in ipairs(existingPositions) do
				if (pos - existingPos).Magnitude < minSpacing then
					valid = false
					break
				end
			end

			if valid then
				return pos
			end
		end
		return nil
	end

	local totalTreesGenerated = 0

	-- Génération pour chaque bande
	for _, band in ipairs(bands) do
		local treePositions = {}

		-- Générer les arbres de la bande
		for i = 1, band.treeCount do
			local pos = findValidPosition(treePositions, band.innerR, band.outerR, band.minSpacing, 20)
			if pos then
				table.insert(treePositions, pos)

				local trunkHeight = 8 * band.treeScale
				local trunkSize = 2 * band.treeScale
				local foliageSize = 6 * band.treeScale

				-- Tronc
				local trunk = Instance.new("Part")
				trunk.Name = "TreeTrunk_" .. band.name .. "_" .. i
				trunk.Size = Vector3.new(trunkSize, trunkHeight, trunkSize)
				trunk.Position = Vector3.new(pos.X, trunkHeight / 2, pos.Z)
				trunk.Anchored = true
				trunk.CanCollide = true
				trunk.Material = Enum.Material.Wood
				trunk.Color = band.trunkColor
				trunk.Parent = forestFolder

				-- Troncs sombres aléatoires (forêt profonde)
				if band.darkTrunks and math.random() < 0.3 then
					trunk.Material = math.random() > 0.5 and Enum.Material.Slate or Enum.Material.Basalt
					trunk.Color = Color3.fromRGB(40, 30, 20)
				end

				-- Inclinaison aléatoire (forêt profonde)
				if band.tiltTrunks and math.random() < 0.4 then
					local tiltX = math.random(-10, 10)
					local tiltZ = math.random(-10, 10)
					trunk.Orientation = Vector3.new(tiltX, 0, tiltZ)
				end

				-- Feuillage
				local foliage = Instance.new("Part")
				foliage.Name = "TreeFoliage_" .. band.name .. "_" .. i
				foliage.Shape = Enum.PartType.Ball
				foliage.Size = Vector3.new(foliageSize, foliageSize, foliageSize)
				foliage.Position = Vector3.new(pos.X, trunkHeight + foliageSize / 2 - 1, pos.Z)
				foliage.Anchored = true
				foliage.CanCollide = false
				foliage.Material = Enum.Material.Grass
				foliage.Color = band.foliageColor
				foliage.Parent = forestFolder

				totalTreesGenerated = totalTreesGenerated + 1
			end
		end

		-- Touffes d'herbe (bande de bord)
		if band.addGrass then
			for i = 1, band.grassCount do
				local pos = findValidPosition({}, band.innerR, band.outerR, 3, 10)
				if pos then
					local grass = Instance.new("Part")
					grass.Name = "GrassTuft_" .. i
					grass.Size = Vector3.new(2, 0.3, 2)
					grass.Position = Vector3.new(pos.X, 0.15, pos.Z)
					grass.Anchored = true
					grass.CanCollide = false
					grass.Material = Enum.Material.Grass
					grass.Color = Color3.fromRGB(60, 100, 40)
					grass.Parent = forestFolder
				end
			end
		end

		-- Rochers (bande intermédiaire)
		if band.addRocks then
			for i = 1, band.rockCount do
				local pos = findValidPosition(treePositions, band.innerR, band.outerR, 6, 15)
				if pos then
					local rockSize = Vector3.new(
						math.random(2, 5),
						math.random(1, 3),
						math.random(2, 4)
					)
					local rock = Instance.new("Part")
					rock.Name = "Rock_" .. i
					rock.Size = rockSize
					rock.Position = Vector3.new(pos.X, rockSize.Y / 2, pos.Z)
					rock.Orientation = Vector3.new(0, math.random(0, 360), 0)
					rock.Anchored = true
					rock.CanCollide = true
					rock.Material = math.random() > 0.5 and Enum.Material.Rock or Enum.Material.Slate
					rock.Color = Color3.fromRGB(math.random(80, 120), math.random(80, 110), math.random(80, 110))
					rock.Parent = forestFolder
				end
			end
		end

		-- Buissons (bande intermédiaire)
		if band.addBushes then
			for i = 1, band.bushCount do
				local pos = findValidPosition({}, band.innerR, band.outerR, 4, 10)
				if pos then
					local bushSize = math.random(15, 30) / 10
					local bush = Instance.new("Part")
					bush.Name = "Bush_" .. i
					bush.Shape = Enum.PartType.Ball
					bush.Size = Vector3.new(bushSize, bushSize * 0.8, bushSize)
					bush.Position = Vector3.new(pos.X, bushSize * 0.4, pos.Z)
					bush.Anchored = true
					bush.CanCollide = false
					bush.Material = Enum.Material.Grass
					bush.Color = Color3.fromRGB(25, 45, 20)
					bush.Parent = forestFolder
				end
			end
		end
	end

	print("[WorldBuilder] Forêt maudite générée avec " .. totalTreesGenerated .. " arbres en 3 bandes concentriques (bord/intermédiaire/profonde).")
end