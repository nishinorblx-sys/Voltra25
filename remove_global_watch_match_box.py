from pathlib import Path
import re

targets = [
    "GLOBAL WATCH MATCH",
    "Global Watch Match",
    "Your built squad queues for a ranked opponent",
    "both teams play as AI",
    "BOTTOM-RIGHT PLAY STARTS SEARCH",
]

changed = []

for path in Path("src/client").rglob("*.lua"):
    text = path.read_text(encoding="utf-8")
    if not any(target in text for target in targets):
        continue

    original = text
    lines = text.splitlines()
    output = []
    hidden = set()

    for line in lines:
        output.append(line)

        title_panel = re.search(r'local\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*panel\s*\([^,]+,\s*["\'](?:GLOBAL WATCH MATCH|Global Watch Match)["\']', line)
        if title_panel:
            name = title_panel.group(1)
            if name not in hidden:
                output.append(f'\t{name}.Visible = false')
                hidden.add(name)
            continue

        label_parent = re.search(r'\b(?:label|copy|body|text)\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*["\'](?:GLOBAL WATCH MATCH|Global Watch Match|Your built squad queues for a ranked opponent|BOTTOM-RIGHT PLAY STARTS SEARCH)', line)
        if label_parent:
            name = label_parent.group(1)
            if name not in hidden:
                output.append(f'\t{name}.Visible = false')
                hidden.add(name)

    text = "\n".join(output) + "\n"

    text = re.sub(
        r'\n\s*label\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*["\']Your built squad queues for a ranked opponent.*?\n',
        "\n",
        text,
        flags=re.S
    )

    text = re.sub(
        r'\n\s*label\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*,\s*["\']BOTTOM-RIGHT PLAY STARTS SEARCH["\'].*?\n',
        "\n",
        text,
        flags=re.S
    )

    if text != original:
        path.write_text(text, encoding="utf-8", newline="\n")
        changed.append(str(path))

if not changed:
    raise SystemExit("Could not find the Global Watch Match box text. Send the next error or tell me which page file contains it.")

print("removed global watch match box from:")
for item in changed:
    print(item)