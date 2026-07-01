from pathlib import Path
import re

prompt_path = Path("src/client/Components/AIMatchModePrompt.lua")
prompt_path.parent.mkdir(parents=True, exist_ok=True)
prompt_path.write_text('''--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Prompt = {}

local function corner(parent: Instance, radius: number)
\tlocal item = Instance.new("UICorner")
\titem.CornerRadius = UDim.new(0, radius)
\titem.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number, thickness: number?)
\tlocal item = Instance.new("UIStroke")
\titem.Color = color
\titem.Transparency = transparency
\titem.Thickness = thickness or 1
\titem.Parent = parent
end

local function label(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3): TextLabel
\tlocal item = Instance.new("TextLabel")
\titem.BackgroundTransparency = 1
\titem.Position = position
\titem.Size = size
\titem.Text = text
\titem.TextColor3 = color
\titem.TextSize = textSize
\titem.Font = Theme.Fonts.Display
\titem.TextXAlignment = Enum.TextXAlignment.Center
\titem.TextYAlignment = Enum.TextYAlignment.Center
\titem.ZIndex = 303
\titem.Parent = parent
\treturn item
end

local function button(parent: Instance, name: string, title: string, subtitle: string, position: UDim2, color: Color3): TextButton
\tlocal item = Instance.new("TextButton")
\titem.Name = name
\titem.Position = position
\titem.Size = UDim2.fromScale(.42, .34)
\titem.BackgroundColor3 = Color3.fromHex("070A06")
\titem.BackgroundTransparency = .04
\titem.BorderSizePixel = 0
\titem.AutoButtonColor = true
\titem.Text = ""
\titem.ZIndex = 304
\titem.Parent = parent
\tcorner(item, 12)
\tstroke(item, color, .12, 2)
\tlocal glow = Instance.new("Frame")
\tglow.Position = UDim2.fromScale(.06, .1)
\tglow.Size = UDim2.fromScale(.88, .22)
\tglow.BackgroundColor3 = color
\tglow.BackgroundTransparency = .06
\tglow.BorderSizePixel = 0
\tglow.ZIndex = 305
\tglow.Parent = item
\tcorner(glow, 8)
\tlabel(item, title, UDim2.fromScale(.06, .33), UDim2.fromScale(.88, .24), 20, Theme.Colors.White)
\tlocal sub = label(item, subtitle, UDim2.fromScale(.08, .6), UDim2.fromScale(.84, .24), 10, Color3.fromHex("C9D0C3"))
\tsub.Font = Theme.Fonts.Strong
\treturn item
end

function Prompt.Choose(): string?
\tlocal playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
\tlocal old = playerGui:FindFirstChild("VTRAIMatchModePrompt")
\tif old then old:Destroy() end
\tlocal done = Instance.new("BindableEvent")
\tlocal gui = Instance.new("ScreenGui")
\tgui.Name = "VTRAIMatchModePrompt"
\tgui.IgnoreGuiInset = true
\tgui.ResetOnSpawn = false
\tgui.DisplayOrder = 380
\tgui.Parent = playerGui
\tlocal overlay = Instance.new("CanvasGroup")
\toverlay.Size = UDim2.fromScale(1, 1)
\toverlay.BackgroundColor3 = Color3.fromHex("030503")
\toverlay.BackgroundTransparency = .08
\toverlay.GroupTransparency = 1
\toverlay.Active = true
\toverlay.ZIndex = 300
\toverlay.Parent = gui
\tlocal panel = Instance.new("CanvasGroup")
\tpanel.AnchorPoint = Vector2.new(.5, .5)
\tpanel.Position = UDim2.fromScale(.5, .52)
\tpanel.Size = UDim2.fromOffset(620, 330)
\tpanel.BackgroundColor3 = Color3.fromHex("081008")
\tpanel.BackgroundTransparency = .02
\tpanel.BorderSizePixel = 0
\tpanel.GroupTransparency = 1
\tpanel.ZIndex = 302
\tpanel.Parent = overlay
\tcorner(panel, 18)
\tstroke(panel, Theme.Colors.Electric, .18, 2)
\tlocal scale = Instance.new("UIScale")
\tscale.Scale = .86
\tscale.Parent = panel
\tlabel(panel, "AI CAMPAIGN MATCH", UDim2.fromScale(.12, .08), UDim2.fromScale(.76, .08), 12, Theme.Colors.Electric)
\tlabel(panel, "CHOOSE HOW TO PLAY", UDim2.fromScale(.08, .16), UDim2.fromScale(.84, .15), 31, Theme.Colors.White)
\tlocal manual = button(panel, "ManualPlay", "MANUALLY PLAY", "Control your squad on the pitch", UDim2.fromScale(.06, .43), Theme.Colors.Electric)
\tlocal manage = button(panel, "ManageMatch", "MANAGE MATCH", "AI plays while you manage tactics", UDim2.fromScale(.52, .43), Color3.fromHex("D9D9D9"))
\tlocal cancel = Instance.new("TextButton")
\tcancel.Name = "Cancel"
\tcancel.AnchorPoint = Vector2.new(.5, 1)
\tcancel.Position = UDim2.fromScale(.5, .96)
\tcancel.Size = UDim2.fromOffset(180, 30)
\tcancel.BackgroundColor3 = Color3.fromHex("111611")
\tcancel.BackgroundTransparency = .12
\tcancel.BorderSizePixel = 0
\tcancel.Text = "CANCEL"
\tcancel.TextColor3 = Color3.fromHex("F5F7F2")
\tcancel.TextSize = 10
\tcancel.Font = Theme.Fonts.Strong
\tcancel.ZIndex = 305
\tcancel.Parent = panel
\tcorner(cancel, 8)
\tstroke(cancel, Color3.fromHex("F5F7F2"), .62)
\tlocal settled = false
\tlocal function choose(value: string?)
\t\tif settled then return end
\t\tsettled = true
\t\tTweenService:Create(panel, TweenInfo.new(.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1, Position = UDim2.fromScale(.5, .56)}):Play()
\t\tTweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 1}):Play()
\t\ttask.delay(.2, function()
\t\t\tif gui.Parent then gui:Destroy() end
\t\t\tdone:Fire(value)
\t\t\tdone:Destroy()
\t\tend)
\tend
\tmanual.Activated:Connect(function() choose("Manual") end)
\tmanage.Activated:Connect(function() choose("Manage") end)
\tcancel.Activated:Connect(function() choose(nil) end)
\tTweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 0}):Play()
\tTweenService:Create(panel, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {GroupTransparency = 0, Position = UDim2.fromScale(.5, .5)}):Play()
\tTweenService:Create(scale, TweenInfo.new(.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
\treturn done.Event:Wait()
end

return Prompt
''', encoding="utf-8", newline="\n")

