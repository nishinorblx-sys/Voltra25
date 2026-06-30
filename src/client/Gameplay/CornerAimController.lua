--!strict
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local Preview=require(script.Parent.CornerTrajectoryPreview)
local Controller={};Controller.__index=Controller

function Controller.new(data:any,remote:RemoteEvent,hud:any)
	local self=setmetatable({Data=data,Remote=remote,HUD=hud,Mouse=Players.LocalPlayer:GetMouse(),Preview=Preview.new(),Connections={},Charging=false,Started=0,Power=0,Active=true},Controller)
	local defaultLocal=Vector3.new(0,.15,data.GoalSign*(data.PitchLength*.5-16));self.Target=data.PitchCFrame:PointToWorldSpace(defaultLocal)
	local gui=Instance.new("BillboardGui");gui.Name="VTRCornerTrainer";gui.Adornee=data.Ball;gui.Size=UDim2.fromOffset(210,58);gui.StudsOffsetWorldSpace=Vector3.new(0,3.4,0);gui.AlwaysOnTop=true;gui.Parent=Players.LocalPlayer.PlayerGui
	local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.Text="LMB  CROSS    RMB  SHORT\nSHIFT  DRIVEN    SPACE  LOB";text.TextColor3=Color3.fromRGB(240,244,238);text.TextStrokeTransparency=.55;text.Font=Enum.Font.GothamBold;text.TextSize=11;text.Parent=gui;self.Trainer=gui
	table.insert(self.Connections,UserInputService.InputBegan:Connect(function(input,_processed)if not self.Active then return end;if input.UserInputType==Enum.UserInputType.MouseButton1 then self.Charging=true;self.Started=os.clock()elseif input.UserInputType==Enum.UserInputType.MouseButton2 then self:_release("Short",.22)end end))
	table.insert(self.Connections,UserInputService.InputEnded:Connect(function(input)if not self.Active then return end;if input.UserInputType==Enum.UserInputType.MouseButton1 and self.Charging then local delivery=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)and"Driven"or UserInputService:IsKeyDown(Enum.KeyCode.Space)and"Lob"or"Cross";self:_release(delivery,self.Power)end end))
	return self
end
function Controller:_mouseTarget():Vector3
	local camera=workspace.CurrentCamera;local frame=self.Data.PitchCFrame;local mouseLocation=UserInputService:GetMouseLocation()
	-- ScreenPointToRay consumes the same screen coordinates returned by
	-- GetMouseLocation, including Roblox's top-bar inset. Mixing this with
	-- ViewportPointToRay caused the visible corner cursor offset.
	local ray=camera:ScreenPointToRay(mouseLocation.X,mouseLocation.Y);local origin=frame:PointToObjectSpace(ray.Origin);local direction=frame:VectorToObjectSpace(ray.Direction);local t=math.abs(direction.Y)>.0001 and(.15-origin.Y)/direction.Y or 200
	-- Do not pin the target to the camera origin when the cursor reaches the
	-- horizon. Continue the ray forward so the complete visible box is aimable.
	if t < 0 then t=2000 end
	local hit=origin+direction*t
	hit=Vector3.new(hit.X,.15,hit.Z)
	return frame:PointToWorldSpace(hit)
end
function Controller:_release(delivery:string,power:number)
	if not self.Active then return end;self.Active=false;self.Charging=false;self.Power=power;self.Remote:FireServer({Type="CornerKick",Delivery=delivery,Power=power,Target=self.Target})
end
function Controller:Update()
	if not self.Active then return end;self.Target=self:_mouseTarget();if self.Charging then self.Power=math.clamp((os.clock()-self.Started)/(Config.Ball.MaxChargeTime/3),0,1)else self.Power=0 end
	local delivery=UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)and"Driven"or UserInputService:IsKeyDown(Enum.KeyCode.Space)and"Lob"or"Cross";local origin=self.Data.Ball.Position;local up=self.Data.PitchCFrame.UpVector;self.Preview:Update(origin,self.Target,delivery,self.Power,up);self.HUD:SetCharge(self.Power,self.Charging and"Pass"or"")
end
function Controller:GetTarget():Vector3 return self.Target end
function Controller:Destroy()self.Active=false;for _,connection in self.Connections do connection:Disconnect()end;if self.Preview then self.Preview:Destroy()end;if self.Trainer then self.Trainer:Destroy()end;self.HUD:SetCharge(0,"")end
return Controller
