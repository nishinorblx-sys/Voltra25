--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local GuiService=game:GetService("GuiService")
local Theme=require(ReplicatedStorage.VTR.Shared.Theme)
local Panel=require(script.Parent.Panel)
local Button=require(script.Parent.Button)
local Modal={}

local function text(parent:Instance,value:string,position:UDim2,size:UDim2,textSize:number,color:Color3,font:Enum.Font)
	local label=Instance.new("TextLabel");label.BackgroundTransparency=1;label.Position=position;label.Size=size;label.Text=value;label.TextColor3=color;label.TextSize=textSize;label.Font=font;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextWrapped=true;label.ZIndex=42;label.Parent=parent;return label
end

function Modal.open(parent:Instance,props:any)
	local overlay=Instance.new("Frame");overlay.Name="ModalOverlay";overlay.BackgroundColor3=Theme.Colors.Black;overlay.BackgroundTransparency=.18;overlay.BorderSizePixel=0;overlay.Size=UDim2.fromScale(1,1);overlay.ZIndex=120;overlay.Active=true;overlay.Selectable=false;overlay.Parent=parent
	local shield=Instance.new("TextButton");shield.Name="ModalInputShield";shield.BackgroundTransparency=1;shield.BorderSizePixel=0;shield.Size=UDim2.fromScale(1,1);shield.Text="";shield.AutoButtonColor=false;shield.Selectable=false;shield.Modal=true;shield.Active=true;shield.ZIndex=120;shield.Parent=overlay
	local hasFields=props.Fields and #props.Fields>0
	local panel=Panel.new({Name="Modal",Size=UDim2.fromOffset(500,hasFields and 350 or 270),ClipsDescendants=true});panel.AnchorPoint=Vector2.new(.5,.5);panel.Position=UDim2.fromScale(.5,.5);panel.ZIndex=121;panel.Parent=overlay
	text(panel,props.Kicker or "VTR 25",UDim2.fromOffset(24,18),UDim2.new(1,-48,0,20),8,Theme.Colors.White,Theme.Fonts.Strong).ZIndex=122
	text(panel,props.Title or "CONFIRM ACTION",UDim2.fromOffset(24,48),UDim2.new(1,-48,0,36),22,Theme.Colors.White,Theme.Fonts.Display).ZIndex=122
	text(panel,props.Meta or "",UDim2.fromOffset(24,84),UDim2.new(1,-48,0,20),8,Theme.Colors.White,Theme.Fonts.Strong).ZIndex=122
	text(panel,props.Description or "Continue with this action?",UDim2.fromOffset(24,108),UDim2.new(1,-48,0,hasFields and 42 or 70),10,Theme.Colors.Muted,Theme.Fonts.Body).ZIndex=122
	local fieldValues={}
	if hasFields then
		for index,field in props.Fields do
			local input=Instance.new("TextBox");input.Name=field.Key;input.BackgroundColor3=Theme.Colors.Gunmetal;input.BorderSizePixel=0;input.Position=UDim2.fromOffset(24+(index-1)*224,168);input.Size=UDim2.fromOffset(210,46);input.PlaceholderText=field.Placeholder;input.Text=field.Default or "";input.TextColor3=Theme.Colors.White;input.PlaceholderColor3=Theme.Colors.Muted;input.TextSize=11;input.Font=Theme.Fonts.Strong;input.ClearTextOnFocus=false;input.ZIndex=122;input.Parent=panel
			local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,Theme.Radius.Medium);corner.Parent=input;fieldValues[field.Key]=input
		end
	end
	local buttonY=hasFields and 278 or 200
	local function close(cancelled:boolean?) overlay:Destroy();GuiService.SelectedObject=nil;if cancelled and props.OnCancel then props.OnCancel() end end
	local cancel=Button.new({Text=props.CancelLabel or "BACK",Variant="Secondary",OnActivated=function()close(true)end});cancel.Position=UDim2.fromOffset(24,buttonY);cancel.ZIndex=122;cancel.Parent=panel
	local confirm=Button.new({Text=props.ConfirmLabel or "CONFIRM",Variant="Primary",OnActivated=function()
		close(false);if props.OnConfirm then local values={};for key,input in fieldValues do values[key]=input.Text end;props.OnConfirm(values) end
	end});confirm.Position=UDim2.new(1,-200,0,buttonY);confirm.ZIndex=122;confirm.Parent=panel
	cancel.NextSelectionRight=confirm;confirm.NextSelectionLeft=cancel
	task.defer(function() GuiService.SelectedObject=nil end)
	return overlay
end
return Modal
