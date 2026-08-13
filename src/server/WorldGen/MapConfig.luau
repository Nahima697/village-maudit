--[[
	MapConfig.luau
	Configuration géométrique pure de la map Village Maudit.
	Aucune logique de création d'instances, que des constantes.
]]

local MapConfig = {}

-- Centre du village (brasier)
MapConfig.VILLAGE_CENTER = Vector3.new(0, 0, 0)
MapConfig.VILLAGE_RADIUS = 25

-- Tracé asymétrique de la rivière (passe à ~50 studs du centre, côté nord-est)
MapConfig.RIVER_PATH = {
	Vector3.new(-80, 0, 40),
	Vector3.new(-40, 0, 45),
	Vector3.new(0, 0, 50),
	Vector3.new(40, 0, 48),
	Vector3.new(80, 0, 52),
	Vector3.new(120, 0, 55)
}
MapConfig.RIVER_WIDTH = 12

-- Pont traversant la rivière
MapConfig.BRIDGE_POSITION = Vector3.new(20, 0, 50)
MapConfig.BRIDGE_WIDTH = 10

-- Emplacements de maisons (disposition asymétrique, tailles et rotations variées)
MapConfig.HOUSE_ZONES = {
	{Position = Vector3.new(-35, 0, -20), Size = Vector3.new(12, 8, 10), Rotation = 15},
	{Position = Vector3.new(-28, 0, 8), Size = Vector3.new(10, 8, 14), Rotation = -30},
	{Position = Vector3.new(-10, 0, -30), Size = Vector3.new(14, 8, 12), Rotation = 45},
	{Position = Vector3.new(15, 0, -25), Size = Vector3.new(11, 8, 11), Rotation = 0},
	{Position = Vector3.new(32, 0, -10), Size = Vector3.new(13, 8, 10), Rotation = 60},
	{Position = Vector3.new(25, 0, 12), Size = Vector3.new(10, 8, 15), Rotation = -15},
	{Position = Vector3.new(-5, 0, 18), Size = Vector3.new(12, 8, 13), Rotation = 90},
	{Position = Vector3.new(-40, 0, 15), Size = Vector3.new(11, 8, 12), Rotation = -45}
}

-- Zone atelier/craft
MapConfig.WORKSHOP_ZONE = {
	Position = Vector3.new(38, 0, 22),
	Size = Vector3.new(16, 8, 12)
}

-- Cimetière (zone secondaire, au-delà de la rivière)
MapConfig.CEMETERY_ZONE = {
	Position = Vector3.new(-15, 0, 70),
	Radius = 18
}

-- Forêt dense (anneaux concentriques)
MapConfig.FOREST_INNER_RADIUS = 65  -- VILLAGE_RADIUS + 40
MapConfig.FOREST_OUTER_RADIUS = 125 -- FOREST_INNER_RADIUS + 60

return MapConfig