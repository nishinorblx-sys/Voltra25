--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)
local PageBase = require(script.Parent.PageBase)
local Panel = require(script.Parent.Parent.Components.Panel)
local Button = require(script.Parent.Parent.Components.Button)
local LaunchService = require(script.Parent.Parent.Services.LaunchService)

local AILabPage = {}

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, textSize: number, color: Color3?, font: Enum.Font?): TextLabel
	local label = PageBase.text(parent, value, position, size, textSize, color or Theme.Colors.White, font or Theme.Fonts.Body)
	label.TextWrapped = true
	return label
end

local function toast(context: any, message: string, kind: string?)
	if context.Toast then context.Toast({Title = "AI LAB", Message = message, Kind = kind or "Info"}) end
end

local function sortedDrafts(map: any): {any}
	local result = {}
	for _, item in pairs(type(map) == "table" and map or {}) do table.insert(result, item) end
	table.sort(result, function(a, b) return tostring(a.Name or a.PlaystyleId) < tostring(b.Name or b.PlaystyleId) end)
	return result
end

local function builtInRows(state: any): {any}
	local result = {}
	for _, id in ipairs(state.BuiltInOrder or {}) do
		local item = state.BuiltIns and state.BuiltIns[id]
		if item then table.insert(result, item) end
	end
	return result
end

local function activeTactics(localState: any): any
	local draft = localState.Draft
	local sliders = {}
	for key, value in pairs(localState.Values) do sliders[key] = value end
	return {PresetId = draft and draft.BasePresetId or "balanced_control", Sliders = sliders, Custom = true}
end

