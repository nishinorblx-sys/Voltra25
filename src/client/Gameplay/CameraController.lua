--!strict
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage.VTR.Shared.GameplayConfig)
local Controller={};Controller.__index=Controller
function Controller.new(model:Model,ball:BasePart?)local root=model:WaitForChild("HumanoidRootPart")::BasePart;local look=root.CFrame.LookVector;return setmetatable({Camera=workspace.CurrentCamera,Model=model,Root=root,Ball=ball,Yaw=math.atan2(-look.X,-look.Z),Pitch=math.rad(12),BallAware=true},Controller)end
function Controller:Start()self.Camera.CameraType=Enum.CameraType.Scriptable;self.Camera.FieldOfView=Config.Camera.FieldOfView;UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter;UserInputService.MouseIconEnabled=false end
function Controller:Forward():Vector3 return Vector3.new(-math.sin(self.Yaw),0,-math.cos(self.Yaw)).Unit end
function Controller:Right():Vector3 local f=self:Forward();return Vector3.new(-f.Z,0,f.X)end
function Controller:Aim():Vector3 local f=self:Forward();if self.BallAware and self.Ball then local toward=self.Ball.Position-self.Root.Position;if toward.Magnitude>18 then return(f*.72+Vector3.new(toward.X,0,toward.Z).Unit*.28).Unit end end;return f end
function Controller:Update(dt:number,sprinting:boolean)if not self.Root.Parent then return end;local delta=UserInputService:GetMouseDelta();self.Yaw-=delta.X*Config.Camera.Sensitivity;self.Pitch=math.clamp(self.Pitch-delta.Y*Config.Camera.Sensitivity,Config.Camera.MinPitch,Config.Camera.MaxPitch);local focus=self.Root.Position+Vector3.new(0,Config.Camera.FocusHeight,0);if self.BallAware and self.Ball then focus=focus:Lerp(self.Ball.Position,.12)end;local rotation=CFrame.fromOrientation(self.Pitch,self.Yaw,0);local desired=focus-rotation.LookVector*Config.Camera.Distance+Vector3.new(0,Config.Camera.Height-Config.Camera.FocusHeight,0);local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={self.Model};local hit=workspace:Raycast(focus,desired-focus,params);if hit then desired=hit.Position+hit.Normal*.5 end;self.Camera.CFrame=self.Camera.CFrame:Lerp(CFrame.lookAt(desired,focus),1-math.exp(-14*dt));local fov=sprinting and Config.Camera.SprintFieldOfView or Config.Camera.FieldOfView;self.Camera.FieldOfView+=(fov-self.Camera.FieldOfView)*(1-math.exp(-7*dt))end
function Controller:Destroy()self.Camera.CameraType=Enum.CameraType.Custom;UserInputService.MouseBehavior=Enum.MouseBehavior.Default;UserInputService.MouseIconEnabled=true end
return Controller
