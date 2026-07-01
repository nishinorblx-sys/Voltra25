from pathlib import Path

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

ball_path = Path("src/server/Gameplay/BallService.lua")
ball = ball_path.read_text(encoding="utf-8")

ball = replace_once(
    ball,
    '''\t\tlocal shotRoot=self:_root(model);local xg=self.Stats:CalculateXG(model,shotRoot and shotRoot.Position or self.Ball.Position,self:_pressure(model),nil)
\t\tself.LastShotXG=xg;self.LastShooter=model;self.Stats:RecordShot(model,targetPoint~=nil,xg)''',
    '''\t\tlocal shotRoot=self:_root(model)
\t\tlocal xg=self.Stats:CalculateXG(model,shotRoot and shotRoot.Position or self.Ball.Position,self:_pressure(model),nil)
\t\tlocal shotChance=math.clamp(tonumber(xg)or 0,.01,.99)
\t\tif shotRoot and targetPoint and Vector3.new(shotRoot.Position.X-targetPoint.X,0,shotRoot.Position.Z-targetPoint.Z).Magnitude<=70 then
\t\t\tshotChance=.95
\t\telseif (tonumber(model:GetAttribute("VTROpenDangerShotChanceUntil"))or 0)>=os.clock() then
\t\t\tshotChance=math.clamp(tonumber(model:GetAttribute("VTROpenDangerShotChance"))or .9,.01,.99)
\t\telseif (tonumber(model:GetAttribute("VTRLongShotChanceUntil"))or 0)>=os.clock() then
\t\t\tshotChance=math.clamp(tonumber(model:GetAttribute("VTRLongShotGoalChance"))or .18,.01,.99)
\t\tend
\t\tmodel:SetAttribute("VTRLastShotScoringChance",shotChance)
\t\tmodel:SetAttribute("VTRLastShotScoringPercent",math.floor(shotChance*100+.5))
\t\tself.LastShotChance=shotChance
\t\tself.LastShotChancePercent=math.floor(shotChance*100+.5)
\t\tself.LastShotXG=xg;self.LastShooter=model;self.Stats:RecordShot(model,targetPoint~=nil,xg)''',
    "shot chance calculation"
)

ball = replace_once(
    ball,
    '''\tself.Remote:FireAllClients({Type = kind, Actor = model, Receiver = receiver, Charge = amount})
\treturn true''',
    '''\tlocal eventPayload={Type=kind,Actor=model,Receiver=receiver,Charge=amount}
\tif kind=="Shot"then
\t\teventPayload.ScoringChance=self.LastShotChance
\t\teventPayload.ScoringChancePercent=self.LastShotChancePercent
\t\teventPayload.ShotXG=self.LastShotXG
\tend
\tself.Remote:FireAllClients(eventPayload)
\treturn true''',
    "shot chance remote payload"
)

ball_path.write_text(ball, encoding="utf-8", newline="\n")

hud_path = Path("src/client/Gameplay/MatchHUDController.lua")
hud = hud_path.read_text(encoding="utf-8")

if "function Controller:ShowShotChance" not in hud:
    hud = replace_once(
        hud,
        '''function Controller:Flash(message: string, duration: number?)
\tself.Banner.Text = string.upper(message)
\tself.Banner.Visible = true
\ttask.delay(duration or 1.5, function()
\t\tif self.Banner and self.Banner.Parent then
\t\t\tself.Banner.Visible = false
\t\tend
\tend)
end''',
        '''function Controller:Flash(message: string, duration: number?)
\tself.Banner.Text = string.upper(message)
\tself.Banner.Visible = true
\ttask.delay(duration or 1.5, function()
\t\tif self.Banner and self.Banner.Parent then
\t\t\tself.Banner.Visible = false
\t\tend
\tend)
end

function Controller:ShowShotChance(chance: any, shooter: Model?)
\tlocal value = tonumber(chance) or tonumber(shooter and shooter:GetAttribute("VTRLastShotScoringChance")) or 0
\tif value > 1 then value /= 100 end
\tvalue = math.clamp(value, 0, .99)
\tlocal percent = math.floor(value * 100 + .5)
\tif self.ShotChancePopup then self.ShotChancePopup:Destroy();self.ShotChancePopup=nil end
\tlocal box = Instance.new("CanvasGroup")
\tbox.Name = "ShotChancePopup"
\tbox.AnchorPoint = Vector2.new(.5, 0)
\tbox.Position = UDim2.new(.5, 0, 0, 116)
\tbox.Size = UDim2.fromOffset(318, 46)
\tbox.BackgroundColor3 = Theme.Colors.Black
\tbox.BackgroundTransparency = .06
\tbox.BorderSizePixel = 0
\tbox.GroupTransparency = 1
\tbox.ZIndex = 70
\tbox.Parent = self.Gui
\tcorner(box, 8)
\tstroke(box, Theme.Colors.Electric, .18)
\tlocal text = label(box, string.format("[%%%d SCORING CHANCE]", percent), UDim2.fromOffset(0, 6), UDim2.new(1, 0, 1, -12), 17)
\ttext.TextXAlignment = Enum.TextXAlignment.Center
\ttext.TextColor3 = Theme.Colors.White
\ttext.ZIndex = 71
\tlocal tag = label(box, "SHOT QUALITY", UDim2.fromOffset(0, 30), UDim2.new(1, 0, 0, 12), 7)
\ttag.TextXAlignment = Enum.TextXAlignment.Center
\ttag.TextColor3 = Theme.Colors.Electric
\ttag.ZIndex = 71
\tlocal scale = Instance.new("UIScale")
\tscale.Scale = .82
\tscale.Parent = box
\tself.ShotChancePopup = box
\tself.ShotChanceResolved = false
\tTweenService:Create(box, TweenInfo.new(.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0, Position = UDim2.new(.5, 0, 0, 104)}):Play()
\tTweenService:Create(scale, TweenInfo.new(.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
\ttask.delay(2.35, function()
\t\tif self.ShotChancePopup == box and not self.ShotChanceResolved then
\t\t\tself:ResolveShotChance(false)
\t\tend
\tend)
end

function Controller:ResolveShotChance(scored: boolean)
\tlocal box = self.ShotChancePopup
\tif not box or not box.Parent then return end
\tself.ShotChanceResolved = true
\tlocal color = scored and Color3.fromHex("21FF72") or Color3.fromHex("FF4056")
\tbox.BackgroundColor3 = color
\tfor _, child in box:GetDescendants() do
\t\tif child:IsA("TextLabel") then
\t\t\tchild.TextColor3 = Theme.Colors.Black
\t\telseif child:IsA("UIStroke") then
\t\t\tchild.Color = color
\t\t\tchild.Transparency = 0
\t\tend
\tend
\tlocal scale = box:FindFirstChildOfClass("UIScale")
\tif scale then
\t\tTweenService:Create(scale, TweenInfo.new(.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.08}):Play()
\t\ttask.delay(.14, function()
\t\t\tif scale.Parent then TweenService:Create(scale, TweenInfo.new(.14), {Scale = 1}):Play() end
\t\tend)
\tend
\ttask.delay(scored and 1.05 or .82, function()
\t\tif self.ShotChancePopup == box then
\t\t\tTweenService:Create(box, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1, Position = box.Position - UDim2.fromOffset(0, 14)}):Play()
\t\t\ttask.delay(.2, function()
\t\t\t\tif self.ShotChancePopup == box then self.ShotChancePopup = nil end
\t\t\t\tif box.Parent then box:Destroy() end
\t\t\tend)
\t\tend
\tend)
end''',
        "shot chance HUD methods"
    )

