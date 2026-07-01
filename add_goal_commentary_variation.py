from pathlib import Path
import re

path = Path("src/client/Gameplay/MatchSoundController.lua")
text = path.read_text(encoding="utf-8")

text = re.sub(
r'''local GOAL_COMMENTATOR = "rbxassetid://103341909626250"''',
'''local GOAL_COMMENTATORS = {
	"rbxassetid://103341909626250",
	"rbxassetid://74702312530338",
	"rbxassetid://103290564397158",
	"rbxassetid://85367905011258",
	"rbxassetid://117754134274157",
	"rbxassetid://72037349498821",
}''',
text,
count=1
)

text = text.replace(
'''		playOneShot(GOAL_COMMENTATOR, 0.76, 1)''',
'''		playOneShot(GOAL_COMMENTATORS[math.random(1, #GOAL_COMMENTATORS)], 0.76, 1)''',
1
)

path.write_text(text, encoding="utf-8", newline="\n")

print("added randomized goal commentator variation")