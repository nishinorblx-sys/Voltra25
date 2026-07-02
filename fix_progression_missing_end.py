from pathlib import Path
import re

root = Path.cwd()

def read(path):
    p = root / path
    if not p.exists():
        return None
    return p.read_text(encoding="utf-8", errors="ignore")

def write(path, text):
    p = root / path
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text.strip() + "\n", encoding="utf-8")

def indent_of(line):
    return re.match(r"^(\s*)", line).group(1)

path = "src/server/Services/ProgressionService.lua"
text = read(path)

if text:
    original = text

    text = re.sub(
        r'(\n([ \t]*)if[^\n]*then\n[ \t]*VTRPendingPackAnimation\.Queue\([^\n]*\)\n)([ \t]*if\b)',
        lambda m: m.group(1) + m.group(2) + "end\n" + m.group(3),
        text
    )

    lines = text.splitlines()
    if len(lines) >= 113:
        a = lines[110]
        b = lines[111]
        c = lines[112]
        if re.search(r"\bthen\s*$", a) and not re.match(r"^\s*end\b", b) and re.match(r"^\s*if\b", c):
            lines.insert(112, indent_of(a) + "end")
            text = "\n".join(lines)

    text = text.replace("end\nend\nend\nreturn ProgressionService", "end\nend\nreturn ProgressionService")

    if text != original:
        write(path, text)
        print("patched", path)
    else:
        print("unchanged", path)
else:
    print("missing", path)

data_path = "src/server/Data/DefaultProfile.lua"
text = read(data_path)

if text:
    original = text
    text = text.replace("script.Parent.Services", "script.Parent.Parent.Services")
    text = text.replace("script.Parent:WaitForChild(\"Services\")", "script.Parent.Parent:WaitForChild(\"Services\")")
    text = text.replace("script.Parent:FindFirstChild(\"Services\")", "script.Parent.Parent:FindFirstChild(\"Services\")")
    text = re.sub(r"require\((script\.Parent)\.Services", r"require(\1.Parent.Services", text)

    if text != original:
        write(data_path, text)
        print("patched", data_path)
    else:
        print("unchanged", data_path)
else:
    print("missing", data_path)