hud_path.write_text(hud, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = replace_once(
    gameplay,
    '''elseif payload.Type=="Shot"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Shoot")end''',
    '''elseif payload.Type=="Shot"then local controller=self.AnimationCache and self.AnimationCache[payload.Actor];if controller then controller:Play("Shoot")end;if self.Visual then self.Visual:PlayShotTrail()end;if self.HUD then self.HUD:ShowShotChance(payload.ScoringChance or payload.ScoringChancePercent,payload.Actor)end;if payload.Actor==self.ActiveModel then self.Trainer:NotifyAction("Shoot")end''',
    "shot popup trigger"
)

gameplay = replace_once(
    gameplay,
    '''elseif payload.Type=="Block"then self.HUD:Flash("SHOT BLOCKED",.6)''',
    '''elseif payload.Type=="Block"then if self.HUD then self.HUD:ResolveShotChance(false)end;self.HUD:Flash("SHOT BLOCKED",.6)''',
    "shot popup block result"
)

gameplay = replace_once(
    gameplay,
    '''elseif payload.Type=="GoalkeeperSave"then if self.Visual then self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Camera and self.Camera.EndCutscene then task.delay(1.5,function()if self.Camera then self.Camera:EndCutscene()end end)end;self.HUD:Flash("GREAT SAVE",.9)''',
    '''elseif payload.Type=="GoalkeeperSave"then if self.HUD then self.HUD:ResolveShotChance(false)end;if self.Visual then self.Visual:StopShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;if self.Camera and self.Camera.EndCutscene then task.delay(1.5,function()if self.Camera then self.Camera:EndCutscene()end end)end;self.HUD:Flash("GREAT SAVE",.9)''',
    "shot popup save result"
)

gameplay = replace_once(
    gameplay,
    '''elseif payload.Type=="Goal"then self.MatchInPlay=false;if self.Visual then self.Visual:ClearLock();self.Visual:HoldShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;self.Trainer:SetMatchActive(false);self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:RememberGoalScorer(payload);self.ReplayBlocking=true;self.ReplayQueuedPayloads={};self.ReplayQueuedClock=nil;if self.ReplayController then self.ReplayController:PlayGoalReplay(function()self:_finishGoalPresentation(payload)end)else self:_finishGoalPresentation(payload)end''',
    '''elseif payload.Type=="Goal"then if self.HUD then self.HUD:ResolveShotChance(true)end;self.MatchInPlay=false;if self.Visual then self.Visual:ClearLock();self.Visual:HoldShotTrail()end;if self.GoalTarget then self.GoalTarget:Unlock()end;self.Trainer:SetMatchActive(false);self.Minimap:SetMatchActive(false);self.AimLine:SetMatchActive(false);self.GoalTarget:SetMatchActive(false);self.HUD:SetClock(payload.GameSeconds or 0,payload.Home,payload.Away,payload.AddedMinutes,payload.InAddedTime,payload.AddedElapsed);self.HUD:RememberGoalScorer(payload);self.ReplayBlocking=true;self.ReplayQueuedPayloads={};self.ReplayQueuedClock=nil;if self.ReplayController then self.ReplayController:PlayGoalReplay(function()self:_finishGoalPresentation(payload)end)else self:_finishGoalPresentation(payload)end''',
    "shot popup goal result"
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

print("added shot scoring chance popup")