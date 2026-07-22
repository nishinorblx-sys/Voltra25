--!strict

local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local NavigationController = {}
NavigationController.__index = NavigationController

local function cleanupPage(page: Instance?)
	if not page then return end
	local bindable = page:FindFirstChild("Cleanup")
	if bindable and bindable:IsA("BindableEvent") then bindable:Fire() end
end

function NavigationController.new(breadcrumb: TextLabel)
	local self = setmetatable({}, NavigationController)
	self.Breadcrumb = breadcrumb
	self.Pages = {}
	self.Items = {}
	self.Current = nil
	self.TransitionId = 0
	return self
end

function NavigationController:RegisterPage(id: string, page: GuiObject)
	local old = self.Pages[id]
	if old and old ~= page then
		cleanupPage(old)
		old:Destroy()
	end
	page.Visible = false
	page.Active = false
	self.Pages[id] = page
end

function NavigationController:RegisterItem(id: string, item: any)
	self.Items[id] = item
end

function NavigationController:HidePage(id: string)
	local page = self.Pages[id]
	if not page then return end
	cleanupPage(page)
	page.Visible=false
	page.Active=false
end

function NavigationController:EnforceCurrent()
	for pageId, page in self.Pages do
		local active = pageId == self.Current
		if not active then
			self:HidePage(pageId)
		else
			page.Visible = true
			page.Active = true
		end
	end
	local currentPage = self.Current and self.Pages[self.Current] or nil
	local parent = currentPage and currentPage.Parent or nil
	if parent then
		local registeredNames:any={}
		for pageId in self.Pages do registeredNames[pageId]=true end
		for _, child in parent:GetChildren() do
			if child:IsA("GuiObject") and registeredNames[child.Name] and child ~= self.Pages[child.Name] then
				cleanupPage(child)
				child:Destroy()
			elseif child:IsA("GuiObject") and child ~= currentPage and child.Name ~= "BackgroundEnergy" then
				child.Visible = false
				child.Active = false
			end
		end
	end
end

function NavigationController:FinalizeSelectionOrder(order: { string })
	for index, id in order do
		local current = self.Items[id]
		local previous = self.Items[order[index - 1] or order[#order]]
		local following = self.Items[order[index + 1] or order[1]]
		if current and previous and following then
			current.Instance.NextSelectionUp = previous.Instance
			current.Instance.NextSelectionDown = following.Instance
		end
	end

	GuiService.AutoSelectGuiEnabled = true
end

function NavigationController:Navigate(id: string)
	if id == self.Current or not self.Pages[id] then return end
	self.TransitionId += 1
	local transitionId = self.TransitionId
	local outgoing = self.Current and self.Pages[self.Current] or nil
	local incoming = self.Pages[id]
	if outgoing then
		local cleanup = outgoing:GetAttribute("VTRPageCleanup")
		if cleanup == true then
			local bindable = outgoing:FindFirstChild("Cleanup")
			if bindable and bindable:IsA("BindableEvent") then bindable:Fire() end
		end
	end
	self.Current = id
	self.Breadcrumb.Text = "VTR X  /  " .. string.upper(id:gsub("(%l)(%u)", "%1 %2"))

	for itemId, item in self.Items do item:SetActive(itemId == id) end
	-- A page is never allowed to survive beneath the destination. Outgoing-page
	-- tweens used to leave Inventory visible when a second navigation happened
	-- before the first transition callback completed.
	for pageId, page in self.Pages do
		if pageId ~= id then
			self:HidePage(pageId)
		end
	end

	incoming.Visible = true
	incoming.Active = true
	GuiService.SelectedObject = nil
	incoming.Position = UDim2.fromOffset(26, 0)
	TweenService:Create(incoming, TweenInfo.new(Theme.Animation.Page, Theme.Animation.EasingStyle, Theme.Animation.EasingDirection), {
		Position = UDim2.fromOffset(0, 0),
	}):Play()
	task.defer(function() if transitionId == self.TransitionId then self:EnforceCurrent() end end)
	for _,delayTime in {0.08,0.18,0.35,0.65,1.05} do
		task.delay(delayTime,function() if transitionId == self.TransitionId then self:EnforceCurrent() end end)
	end

	-- Only the incoming page animates; this keeps transitions premium without
	-- keeping a second interactive page alive underneath it.
end

function NavigationController:SyncPageVisibility()
	for pageId, page in self.Pages do
		local active = pageId == self.Current
		page.Visible = active
		page.Active = active
	end
end

return NavigationController