function AILabPage.new(context: any): CanvasGroup
	local group, scroll = PageBase.new("AILab", 1380)
	local state = {Loaded = false, Allowed = false, Side = "Home", Draft = nil, Values = {}, Name = "Lab Playstyle", ExportText = ""}

	local function clear()
		for _, child in ipairs(scroll:GetChildren()) do
			if not child:IsA("UIPadding") then child:Destroy() end
		end
	end

	local function applyDraftValues(draft: any?)
		state.Draft = draft
		state.Name = tostring(draft and draft.Name or state.Name or "Lab Playstyle")
		state.Values = {}
		local tactics = draft and draft.Tactics or nil
		for _, setting in ipairs(state.Metadata and state.Metadata.HighImpactSettings or {}) do
			local value = tactics and tactics.Sliders and tactics.Sliders[setting.Id] or setting.Default
			state.Values[setting.Id] = tonumber(value) or tonumber(setting.Default) or 50
		end
	end

	local function request(action: string, payload: any?): any
		local response = LaunchService:Request(action, payload or {})
		if not response.Success then toast(context, response.Message or "Request failed.", "Error") end
		return response
	end

	local render: () -> ()

	local function refresh()
		local response = request("GetAILabState", {})
		if response.Success then
			state.Server = response.Data
			state.Metadata = response.Data.Metadata
			state.Allowed = response.Data.DeveloperAllowed == true
			state.Loaded = true
			local drafts = sortedDrafts(response.Data.Drafts)
			applyDraftValues(drafts[1] or builtInRows(response.Data)[1])
		end
		render()
	end

	local function actionButton(parent: Instance, label: string, x: number, y: number, width: number, callback: () -> ())
		local button = Button.new({Text = label, Variant = "Primary", Size = UDim2.fromOffset(width, 42), OnActivated = callback})
		button.Position = UDim2.fromOffset(x, y)
		button.Parent = parent
		return button
	end

	local function secondaryButton(parent: Instance, label: string, x: number, y: number, width: number, callback: () -> ())
		local button = Button.new({Text = label, Variant = "Secondary", Size = UDim2.fromOffset(width, 38), OnActivated = callback})
		button.Position = UDim2.fromOffset(x, y)
		button.Parent = parent
		return button
	end

	local function saveDraft()
		local payload = {DraftId = state.Draft and state.Draft.Status == "Draft" and state.Draft.PlaystyleId or nil, Playstyle = {Name = state.Name, BasePresetId = state.Draft and state.Draft.BasePresetId or "balanced_control", Tactics = activeTactics(state)}}
		local response = request("SaveAILabDraft", payload)
		if response.Success then
			state.Server = response.Data.State
			applyDraftValues(response.Data.Draft)
			toast(context, "Draft saved.", "Reward")
			render()
		end
	end

	render = function()
		clear()
		PageBase.heading(scroll, "STUDIO ONLY", "AI LAB", "Author reusable Home and Away playstyles against a real paused AI-vs-AI match.")
		if not state.Loaded then
			text(scroll, "Loading AI LAB...", UDim2.fromOffset(0, 104), UDim2.new(1, 0, 0, 32), 14, Theme.Colors.Silver, Theme.Fonts.Strong)
			task.defer(refresh)
			return
		end
		if not state.Allowed then
			local denied = Panel.new({Name = "Denied", Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 0, 130)})
			denied.Parent = scroll
			text(denied, "DEVELOPER ACCESS REQUIRED", UDim2.fromOffset(22, 18), UDim2.new(1, -44, 0, 28), 16, Theme.Colors.Warning, Theme.Fonts.Display)
			text(denied, "Open this in Studio or a private developer server with an authorized developer account.", UDim2.fromOffset(22, 52), UDim2.new(1, -44, 0, 44), 11, Theme.Colors.Silver, Theme.Fonts.Body)
			return
		end

		local command = Panel.new({Name = "Command", Position = UDim2.fromOffset(0, 104), Size = UDim2.new(1, 0, 0, 156)})
		command.Parent = scroll
		text(command, "MATCH CONTROL", UDim2.fromOffset(22, 14), UDim2.fromOffset(240, 24), 12, Theme.Colors.Electric, Theme.Fonts.Strong)
		text(command, "Start a real AI-vs-AI lab match, pause it for overhead inspection, then apply drafts live to Home or Away.", UDim2.fromOffset(22, 40), UDim2.new(1, -44, 0, 34), 10, Theme.Colors.Silver, Theme.Fonts.Body)
		actionButton(command, "START PAUSED AI MATCH", 22, 88, 230, function()
			local response = request("StartAILabSession", {})
			if response.Success then toast(context, response.Message or "AI LAB match loaded.", "Reward") end
		end)
		secondaryButton(command, state.Side == "Home" and "SIDE: HOME" or "SIDE: AWAY", 268, 90, 142, function()
			state.Side = state.Side == "Home" and "Away" or "Home"
			render()
		end)
		actionButton(command, "APPLY LIVE", 426, 88, 136, function()
			saveDraft()
			local response = request("ApplyAILabDraft", {Side = state.Side, DraftId = state.Draft and state.Draft.PlaystyleId})
			if response.Success then toast(context, "Applied to " .. state.Side .. ".", "Reward") end
		end)
		actionButton(command, "SAVE DRAFT", 578, 88, 138, saveDraft)
		actionButton(command, "PUBLISH VERSION", 732, 88, 168, function()
			saveDraft()
			local response = request("PublishAILabPlaystyle", {DraftId = state.Draft and state.Draft.PlaystyleId})
			if response.Success then
				state.Server = response.Data.State
				toast(context, "Published immutable version " .. tostring(response.Data.Playstyle.Version) .. ".", "Reward")
				render()
			end
		end)

		local controls = Panel.new({Name = "Controls", Position = UDim2.fromOffset(0, 278), Size = UDim2.new(.66, -8, 0, 860)})
		controls.Parent = scroll
		text(controls, "10 GAMEPLAY DRIVERS", UDim2.fromOffset(22, 16), UDim2.new(1, -44, 0, 26), 15, Theme.Colors.White, Theme.Fonts.Display)
		text(controls, "These controls feed Voltra tactics, AI decisions, run selection, shape, pressing, and loose-ball urgency.", UDim2.fromOffset(22, 45), UDim2.new(1, -44, 0, 32), 10, Theme.Colors.Silver, Theme.Fonts.Body)
		local y = 92
		for _, setting in ipairs(state.Metadata.HighImpactSettings or {}) do
			local row = Instance.new("Frame")
			row.BackgroundColor3 = Theme.Colors.Black
			row.BackgroundTransparency = .72
			row.BorderSizePixel = 0
			row.Position = UDim2.fromOffset(22, y)
			row.Size = UDim2.new(1, -44, 0, 68)
			row.Parent = controls
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, Theme.Radius.Small)
			corner.Parent = row
			local current = math.clamp(tonumber(state.Values[setting.Id]) or tonumber(setting.Default) or 50, tonumber(setting.Min) or 0, tonumber(setting.Max) or 100)
			text(row, setting.Label, UDim2.fromOffset(14, 8), UDim2.new(.46, -14, 0, 22), 11, Theme.Colors.White, Theme.Fonts.Strong)
			text(row, setting.LowLabel .. " / " .. setting.HighLabel, UDim2.fromOffset(14, 31), UDim2.new(.46, -14, 0, 22), 8, Theme.Colors.Muted, Theme.Fonts.Body)
			secondaryButton(row, "-10", 0, 0, 58, function()
				state.Values[setting.Id] = math.max(tonumber(setting.Min) or 0, current - 10)
				render()
			end).Position = UDim2.new(1, -224, .5, -18)
			text(row, tostring(math.floor(current + .5)) .. tostring(setting.Unit or "%"), UDim2.new(1, -154, .5, -13), UDim2.fromOffset(74, 26), 14, Theme.Colors.Electric, Theme.Fonts.Display).TextXAlignment = Enum.TextXAlignment.Center
			secondaryButton(row, "+10", 0, 0, 58, function()
				state.Values[setting.Id] = math.min(tonumber(setting.Max) or 100, current + 10)
				render()
			end).Position = UDim2.new(1, -66, .5, -18)
			y += 76
		end

		local library = Panel.new({Name = "Library", Position = UDim2.new(.66, 8, 0, 278), Size = UDim2.new(.34, -8, 0, 860)})
		library.Parent = scroll
		text(library, "PLAYSTYLE LIBRARY", UDim2.fromOffset(18, 16), UDim2.new(1, -36, 0, 26), 15, Theme.Colors.White, Theme.Fonts.Display)
		text(library, "Drafts and built-ins can be assigned to either side.", UDim2.fromOffset(18, 45), UDim2.new(1, -36, 0, 32), 9, Theme.Colors.Silver, Theme.Fonts.Body)
		local list = Instance.new("ScrollingFrame")
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.Position = UDim2.fromOffset(18, 86)
		list.Size = UDim2.new(1, -36, 0, 548)
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.ScrollBarThickness = 3
		list.ScrollBarImageColor3 = Theme.Colors.Electric
		list.Parent = library
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 8)
		layout.Parent = list
		for _, item in ipairs(sortedDrafts(state.Server.Drafts)) do
			secondaryButton(list, "DRAFT  " .. tostring(item.Name), 0, 0, 260, function()
				applyDraftValues(item)
				render()
			end)
		end
		for _, item in ipairs(builtInRows(state.Server)) do
			secondaryButton(list, "BASE  " .. tostring(item.Name), 0, 0, 260, function()
				applyDraftValues(item)
				render()
			end)
		end
		actionButton(library, "ASSIGN TO " .. string.upper(state.Side), 18, 654, 180, function()
			local response = request("AssignAILabPlaystyle", {Side = state.Side, PlaystyleId = state.Draft and state.Draft.PlaystyleId, Version = state.Draft and state.Draft.Version})
			if response.Success then
				state.Server = response.Data.State
				toast(context, "Assigned to " .. state.Side .. ".", "Reward")
				render()
			end
		end)
		secondaryButton(library, "EXPORT", 212, 656, 94, function()
			local response = request("ExportAILabPlaystyle", {PlaystyleId = state.Draft and state.Draft.PlaystyleId, DraftId = state.Draft and state.Draft.PlaystyleId, Version = state.Draft and state.Draft.Version})
			if response.Success then
				state.ExportText = response.Data.Json
				render()
			end
		end)
		text(library, "EXPORT JSON", UDim2.fromOffset(18, 714), UDim2.new(1, -36, 0, 18), 9, Theme.Colors.Electric, Theme.Fonts.Strong)
		local box = Instance.new("TextBox")
		box.BackgroundColor3 = Theme.Colors.Black
		box.BackgroundTransparency = .55
		box.BorderSizePixel = 0
		box.Position = UDim2.fromOffset(18, 738)
		box.Size = UDim2.new(1, -36, 0, 94)
		box.Text = state.ExportText
		box.PlaceholderText = "Paste export JSON here, then import."
		box.TextColor3 = Theme.Colors.White
		box.PlaceholderColor3 = Theme.Colors.Muted
		box.TextSize = 9
		box.Font = Theme.Fonts.Body
		box.TextWrapped = true
		box.ClearTextOnFocus = false
		box.MultiLine = true
		box.Parent = library
		box.FocusLost:Connect(function() state.ExportText = box.Text end)
		secondaryButton(library, "IMPORT", 18, 842, 110, function()
			local response = request("ImportAILabPlaystyle", {Json = state.ExportText})
			if response.Success then
				state.Server = response.Data.State
				applyDraftValues(response.Data.Draft)
				toast(context, "Imported as draft.", "Reward")
				render()
			end
		end)

		local inspector = Panel.new({Name = "Inspector", Position = UDim2.fromOffset(0, 1158), Size = UDim2.new(1, 0, 0, 160)})
		inspector.Parent = scroll
		local home = state.Server.Assignments and state.Server.Assignments.Home
		local away = state.Server.Assignments and state.Server.Assignments.Away
		text(inspector, "INSPECTOR", UDim2.fromOffset(22, 16), UDim2.new(1, -44, 0, 22), 13, Theme.Colors.White, Theme.Fonts.Display)
		text(inspector, "Home: " .. tostring(home and home.Name or "Balanced Control") .. "    Away: " .. tostring(away and away.Name or "Balanced Control") .. "    Revision: " .. tostring(state.Server.Revision or 0), UDim2.fromOffset(22, 48), UDim2.new(1, -44, 0, 26), 11, Theme.Colors.Electric, Theme.Fonts.Strong)
		text(inspector, "Current draft: " .. tostring(state.Draft and state.Draft.Name or "None") .. "    Status: " .. tostring(state.Draft and state.Draft.Status or "Draft") .. "    Version: " .. tostring(state.Draft and state.Draft.Version or 1), UDim2.fromOffset(22, 78), UDim2.new(1, -44, 0, 26), 10, Theme.Colors.Silver, Theme.Fonts.Body)
		text(inspector, "Runtime checks: server access gate, immutable publish versions, live Home/Away resolver, stale-plan clearing, reusable export/import JSON.", UDim2.fromOffset(22, 106), UDim2.new(1, -44, 0, 36), 9, Theme.Colors.Muted, Theme.Fonts.Body)
	end

	task.defer(refresh)
	return group
end

return AILabPage
