--[[
    CraftingClient.client.luau
    Interface client moderne, propre et compatible avec l'API Roblox.
]]

print("[CraftingClient] 1. Script demarre")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mouse = player:GetMouse()

print("[CraftingClient] 2. Avant WaitForChild RemoteEvents")
local RemoteEventsFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
print("[CraftingClient] 3. RemoteEvents trouve")
local CollectResourceEvent = RemoteEventsFolder:WaitForChild("CollectResourceEvent")
local CraftItemEvent = RemoteEventsFolder:WaitForChild("CraftItemEvent")
local CraftSuccessEvent = RemoteEventsFolder:WaitForChild("CraftSuccessEvent")
print("[CraftingClient] 4. Tous les RemoteEvents trouves")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
print("[CraftingClient] 5. GameConfig charge")

local CRAFT_RECIPES = {
    {Name = "Barricade", Wood = 5, Stone = 2, Description = "Barricade temporaire (60s)"},
    {Name = "Fortification", Wood = 10, Stone = 5, Description = "Répare une porte (+100 HP)"},
    {Name = "Lance", Wood = 3, Stone = 1, Description = "Arme de mêlée (25 dégâts)"},
    {Name = "Torche", Wood = 2, Stone = 1, Description = "Éclairage et vitesse +"},
    {Name = "Piege", Wood = 4, Stone = 2, Description = "Piège au sol ralentissant les ennemis"}
}

-- Création du son de succès de craft (une seule fois au démarrage)
local craftSuccessSound = Instance.new("Sound")
craftSuccessSound.Name = "CraftSuccessSound"
craftSuccessSound.SoundId = GameConfig.SOUNDS.CraftSuccess
craftSuccessSound.Volume = 0.6
craftSuccessSound.Parent = SoundService

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CraftingUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui
print("[CraftingClient] 6. UI creee")

local resourceFrame = Instance.new("Frame")
resourceFrame.Name = "ResourceFrame"
resourceFrame.Size = UDim2.new(0, 180, 0, 64)
resourceFrame.Position = UDim2.new(0, 20, 0, 85)
resourceFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
resourceFrame.BackgroundTransparency = 0.15
resourceFrame.BorderSizePixel = 0
resourceFrame.Parent = screenGui

local resCorner = Instance.new("UICorner")
resCorner.CornerRadius = UDim.new(0, 8)
resCorner.Parent = resourceFrame

local woodLabel = Instance.new("TextLabel")
woodLabel.Name = "WoodLabel"
woodLabel.Size = UDim2.new(1, -16, 0.5, 0)
woodLabel.Position = UDim2.new(0, 12, 0, 4)
woodLabel.BackgroundTransparency = 1
woodLabel.Text = "🪵 Bois : 0"
woodLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
woodLabel.TextXAlignment = Enum.TextXAlignment.Left
woodLabel.Font = Enum.Font.GothamBold
woodLabel.TextSize = 15
woodLabel.Parent = resourceFrame

local stoneLabel = Instance.new("TextLabel")
stoneLabel.Name = "StoneLabel"
stoneLabel.Size = UDim2.new(1, -16, 0.5, 0)
stoneLabel.Position = UDim2.new(0, 12, 0.5, 0)
stoneLabel.BackgroundTransparency = 1
stoneLabel.Text = "🪨 Pierre : 0"
stoneLabel.TextColor3 = Color3.fromRGB(235, 235, 245)
stoneLabel.TextXAlignment = Enum.TextXAlignment.Left
stoneLabel.Font = Enum.Font.GothamBold
stoneLabel.TextSize = 15
stoneLabel.Parent = resourceFrame

local craftFrame = Instance.new("Frame")
craftFrame.Name = "CraftFrame"
craftFrame.Size = UDim2.new(0, 400, 0, 500)
craftFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
craftFrame.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
craftFrame.BackgroundTransparency = 0.05
craftFrame.BorderSizePixel = 0
craftFrame.Visible = false
craftFrame.Parent = screenGui

local craftCorner = Instance.new("UICorner")
craftCorner.CornerRadius = UDim.new(0, 12)
craftCorner.Parent = craftFrame

local craftTitle = Instance.new("TextLabel")
craftTitle.Name = "Title"
craftTitle.Size = UDim2.new(1, 0, 0, 60)
craftTitle.BackgroundTransparency = 1
craftTitle.Text = "🛠️ Menu de Craft"
craftTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
craftTitle.Font = Enum.Font.GothamBold
craftTitle.TextSize = 22
craftTitle.Parent = craftFrame

local craftList = Instance.new("ScrollingFrame")
craftList.Name = "CraftList"
craftList.Size = UDim2.new(1, -30, 1, -80)
craftList.Position = UDim2.new(0, 15, 0, 65)
craftList.BackgroundTransparency = 1
craftList.BorderSizePixel = 0
craftList.ScrollBarThickness = 6
craftList.Parent = craftFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 10)
listLayout.Parent = craftList