teleport_path = Path("src/client/Components/VoltraMatchTeleport.lua")
teleport_path.write_text('''--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.VTR.Shared.Theme)

local Teleport = {}

function Teleport.Run(title: string, callback: () -> any): any
\tlocal playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
\tlocal old = playerGui:FindFirstChild("VTRMatchTeleport")
\tif old then old:Destroy() end
\tlocal gui = Instance.new("ScreenGui")
\tgui.Name = "VTRMatchTeleport"
\tgui.IgnoreGuiInset = true
\tgui.ResetOnSpawn = false
\tgui.DisplayOrder = 390
\tgui.Parent = playerGui
\tlocal overlay = Instance.new("CanvasGroup")
\toverlay.Size = UDim2.fromScale(1, 1)
\toverlay.BackgroundColor3 = Color3.fromHex("020402")
\toverlay.GroupTransparency = 1
\toverlay.ZIndex = 390
\toverlay.Parent = gui
\tlocal text = Instance.new("TextLabel")
\ttext.BackgroundTransparency = 1
\ttext.AnchorPoint = Vector2.new(.5, .5)
\ttext.Position = UDim2.fromScale(.5, .47)
\ttext.Size = UDim2.fromScale(.8, .1)
\ttext.Text = string.upper(title)
\ttext.TextColor3 = Theme.Colors.White
\ttext.TextSize = 34
\ttext.Font = Theme.Fonts.Display
\ttext.ZIndex = 392
\ttext.Parent = overlay
\tlocal sub = Instance.new("TextLabel")
\tsub.BackgroundTransparency = 1
\tsub.AnchorPoint = Vector2.new(.5, .5)
\tsub.Position = UDim2.fromScale(.5, .56)
\tsub.Size = UDim2.fromScale(.8, .04)
\tsub.Text = "TELEPORTING TO VOLTRA MATCH"
\tsub.TextColor3 = Theme.Colors.Electric
\tsub.TextSize = 11
\tsub.Font = Theme.Fonts.Strong
\tsub.ZIndex = 392
\tsub.Parent = overlay
\tlocal bar = Instance.new("Frame")
\tbar.AnchorPoint = Vector2.new(.5, .5)
\tbar.Position = UDim2.fromScale(.5, .62)
\tbar.Size = UDim2.fromScale(.38, .008)
\tbar.BackgroundColor3 = Color3.fromHex("111711")
\tbar.BorderSizePixel = 0
\tbar.ZIndex = 392
\tbar.Parent = overlay
\tlocal fill = Instance.new("Frame")
\tfill.Size = UDim2.fromScale(0, 1)
\tfill.BackgroundColor3 = Theme.Colors.Electric
\tfill.BorderSizePixel = 0
\tfill.ZIndex = 393
\tfill.Parent = bar
\tTweenService:Create(overlay, TweenInfo.new(.18), {GroupTransparency = 0}):Play()
\tTweenService:Create(fill, TweenInfo.new(.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
\ttask.wait(.28)
\tlocal result = callback()
\ttask.wait(.28)
\tTweenService:Create(overlay, TweenInfo.new(.22), {GroupTransparency = 1}):Play()
\ttask.delay(.24, function()
\t\tif gui.Parent then gui:Destroy() end
\tend)
\treturn result
end

return Teleport
''', encoding="utf-8", newline="\n")

