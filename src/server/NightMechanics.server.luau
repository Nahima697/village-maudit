local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local isNight = false
local NIGHT_START = 18
local NIGHT_END = 6

local NIGHT_FOG_END = 40
local NIGHT_FOG_COLOR = Color3.new(0, 0, 0)
local DAY_FOG_END = 10000
local DAY_FOG_COLOR = Color3.new(0.75, 0.75, 0.75)

local SAFE_DISTANCE = 30
local DAMAGE_AMOUNT = 10

local function isTimeNight(clockTime)
	return clockTime >= NIGHT_START or clockTime < NIGHT_END
end

local function updateFog(night)
	if night then
		Lighting.FogEnd = NIGHT_FOG_END
		Lighting.FogColor = NIGHT_FOG_COLOR
	else
		Lighting.FogEnd = DAY_FOG_END
		Lighting.FogColor = DAY_FOG_COLOR
	end
end

local function updateRefugeDoors(night)
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and obj.Name == "RefugeDoor" then
			if night then
				obj.Transparency = 0.5
				obj.CanCollide = false
			else
				obj.Transparency = 0
				obj.CanCollide = true
			end
		end
	end
end

local function findNearestSafeZone(position)
	local minDistance = math.huge
	
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("BasePart") and (obj.Name == "RefugeDoor" or obj.Name:lower():find("fire") or obj.Name:lower():find("feu")) then
			local distance = (obj.Position - position).Magnitude
			if distance < minDistance then
				minDistance = distance
			end
		end
	end
	
	return minDistance
end

local function checkPlayerSafety()
	if not isNight then return end
	
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			
			if humanoid and humanoid.Health > 0 and rootPart then
				local distanceToSafety = findNearestSafeZone(rootPart.Position)
				
				if distanceToSafety > SAFE_DISTANCE then
					humanoid:TakeDamage(DAMAGE_AMOUNT)
				end
			end
		end
	end
end

local function updateNightState()
	local currentTime = Lighting.ClockTime
	local shouldBeNight = isTimeNight(currentTime)
	
	if shouldBeNight ~= isNight then
		isNight = shouldBeNight
		updateFog(isNight)
		updateRefugeDoors(isNight)
	end
end

task.spawn(function()
	while task.wait(2) do
		checkPlayerSafety()
	end
end)

Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateNightState)

updateNightState()