--[[
	HouseGenerator.luau
	Module de génération procédurale de maisons médiévales stylisées low-poly
	pour le projet "Village Maudit".
	
	Exports:
		HouseGenerator.Create(variantIndex, position, size, rotation) -> Model
		
	Variantes disponibles (1-5):
		1. Maison en pierre avec cheminée
		2. Maison à colombages
		3. Petite maison basse avec clôture
		4. Maison en pierre à étage
		5. Maison en bois avec terrasse couverte
]]

local HouseGenerator = {}

-- ========================================
-- UTILITAIRES DE CONSTRUCTION
-- ========================================

local function createPart(parent, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(200, 200, 200)
	part.Material = material or Enum.Material.Brick
	part.Transparency = transparency or 0
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function createWedge(parent, size, cframe, color, material)
	local wedge = Instance.new("WedgePart")
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color or Color3.fromRGB(60, 60, 60)
	wedge.Material = material or Enum.Material.Slate
	wedge.Anchored = true
	wedge.TopSurface = Enum.SurfaceType.Smooth
	wedge.BottomSurface = Enum.SurfaceType.Smooth
	wedge.Parent = parent
	return wedge
end

-- ========================================
-- VARIANTE 1 : MAISON EN PIERRE AVEC CHEMINÉE
-- ========================================

local function createVariant1House(model, size, baseCFrame)
	local wallHeight = size.Y
	local width = size.X
	local depth = size.Z
	
	-- Murs en pierre grise
	local wallColor = Color3.fromRGB(140, 140, 140)
	local wallMaterial = Enum.Material.Brick
	
	-- Mur avant
	local frontWall = createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, -depth/2), wallColor, wallMaterial)
	
	-- Mur arrière
	createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, depth/2), wallColor, wallMaterial)
	
	-- Mur gauche
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(-width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Mur droit
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Porte marron (centrée sur mur avant)
	local doorColor = Color3.fromRGB(101, 67, 33)
	createPart(model, Vector3.new(1.5, 2.5, 0.3), 
		baseCFrame * CFrame.new(0, 1.25, -depth/2 - 0.1), doorColor, Enum.Material.Wood)
	
	-- Fenêtres (deux, de part et d'autre de la porte)
	local windowColor = Color3.fromRGB(150, 170, 180)
	createPart(model, Vector3.new(1, 1.2, 0.3), 
		baseCFrame * CFrame.new(-2, wallHeight * 0.6, -depth/2 - 0.1), windowColor, Enum.Material.Glass, 0.5)
	createPart(model, Vector3.new(1, 1.2, 0.3), 
		baseCFrame * CFrame.new(2, wallHeight * 0.6, -depth/2 - 0.1), windowColor, Enum.Material.Glass, 0.5)
	
	-- Toit à deux pentes (ardoise sombre)
	local roofColor = Color3.fromRGB(50, 50, 55)
	local roofHeight = wallHeight + 2
	
	-- Pente gauche
	local leftRoof = Instance.new("Part")
	leftRoof.Size = Vector3.new(depth + 1, 0.4, width/2 + 1)
	leftRoof.CFrame = baseCFrame * CFrame.new(-width/4, roofHeight, 0) * CFrame.Angles(0, 0, math.rad(30))
	leftRoof.Color = roofColor
	leftRoof.Material = Enum.Material.Slate
	leftRoof.Anchored = true
	leftRoof.TopSurface = Enum.SurfaceType.Smooth
	leftRoof.BottomSurface = Enum.SurfaceType.Smooth
	leftRoof.Parent = model
	
	-- Pente droite
	local rightRoof = Instance.new("Part")
	rightRoof.Size = Vector3.new(depth + 1, 0.4, width/2 + 1)
	rightRoof.CFrame = baseCFrame * CFrame.new(width/4, roofHeight, 0) * CFrame.Angles(0, 0, -math.rad(30))
	rightRoof.Color = roofColor
	rightRoof.Material = Enum.Material.Slate
	rightRoof.Anchored = true
	rightRoof.TopSurface = Enum.SurfaceType.Smooth
	rightRoof.BottomSurface = Enum.SurfaceType.Smooth
	rightRoof.Parent = model
	
	-- Cheminée (petit cylindre sur le toit)
	local chimney = Instance.new("Part")
	chimney.Shape = Enum.PartType.Cylinder
	chimney.Size = Vector3.new(1.5, 0.6, 0.6)
	chimney.CFrame = baseCFrame * CFrame.new(width/3, roofHeight + 1, 0) * CFrame.Angles(0, 0, math.pi/2)
	chimney.Color = Color3.fromRGB(120, 110, 100)
	chimney.Material = Enum.Material.Brick
	chimney.Anchored = true
	chimney.Parent = model
	
	return frontWall
end

-- ========================================
-- VARIANTE 2 : MAISON À COLOMBAGES
-- ========================================

local function createVariant2House(model, size, baseCFrame)
	local wallHeight = size.Y
	local width = size.X
	local depth = size.Z
	
	-- Murs de base clairs (plâtre)
	local wallColor = Color3.fromRGB(220, 210, 190)
	local wallMaterial = Enum.Material.Concrete
	
	-- Mur avant
	local frontWall = createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, -depth/2), wallColor, wallMaterial)
	
	-- Mur arrière
	createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, depth/2), wallColor, wallMaterial)
	
	-- Mur gauche
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(-width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Mur droit
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Colombages (poutres fines en bois sombre)
	local beamColor = Color3.fromRGB(60, 40, 20)
	local beamMaterial = Enum.Material.Wood
	
	-- Poutres verticales sur mur avant
	createPart(model, Vector3.new(0.3, wallHeight, 0.3), 
		baseCFrame * CFrame.new(-width/3, wallHeight/2, -depth/2 - 0.2), beamColor, beamMaterial)
	createPart(model, Vector3.new(0.3, wallHeight, 0.3), 
		baseCFrame * CFrame.new(width/3, wallHeight/2, -depth/2 - 0.2), beamColor, beamMaterial)
	
	-- Poutre horizontale
	createPart(model, Vector3.new(width, 0.3, 0.3), 
		baseCFrame * CFrame.new(0, wallHeight * 0.6, -depth/2 - 0.2), beamColor, beamMaterial)
	
	-- Porte
	local doorColor = Color3.fromRGB(90, 60, 30)
	createPart(model, Vector3.new(1.4, 2.3, 0.3), 
		baseCFrame * CFrame.new(0, 1.15, -depth/2 - 0.15), doorColor, Enum.Material.Wood)
	
	-- Fenêtre unique
	local windowColor = Color3.fromRGB(140, 160, 170)
	createPart(model, Vector3.new(1.2, 1, 0.3), 
		baseCFrame * CFrame.new(width/3, wallHeight * 0.65, -depth/2 - 0.15), windowColor, Enum.Material.Glass, 0.5)
	
	-- Toit à deux pentes
	local roofColor = Color3.fromRGB(45, 40, 40)
	local roofHeight = wallHeight + 1.8
	
	-- Pente gauche
	local leftRoof = Instance.new("Part")
	leftRoof.Size = Vector3.new(depth + 1, 0.4, width/2 + 1)
	leftRoof.CFrame = baseCFrame * CFrame.new(-width/4, roofHeight, 0) * CFrame.Angles(0, 0, math.rad(30))
	leftRoof.Color = roofColor
	leftRoof.Material = Enum.Material.Slate
	leftRoof.Anchored = true
	leftRoof.TopSurface = Enum.SurfaceType.Smooth
	leftRoof.BottomSurface = Enum.SurfaceType.Smooth
	leftRoof.Parent = model
	
	-- Pente droite
	local rightRoof = Instance.new("Part")
	rightRoof.Size = Vector3.new(depth + 1, 0.4, width/2 + 1)
	rightRoof.CFrame = baseCFrame * CFrame.new(width/4, roofHeight, 0) * CFrame.Angles(0, 0, -math.rad(30))
	rightRoof.Color = roofColor
	rightRoof.Material = Enum.Material.Slate
	rightRoof.Anchored = true
	rightRoof.TopSurface = Enum.SurfaceType.Smooth
	rightRoof.BottomSurface = Enum.SurfaceType.Smooth
	rightRoof.Parent = model
	
	return frontWall
end

-- ========================================
-- VARIANTE 3 : PETITE MAISON BASSE AVEC CLÔTURE
-- ========================================

local function createVariant3House(model, size, baseCFrame)
	local wallHeight = size.Y * 0.8
	local width = size.X * 0.85
	local depth = size.Z * 0.85
	
	-- Murs en bois clair
	local wallColor = Color3.fromRGB(180, 150, 110)
	local wallMaterial = Enum.Material.Wood
	
	-- Mur avant
	local frontWall = createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, -depth/2), wallColor, wallMaterial)
	
	-- Mur arrière
	createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, depth/2), wallColor, wallMaterial)
	
	-- Mur gauche
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(-width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Mur droit
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Porte
	createPart(model, Vector3.new(1.3, 2, 0.3), 
		baseCFrame * CFrame.new(0, 1, -depth/2 - 0.1), Color3.fromRGB(80, 50, 25), Enum.Material.Wood)
	
	-- Toit plat légèrement incliné (un seul wedge)
	local roofColor = Color3.fromRGB(55, 50, 50)
	createWedge(model, Vector3.new(depth + 1, 0.8, width + 1), 
		baseCFrame * CFrame.new(0, wallHeight + 0.4, 0) * CFrame.Angles(0, 0, math.rad(10)), 
		roofColor, Enum.Material.Slate)
	
	-- Petite clôture à l'avant (3 piquets simples)
	local fenceColor = Color3.fromRGB(100, 70, 40)
	local fenceZ = -depth/2 - 1.5
	
	createPart(model, Vector3.new(0.2, 1, 0.2), 
		baseCFrame * CFrame.new(-1.5, 0.5, fenceZ), fenceColor, Enum.Material.Wood)
	createPart(model, Vector3.new(0.2, 1, 0.2), 
		baseCFrame * CFrame.new(0, 0.5, fenceZ), fenceColor, Enum.Material.Wood)
	createPart(model, Vector3.new(0.2, 1, 0.2), 
		baseCFrame * CFrame.new(1.5, 0.5, fenceZ), fenceColor, Enum.Material.Wood)
	
	return frontWall
end

-- ========================================
-- VARIANTE 4 : MAISON EN PIERRE À ÉTAGE
-- ========================================

local function createVariant4House(model, size, baseCFrame)
	local wallHeight = size.Y
	local width = size.X
	local depth = size.Z
	
	-- Murs en pierre gris foncé
	local wallColor = Color3.fromRGB(120, 120, 120)
	local wallMaterial = Enum.Material.Brick
	
	-- Étage inférieur
	local lowerWall = createPart(model, Vector3.new(width, wallHeight * 0.5, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight * 0.25, -depth/2), wallColor, wallMaterial)
	
	createPart(model, Vector3.new(width, wallHeight * 0.5, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight * 0.25, depth/2), wallColor, wallMaterial)
	
	createPart(model, Vector3.new(0.5, wallHeight * 0.5, depth), 
		baseCFrame * CFrame.new(-width/2, wallHeight * 0.25, 0), wallColor, wallMaterial)
	
	createPart(model, Vector3.new(0.5, wallHeight * 0.5, depth), 
		baseCFrame * CFrame.new(width/2, wallHeight * 0.25, 0), wallColor, wallMaterial)
	
	-- Étage supérieur (légèrement plus large = surplomb)
	local upperWidth = width + 1
	local upperDepth = depth + 0.8
	local upperHeight = wallHeight * 0.5
	
	createPart(model, Vector3.new(upperWidth, upperHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight * 0.5 + upperHeight/2, -upperDepth/2), wallColor, wallMaterial)
	
	createPart(model, Vector3.new(upperWidth, upperHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight * 0.5 + upperHeight/2, upperDepth/2), wallColor, wallMaterial)
	
	createPart(model, Vector3.new(0.5, upperHeight, upperDepth), 
		baseCFrame * CFrame.new(-upperWidth/2, wallHeight * 0.5 + upperHeight/2, 0), wallColor, wallMaterial)
	
	createPart(model, Vector3.new(0.5, upperHeight, upperDepth), 
		baseCFrame * CFrame.new(upperWidth/2, wallHeight * 0.5 + upperHeight/2, 0), wallColor, wallMaterial)
	
	-- Porte (étage inférieur)
	createPart(model, Vector3.new(1.5, 2.2, 0.3), 
		baseCFrame * CFrame.new(0, 1.1, -depth/2 - 0.1), Color3.fromRGB(95, 65, 35), Enum.Material.Wood)
	
	-- Fenêtres
	local windowColor = Color3.fromRGB(145, 165, 175)
	createPart(model, Vector3.new(1, 1, 0.3), 
		baseCFrame * CFrame.new(-width/3, wallHeight * 0.7, -upperDepth/2 - 0.1), windowColor, Enum.Material.Glass, 0.5)
	createPart(model, Vector3.new(1, 1, 0.3), 
		baseCFrame * CFrame.new(width/3, wallHeight * 0.7, -upperDepth/2 - 0.1), windowColor, Enum.Material.Glass, 0.5)
	
	-- Toit à deux pentes
	local roofColor = Color3.fromRGB(48, 45, 45)
	local roofHeight = wallHeight + 2.2
	
	-- Pente gauche
	local leftRoof = Instance.new("Part")
	leftRoof.Size = Vector3.new(upperDepth + 1, 0.4, upperWidth/2 + 1)
	leftRoof.CFrame = baseCFrame * CFrame.new(-upperWidth/4, roofHeight, 0) * CFrame.Angles(0, 0, math.rad(30))
	leftRoof.Color = roofColor
	leftRoof.Material = Enum.Material.Slate
	leftRoof.Anchored = true
	leftRoof.TopSurface = Enum.SurfaceType.Smooth
	leftRoof.BottomSurface = Enum.SurfaceType.Smooth
	leftRoof.Parent = model
	
	-- Pente droite
	local rightRoof = Instance.new("Part")
	rightRoof.Size = Vector3.new(upperDepth + 1, 0.4, upperWidth/2 + 1)
	rightRoof.CFrame = baseCFrame * CFrame.new(upperWidth/4, roofHeight, 0) * CFrame.Angles(0, 0, -math.rad(30))
	rightRoof.Color = roofColor
	rightRoof.Material = Enum.Material.Slate
	rightRoof.Anchored = true
	rightRoof.TopSurface = Enum.SurfaceType.Smooth
	rightRoof.BottomSurface = Enum.SurfaceType.Smooth
	rightRoof.Parent = model
	
	-- Cheminée
	local chimney = Instance.new("Part")
	chimney.Shape = Enum.PartType.Cylinder
	chimney.Size = Vector3.new(1.6, 0.5, 0.5)
	chimney.CFrame = baseCFrame * CFrame.new(upperWidth/3.5, roofHeight + 1.2, 0) * CFrame.Angles(0, 0, math.pi/2)
	chimney.Color = Color3.fromRGB(110, 100, 95)
	chimney.Material = Enum.Material.Brick
	chimney.Anchored = true
	chimney.Parent = model
	
	return lowerWall
end

-- ========================================
-- VARIANTE 5 : MAISON BOIS AVEC TERRASSE
-- ========================================

local function createVariant5House(model, size, baseCFrame)
	local wallHeight = size.Y
	local width = size.X
	local depth = size.Z
	
	-- Murs en bois naturel
	local wallColor = Color3.fromRGB(160, 130, 90)
	local wallMaterial = Enum.Material.Wood
	
	-- Mur avant
	local frontWall = createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, -depth/2), wallColor, wallMaterial)
	
	-- Mur arrière
	createPart(model, Vector3.new(width, wallHeight, 0.5), 
		baseCFrame * CFrame.new(0, wallHeight/2, depth/2), wallColor, wallMaterial)
	
	-- Mur gauche
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(-width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Mur droit
	createPart(model, Vector3.new(0.5, wallHeight, depth), 
		baseCFrame * CFrame.new(width/2, wallHeight/2, 0), wallColor, wallMaterial)
	
	-- Porte
	createPart(model, Vector3.new(1.4, 2.4, 0.3), 
		baseCFrame * CFrame.new(0, 1.2, -depth/2 - 0.1), Color3.fromRGB(85, 55, 30), Enum.Material.Wood)
	
	-- Fenêtre
	local windowColor = Color3.fromRGB(140, 155, 165)
	createPart(model, Vector3.new(1.1, 1.1, 0.3), 
		baseCFrame * CFrame.new(width/3, wallHeight * 0.65, -depth/2 - 0.1), windowColor, Enum.Material.Glass, 0.5)
	
	-- Plancher de terrasse
	local terraceDist = -depth/2 - 1.5
	createPart(model, Vector3.new(width, 0.3, 2), 
		baseCFrame * CFrame.new(0, 0.15, terraceDist), Color3.fromRGB(140, 110, 70), Enum.Material.Wood)
	
	-- Poteaux de terrasse
	local postColor = Color3.fromRGB(100, 70, 40)
	createPart(model, Vector3.new(0.3, 2.5, 0.3), 
		baseCFrame * CFrame.new(-width/2 + 0.5, 1.25, terraceDist - 0.8), postColor, Enum.Material.Wood)
	createPart(model, Vector3.new(0.3, 2.5, 0.3), 
		baseCFrame * CFrame.new(width/2 - 0.5, 1.25, terraceDist - 0.8), postColor, Enum.Material.Wood)
	
	-- Auvent (wedge en extension)
	local awningColor = Color3.fromRGB(50, 45, 45)
	createWedge(model, Vector3.new(2.5, 0.5, width), 
		baseCFrame * CFrame.new(0, wallHeight * 0.4, terraceDist) * CFrame.Angles(0, math.pi/2, -math.rad(25)), 
		awningColor, Enum.Material.Slate)
	
	-- Toit principal à deux pentes
	local roofColor = Color3.fromRGB(48, 43, 43)
	local roofHeight = wallHeight + 1.9
	
	-- Pente gauche
	local leftRoof = Instance.new("Part")
	leftRoof.Size = Vector3.new(depth + 1, 0.4, width/2 + 1)
	leftRoof.CFrame = baseCFrame * CFrame.new(-width/4, roofHeight, 0) * CFrame.Angles(0, 0, math.rad(30))
	leftRoof.Color = roofColor
	leftRoof.Material = Enum.Material.Slate
	leftRoof.Anchored = true
	leftRoof.TopSurface = Enum.SurfaceType.Smooth
	leftRoof.BottomSurface = Enum.SurfaceType.Smooth
	leftRoof.Parent = model
	
	-- Pente droite
	local rightRoof = Instance.new("Part")
	rightRoof.Size = Vector3.new(depth + 1, 0.4, width/2 + 1)
	rightRoof.CFrame = baseCFrame * CFrame.new(width/4, roofHeight, 0) * CFrame.Angles(0, 0, -math.rad(30))
	rightRoof.Color = roofColor
	rightRoof.Material = Enum.Material.Slate
	rightRoof.Anchored = true
	rightRoof.TopSurface = Enum.SurfaceType.Smooth
	rightRoof.BottomSurface = Enum.SurfaceType.Smooth
	rightRoof.Parent = model
	
	return frontWall
end

-- ========================================
-- FONCTION PUBLIQUE Create
-- ========================================

function HouseGenerator.Create(variantIndex, position, size, rotation)
	local model = Instance.new("Model")
	model.Name = "House_Variant" .. tostring(variantIndex)
	
	-- CFrame de base : position + rotation (rotation en degrés Y)
	local baseCFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
	
	-- Sélection de la variante
	local primaryPart = nil
	
	if variantIndex == 1 then
		primaryPart = createVariant1House(model, size, baseCFrame)
	elseif variantIndex == 2 then
		primaryPart = createVariant2House(model, size, baseCFrame)
	elseif variantIndex == 3 then
		primaryPart = createVariant3House(model, size, baseCFrame)
	elseif variantIndex == 4 then
		primaryPart = createVariant4House(model, size, baseCFrame)
	elseif variantIndex == 5 then
		primaryPart = createVariant5House(model, size, baseCFrame)
	else
		warn("[HouseGenerator] Variante inconnue : " .. tostring(variantIndex) .. ", utilisation de la variante 1")
		primaryPart = createVariant1House(model, size, baseCFrame)
	end
	
	-- Définir la PrimaryPart
	if primaryPart then
		model.PrimaryPart = primaryPart
	end
	
	return model
end

return HouseGenerator