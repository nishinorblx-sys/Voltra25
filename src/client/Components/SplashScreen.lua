--!strict
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local SplashScreen={}
local function fadeOut(frame:Frame)
	TweenService:Create(frame,TweenInfo.new(.25),{BackgroundTransparency=1}):Play()
	for _,child in ipairs(frame:GetDescendants())do
		if child:IsA("TextLabel")or child:IsA("TextButton")or child:IsA("TextBox")then TweenService:Create(child,TweenInfo.new(.25),{TextTransparency=1,BackgroundTransparency=1}):Play()
		elseif child:IsA("ImageLabel")or child:IsA("ImageButton")then TweenService:Create(child,TweenInfo.new(.25),{ImageTransparency=1,BackgroundTransparency=1}):Play()
		elseif child:IsA("Frame")then TweenService:Create(child,TweenInfo.new(.25),{BackgroundTransparency=1}):Play()
		elseif child:IsA("UIStroke")then TweenService:Create(child,TweenInfo.new(.25),{Transparency=1}):Play()end
	end
end
function SplashScreen.new(parent:Instance):Frame
	local group=Instance.new("Frame");group.Name="LaunchSplash";group.BackgroundColor3=Theme.Colors.Black;group.BorderSizePixel=0;group.Size=UDim2.fromScale(1,1);group.ZIndex=120;group.Parent=parent
	local mark=Instance.new("TextLabel");mark.AnchorPoint=Vector2.new(.5,.5);mark.BackgroundColor3=Theme.Colors.Electric;mark.BorderSizePixel=0;mark.Position=UDim2.fromScale(.5,.45);mark.Size=UDim2.fromOffset(92,92);mark.Text="V";mark.TextColor3=Theme.Colors.Black;mark.TextSize=58;mark.Font=Theme.Fonts.Display;mark.ZIndex=121;mark.Parent=group
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,15);corner.Parent=mark
	local title=Instance.new("TextLabel");title.AnchorPoint=Vector2.new(.5,0);title.BackgroundTransparency=1;title.Position=UDim2.fromScale(.5,.54);title.Size=UDim2.fromOffset(500,55);title.Text="VTR 25";title.TextColor3=Theme.Colors.White;title.TextSize=32;title.Font=Theme.Fonts.Display;title.ZIndex=121;title.Parent=group
	local sub=title:Clone();sub.Position=UDim2.fromScale(.5,.595);sub.Size=UDim2.fromOffset(500,25);sub.Text="VOLTRA FOOTBALL";sub.TextColor3=Theme.Colors.Electric;sub.TextSize=9;sub.Font=Theme.Fonts.Strong;sub.Parent=group
	local scale=Instance.new("UIScale");scale.Scale=.86;scale.Parent=mark;TweenService:Create(scale,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	return group
end
function SplashScreen.complete(group:Frame) fadeOut(group);task.delay(.26,function()if group.Parent then group:Destroy()end end)end
return SplashScreen
