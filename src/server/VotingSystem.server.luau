local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local GameManager = require(script.Parent.GameManager)

local RemoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
if not RemoteEventsFolder then
    RemoteEventsFolder = Instance.new("Folder")
    RemoteEventsFolder.Name = "RemoteEvents"
    RemoteEventsFolder.Parent = ReplicatedStorage
end

local VoteEvent = RemoteEventsFolder:FindFirstChild("VoteEvent")
if not VoteEvent then
    VoteEvent = Instance.new("RemoteEvent")
    VoteEvent.Name = "VoteEvent"
    VoteEvent.Parent = RemoteEventsFolder
end

local VoteResultEvent = RemoteEventsFolder:FindFirstChild("VoteResultEvent")
if not VoteResultEvent then
    VoteResultEvent = Instance.new("RemoteEvent")
    VoteResultEvent.Name = "VoteResultEvent"
    VoteResultEvent.Parent = RemoteEventsFolder
end

local VotingSystem = {}
VotingSystem.Votes = {}
VotingSystem.IsVotingActive = false

function VotingSystem.IsPlayerAlive(player)
    if not player or not player:IsDescendantOf(Players) then
        return false
    end
    local playerData = GameManager.GetPlayerData(player)
    if playerData and playerData.IsAlive then
        return true
    end
    return false
end

function VotingSystem.StartVoting(duration)
    VotingSystem.Votes = {}
    VotingSystem.IsVotingActive = true
    
    task.delay(duration, function()
        VotingSystem.EndVoting()
    end)
end

function VotingSystem.ProcessVote(voter, target)
    if not VotingSystem.IsVotingActive then
        return false
    end
    
    if not VotingSystem.IsPlayerAlive(voter) then
        return false
    end
    
    if not VotingSystem.IsPlayerAlive(target) then
        return false
    end
    
    if voter == target then
        return false
    end
    
    VotingSystem.Votes[voter.UserId] = target.UserId
    return true
end

function VotingSystem.EndVoting()
    VotingSystem.IsVotingActive = false
    
    local voteCount = {}
    
    for voterUserId, targetUserId in pairs(VotingSystem.Votes) do
        local targetPlayer = Players:GetPlayerByUserId(targetUserId)
        if targetPlayer and VotingSystem.IsPlayerAlive(targetPlayer) then
            voteCount[targetUserId] = (voteCount[targetUserId] or 0) + 1
        end
    end
    
    local maxVotes = 0
    local eliminatedUserId = nil
    local tieCount = 0
    
    for userId, votes in pairs(voteCount) do
        if votes > maxVotes then
            maxVotes = votes
            eliminatedUserId = userId
            tieCount = 1
        elseif votes == maxVotes then
            tieCount = tieCount + 1
        end
    end
    
    local eliminatedPlayer = nil
    
    if maxVotes > 0 and tieCount == 1 then
        eliminatedPlayer = Players:GetPlayerByUserId(eliminatedUserId)
        if eliminatedPlayer and VotingSystem.IsPlayerAlive(eliminatedPlayer) then
            GameManager.RemovePlayer(eliminatedPlayer)
        else
            eliminatedPlayer = nil
        end
    end
    
    VoteResultEvent:FireAllClients(eliminatedPlayer)
    
    VotingSystem.Votes = {}
end

VoteEvent.OnServerEvent:Connect(function(voter, target)
    if typeof(target) ~= "Instance" or not target:IsA("Player") then
        return
    end
    
    VotingSystem.ProcessVote(voter, target)
end)

return VotingSystem