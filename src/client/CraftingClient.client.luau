--[[
    CraftingClient.client.luau
    Système client ultra-fiable basé sur les tags CollectionService
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
local CollectResourceEvent = remoteEventsFolder:WaitForChild("CollectResourceEvent", 10)
local CraftItemEvent = remoteEventsFolder:WaitForChild("CraftItemEvent", 10)

local CRAFT_RECIPES = {
    {Name = "Fortification", Wood = 3, Stone = 2, Description = "Répare une porte (+100 HP)"},
    {Name = "Barricade", Wood = 5, Stone = 0, Description = "Barricade temporaire (60s)"},
    {Name = "Torche", Wood = 2, Stone = 1, Description = "Éclairage et vitesse +"},
    {Name = "Lance", Wood = 4, Stone = 1, Description = "Arme de mêlée (25 dégâts)"}
}

-- UI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CraftingUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local resourceFrame = Instance.new("Frame")
resourceFrame.Name = "ResourceFrame"
resourceFrame.Size = UDim2.new(0, 200, 0, 60)
resourceFrame.Position = UDim2.new(0, 10, 0, 10)
resourceFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
resourceFrame.BackgroundTransparency = 0.3
resourceFrame.Parent = screenGui

local woodLabel = Instance.new("TextLabel")
woodLabel.Name = "WoodLabel"
woodLabel.Size = UDim2.new(1, 0, 0.5, 0)
woodLabel.BackgroundTransparency = 1
woodLabel.Text = "Bois: 0"
woodLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
woodLabel.TextScaled = true
woodLabel.Font = Enum.Font.SourceSansBold
woodLabel.Parent = resourceFrame

local stoneLabel = Instance.new("TextLabel")
stoneLabel.Name = "StoneLabel"
stoneLabel.Size = UDim2.new(1, 0, 0.5, 0)
stoneLabel.Position = UDim2.new(0, 0, 0.5, 0)
stoneLabel.BackgroundTransparency = 1
stoneLabel.Text = "Pierre: 0"
stoneLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
stoneLabel.TextScaled = true
stoneLabel.Font = Enum.Font.SourceSansBold
stoneLabel.Parent = resourceFrame

local craftFrame = Instance.new("Frame")
craftFrame.Name = "CraftFrame"
craftFrame.Size = UDim2.new(0, 300, 0, 400)
craftFrame.Position = UDim2.new(0.5, -150, 0.5, -200)
craftFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
craftFrame.BackgroundTransparency = 0.2
craftFrame.Visible = false
craftFrame.Parent = screenGui

local craftTitle = Instance.new("TextLabel")
craftTitle.Size = UDim2.new(1, 0, 0, 40)
craftTitle.BackgroundTransparency = 1
craftTitle.Text = "Menu de Craft (Touche C)"
craftTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
craftTitle.TextScaled = true
craftTitle.Font = Enum.Font.SourceSansBold
craftTitle.Parent = craftFrame

local craftList = Instance.new("ScrollingFrame")
craftList.Size = UDim2.new(1, -20, 1, -60)
craftList.Position = UDim2.new(0, 10, 0, 50)
craftList.BackgroundTransparency = 1
craftList.ScrollBarThickness = 6
craftList.Parent = craftFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = craftList

for _, recipe in ipairs(CRAFT_RECIPES) do
    local itemFrame = Instance.new("Frame")
    itemFrame.Size = UDim2.new(1, -10, 0, 80)
    itemFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    itemFrame.Parent = craftList
    
    local itemName = Instance.new("TextLabel")
    itemName.Size = UDim2.new(1, -10, 0, 20)
    itemName.Position = UDim2.new(0, 5, 0, 5)
    itemName.BackgroundTransparency = 1
    itemName.Text = recipe.Name
    itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemName.Font = Enum.Font.SourceSansBold
    itemName.TextSize = 18
    itemName.Parent = itemFrame
    
    local itemCost = Instance.new("TextLabel")
    itemCost.Size = UDim2.new(1, -10, 0, 15)
    itemCost.Position = UDim2.new(0, 5, 0, 25)
    itemCost.BackgroundTransparency = 1
    itemCost.Text = string.format("Coût: %d Bois, %d Pierre", recipe.Wood, recipe.Stone)
    itemCost.TextColor3 = Color3.fromRGB(200, 200, 200)
    itemCost.TextSize = 14
    itemCost.Parent = itemFrame
    
    local craftButton = Instance.new("TextButton")
    craftButton.Size = UDim2.new(0, 100, 0, 20)
    craftButton.Position = UDim2.new(1, -110, 1, -25)
    craftButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    craftButton.Text = "Fabriquer"
    craftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    craftButton.TextSize = 14
    craftButton.Parent = itemFrame
    
    craftButton.MouseButton1Click:Connect(function()
        if CraftItemEvent then
            CraftItemEvent:FireServer(recipe.Name)
        end
    end)
end

local function updateResourceDisplay()
    local wood = player:GetAttribute("Wood") or 0
    local stone = player:GetAttribute("Stone") or 0
    woodLabel.Text = "Bois: " .. wood
    stoneLabel.Text = "Pierre: " .. stone
end

player:GetAttributeChangedSignal("Wood"):Connect(updateResourceDisplay)
player:GetAttributeChangedSignal("Stone"):Connect(updateResourceDisplay)
updateResourceDisplay()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.C then
        craftFrame.Visible = not craftFrame.Visible
    elseif input.KeyCode == Enum.KeyCode.E then
        local character = player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local rootPos = character.HumanoidRootPart.Position
        
        local nearestPart = nil
        local shortestDist = 12 -- Distance max de récolte
        
        -- On cherche uniquement parmi les éléments tagués "Collectable"
        for _, obj in ipairs(CollectionService:GetTagged("Collectable")) do
            if obj:IsA("BasePart") then
                local dist = (obj.Position - rootPos).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    nearestPart = obj
                end
            end
        end
        
        if nearestPart and CollectResourceEvent then
            CollectResourceEvent:FireServer(nearestPart)
        end
    end
end)
