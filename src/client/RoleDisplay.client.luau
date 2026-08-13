-- RoleDisplay.client.luau
-- Point d'entrée React pour l'affichage du rôle du joueur

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import des packages React
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

-- Import des composants
local RoleReveal = require(script.Parent.Components.RoleReveal)
local RoleBadge = require(script.Parent.Components.RoleBadge)

-- Référence au RemoteEvent créé par GameManager
local RemoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local AssignRoleEvent = RemoteEvents:WaitForChild("AssignRole")

-- Configuration
local OVERLAY_DURATION = 5 -- secondes

-- Composant racine de l'application
local function RoleDisplayApp()
	local role, setRole = React.useState(nil)
	local visible, setVisible = React.useState(false)
	
	-- Effect pour gérer le timer de disparition de l'overlay
	React.useEffect(function()
		if visible then
			local connection = task.delay(OVERLAY_DURATION, function()
				setVisible(false)
			end)
			
			-- Cleanup (annulation du timer si le composant est démonté)
			return function()
				task.cancel(connection)
			end
		end
	end, { visible })
	
	-- Effect pour écouter l'événement d'assignation de rôle
	React.useEffect(function()
		local connection = AssignRoleEvent.OnClientEvent:Connect(function(assignedRole)
			print("[RoleDisplay] Rôle assigné:", assignedRole)
			setRole(assignedRole)
			setVisible(true)
		end)
		
		-- Cleanup de la connexion à la destruction du composant
		return function()
			connection:Disconnect()
		end
	end, {})
	
	-- Si aucun rôle n'est assigné, ne rien afficher
	if not role then
		return nil
	end
	
	-- Rendu de l'overlay de révélation et du badge permanent
	return React.createElement(React.Fragment, nil, {
		RoleReveal = React.createElement(RoleReveal, {
			role = role,
			visible = visible
		}),
		RoleBadge = React.createElement(RoleBadge, {
			role = role,
			visible = not visible -- Le badge n'apparaît que quand l'overlay disparaît
		})
	})
end

-- Montage de l'application React
local root = ReactRoblox.createRoot(playerGui)
root:render(React.createElement(RoleDisplayApp))

print("[RoleDisplay] Client React initialisé et en attente du rôle...")

-- Nettoyage à la déconnexion du joueur
player.AncestryChanged:Connect(function()
	if not player:IsDescendantOf(game) then
		root:unmount()
		print("[RoleDisplay] Application React démontée")
	end
end)