--[[
	RoleReveal.luau
	Composant React : overlay plein écran de révélation de rôle.
	Props :
		- role: string ("Traitor" | "Villager")
		- visible: boolean
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local React = require(ReplicatedStorage.Packages.React)

local function RoleReveal(props)
	local role = props.role or "Villager"
	local visible = props.visible

	-- Ne rien afficher si non visible
	if not visible then
		return nil
	end

	-- Configuration par rôle
	local backgroundColor, titleText, descriptionText
	if role == "Traitor" then
		backgroundColor = Color3.fromRGB(200, 30, 30)
		titleText = "Vous êtes un TRAÎTRE"
		descriptionText = "Sabotez le village la nuit, sans vous faire démasquer."
	else
		backgroundColor = Color3.fromRGB(80, 200, 120)
		titleText = "Vous êtes un VILLAGEOIS"
		descriptionText = "Survivez et démasquez le traître."
	end

	return React.createElement("ScreenGui", {
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 100,
	}, {
		Overlay = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			BackgroundColor3 = backgroundColor,
			BackgroundTransparency = 0.1,
			BorderSizePixel = 0,
			ZIndex = 1,
		}, {
			Container = React.createElement("Frame", {
				Size = UDim2.new(0, 600, 0, 300),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BackgroundTransparency = 0.2,
				BorderSizePixel = 0,
				ZIndex = 2,
			}, {
				UICorner = React.createElement("UICorner", {
					CornerRadius = UDim.new(0, 16),
				}),

				UIStroke = React.createElement("UIStroke", {
					Color = backgroundColor,
					Thickness = 4,
					Transparency = 0,
				}),

				Title = React.createElement("TextLabel", {
					Size = UDim2.new(1, -40, 0, 80),
					Position = UDim2.new(0, 20, 0, 40),
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Text = titleText,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 42,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					ZIndex = 3,
				}),

				Description = React.createElement("TextLabel", {
					Size = UDim2.new(1, -60, 0, 120),
					Position = UDim2.new(0, 30, 0, 140),
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					Text = descriptionText,
					TextColor3 = Color3.fromRGB(230, 230, 230),
					TextSize = 22,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 3,
				}),
			}),
		}),
	})
end

return RoleReveal