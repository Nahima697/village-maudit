local refugeDoor = Instance.new("Part")
refugeDoor.Name = "RefugeDoor"
refugeDoor.Size = Vector3.new(5, 8, 1)
refugeDoor.Position = Vector3.new(0, 4, -15)
refugeDoor.Anchored = true
refugeDoor.BrickColor = BrickColor.new("Brown")
refugeDoor.Parent = workspace

local safeZone = Instance.new("Part")
safeZone.Name = "SafeZone"
safeZone.Size = Vector3.new(15, 1, 15)
safeZone.Position = Vector3.new(0, 0.5, 15)
safeZone.Anchored = true
safeZone.CanCollide = false
safeZone.Transparency = 0.5
safeZone.BrickColor = BrickColor.new("Green")
safeZone.Parent = workspace