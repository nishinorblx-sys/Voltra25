from pathlib import Path
import re

root = Path.cwd()

paths = [
    root / "src/server/Services/StoreService.lua",
    root / "src/server/Services/ProgressionService.lua",
]

for path in (root / "src/server/Services").glob("*.lua"):
    if path not in paths:
        paths.append(path)

def indent(line):
    return re.match(r"^(\s*)", line).group(1)

def fix_text(text):
    text = re.sub(
        r'(\n([ \t]*)if[^\n]*then\n[ \t]*VTRPendingPackAnimation\.Queue\([^\n]*\)\n)([ \t]*if\b)',
        lambda m: m.group(1) + m.group(2) + "end\n" + m.group(3),
        text
    )

    lines = text.splitlines()
    out = []
    i = 0

    while i < len(lines):
        out.append(lines[i])

        if re.search(r"\bif\b.*\bthen\s*$", lines[i]):
            j = i + 1
            seen_queue = False
            while j < len(lines) and j <= i + 5:
                if "VTRPendingPackAnimation.Queue" in lines[j]:
                    seen_queue = True
                if seen_queue and j + 1 < len(lines) and re.match(r"^\s*if\b", lines[j + 1]):
                    out.append(indent(lines[i]) + "end")
                    break
                if re.match(r"^\s*end\b", lines[j]):
                    break
                j += 1

        i += 1

    text = "\n".join(out) + "\n"

    text = re.sub(
        r'(\n([ \t]*)if\s+[^;\n]*VTRPendingPackAnimation[^;\n]*then\n(?:[^\n]*\n){0,3}?)([ \t]*if\b)',
        lambda m: m.group(1) + m.group(2) + "end\n" + m.group(3),
        text
    )

    return text

for path in paths:
    if not path.exists():
        continue

    original = path.read_text(encoding="utf-8", errors="ignore")
    fixed = fix_text(original)

    if fixed != original:
        path.write_text(fixed.strip() + "\n", encoding="utf-8")
        print("patched", path.relative_to(root).as_posix())

print("done")