for _, recipe in ipairs(CRAFT_RECIPES) do
    local itemFrame = Instance.new("Frame")
    itemFrame.Name = recipe.Name
    itemFrame.Size = UDim2.new(1, -6, 0, 76)
    itemFrame.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
    itemFrame.BorderSizePixel = 0
    itemFrame.Parent = craftList
    
    local itemCorner = Instance.new("UICorner")
    itemCorner.CornerRadius = UDim.new(0, 8)
    itemCorner.Parent = itemFrame
    
    local itemName = Instance.new("TextLabel")
    itemName.Size = UDim2.new(1, -120, 0, 24)
    itemName.Position = UDim2.new(0, 14, 0, 10)
    itemName.BackgroundTransparency = 1
    itemName.Text = recipe.Name
    itemName.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemName.Font = Enum.Font.GothamBold
    itemName.TextSize = 16
    itemName.TextXAlignment = Enum.TextXAlignment.Left
    itemName.Parent = itemFrame
    
    local itemCost = Instance.new("TextLabel")
    itemCost.Size = UDim2.new(1, -120, 0, 18)
    itemCost.Position = UDim2.new(0, 14, 0, 32)
    itemCost.BackgroundTransparency = 1
    itemCost.Text = string.format("Coût : %d Bois | %d Pierre", recipe.Wood, recipe.Stone)
    itemCost.TextColor3 = Color3.fromRGB(160, 160, 175)
    itemCost.Font = Enum.Font.Gotham
    itemCost.TextSize = 13
    itemCost.TextXAlignment = Enum.TextXAlignment.Left
    itemCost.Parent = itemFrame
    
    local itemDesc = Instance.new("TextLabel")
    itemDesc.Size = UDim2.new(1, -120, 0, 18)
    itemDesc.Position = UDim2.new(0, 14, 0, 50)
    itemDesc.BackgroundTransparency = 1
    itemDesc.Text = recipe.Description
    itemDesc.TextColor3 = Color3.fromRGB(110, 110, 125)
    itemDesc.Font = Enum.Font.Gotham
    itemDesc.TextSize = 12
    itemDesc.TextXAlignment = Enum.TextXAlignment.Left
    itemDesc.Parent = itemFrame
    
    local craftButton = Instance.new("TextButton")
    craftButton.Name = "CraftButton"
    craftButton.Size = UDim2.new(0, 100, 0, 34)
    craftButton.Position = UDim2.new(1, -112, 0.5, -17)
    craftButton.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    craftButton.BorderSizePixel = 0
    craftButton.Text = "Fabriquer"
    craftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    craftButton.Font = Enum.Font.GothamBold
    craftButton.TextSize = 13
    craftButton.Parent = itemFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = craftButton
    
    craftButton.MouseButton1Click:Connect(function()
        CraftItemEvent:FireServer(recipe.Name)
    end)
end

local function updateResourceDisplay()
    local wood = player:GetAttribute("Wood") or 0
    local stone = player:GetAttribute("Stone") or 0
    
    woodLabel.Text = "🪵 Bois : " .. wood
    stoneLabel.Text = "🪨 Pierre : " .. stone
    
    for _, itemFrame in ipairs(craftList:GetChildren()) do
        if itemFrame:IsA("Frame") then
            local craftButton = itemFrame:FindFirstChild("CraftButton")
            if craftButton then
                local recipeName = itemFrame.Name
                local recipe = nil
                for _, r in ipairs(CRAFT_RECIPES) do
                    if r.Name == recipeName then
                        recipe = r
                        break
                    end
                end
                
                if recipe then
                    local canCraft = wood >= recipe.Wood and stone >= recipe.Stone
                    craftButton.BackgroundColor3 = canCraft and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(50, 50, 60)
                    craftButton.TextColor3 = canCraft and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 130)
                end
            end
        end
    end
end

player:GetAttributeChangedSignal("Wood"):Connect(updateResourceDisplay)
player:GetAttributeChangedSignal("Stone"):Connect(updateResourceDisplay)
updateResourceDisplay()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.C then
        craftFrame.Visible = not craftFrame.Visible
    end
end)

mouse.Button1Down:Connect(function()
    local target = mouse.Target
    if target and target:IsA("BasePart") then
        CollectResourceEvent:FireServer(target)
    end
end)

CraftSuccessEvent.OnClientEvent:Connect(function(success, message)
    if success then
        -- Jouer le son de succès
        craftSuccessSound:Play()
        
        -- Fermer le menu de craft après un court délai
        task.wait(0.5)
        craftFrame.Visible = false
    end
end)