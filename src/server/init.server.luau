local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local CYCLE_DURATION = 300
local DAY_START = 6
local DUSK_START = 18
local NIGHT_START = 20
local DAWN_START = 4

local atmosphereExists = Lighting:FindFirstChildOfClass("Atmosphere")
local skyExists = Lighting:FindFirstChildOfClass("Sky")

local function updateLighting(currentTime)
	Lighting.ClockTime = currentTime
	
	if currentTime >= DAY_START and currentTime < DUSK_START then
		local dayProgress = (currentTime - DAY_START) / (DUSK_START - DAY_START)
		Lighting.Brightness = 2
		Lighting.FogEnd = 10000
		Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 150)
		
		if atmosphereExists then
			atmosphereExists.Density = 0.3
			atmosphereExists.Offset = 0
			atmosphereExists.Color = Color3.fromRGB(199, 220, 255)
			atmosphereExists.Decay = Color3.fromRGB(106, 112, 125)
			atmosphereExists.Glare = 0.4
			atmosphereExists.Haze = 0
		end
		
	elseif currentTime >= DUSK_START and currentTime < NIGHT_START then
		local duskProgress = (currentTime - DUSK_START) / (NIGHT_START - DUSK_START)
		Lighting.Brightness = 2 - (1.8 * duskProgress)
		Lighting.FogEnd = 10000 - (8500 * duskProgress)
		
		local ambientR = math.floor(150 - (100 * duskProgress))
		local ambientG = math.floor(150 - (120 * duskProgress))
		local ambientB = math.floor(150 - (100 * duskProgress))
		Lighting.OutdoorAmbient = Color3.fromRGB(ambientR, ambientG, ambientB)
		
		if atmosphereExists then
			atmosphereExists.Density = 0.3 + (0.15 * duskProgress)
			atmosphereExists.Offset = 0.25 * duskProgress
			atmosphereExists.Color = Color3.fromRGB(
				199 - math.floor(99 * duskProgress),
				220 - math.floor(150 * duskProgress),
				255 - math.floor(155 * duskProgress)
			)
			atmosphereExists.Decay = Color3.fromRGB(
				106 - math.floor(56 * duskProgress),
				112 - math.floor(52 * duskProgress),
				125 - math.floor(75 * duskProgress)
			)
			atmosphereExists.Glare = 0.4 - (0.4 * duskProgress)
			atmosphereExists.Haze = 1.5 * duskProgress
		end
		
		if duskProgress > 0.8 and not Lighting:GetAttribute("NightWarningShown") then
			warn("🌙 La nuit commence à envelopper le village...")
			Lighting:SetAttribute("NightWarningShown", true)
		end
		
	elseif currentTime >= NIGHT_START or currentTime < DAWN_START then
		Lighting.Brightness = 0.2
		Lighting.FogEnd = 1500
		Lighting.OutdoorAmbient = Color3.fromRGB(50, 30, 50)
		
		if atmosphereExists then
			atmosphereExists.Density = 0.45
			atmosphereExists.Offset = 0.25
			atmosphereExists.Color = Color3.fromRGB(100, 70, 100)
			atmosphereExists.Decay = Color3.fromRGB(50, 60, 50)
			atmosphereExists.Glare = 0
			atmosphereExists.Haze = 1.5
		end
		
	elseif currentTime >= DAWN_START and currentTime < DAY_START then
		local dawnProgress = (currentTime - DAWN_START) / (DAY_START - DAWN_START)
		Lighting.Brightness = 0.2 + (1.8 * dawnProgress)
		Lighting.FogEnd = 1500 + (8500 * dawnProgress)
		
		local ambientR = math.floor(50 + (100 * dawnProgress))
		local ambientG = math.floor(30 + (120 * dawnProgress))
		local ambientB = math.floor(50 + (100 * dawnProgress))
		Lighting.OutdoorAmbient = Color3.fromRGB(ambientR, ambientG, ambientB)
		
		if atmosphereExists then
			atmosphereExists.Density = 0.45 - (0.15 * dawnProgress)
			atmosphereExists.Offset = 0.25 - (0.25 * dawnProgress)
			atmosphereExists.Color = Color3.fromRGB(
				100 + math.floor(99 * dawnProgress),
				70 + math.floor(150 * dawnProgress),
				100 + math.floor(155 * dawnProgress)
			)
			atmosphereExists.Decay = Color3.fromRGB(
				50 + math.floor(56 * dawnProgress),
				60 + math.floor(52 * dawnProgress),
				50 + math.floor(75 * dawnProgress)
			)
			atmosphereExists.Glare = 0.4 * dawnProgress
			atmosphereExists.Haze = 1.5 - (1.5 * dawnProgress)
		end
		
		if dawnProgress > 0.2 and not Lighting:GetAttribute("DawnWarningShown") then
			warn("🌅 L'aube chasse lentement les ténèbres...")
			Lighting:SetAttribute("DawnWarningShown", true)
			Lighting:SetAttribute("NightWarningShown", false)
		end
		
		if dawnProgress > 0.9 then
			Lighting:SetAttribute("DawnWarningShown", false)
		end
	end
end

local startTime = os.clock()

while true do
	local elapsed = os.clock() - startTime
	local cycleProgress = (elapsed % CYCLE_DURATION) / CYCLE_DURATION
	local currentTime = cycleProgress * 24
	
	updateLighting(currentTime)
	
	task.wait(0.1)
end