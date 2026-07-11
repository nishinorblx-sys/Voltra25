from pathlib import Path

path=Path("src/client/DailyRewardHudButton.client.lua")
text=path.read_text(encoding="utf-8",errors="ignore")
text=text.replace("rbxassetid://107242746684663","rbxassetid://106068354237205")
path.write_text(text.strip()+"\n",encoding="utf-8")
print("updated daily reward button icon id")