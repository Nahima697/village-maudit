local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local SharedData = ReplicatedStorage:FindFirstChild("SharedData")
if not SharedData then
	SharedData = Instance.new("Folder")
	SharedData.Name = "SharedData"
	SharedData.Parent = ReplicatedStorage
end

local RemovePlayerFromGame = ReplicatedStorage:FindFirstChild("RemovePlayerFromGame")
if not RemovePlayerFromGame then
	RemovePlayerFromGame = Instance.new("BindableEvent")
	RemovePlayerFromGame.Name = "RemovePlayerFromGame"
	RemovePlayerFromGame.Parent = ReplicatedStorage
end

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

-- Un joueur est vivant si l'attribut "IsAlive" posé par RoleManager est vrai.
-- (Plus de dépendance à un GameManager.GetPlayerData qui n'existe pas.)
function VotingSystem.IsPlayerAlive(player)
	if not player or not player:IsDescendantOf(Players) then
		return false
	end
	return player:GetAttribute("IsAlive") == true
end

function VotingSystem.StartVoting(duration)
	VotingSystem.Votes = {}
	VotingSystem.IsVotingActive = true
	print("[VotingSystem] Vote ouvert pour", duration, "secondes")

	task.delay(duration, function()
		if VotingSystem.IsVotingActive then
			VotingSystem.EndVoting()
		end
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
			-- Notifie GameManager via le BindableEvent partagé, pas un appel de module.
			RemovePlayerFromGame:Fire(eliminatedPlayer)
		else
			eliminatedPlayer = nil
		end
	end

	print("[VotingSystem] Résultat du vote :", eliminatedPlayer and eliminatedPlayer.Name or "personne (égalité ou abstention)")
	VoteResultEvent:FireAllClients(eliminatedPlayer)

	VotingSystem.Votes = {}
end

VoteEvent.OnServerEvent:Connect(function(voter, target)
	if typeof(target) ~= "Instance" or not target:IsA("Player") then
		return
	end

	VotingSystem.ProcessVote(voter, target)
end)

-- Déclenchement automatique : on écoute directement le changement de phase
-- écrit par GameManager.server.luau, exactement comme MonsterSpawner le fait.
SharedData:GetAttributeChangedSignal("CurrentPhase"):Connect(function()
	local currentPhase = SharedData:GetAttribute("CurrentPhase")
	if currentPhase == "VOTE_PHASE" then
		VotingSystem.StartVoting(GameConfig.VOTE_DURATION)
	end
end)

print("[VotingSystem] Prêt, en attente de la phase VOTE_PHASE")
