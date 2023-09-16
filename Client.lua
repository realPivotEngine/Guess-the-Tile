-- Get references to necessary services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local StarterGui = game:GetService('StarterGui')

-- Get references to objects in the ScreenGui
local gameUtility = ReplicatedStorage.gameUtility
local difficultyValue = ReplicatedStorage.Difficulty
local screenGui = script.Parent
local Difficulty = screenGui.Frame.Difficulty
local Play = screenGui.Play
local Over = screenGui.Over
local Status = screenGui.Status

-- Connect the Play button's click event to start the game
Play.MouseButton1Click:Connect(function()
	gameUtility:FireServer('Play')
	Over.Visible = false
	Play.Visible = false
end)

-- Connect the Over button's click event to signal the game's end
Over.MouseButton1Click:Connect(function()
	gameUtility:FireServer('Over')
	Over.Visible = false
end)

-- Connect to changes in the difficulty value and update the display
difficultyValue:GetPropertyChangedSignal('Value'):Connect(function()
	Difficulty.Text = (difficultyValue.Value == 1 and 'EASY') or (difficultyValue.Value == 2 and 'MEDIUM') or 'HARD'
	Difficulty.TextColor3 = (Difficulty.Text == 'EASY' and Color3.fromRGB(0, 255, 0)) or
		(Difficulty.Text == 'MEDIUM' and Color3.fromRGB(255, 255, 0)) or
		Color3.fromRGB(255, 0, 0)
end)

-- Connect to client events for game status updates
gameUtility.OnClientEvent:Connect(function(...)
	local Args = {...}

	if Args[1] == 'Begin' then
		Play.Visible = true
	elseif Args[1] == 'Won' or Args[1] == 'Lose' then
		-- Show a status message based on whether the player won or lost
		Status.Text = Args[1] == 'Won' and '🏆 YOU WON! 🏆' or '❌ YOU LOST! ❌'
		Status.Visible = true
		Over.Visible = false

		-- Delay to hide the status message after 2 seconds
		task.delay(2, function()
			Status.Visible = false
		end)
	elseif Args[1] == 'Over' then
		Over.Visible = true
	end
end)

-- Disable the Reset Button callback and ChatActive
repeat
	local success = pcall(function()
		StarterGui:SetCore("ResetButtonCallback", false)
		StarterGui:SetCore('ChatActive', false)
	end)

	task.wait(1)
until success
