--[[
	VotingClient.client.luau
	Client-side voting interface for Village Maudit
	Displays voting UI during VOTE_PHASE and handles vote submission
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Références SharedData et RemoteEvents
local sharedData = ReplicatedStorage:WaitForChild("SharedData")
local remoteEvents = ReplicatedStorage:WaitForChild("RemoteEvents")
local voteEvent = remoteEvents:WaitForChild("VoteEvent")
local voteResultEvent = remoteEvents:WaitForChild("VoteResultEvent")

-- UI Container
local votingGui: ScreenGui = nil
local votingFrame: Frame = nil
local resultLabel: TextLabel = nil
local hasVoted = false

-- Son de vote
local voteCastSound = Instance.new("Sound")
voteCastSound.Name = "VoteCastSound"
voteCastSound.SoundId = GameConfig.SOUNDS.VoteCast
voteCastSound.Volume = 0.6
voteCastSound.Parent = SoundService

--[[
	Crée l'interface de vote
]]
local function createVotingUI()
	if votingGui then
		votingGui:Destroy()
	end

	votingGui = Instance.new("ScreenGui")
	votingGui.Name = "VotingUI"
	votingGui.ResetOnSpawn = false
	votingGui.DisplayOrder = 10
	votingGui.Parent = playerGui

	-- Frame principal
	votingFrame = Instance.new("Frame")
	votingFrame.Name = "VotingFrame"
	votingFrame.Size = UDim2.new(0, 400, 0, 500)
	votingFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
	votingFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	votingFrame.BorderSizePixel = 2
	votingFrame.BorderColor3 = Color3.fromRGB(200, 0, 0)
	votingFrame.Parent = votingGui

	-- Titre
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 50)
	titleLabel.BackgroundColor3 = Color3.fromRGB(60, 0, 0)
	titleLabel.BorderSizePixel = 0
	titleLabel.Text = "PHASE DE VOTE"
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = 24
	titleLabel.Font = Enum.Font.SourceSansBold
	titleLabel.Parent = votingFrame

	-- ScrollingFrame pour la liste des joueurs
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "PlayerList"
	scrollFrame.Size = UDim2.new(1, -20, 1, -70)
	scrollFrame.Position = UDim2.new(0, 10, 0, 60)
	scrollFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	scrollFrame.BorderSizePixel = 1
	scrollFrame.BorderColor3 = Color3.fromRGB(100, 100, 100)
	scrollFrame.ScrollBarThickness = 8
	scrollFrame.Parent = votingFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.Name
	listLayout.Padding = UDim.new(0, 5)
	listLayout.Parent = scrollFrame

	-- Label pour afficher le résultat
	resultLabel = Instance.new("TextLabel")
	resultLabel.Name = "ResultLabel"
	resultLabel.Size = UDim2.new(1, 0, 0, 60)
	resultLabel.Position = UDim2.new(0, 0, 1, -60)
	resultLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 0)
	resultLabel.BorderSizePixel = 0
	resultLabel.Text = ""
	resultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultLabel.TextSize = 20
	resultLabel.Font = Enum.Font.SourceSansBold
	resultLabel.Visible = false
	resultLabel.Parent = votingFrame

	return scrollFrame
end

--[[
	Peuple la liste des joueurs vivants (sauf le joueur local)
]]
local function populatePlayerList(scrollFrame: ScrollingFrame)
	-- Nettoie les boutons existants
	for _, child in ipairs(scrollFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	local buttonHeight = 50
	local yOffset = 0

	for _, player in ipairs(Players:GetPlayers()) do
		-- Exclusion : joueur local ou joueur mort
		if player == localPlayer then
			continue
		end
		if player:GetAttribute("IsAlive") ~= true then
			continue
		end

		local button = Instance.new("TextButton")
		button.Name = player.Name
		button.Size = UDim2.new(1, -10, 0, buttonHeight)
		button.Position = UDim2.new(0, 5, 0, yOffset)
		button.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
		button.BorderSizePixel = 1
		button.BorderColor3 = Color3.fromRGB(150, 150, 150)
		button.Text = player.Name
		button.TextColor3 = Color3.fromRGB(255, 255, 255)
		button.TextSize = 18
		button.Font = Enum.Font.SourceSans
		button.AutoButtonColor = true
		button.Parent = scrollFrame

		-- Gestion du clic
		button.Activated:Connect(function()
			if hasVoted then
				return
			end

			-- Joue le son de vote
			voteCastSound:Play()

			-- Envoie le vote au serveur (instance Player, pas UserId)
			voteEvent:FireServer(player)

			-- Désactive tous les boutons
			hasVoted = true
			for _, btn in ipairs(scrollFrame:GetChildren()) do
				if btn:IsA("TextButton") then
					btn.Active = false
					btn.AutoButtonColor = false
					btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
					btn.TextColor3 = Color3.fromRGB(150, 150, 150)
				end
			end

			-- Feedback visuel sur le bouton cliqué
			button.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
			button.Text = button.Text .. " ✓"
		end)

		yOffset = yOffset + buttonHeight + 5
	end

	-- Ajuste la taille du canvas
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

--[[
	Affiche le résultat du vote
]]
local function showVoteResult(eliminatedPlayer: Player?)
	if not votingGui or not resultLabel then
		return
	end

	resultLabel.Visible = true

	if eliminatedPlayer then
		resultLabel.Text = eliminatedPlayer.Name .. " a été éliminé !"
		resultLabel.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
	else
		resultLabel.Text = "Personne n'a été éliminé."
		resultLabel.BackgroundColor3 = Color3.fromRGB(80, 80, 0)
	end

	-- Ferme l'UI après 5 secondes
	task.wait(5)
	if votingGui then
		votingGui:Destroy()
		votingGui = nil
		votingFrame = nil
		resultLabel = nil
	end
end

--[[
	Ferme l'UI de vote
]]
local function closeVotingUI()
	if votingGui then
		votingGui:Destroy()
		votingGui = nil
		votingFrame = nil
		resultLabel = nil
	end
	hasVoted = false
end

--[[
	Gère l'ouverture/fermeture de l'UI selon la phase
]]
local function handlePhaseChange()
	local currentPhase = sharedData:GetAttribute("CurrentPhase")

	if currentPhase == "VOTE_PHASE" then
		-- Ouvre l'UI de vote
		hasVoted = false
		local scrollFrame = createVotingUI()
		populatePlayerList(scrollFrame)
	else
		-- Ferme l'UI si elle est ouverte
		closeVotingUI()
	end
end

--[[
	Réception du résultat du vote
]]
voteResultEvent.OnClientEvent:Connect(function(eliminatedPlayer: Player?)
	showVoteResult(eliminatedPlayer)
end)

--[[
	Écoute les changements de phase
]]
sharedData:GetAttributeChangedSignal("CurrentPhase"):Connect(handlePhaseChange)

-- Initialisation au démarrage (si déjà en VOTE_PHASE)
handlePhaseChange()

print("[VotingClient] Initialisé pour", localPlayer.Name)