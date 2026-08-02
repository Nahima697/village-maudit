local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prefabs = ReplicatedStorage:FindFirstChild("Prefabs")

local function spawnAsset(prefab, x, z, parentFolder)
    if not prefab then return nil end
    local clone = prefab:Clone()

    if clone:IsA("Model") then
        for _, desc in ipairs(clone:GetDescendants()) do
            if desc:IsA("BasePart") then
                desc.Anchored = true
                desc.CanCollide = true
            end
        end
    elseif clone:IsA("BasePart") then
        clone.Anchored = true
        clone.CanCollide = true
    end

    if clone:IsA("BasePart") then
        clone.CFrame = CFrame.new(x, 0, z)
    elseif clone:IsA("Model") then
        clone:PivotTo(CFrame.new(x, 0, z))
    end

    clone.Parent = parentFolder
    return clone
end

local function generateWorld()
    local villageFolder = Instance.new("Folder")
    villageFolder.Name = "Village"
    villageFolder.Parent = workspace

    local buildings = Prefabs:FindFirstChild("Buildings")
    if buildings then
        local count = 6
        local radius = 35
        for i = 1, count do
            local angle = (i - 1) * (math.pi * 2 / count)
            local x = math.cos(angle) * radius
            local z = math.sin(angle) * radius
            local prefabList = buildings:GetChildren()
            if #prefabList > 0 then
                local prefab = prefabList[math.random(1, #prefabList)]
                spawnAsset(prefab, x, z, villageFolder)
            end
        end
    end

    local firePrefab = Prefabs:FindFirstChild("CentralFire")
    if firePrefab then
        spawnAsset(firePrefab, 0, 0, workspace)
    end

    local treesFolder = Instance.new("Folder")
    treesFolder.Name = "Trees"
    treesFolder.Parent = workspace

    local trees = Prefabs:FindFirstChild("Trees")
    if trees then
        for i = 1, 100 do
            local angle = math.random() * math.pi * 2
            local dist = 45 + math.random() * 75
            local x = math.cos(angle) * dist
            local z = math.sin(angle) * dist
            local prefabList = trees:GetChildren()
            if #prefabList > 0 then
                local prefab = prefabList[math.random(1, #prefabList)]
                spawnAsset(prefab, x, z, treesFolder)
            end
        end
    end
end

generateWorld()
