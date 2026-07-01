from pathlib import Path
import re

def replace_once(text, old, new, label):
    if old in text:
        return text.replace(old, new, 1)
    print("skipped", label)
    return text

runtime_path = Path("src/server/Gameplay/MatchRuntimeService.lua")
runtime = runtime_path.read_text(encoding="utf-8")

if "function Service:_applyRankedForfeit" not in runtime:
    runtime = runtime.replace(
'''function Service:EndMatch(player:Player,showResult:boolean):boolean''',
'''function Service:_applyRankedForfeit(session:any,player:Player,reason:string?)
\tif not session or session.Ended or not session.Ranked then return false end
\tlocal side=session.PlayerSides and session.PlayerSides[player] or "Home"
\tlocal opponentSide=side=="Home" and "Away" or "Home"
\tif opponentSide=="Home" then
\t\tsession.World.HomeScore.Value=math.max(session.World.HomeScore.Value,session.World.AwayScore.Value+3)
\telse
\t\tsession.World.AwayScore.Value=math.max(session.World.AwayScore.Value,session.World.HomeScore.Value+3)
\tend
\tsession.ForfeitBy=player.UserId
\tsession.ForfeitReason=reason or "Leave"
\tsession.RankedForceLossUserId=player.UserId
\tfor _,participant in session.Players or{}do
\t\tif participant==player then
\t\t\tparticipant:SetAttribute("VTRRankedResult","Loss")
\t\t\tparticipant:SetAttribute("VTRRankedForfeitLoss",true)
\t\telse
\t\t\tparticipant:SetAttribute("VTRRankedResult","Win")
\t\t\tparticipant:SetAttribute("VTRRankedForfeitWin",true)
\t\tend
\tend
\treturn true
end

function Service:EndMatch(player:Player,showResult:boolean):boolean''',
1
    )

runtime = replace_once(
    runtime,
'''	if payload.Type=="Forfeit"then
		local side=session.PlayerSides[player]or"Home";local opponentSide=side=="Home"and"Away"or"Home"
		if opponentSide=="Home"then session.World.HomeScore.Value=math.max(session.World.HomeScore.Value,session.World.AwayScore.Value+3)else session.World.AwayScore.Value=math.max(session.World.AwayScore.Value,session.World.HomeScore.Value+3)end
		session.ForfeitBy=player.UserId
		self:EndMatch(session.StepOwner,true)
		return
	end''',
'''	if payload.Type=="Forfeit"then
		if session.Ranked then
			self:_applyRankedForfeit(session,player,"Forfeit")
		else
			local side=session.PlayerSides[player]or"Home";local opponentSide=side=="Home"and"Away"or"Home"
			if opponentSide=="Home"then session.World.HomeScore.Value=math.max(session.World.HomeScore.Value,session.World.AwayScore.Value+3)else session.World.AwayScore.Value=math.max(session.World.AwayScore.Value,session.World.HomeScore.Value+3)end
			session.ForfeitBy=player.UserId
		end
		self:EndMatch(session.StepOwner,true)
		return
	end''',
"forfeit action ranked loss"
)

runtime = re.sub(
r'''function Service:PlayerRemoving\(player:Player\)
	if self\.PostMatchReturns then self\.PostMatchReturns\[player\]=nil end
	player:SetAttribute\("VTRRankedTeleporting",nil\)
	player:SetAttribute\("VTRRankedQueueLockedUntil",os\.clock\(\)\+10\)
	local session=self\.Sessions\[player\]
	if not session then return end
	if not session\.Ended and session\.Running and session\.Ranked then
		local side=session\.PlayerSides\[player\]or"Home"
		local opponentSide=side=="Home"and"Away"or"Home"
		if opponentSide=="Home"then
			session\.World\.HomeScore\.Value=math\.max\(session\.World\.HomeScore\.Value,session\.World\.AwayScore\.Value\+3\)
		else
			session\.World\.AwayScore\.Value=math\.max\(session\.World\.AwayScore\.Value,session\.World\.HomeScore\.Value\+3\)
		end
		session\.ForfeitBy=player\.UserId
		self:EndMatch\(session\.StepOwner,true\)
	else
		self:EndMatch\(player,false\)
	end
end''',
'''function Service:PlayerRemoving(player:Player)
	if self.PostMatchReturns then self.PostMatchReturns[player]=nil end
	player:SetAttribute("VTRRankedTeleporting",nil)
	player:SetAttribute("VTRRankedQueueLockedUntil",os.clock()+10)
	local session=self.Sessions[player]
	if not session then return end
	if not session.Ended and session.Ranked then
		self:_applyRankedForfeit(session,player,"Leave")
		self:EndMatch(session.StepOwner,true)
	else
		self:EndMatch(player,false)
	end
end''',
runtime,
count=1
)

runtime = replace_once(
    runtime,
'''			if session.ForfeitBy==participant.UserId then
				result="ForfeitLoss"
			elseif session.ForfeitBy then
				result="ForfeitWin"''',
'''			if session.RankedForceLossUserId==participant.UserId or session.ForfeitBy==participant.UserId then
				result="ForfeitLoss"
			elseif session.ForfeitBy then
				result="ForfeitWin"''',
"ranked forced loss result"
)

runtime = replace_once(
    runtime,
'''				self.State:FireClient(participant,{Type="MatchEnded",Ranked=session.Ranked,LocalSide=side,Result=result,Forfeit=session.ForfeitBy~=nil,Home=homeScore,Away=awayScore,Stats=resultStats,Reward=rewardPayload,RankedWinPack=rankedWin and rewardPayload or nil})''',
'''				self.State:FireClient(participant,{Type="MatchEnded",Ranked=session.Ranked,LocalSide=side,Result=result,Forfeit=session.ForfeitBy~=nil,ForfeitReason=session.ForfeitReason,RankedLossUserId=session.RankedForceLossUserId,Home=homeScore,Away=awayScore,Stats=resultStats,Reward=rewardPayload,RankedWinPack=rankedWin and rewardPayload or nil})''',
"ranked loss payload"
)

runtime_path.write_text(runtime, encoding="utf-8", newline="\n")

patched_rank_service = False

for path in Path("src/server").rglob("*.lua"):
    if path == runtime_path:
        continue
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text
    if "ForfeitWin" in text and "ForfeitLoss" not in text:
        text = text.replace('"ForfeitWin"', '"ForfeitWin" or result=="ForfeitLoss"', 1)
    if 'result=="Win"' in text and 'result=="ForfeitWin"' not in text:
        text = text.replace('result=="Win"', '(result=="Win" or result=="ForfeitWin")')
    if 'result=="Loss"' in text and 'result=="ForfeitLoss"' not in text:
        text = text.replace('result=="Loss"', '(result=="Loss" or result=="ForfeitLoss")')
    if "Result == \"Win\"" in text and "ForfeitWin" not in text:
        text = text.replace('Result == "Win"', '(Result == "Win" or Result == "ForfeitWin")')
    if "Result == \"Loss\"" in text and "ForfeitLoss" not in text:
        text = text.replace('Result == "Loss"', '(Result == "Loss" or Result == "ForfeitLoss")')
    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("patched ranked result handling", path)
        patched_rank_service = True

print("leaving ranked matches now counts as a ranked forfeit loss")
if not patched_rank_service:
    print("no separate rank progression result file matched; MatchRuntimeService now sends ForfeitLoss/ForfeitWin consistently")