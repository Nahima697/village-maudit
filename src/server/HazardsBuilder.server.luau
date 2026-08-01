-- HazardsBuilder.server.luau
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local HazardsFolder = Instance.new("Folder")
HazardsFolder.Name = "Hazards"
HazardsFolder.Parent = Workspace

local CampfiresFolder = Instance.new("Folder")
CampfiresFolder.Name = "Campfires"
CampfiresFolder.Parent = Workspace

local hazardsList = {}
local campfiresList = {}

local TRAP_DAMAGE = 25
local TRAP_COOLDOWN = 2
local HEAL_AMOUNT = 5
local HEAL_INTERVAL = 1
local CAMPFIRE_RADIUS = 15

local function createSpikeTrap(position)
	local trap = Instance.new("Part")
	trap.Name = "SpikeTrap"
	trap.Size = Vector3.new(6, 1, 6)
	trap.Position = position
	trap.Anchored = true
	trap.Color = Color3.fromRGB(80, 80, 80)
	trap.Material = Enum.Material.Metal
	trap.Parent = HazardsFolder
	
	local spikes = Instance.new("Part")
	spikes.Name = "Spikes"
	spikes.Size = Vector3.new(5, 2, 5)
	spikes.Position = position + Vector3.new(0, 1.5, 0)
	spikes.Anchored = true
	spikes.Color = Color3.fromRGB(150, 0, 0)
	spikes.Material = Enum.Material.CorrodedMetal
	spikes.CanCollide = false
	spikes.Parent = trap
	
	local hitPlayers = {}
	
	spikes.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		
		if humanoid and player then
			local currentTime = tick()
			if not hitPlayers[player.UserId] or (currentTime - hitPlayers[player.UserId]) > TRAP_COOLDOWN then
				hitPlayers[player.UserId] = currentTime
				humanoid:TakeDamage(TRAP_DAMAGE)
				
				local blood = Instance.new("ParticleEmitter")
				blood.Texture = "rbxasset://textures/particles/smoke_main.dds"
				blood.Color = ColorSequence.new(Color3.fromRGB(150, 0, 0))
				blood.Rate = 50
				blood.Lifetime = NumberRange.new(0.3, 0.5)
				blood.Speed = NumberRange.new(5, 10)
				blood.Parent = hit
				
				task.delay(0.2, function()
					blood.Enabled = false
					task.wait(1)
					blood:Destroy()
				end)
			end
		end
	end)
	
	table.insert(hazardsList, trap)
	return trap
end

local function createCampfire(position)
	local base = Instance.new("Part")
	base.Name = "Campfire"
	base.Size = Vector3.new(4, 0.5, 4)
	base.Position = position
	base.Anchored = true
	base.Color = Color3.fromRGB(70, 50, 40)
	base.Material = Enum.Material.Wood
	base.Parent = CampfiresFolder
	
	local fire = Instance.new("Part")
	fire.Name = "Fire"
	fire.Size = Vector3.new(2, 3, 2)
	fire.Position = position + Vector3.new(0, 2, 0)
	fire.Anchored = true
	fire.Transparency = 0.8
	fire.Color = Color3.fromRGB(255, 100, 0)
	fire.Material = Enum.Material.Neon
	fire.CanCollide = false
	fire.Parent = base
	
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 150, 50)
	light.Range = CAMPFIRE_RADIUS * 2
	light.Shadows = true
	light.Parent = fire
	
	local fireEffect = Instance.new("Fire")
	fireEffect.Size = 8
	fireEffect.Heat = 10
	fireEffect.Color = Color3.fromRGB(255, 100, 0)
	fireEffect.SecondaryColor = Color3.fromRGB(255, 200, 0)
	fireEffect.Parent = fire
	
	local healRegion = Instance.new("Part")
	healRegion.Name = "HealRegion"
	healRegion.Size = Vector3.new(CAMPFIRE_RADIUS * 2, 10, CAMPFIRE_RADIUS * 2)
	healRegion.Position = position + Vector3.new(0, 5, 0)
	healRegion.Anchored = true
	healRegion.Transparency = 1
	healRegion.CanCollide = false
	healRegion.Parent = base
	
	local playersInRange = {}
	
	healRegion.Touched:Connect(function(hit)
		local humanoid = hit.Parent:FindFirstChild("Humanoid")
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		
		if humanoid and player and not playersInRange[player.UserId] then
			playersInRange[player.UserId] = true
			
			task.spawn(function()
				while playersInRange[player.UserId] and humanoid.Health > 0 do
					if humanoid.Health < humanoid.MaxHealth then
						humanoid.Health = math.min(humanoid.Health + HEAL_AMOUNT, humanoid.MaxHealth)
					end
					task.wait(HEAL_INTERVAL)
				end
			end)
		end
	end)
	
	healRegion.TouchEnded:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player then
			playersInRange[player.UserId] = nil
		end
	end)
	
	task.spawn(function()
		while fire.Parent do
			light.Brightness = 3 + math.random() * 0.5
			task.wait(0.1)
		end
	end)
	
	table.insert(campfiresList, base)
	return base
end

local function createLantern(position)
	local pole = Instance.new("Part")
	pole.Name = "Lantern"
	pole.Size = Vector3.new(0.5, 8, 0.5)
	pole.Position = position + Vector3.new(0, 4, 0)
	pole.Anchored = true
	pole.Color = Color3.fromRGB(40, 40, 40)
	pole.Material = Enum.Material.Metal
	pole.Parent = CampfiresFolder
	
	local lamp = Instance.new("Part")
	lamp.Name = "Lamp"
	lamp.Size = Vector3.new(2, 2, 2)
	lamp.Position = position + Vector3.new(0, 8.5, 0)
	lamp.Anchored = true
	lamp.Transparency = 0.3
	lamp.Color = Color3.fromRGB(255, 230, 150)
	lamp.Material = Enum.Material.Glass
	lamp.Shape = Enum.PartType.Ball
	lamp.Parent = pole
	
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Color = Color3.fromRGB(255, 230, 150)
	light.Range = 25
	light.Shadows = true
	light.Parent = lamp
	
	task.spawn(function()
		while lamp.Parent do
			light.Brightness = 2 + math.sin(tick() * 3) * 0.3
			task.wait(0.05)
		end
	end)
	
	table.insert(campfiresList, pole)
	return pole
end

for i = 1, 5 do
	local x = math.random(-100, 100)
	local z = math.random(-100, 100)
	createSpikeTrap(Vector3.new(x, 5, z))
end

for i = 1, 3 do
	local x = math.random(-80, 80)
	local z = math.random(-80, 80)
	createCampfire(Vector3.new(x, 3, z))
end

for i = 1, 4 do
	local x = math.random(-90, 90)
	local z = math.random(-90, 90)
	createLantern(Vector3.new(x, 0, z))
end

print("[HazardsBuilder] Generated", #hazardsList, "traps and", #campfiresList, "light sources")