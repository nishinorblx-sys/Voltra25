from pathlib import Path
import re

roots = [Path("src/client"), Path("src/shared"), Path("src")]
needles = [
    "WATCH MATCH READY",
    "AI VS AI BROADCAST",
    "POWERED BY VOLTRA",
    "VOLTRA CAMPAIGN",
    "MATCHDAY",
    "WatchMatch",
    "watch match",
]

files = []
seen = set()

for root in roots:
    if not root.exists():
        continue
    for path in root.rglob("*.lua"):
        if path in seen:
            continue
        seen.add(path)
        text = path.read_text(encoding="utf-8", errors="ignore")
        low = text.lower()
        if any(n.lower() in low for n in needles):
            files.append(path)

if not files:
    for path in Path("src").rglob("*.lua"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        low = text.lower()
        if "tweenservice" in low and ("screen" in low or "gui" in low) and ("match" in low or "ready" in low or "watch" in low):
            files.append(path)

if not files:
    raise RuntimeError("Could not find the matchday screen file. Send me the output of: dir /s /b src\\client\\*.lua")

patched = False

for path in files:
    text = path.read_text(encoding="utf-8", errors="ignore")
    original = text

    if "MATCHUP_PANEL_DELAY" not in text:
        if "local TweenService = game:GetService(\"TweenService\")" in text:
            text = text.replace(
                "local TweenService = game:GetService(\"TweenService\")",
                "local TweenService = game:GetService(\"TweenService\")\nlocal MATCHUP_PANEL_DELAY = 0.85",
                1
            )
        else:
            text = "local MATCHUP_PANEL_DELAY = 0.85\n" + text

    names = []
    patterns = [
        r'local\s+(\w+)\s*=\s*Instance\.new\("CanvasGroup"\).*?label\(\s*\1\s*,\s*"VS"',
        r'local\s+(\w+)\s*=\s*Instance\.new\("Frame"\).*?label\(\s*\1\s*,\s*"VS"',
        r'local\s+(\w+)\s*=\s*panel\(.*?label\(\s*\1\s*,\s*"VS"',
        r'local\s+(\w*match\w*)\s*=',
        r'local\s+(\w*versus\w*)\s*=',
        r'local\s+(\w*fixture\w*)\s*=',
    ]

    for pattern in patterns:
        for match in re.finditer(pattern, text, flags=re.I | re.S):
            name = match.group(1)
            if name not in names:
                names.append(name)

    for name in names:
        if f"{name}.Visible = true" in text and f"Delayed{name}Visible" not in text:
            text = text.replace(
                f"{name}.Visible = true",
                f"task.delay(MATCHUP_PANEL_DELAY, function()\n\t\tif {name}.Parent then\n\t\t\t{name}.Visible = true\n\t\tend\n\tend)",
                1
            )
            patched = True

        tween_pattern = rf'(TweenService:Create\({name}\s*,\s*TweenInfo\.new\([^)]*\)\s*,\s*\{{[^}}]*\}}\):Play\(\))'
        if re.search(tween_pattern, text) and f"Delayed{name}Tween" not in text:
            text = re.sub(
                tween_pattern,
                f'task.delay(MATCHUP_PANEL_DELAY, function()\n\t\tif {name}.Parent then\n\t\t\t\\1\n\t\tend\n\tend)',
                text,
                count=1,
                flags=re.S
            )
            patched = True

        if not patched and re.search(rf'local\s+{name}\s*=', text):
            parent_match = re.search(rf'({name}\.Parent\s*=\s*[^\n]+)', text)
            if parent_match and f"{name}.Visible = false" not in text:
                replacement = parent_match.group(1) + f'\n\t{name}.Visible = false\n\ttask.delay(MATCHUP_PANEL_DELAY, function()\n\t\tif {name}.Parent then\n\t\t\t{name}.Visible = true\n\t\tend\n\tend)'
                text = text.replace(parent_match.group(1), replacement, 1)
                patched = True

    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        print("patched", path)

if not patched:
    print("found candidate files:")
    for path in files:
        print(path)
    raise RuntimeError("Found the screen file but could not safely find the matchup panel variable. Send me the file name printed above.")

print("matchday center panel delay applied")