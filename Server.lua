-- Get references to necessary services
local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- Require the 'Trove' garbage collecting utility and get other required objects
local Trove = require(ReplicatedStorage.Trove)
local gameUtility = ReplicatedStorage.gameUtility
local difficultyValue = ReplicatedStorage.Difficulty

-- Get references to related folders in workspace
local Tiles = workspace:WaitForChild('Tiles')
local Kill = workspace:WaitForChild('Kill')
local End = workspace:WaitForChild('End')
local Borders = workspace:WaitForChild('Borders')

-- Initialize the current level and create a new Trove
local currentLevel = 1
local newTrove = Trove.new()

-- Function to get random tiles and set up the game
function getRandomTiles()
	newTrove:Clean()

	-- Enable collision for all border parts around the player
	for _, Part in next, Borders:GetChildren() do
		Part.CanCollide = true
	end

	-- Reset chosen attribute and enable collision for all tile parts
	for _, Part in next, Tiles:GetDescendants() do
		if not Part:IsA('BasePart') then
			continue
		end

		Part:SetAttribute('Chosen', nil)
		Part.CanCollide = true
	end

	-- Randomly choose one part from each tile
	for Index = 1, #Tiles:GetChildren() do
		local tileModel = Tiles:FindFirstChild(Index)

		if not tileModel then
			continue
		end

		local chosenPart = tileModel:GetChildren()[Random.new():NextInteger(1, #tileModel:GetChildren())]

		if not chosenPart then
			continue
		end

		chosenPart:SetAttribute('Chosen', true)
	end

	-- Set up the tiles for the game
	setUpTiles()
end

-- Function to get player and humanoid from a hit part
function getFromPart(hitPart)
	local Humanoid = hitPart and hitPart.Parent and (hitPart.Parent:FindFirstChild('Humanoid') or hitPart.Parent.Parent:FindFirstChild('Humanoid'))

	if not Humanoid then
		return
	end

	local Player = Players:GetPlayerFromCharacter(Humanoid.Parent)

	if not Player then
		return
	end

	return {Player, Humanoid}
end

-- Function to handle the end of a game level
function levelEndHandle(hitPart)
	if End:GetAttribute('Debounce') then
		return
	end

	local Player = (hitPart:IsA('Player') and hitPart) or getFromPart(hitPart)[1]

	if not Player then
		return
	end

	End:SetAttribute('Debounce', true)

	if currentLevel == 3 then
		local leaderstats = Player:WaitForChild('leaderstats')
		local Wins = leaderstats.Wins

		Wins.Value += 1

		gameUtility:FireClient(Player, 'Won')
	end

	-- Update the current level and difficulty value
	currentLevel = ((not currentLevel or currentLevel <= 0 or currentLevel >= 3) and 1) or currentLevel + 1
	difficultyValue.Value = currentLevel

	-- Destroy and recreate the player's character
	local Character = Player.Character
	Player.Character = nil
	Character:Destroy()
	Player:LoadCharacter()

	-- Set the End brick color based on the current level
	End.BrickColor = (currentLevel <= 1 and BrickColor.new('Lime green')) or
		(currentLevel == 2 and BrickColor.new('New Yeller')) or
		(BrickColor.new('Really red'))

	-- Get random tiles and inform the client to begin
	getRandomTiles()
	gameUtility:FireClient(Player, 'Begin')

	-- Delay to prevent immediate re-triggering of the End zone
	task.delay(1, function()
		End:SetAttribute('Debounce', false)
	end)
end

-- Function to handle player death and end the level
function killHandle(hitPart)
	local Info = getFromPart(hitPart)

	if not Info then
		return
	end

	local Player = Info[1]
	local Humanoid = Info[2]

	currentLevel = nil
	task.delay(1, levelEndHandle, Player)
	Humanoid.Health = 0
end

-- Function to set up event handlers for tile interaction
function setUpTiles()
	newTrove = Trove.new()

	for _, Part in next, Tiles:GetDescendants() do
		if not Part:IsA('BasePart') or Part:GetAttribute('Chosen') then
			continue
		end

		newTrove:Connect(Part.Touched, function(hitPart)
			local Info = getFromPart(hitPart)

			if not Info then
				return
			end

			local Player = Info[1]
			local Humanoid = Info[2]

			Humanoid.Health = 0
			Part.CanCollide = false
		end)
	end
end

-- Function to start the tile game for a player
function startTileGame(Player)
	for Index = 1, #Tiles:GetChildren() do
		local tileModel = Tiles:FindFirstChild(Index)

		if not tileModel then
			continue
		end

		for _, Chosen in next, tileModel:GetChildren() do
			if not Chosen:GetAttribute('Chosen') then
				continue
			end

			-- Create a highlight effect and sound for chosen parts
			local Highlight = Instance.new('Highlight')
			Highlight.Parent = Chosen

			local Sound = workspace.Sound:Clone()
			Sound.Parent = Chosen
			Sound:Play()

			-- Delay and destroy the sound effect
			task.delay(Sound.TimeLength, function()
				Sound:Destroy()
			end)

			-- Delay and destroy the highlight effect
			task.delay(1/currentLevel, function()
				Highlight:Destroy()
			end)
		end

		-- Delay between tile highlights based on current level
		task.wait(1/currentLevel)
	end

	-- Disable collision for border parts
	for _, Part in next, Borders:GetChildren() do
		Part.CanCollide = false
	end

	-- Inform the client that the game is over
	gameUtility:FireClient(Player, 'Over')
end

-- Function to handle when a player joins the game
function playerAdded(Player : Player)
	-- Create 'leaderstats' for the player
	local leaderstats = Instance.new('Configuration')
	leaderstats.Name = 'leaderstats'

	local Wins = Instance.new('NumberValue', leaderstats)
	Wins.Name = 'Wins'

	leaderstats.Parent = Player

	local function charAdded(Character)
		local Humanoid = Character:WaitForChild('Humanoid')

		Humanoid.Died:Connect(function()
			gameUtility:FireClient(Player, 'Lose')
			currentLevel = nil
			task.delay(1, levelEndHandle, Player)
		end)
	end

	-- Connect characterAdded event
	charAdded(Player.Character or Player.CharacterAdded:Wait())
	Player.CharacterAdded:Connect(charAdded)
end

-- Connect the playerAdded event to the playerAdded function
Players.PlayerAdded:Connect(playerAdded)

-- Call playerAdded for existing players
for _, Player in next, Players:GetPlayers() do
	playerAdded(Player)
end

-- Connect events for the End and Kill zones
End.Touched:Connect(levelEndHandle)
Kill.Touched:Connect(killHandle)

-- Get random tiles and set up the game initially
getRandomTiles()

-- Connect a server event to handle client requests
gameUtility.OnServerEvent:Connect(function(Player, ...)
	local Args = {...}

	if Args[1] == 'Play' then
		-- Start the tile game for the player
		startTileGame(Player)
	elseif Args[1] == 'Over' then
		-- End the current level
		currentLevel = nil
		levelEndHandle(Player)
	end
end)
