from pathlib import Path

path = Path("src/server/Gameplay/AIPassingDecisionService.lua")
text = path.read_text(encoding="utf-8")

text = text.replace(
    "score += open or veryOpen and 20 or 8",
    "score += (open or veryOpen) and 20 or 8"
)

text = text.replace(
    "score += laneClear and (open or veryOpen) and 24 or 0",
    "score += (laneClear and (open or veryOpen)) and 24 or 0"
)

text = text.replace(
    "score += laneClear and 28 or -42",
    "score += laneClear and 28 or -42"
)

path.write_text(text, encoding="utf-8", newline="\n")
print("fixed boolean arithmetic in pass scoring")