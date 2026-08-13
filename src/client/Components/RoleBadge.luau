--[[
	RoleBadge.luau
	Composant React affichant un badge permanent en haut à droite rappelant le rôle du joueur.
	Props: { role: string }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local function RoleBadge(props)
	local role = props.role or "Inconnu"
	
	-- Définir les couleurs selon le rôle (identiques à RoleReveal)
	local backgroundColor
	local textColor = Color3.fromRGB(255, 255, 255)
	
	if role == "Traître" then
		backgroundColor = Color3.fromRGB(139, 0, 0) -- Rouge sombre
	elseif role == "Villageois" then
		backgroundColor = Color3.fromRGB(34, 139, 34) -- Vert forêt
	else
		backgroundColor = Color3.fromRGB(100, 100, 100) -- Gris par défaut
	end
	
	return React.createElement("ScreenGui", {
		Name = "RoleBadgeGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		Badge = React.createElement("Frame", {
			Name = "Badge",
			Size = UDim2.new(0, 140, 0, 40),
			Position = UDim2.new(1, -150, 0, 10), -- Haut à droite avec marge
			AnchorPoint = Vector2.new(0, 0),
			BackgroundColor3 = backgroundColor,
			BorderSizePixel = 0,
		}, {
			UICorner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 8),
			}),
			
			UIStroke = React.createElement("UIStroke", {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 2,
				Transparency = 0.3,
			}),
			
			RoleLabel = React.createElement("TextLabel", {
				Name = "RoleLabel",
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = role,
				TextColor3 = textColor,
				TextSize = 18,
				Font = Enum.Font.GothamBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),
	})
end

return RoleBadge