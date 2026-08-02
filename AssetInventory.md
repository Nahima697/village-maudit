local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Prefabs = ReplicatedStorage:FindFirstChild("Prefabs")

if not Prefabs then
    warn("Dossier Prefabs introuvable dans ReplicatedStorage")
    return
end

local categories = {
    Buildings = {},
    Walls = {},
    Roofs = {},
    Floors = {},
    Doors = {},
    Trees = {},
    Rocks = {},
    Decorations = {},
    Props = {},
    Other = {}
}

local function classifyAsset(assetName)
    local lower = assetName:lower()
    
    if lower:match("building") or lower:match("house") or lower:match("structure") then
        return "Buildings"
    elseif lower:match("wall") or lower:match("fence") then
        return "Walls"
    elseif lower:match("roof") or lower:match("ceiling") then
        return "Roofs"
    elseif lower:match("floor") or lower:match("ground") or lower:match("tile") then
        return "Floors"
    elseif lower:match("door") or lower:match("gate") then
        return "Doors"
    elseif lower:match("tree") or lower:match("plant") or lower:match("bush") then
        return "Trees"
    elseif lower:match("rock") or lower:match("stone") or lower:match("boulder") then
        return "Rocks"
    elseif lower:match("decor") or lower:match("decoration") then
        return "Decorations"
    elseif lower:match("prop") then
        return "Props"
    else
        return "Other"
    end
end

local function scanFolder(folder, depth)
    depth = depth or 0
    local indent = string.rep("  ", depth)
    
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Folder") then
            print(indent .. "📁 " .. child.Name)
            scanFolder(child, depth + 1)
        elseif child:IsA("Model") or child:IsA("Part") or child:IsA("MeshPart") then
            local category = classifyAsset(child.Name)
            table.insert(categories[category], {
                name = child.Name,
                type = child.ClassName,
                path = child:GetFullName()
            })
            print(indent .. "📦 " .. child.Name .. " (" .. child.ClassName .. ") -> " .. category)
        end
    end
end

print("🔍 Scan des assets dans Prefabs...")
scanFolder(Prefabs)

print("\n📊 Résumé par catégorie:")
for category, assets in pairs(categories) do
    print(category .. ": " .. #assets .. " asset(s)")
end