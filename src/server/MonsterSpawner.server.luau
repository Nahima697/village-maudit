--[[
	Gère le comportement d'un monstre individuel
	@param monster Model - Le monstre à gérer
	@param spawnPosition Vector3 - Position de spawn initiale
]]
local function setupMonsterBehavior(monster, spawnPosition)
	local humanoid = monster:FindFirstChild("Humanoid")
	local rootPart = monster:FindFirstChild("HumanoidRootPart")
	
	if not humanoid or not rootPart then
		monster:Destroy()
		return
	end
	
	-- Données du monstre
	local monsterData = {
		model = monster,
		currentTarget = nil,
		lastPathfindTime = 0,
		lastAttackTime = 0,
		isActive = true,
		path = PathfindingService:CreatePath({
			AgentRadius = 2,
			AgentHeight = 5,
			AgentCanJump = true,
			WaypointSpacing = 4,
			Costs = {
				Water = math.huge
			}
		})
	}
	
	table.insert(activeMonsters, monsterData)
	
	-- Connexion à la mort du monstre
	humanoid.Died:Connect(function()
		monsterData.isActive = false
		Debris:AddItem(monster, 3)
	end)
	
	-- Boucle de comportement
	task.spawn(function()
		while monsterData.isActive and monster.Parent and humanoid.Health > 0 do
			if not isNightPhase then
				break
			end
			
			local currentTime = tick()
			
			-- Vérifier si un joueur est à portée
			local nearestPlayer, playerDistance = findNearestPlayer(rootPart.Position)
			
			if nearestPlayer and nearestPlayer.Character then
				-- Cibler le joueur
				monsterData.currentTarget = nearestPlayer.Character
			else
				-- Cibler la porte la plus proche
				local nearestDoor = findNearestDoor(rootPart.Position)
				if nearestDoor then
					monsterData.currentTarget = nearestDoor
				else
					monsterData.currentTarget = nil
				end
			end
			
			-- Déplacement et attaque
			if monsterData.currentTarget then
				local targetPosition
				if monsterData.currentTarget:IsA("Model") then
					local targetRoot = monsterData.currentTarget:FindFirstChild("HumanoidRootPart")
					if targetRoot then
						targetPosition = targetRoot.Position
					end
				else
					targetPosition = monsterData.currentTarget.Position
				end
				
				if targetPosition then
					local distance = (rootPart.Position - targetPosition).Magnitude
					
					-- Attaquer si assez proche
					if distance < 5 then
						humanoid:MoveTo(rootPart.Position) -- Arrêter le mouvement
						attackTarget(monster, monsterData.currentTarget, monsterData)
					else
						-- Recalculer le chemin périodiquement
						if currentTime - monsterData.lastPathfindTime > PATHFINDING_RECALCULATE_INTERVAL then
							monsterData.lastPathfindTime = currentTime
							
							local success, errorMsg = pcall(function()
								monsterData.path:ComputeAsync(rootPart.Position, targetPosition)
							end)
							
							if success and monsterData.path.Status == Enum.PathStatus.Success then
								local waypoints = monsterData.path:GetWaypoints()
								
								if #waypoints > 0 then
									-- Suivre le chemin
									for i = 2, math.min(#waypoints, 5) do
										if not monsterData.isActive or not isNightPhase then
											break
										end
										
										local waypoint = waypoints[i]
										humanoid:MoveTo(waypoint.Position)
										
										if waypoint.Action == Enum.PathWaypointAction.Jump then
											humanoid.Jump = true
										end
										
										-- Attendre que le monstre atteigne le waypoint avec timeout de sécurité
										local moveFinished = false
										local moveConnection
										
										moveConnection = humanoid.MoveToFinished:Connect(function(reached)
											moveFinished = true
											if moveConnection then
												moveConnection:Disconnect()
											end
										end)
										
										-- Attendre avec timeout de 1 seconde
										local waitStart = tick()
										while not moveFinished and (tick() - waitStart) < 1 do
											task.wait(0.05)
										end
										
										-- Nettoyer la connexion si elle existe encore
										if moveConnection then
											moveConnection:Disconnect()
										end
										
										-- Si timeout, passer quand même au waypoint suivant
										if not moveFinished then
											-- Le monstre est peut-être bloqué, on continue
										end
									end
								end
							else
								-- Fallback : déplacement direct
								humanoid:MoveTo(targetPosition)
							end
						end
					end
				end
			end
			
			task.wait(0.5)
		end
		
		monsterData.isActive = false
	end)
end