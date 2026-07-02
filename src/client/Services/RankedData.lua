--!strict
local Factory = require(script.Parent.MockModeService)
local PackRouletteAlignmentService = require(script.Parent:WaitForChild("PackRouletteAlignmentService"))

return Factory.new({
	Id = "Ranked",
	Kicker = "7-GAME PATH",
	Title = "RANKED RUN",
	Subtitle = "Enter with your current squad. Your seven-game record decides the path reward.",
	Tabs = {
		{
			Id = "Run",
			Label = "TOURNAMENT",
			Description = "Current seven-game path",
			Cards = {
				{ Title = "7-GAME PATH", Subtitle = "0 / 7 GAMES", Meta = "FINAL RECORD DECIDES REWARD", Accent = true, Action = { Label = "ENTER MATCH", Operation = "RankedQueue", Loading = true } },
				{ Title = "NEXT OPPONENT", Subtitle = "AI TOURNAMENT SQUAD", Meta = "ONLINE 1V1 SLOT READY FOR LATER", Action = { Label = "PREVIEW", Operation = "Toast", Message = "Opponent preview will show squad, tactics and star player." } },
			},
		},
		{
			Id = "Rewards",
			Label = "REWARDS",
			Description = "Reward improves with your seven-game record",
			Cards = {
				{ Title = "1+ WINS", Subtitle = "BRONZE PACK", Meta = "PATH REWARD", Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "3+ WINS", Subtitle = "GOLD PACK", Meta = "PATH REWARD", Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "5+ WINS", Subtitle = "ELITE PACK", Meta = "PATH REWARD", Accent = true, Action = { Label = "VIEW PATH", TargetTab = "Run" } },
				{ Title = "7-0 RECORD", Subtitle = "MYTHIC PACK", Meta = "PERFECT PATH", Accent = true, Action = { Label = "CLAIM WHEN COMPLETE", Operation = "Toast", Message = "Finish all 7 path games to claim the record-based reward." } },
			},
		},
		{
			Id = "History",
			Label = "HISTORY",
			Description = "Completed tournament runs",
			Cards = {},
		},
	},
})

local function vtrFindRouletteGuiObjects(root)
	local scroller
	local container

	if typeof(root) ~= "Instance" then
		return nil, nil
	end

	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("ScrollingFrame") then
			local n = string.lower(obj.Name)
			if string.find(n, "roulette") or string.find(n, "spin") or string.find(n, "reward") or string.find(n, "pack") then
				scroller = obj
				break
			end
			scroller = scroller or obj
		end
	end

	if scroller then
		for _, obj in ipairs(scroller:GetDescendants()) do
			if obj:IsA("GuiObject") then
				local hasPack = obj:GetAttribute("PackId") or obj:GetAttribute("PackName")
				local n = string.lower(obj.Name)
				if hasPack or string.find(n, "pack") or string.find(n, "card") or string.find(n, "item") then
					container = obj.Parent
					break
				end
			end
		end
	end

	return scroller, container
end

local function vtrForceRouletteWinningCenter(root, winningPack, winningIndex)
	if not winningPack then
		return
	end

	task.defer(function()
		local scroller, container = vtrFindRouletteGuiObjects(root)
		if scroller and container then
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
			task.wait(0.05)
			PackRouletteAlignmentService.ForceWinningCenter(scroller, container, winningPack, winningIndex)
		end
	end)
end
