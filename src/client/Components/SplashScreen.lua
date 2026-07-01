--!strict
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local SplashScreen={}
function SplashScreen.new(parent:Instance):CanvasGroup
	local group=Instance.new("CanvasGroup");group.Name="LaunchSplash";group.BackgroundColor3=Theme.Colors.Black;group.BorderSizePixel=0;group.Size=UDim2.fromScale(1,1);group.ZIndex=120;group.Parent=parent
	local mark=Instance.new("TextLabel");mark.AnchorPoint=Vector2.new(.5,.5);mark.BackgroundColor3=Theme.Colors.White;mark.BorderSizePixel=0;mark.Position=UDim2.fromScale(.5,.45);mark.Size=UDim2.fromOffset(92,92);mark.Text="V";mark.TextColor3=Theme.Colors.Black;mark.TextSize=58;mark.Font=Theme.Fonts.Display;mark.ZIndex=121;mark.Parent=group
	local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,15);corner.Parent=mark
	local title=Instance.new("TextLabel");title.AnchorPoint=Vector2.new(.5,0);title.BackgroundTransparency=1;title.Position=UDim2.fromScale(.5,.54);title.Size=UDim2.fromOffset(500,55);title.Text="VTR 25";title.TextColor3=Theme.Colors.White;title.TextSize=32;title.Font=Theme.Fonts.Display;title.ZIndex=121;title.Parent=group
	local sub=title:Clone();sub.Position=UDim2.fromScale(.5,.595);sub.Size=UDim2.fromOffset(500,25);sub.Text="VOLTRA FOOTBALL";sub.TextColor3=Theme.Colors.White;sub.TextSize=9;sub.Font=Theme.Fonts.Strong;sub.Parent=group
	local scale=Instance.new("UIScale");scale.Scale=.86;scale.Parent=mark;TweenService:Create(scale,TweenInfo.new(.7,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
	return group
end
function SplashScreen.complete(group:CanvasGroup) local tween=TweenService:Create(group,TweenInfo.new(.25),{GroupTransparency=1});tween.Completed:Once(function() group:Destroy() end);tween:Play() end
return SplashScreen
