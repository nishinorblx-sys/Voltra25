from pathlib import Path

path = Path("src/client/Gameplay/GameplayController.lua")
text = path.read_text(encoding="utf-8")

bad = '''local uiState=UIStateService:Get();local settings=uiState and uiState.Settings or {};self.ManualPassKey="LeftControl",LobbedPassKey="LeftAlt",ChangePlayerKey="Q",TackleKey="E",SlideTackleKey="F",PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);self.Input:SetAutoSwitch(UserInputService.TouchEnabled and "Instant" or settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(UserInputService.TouchEnabled and "Assisted" or settings.ReceiverAssist or "Light");if self.Input.SetControlsSettings then self.Input:SetControlsSettings(settings)end;'''

good = '''local uiState=UIStateService:Get();local settings=uiState and uiState.Settings or {};settings.ManualPassKey=settings.ManualPassKey or "LeftControl";settings.LobbedPassKey=settings.LobbedPassKey or "LeftAlt";settings.ChangePlayerKey=settings.ChangePlayerKey or "Q";settings.TackleKey=settings.TackleKey or "E";settings.SlideTackleKey=settings.SlideTackleKey or "F";self.PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);self.Input:SetAutoSwitch(UserInputService.TouchEnabled and "Instant" or settings.PassReceiverAutoSwitch or "Assisted");self.Input:SetReceiverAssist(UserInputService.TouchEnabled and "Assisted" or settings.ReceiverAssist or "Light");if self.Input.SetControlsSettings then self.Input:SetControlsSettings(settings)end;'''

if bad not in text:
    print("exact bad line not found, trying fallback")
    text = text.replace('self.ManualPassKey="LeftControl",LobbedPassKey="LeftAlt",ChangePlayerKey="Q",TackleKey="E",SlideTackleKey="F",PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);', 'settings.ManualPassKey=settings.ManualPassKey or "LeftControl";settings.LobbedPassKey=settings.LobbedPassKey or "LeftAlt";settings.ChangePlayerKey=settings.ChangePlayerKey or "Q";settings.TackleKey=settings.TackleKey or "E";settings.SlideTackleKey=settings.SlideTackleKey or "F";self.PauseKey=keyCodeFromSetting(settings.PauseKey,Enum.KeyCode.M);', 1)
else:
    text = text.replace(bad, good, 1)

path.write_text(text, encoding="utf-8", newline="\n")
print("fixed GameplayController bad settings syntax")