service_path = Path("src/client/Services/MatchSetupService.lua")
service = service_path.read_text(encoding="utf-8")

if "AIMatchModePrompt" not in service:
    service = service.replace(
        'local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)',
        'local NetworkConfig=require(ReplicatedStorage.VTR.Shared.NetworkConfig)\nlocal AIMatchModePrompt=require(script:FindFirstAncestor("VTRClient").Components.AIMatchModePrompt)\nlocal VoltraMatchTeleport=require(script:FindFirstAncestor("VTRClient").Components.VoltraMatchTeleport)',
        1
    )

if "local function isCampaignSetup" not in service:
    service = service.replace(
        'local function request(action:string,payload:any?):any local ok,response=pcall(function()return remote:InvokeServer(action,payload or{})end);if not ok or type(response)~="table"then return{Success=false,Message="Match setup service unavailable."}end;return response end',
        '''local function request(action:string,payload:any?):any local ok,response=pcall(function()return remote:InvokeServer(action,payload or{})end);if not ok or type(response)~="table"then return{Success=false,Message="Match setup service unavailable."}end;return response end
local function responseData(response:any):any
\tif type(response)~="table"then return nil end
\treturn response.Data or response.Setup and response or response
end
local function isCampaignSetup():boolean
\tlocal response=request("GetConfig")
\tlocal data=responseData(response)
\tlocal setup=data and data.Setup or data
\treturn type(setup)=="table" and type(setup.CampaignTeamId)=="string" and setup.CampaignTeamId~=""
end
local function startCampaignChoice():any
\tlocal choice=AIMatchModePrompt.Choose()
\tif choice=="Manual"then
\t\treturn VoltraMatchTeleport.Run("Manual Campaign Match",function()
\t\t\treturn request("StartMatch",{AIMatchTeleport=true,CampaignMode="Manual"})
\t\tend)
\telseif choice=="Manage"then
\t\treturn VoltraMatchTeleport.Run("Manage Campaign Match",function()
\t\t\treturn request("WatchMatch",{AIMatchTeleport=true,CampaignMode="Manage"})
\t\tend)
\tend
\treturn{Success=false,Message="Match cancelled."}
end''',
        1
    )

service = re.sub(
    r'function Service:StartMatch\(\):any return request\("StartMatch"\)end',
    '''function Service:StartMatch():any
\tif isCampaignSetup()then
\t\treturn startCampaignChoice()
\tend
\treturn VoltraMatchTeleport.Run("Loading Match",function()
\t\treturn request("StartMatch",{AIMatchTeleport=true,CampaignMode="Manual"})
\tend)
end''',
    service,
    count=1
)

service = re.sub(
    r'function Service:WatchMatch\(\):any return request\("WatchMatch"\)end',
    '''function Service:WatchMatch():any
\tif isCampaignSetup()then
\t\treturn startCampaignChoice()
\tend
\treturn VoltraMatchTeleport.Run("Loading AI Match",function()
\t\treturn request("WatchMatch",{AIMatchTeleport=true,CampaignMode="Manage"})
\tend)
end''',
    service,
    count=1
)

service_path.write_text(service, encoding="utf-8", newline="\n")

server_path = Path("src/server/Services/MatchSetupService.lua")
server = server_path.read_text(encoding="utf-8")

server = server.replace(
    'local success,text,data=self.Runtime:StartMatch(player,setup);if not success then return false,text,nil end',
    'local success,text,data=self.Runtime:StartMatch(player,setup);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manual"end',
    1
)

server = server.replace(
    'local success,text,data=self.Runtime:StartMatch(player,watchSetup,nil,nil,homeRoster,nil);if not success then return false,text,nil end',
    'local success,text,data=self.Runtime:StartMatch(player,watchSetup,nil,nil,homeRoster,nil);if not success then return false,text,nil end;if data then data.AIMatchTeleport=true;data.MatchLaunchType="Manage"end',
    1
)

server_path.write_text(server, encoding="utf-8", newline="\n")

print("added AI Campaign match mode prompt and match teleport transition")