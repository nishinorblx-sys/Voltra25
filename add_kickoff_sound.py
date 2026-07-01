from pathlib import Path

sound_path = Path("src/client/Gameplay/MatchSoundController.lua")
sound = sound_path.read_text(encoding="utf-8")

if 'local KICKOFF_SOUND = "rbxassetid://99361731737732"' not in sound:
    sound = sound.replace(
        'local KICK_SOUND = "rbxassetid://107963207460422"',
        'local KICK_SOUND = "rbxassetid://107963207460422"\nlocal KICKOFF_SOUND = "rbxassetid://99361731737732"',
        1
    )

if "function Controller:PlayKickoff()" not in sound:
    sound = sound.replace(
'''function Controller:PlayKick()
	playOneShot(KICK_SOUND, 0.36, 1)
end''',
'''function Controller:PlayKick()
	playOneShot(KICK_SOUND, 0.36, 1)
end

function Controller:PlayKickoff()
	playOneShot(KICKOFF_SOUND, 0.62, 1)
end''',
        1
    )

sound_path.write_text(sound, encoding="utf-8", newline="\n")

gameplay_path = Path("src/client/Gameplay/GameplayController.lua")
gameplay = gameplay_path.read_text(encoding="utf-8")

gameplay = gameplay.replace(
    'elseif payload.Type=="Kickoff"then if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)',
    'elseif payload.Type=="Kickoff"then if self.MatchSounds then self.MatchSounds:PlayKickoff()end;if self.Visual then self.Visual:StopShotTrail()end;self.HUD:Flash("Kick Off",1)',
    1
)

gameplay = gameplay.replace(
    'if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;self.Cutscenes:Play(payload)',
    'if payload.Kind=="Kickoff"and self.MatchSounds then self.MatchSounds:PlayKickoff()end;if payload.Kind=="Kickoff"and self.HUD then self.HUD:PlayMatchHudIntro();self.HUD:ShowKickoffScorer()end;self.Cutscenes:Play(payload)',
    1
)

gameplay_path.write_text(gameplay, encoding="utf-8", newline="\n")

print("added kickoff sound")