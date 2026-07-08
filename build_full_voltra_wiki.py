from pathlib import Path
import re
import json
import csv
import html
import shutil
import math

root = Path.cwd()
site = root / "voltra_wiki_full"
assets = site / "assets"

if site.exists():
	shutil.rmtree(site)

assets.mkdir(parents=True, exist_ok=True)

skip_dirs = {".git", "node_modules", "voltra_wiki_full", "voltra_complete_wiki", "docs", "__pycache__"}

def esc(value):
	return html.escape(str(value if value is not None else ""))

def slug(value):
	value = str(value or "").lower().strip()
	value = re.sub(r"[^a-z0-9]+", "-", value)
	value = value.strip("-")
	return value or "item"

def compact(value):
	return re.sub(r"[^a-z0-9]+", "", str(value or "").lower())

def clean_lua(text):
	text = re.sub(r"--\[\[[\s\S]*?\]\]", "", text)
	text = re.sub(r"--[^\n]*", "", text)
	return text

def files():
	out = []
	for path in root.rglob("*"):
		if any(part in skip_dirs for part in path.parts):
			continue
		if path.suffix.lower() in {".lua", ".json", ".csv"}:
			out.append(path)
	return out

class Lexer:
	def __init__(self, text):
		self.text = text
		self.i = 0
		self.n = len(text)
		self.tokens = []

	def run(self):
		while self.i < self.n:
			ch = self.text[self.i]
			if ch.isspace():
				self.i += 1
			elif ch in "{}[]=,;":
				self.tokens.append((ch, ch))
				self.i += 1
			elif ch in "\"'":
				self.tokens.append(("string", self.read_string(ch)))
			elif ch.isdigit() or ch == "-" and self.i + 1 < self.n and self.text[self.i + 1].isdigit():
				self.tokens.append(("number", self.read_number()))
			elif ch.isalpha() or ch == "_":
				self.tokens.append(("id", self.read_id()))
			else:
				self.i += 1
		return self.tokens

	def read_string(self, quote):
		self.i += 1
		out = ""
		while self.i < self.n:
			ch = self.text[self.i]
			if ch == "\\" and self.i + 1 < self.n:
				out += self.text[self.i + 1]
				self.i += 2
			elif ch == quote:
				self.i += 1
				break
			else:
				out += ch
				self.i += 1
		return out

	def read_number(self):
		start = self.i
		self.i += 1
		while self.i < self.n and re.match(r"[0-9eE\.\+\-]", self.text[self.i]):
			self.i += 1
		raw = self.text[start:self.i]
		try:
			value = float(raw)
			return int(value) if value.is_integer() else value
		except:
			return raw

	def read_id(self):
		start = self.i
		self.i += 1
		while self.i < self.n and re.match(r"[A-Za-z0-9_]", self.text[self.i]):
			self.i += 1
		return self.text[start:self.i]

class Parser:
	def __init__(self, tokens):
		self.tokens = tokens
		self.i = 0

	def peek(self, offset=0):
		j = self.i + offset
		if j >= len(self.tokens):
			return None
		return self.tokens[j]

	def take(self):
		tok = self.peek()
		if tok:
			self.i += 1
		return tok

	def eat(self, value):
		tok = self.peek()
		if tok and tok[0] == value:
			self.i += 1
			return True
		return False

	def parse(self):
		items = []
		while self.peek():
			if self.peek()[0] == "{":
				items.append(self.table())
			else:
				self.take()
		return items

	def value(self):
		tok = self.peek()
		if not tok:
			return None
		if tok[0] == "{":
			return self.table()
		if tok[0] == "string":
			self.take()
			return tok[1]
		if tok[0] == "number":
			self.take()
			return tok[1]
		if tok[0] == "id":
			self.take()
			v = tok[1]
			if v == "true":
				return True
			if v == "false":
				return False
			if v == "nil":
				return None
			return v
		self.take()
		return None

	def table(self):
		self.eat("{")
		arr = []
		d = {}
		while self.peek() and self.peek()[0] != "}":
			key = None
			has_key = False

			if self.peek()[0] == "[":
				self.take()
				key = self.value()
				self.eat("]")
				if self.eat("="):
					has_key = True
			elif self.peek()[0] in {"id", "string"} and self.peek(1) and self.peek(1)[0] == "=":
				key = self.take()[1]
				self.eat("=")
				has_key = True

			if has_key:
				d[str(key)] = self.value()
			else:
				arr.append(self.value())

			if self.peek() and self.peek()[0] in {",", ";"}:
				self.take()

		self.eat("}")

		if d and arr:
			d["_array"] = arr
			return d
		if d:
			return d
		return arr

def parse_lua(path):
	text = clean_lua(path.read_text(encoding="utf-8", errors="ignore"))
	tokens = Lexer(text).run()
	return Parser(tokens).parse()

def lookup(obj, aliases, depth=4):
	keys = {compact(x) for x in aliases}
	if isinstance(obj, dict):
		for k, v in obj.items():
			if compact(k) in keys and v not in [None, ""]:
				return v
		if depth > 0:
			for v in obj.values():
				if isinstance(v, (dict, list)):
					got = lookup(v, aliases, depth - 1)
					if got not in [None, ""]:
						return got
	elif isinstance(obj, list) and depth > 0:
		for v in obj:
			if isinstance(v, (dict, list)):
				got = lookup(v, aliases, depth - 1)
				if got not in [None, ""]:
					return got
	return None

def num(value):
	try:
		if value is None or value == "":
			return None
		x = float(value)
		return int(x) if x.is_integer() else x
	except:
		return None

def text(value):
	if value is None:
		return None
	return str(value)

def stat(obj, aliases):
	value = num(lookup(obj, aliases))
	if value is None:
		return None
	return int(round(value))

top_aliases = {
	"OVR": ["OVR", "Overall", "Rating", "CardRating", "overall", "rating"],
	"POT": ["POT", "Potential", "potential"],
	"PAC": ["PAC", "Pace", "Speed", "pace"],
	"SHO": ["SHO", "Shooting", "shooting"],
	"PAS": ["PAS", "Passing", "passing"],
	"DRI": ["DRI", "Dribbling", "dribbling"],
	"DEF": ["DEF", "Defending", "defending"],
	"PHY": ["PHY", "Physical", "Physicality", "physical"],
}

sub_aliases = {
	"Pace": {
		"Sprint Speed": ["SprintSpeed", "Sprint Speed", "sprintSpeed"],
		"Acceleration": ["Acceleration", "Accel", "acceleration"],
	},
	"Shooting": {
		"Finishing": ["Finishing", "finishing"],
		"Heading Accuracy": ["HeadingAccuracy", "Heading Accuracy", "headingAccuracy"],
		"Volleys": ["Volleys", "volleys"],
		"Shot Power": ["ShotPower", "Shot Power", "shotPower"],
		"Long Shots": ["LongShots", "Long Shots", "longShots"],
		"Penalties": ["Penalties", "penalties"],
	},
	"Passing": {
		"Crossing": ["Crossing", "crossing"],
		"Short Passing": ["ShortPassing", "Short Passing", "shortPassing"],
		"Curve": ["Curve", "curve"],
		"FK Accuracy": ["FKAccuracy", "FreeKickAccuracy", "FK Accuracy"],
		"Long Passing": ["LongPassing", "Long Passing", "longPassing"],
		"Vision": ["Vision", "vision"],
	},
	"Dribbling": {
		"Dribbling": ["Dribbling", "dribbling"],
		"Ball Control": ["BallControl", "Ball Control", "ballControl"],
		"Balance": ["Balance", "balance"],
		"Composure": ["Composure", "composure"],
		"Attacking Position": ["AttackingPosition", "Positioning", "Attacking Position"],
	},
	"Defending": {
		"Interceptions": ["Interceptions", "interceptions"],
		"Defensive Awareness": ["DefensiveAwareness", "Defensive Awareness"],
		"Standing Tackle": ["StandingTackle", "Standing Tackle"],
		"Sliding Tackle": ["SlidingTackle", "Sliding Tackle"],
		"Marking": ["Marking", "marking"],
	},
	"Physical": {
		"Strength": ["Strength", "strength"],
		"Stamina": ["Stamina", "stamina"],
		"Jumping": ["Jumping", "jumping"],
		"Aggression": ["Aggression", "aggression"],
		"Reactions": ["Reactions", "reactions"],
	},
	"Goalkeeping": {
		"Diving": ["Diving", "GKDiving"],
		"Handling": ["Handling", "GKHandling"],
		"Kicking": ["Kicking", "GKKicking"],
		"Reflexes": ["Reflexes", "GKReflexes"],
		"Positioning": ["GKPositioning", "KeeperPositioning"],
	},
}

def player_from_dict(obj, parent_key, source):
	first = lookup(obj, ["FirstName", "First Name"])
	last = lookup(obj, ["LastName", "Last Name"])
	name = lookup(obj, ["Name", "DisplayName", "FullName", "PlayerName", "CardName", "CommonName", "ShortName"])

	if not name and first and last:
		name = str(first) + " " + str(last)
	if not name and parent_key and compact(parent_key) not in {"players", "database", "cards", "items", "array"}:
		name = str(parent_key)

	if not name:
		return None

	top = {k: stat(obj, aliases) for k, aliases in top_aliases.items()}
	has_stats = sum(1 for v in top.values() if v is not None)

	if top["OVR"] is None and has_stats < 3:
		return None

	substats = {}
	for group, values in sub_aliases.items():
		substats[group] = {label: stat(obj, aliases) for label, aliases in values.items()}

	meta = {
		"id": text(lookup(obj, ["Id", "ID", "PlayerId", "PlayerID", "CardId", "CardID"])),
		"rarity": text(lookup(obj, ["Rarity", "Tier", "Class", "CardTier", "Quality"])) or "Standard",
		"nation": text(lookup(obj, ["Nation", "Nationality", "Country"])),
		"club": text(lookup(obj, ["Club", "Team", "Squad"])),
		"league": text(lookup(obj, ["League"])),
		"position": text(lookup(obj, ["Position", "Pos", "PrimaryPosition", "Role"])),
		"age": text(lookup(obj, ["Age"])),
		"height": text(lookup(obj, ["Height", "HeightCm", "CM"])),
		"weight": text(lookup(obj, ["Weight", "WeightKg", "KG"])),
		"foot": text(lookup(obj, ["Foot", "PreferredFoot", "StrongFoot"])),
		"value": text(lookup(obj, ["Value", "MarketValue", "Price"])),
		"wage": text(lookup(obj, ["Wage", "Salary"])),
		"dob": text(lookup(obj, ["DOB", "DateOfBirth", "BirthDate"])),
		"skills": text(lookup(obj, ["Skills", "SkillMoves", "SkillStars"])),
		"weakFoot": text(lookup(obj, ["WeakFoot", "Weak Foot", "WeakFootStars"])),
		"body": text(lookup(obj, ["Body", "BodyType"])),
		"accelerationType": text(lookup(obj, ["AccelerationType", "Accelerate", "AcceleRATE"])),
		"workRates": text(lookup(obj, ["WorkRates", "WorkRate", "Work Rate"])),
	}

	return {
		"name": str(name),
		"source": source,
		"top": top,
		"substats": substats,
		"meta": meta,
	}

def walk(obj, parent_key, source, out):
	if isinstance(obj, dict):
		player = player_from_dict(obj, parent_key, source)
		if player:
			out.append(player)
		for k, v in obj.items():
			walk(v, k, source, out)
	elif isinstance(obj, list):
		for v in obj:
			walk(v, parent_key, source, out)

def extract_players():
	raw = []

	for path in files():
		source = path.relative_to(root).as_posix()
		try:
			if path.suffix.lower() == ".json":
				data = json.loads(path.read_text(encoding="utf-8", errors="ignore"))
				walk(data, None, source, raw)
			elif path.suffix.lower() == ".csv":
				with path.open("r", encoding="utf-8", errors="ignore", newline="") as f:
					for row in csv.DictReader(f):
						walk(row, None, source, raw)
			elif path.suffix.lower() == ".lua":
				for item in parse_lua(path):
					walk(item, None, source, raw)
		except Exception as e:
			print("skip", source, str(e)[:80])

	players = []
	used = {}

	for i, p in enumerate(raw):
		base = p["meta"].get("id") or p["name"]
		key = slug(str(base) + "-" + str(p["top"].get("OVR") or "") + "-" + str(p["source"]))
		count = used.get(key, 0)
		used[key] = count + 1
		uid = key if count == 0 else key + "-" + str(count + 1)
		p["uid"] = uid
		p["slug"] = uid
		p["search"] = " ".join(str(x or "") for x in [
			p["name"],
			p["meta"].get("nation"),
			p["meta"].get("club"),
			p["meta"].get("league"),
			p["meta"].get("position"),
			p["meta"].get("rarity"),
			p["source"],
		]).lower()
		players.append(p)

	players.sort(key=lambda x: (-(x["top"].get("OVR") or 0), x["name"]))
	return players

def extract_simple_records(kind_words):
	records = []
	for path in files():
		source = path.relative_to(root).as_posix()
		low_source = compact(source)
		if not any(w in low_source for w in kind_words):
			continue
		try:
			values = []
			if path.suffix.lower() == ".json":
				values = [json.loads(path.read_text(encoding="utf-8", errors="ignore"))]
			elif path.suffix.lower() == ".lua":
				values = parse_lua(path)
			elif path.suffix.lower() == ".csv":
				with path.open("r", encoding="utf-8", errors="ignore", newline="") as f:
					values = list(csv.DictReader(f))
			for item in values:
				collect_simple(item, source, records)
		except:
			pass
	return records

def collect_simple(obj, source, records):
	if isinstance(obj, dict):
		name = lookup(obj, ["Name", "DisplayName", "Title", "Id", "ID", "PackName", "MissionName", "FixtureName"])
		if name:
			records.append({
				"name": str(name),
				"source": source,
				"description": str(lookup(obj, ["Description", "Desc", "Text"]) or ""),
				"reward": str(lookup(obj, ["Reward", "Rewards", "Prize"]) or ""),
				"price": str(lookup(obj, ["Price", "Cost", "Coins", "Gems"]) or ""),
				"rarity": str(lookup(obj, ["Rarity", "Tier", "Class", "Quality"]) or ""),
			})
		for v in obj.values():
			collect_simple(v, source, records)
	elif isinstance(obj, list):
		for v in obj:
			collect_simple(v, source, records)

players = extract_players()
packs = extract_simple_records(["pack", "reward", "store"])
campaign = extract_simple_records(["campaign", "fixture", "objective", "mission", "challenge"])

(assets / "data.js").write_text(
	"window.VOLTRA_PLAYERS=" + json.dumps(players, ensure_ascii=False) + ";\n"
	+ "window.VOLTRA_PACKS=" + json.dumps(packs, ensure_ascii=False) + ";\n"
	+ "window.VOLTRA_CAMPAIGN=" + json.dumps(campaign, ensure_ascii=False) + ";\n",
	encoding="utf-8"
)

css = r'''
:root{--bg:#050705;--panel:#0d100f;--line:#25321f;--lime:#9cff12;--cyan:#42eaff;--white:#f6f6f6;--muted:#929892;--yellow:#f4e84b;--orange:#ff8b35;--green:#55e174}
*{box-sizing:border-box}
body{margin:0;background:radial-gradient(circle at top right,rgba(156,255,18,.13),transparent 24%),var(--bg);color:var(--white);font-family:Arial,Helvetica,sans-serif}
a{text-decoration:none;color:inherit}
header{position:sticky;top:0;z-index:20;background:rgba(4,6,5,.92);backdrop-filter:blur(14px);border-bottom:1px solid rgba(156,255,18,.22);padding:18px 28px;display:flex;justify-content:space-between;align-items:center;gap:18px}
.brand{font-weight:900;color:var(--lime);letter-spacing:.08em}
nav{display:flex;gap:8px;flex-wrap:wrap}
nav a{padding:10px 12px;border-radius:12px;color:#bbc0bb;font-weight:900;font-size:13px}
nav a.active,nav a:hover{background:var(--lime);color:#111}
main{max-width:1600px;margin:auto;padding:28px}
.hero{display:flex;justify-content:space-between;gap:30px;padding:30px;border:1px solid rgba(156,255,18,.4);border-radius:18px;background:rgba(10,12,11,.9)}
.breadcrumb{color:var(--lime);font-weight:900;font-size:12px;text-transform:uppercase;letter-spacing:.06em;margin-bottom:14px}
h1{font-size:clamp(36px,5vw,68px);line-height:.95;margin:0 0 14px}
h2{margin:0 0 16px;color:var(--lime);text-transform:uppercase;font-size:18px}
h3{margin:0 0 8px;font-size:22px}
p{color:#c7ccc7;line-height:1.6}
.count{font-size:42px;font-weight:900;background:#151b16;border-radius:18px;padding:22px;min-width:190px;text-align:center}
.toolbar{display:flex;gap:12px;margin:22px 0;flex-wrap:wrap}
input,select{background:#0d1210;border:1px solid rgba(156,255,18,.3);color:#fff;border-radius:14px;padding:14px;font-weight:900}
input{flex:1;min-width:260px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:16px}
.card{display:grid;grid-template-columns:64px 1fr;gap:16px;background:rgba(12,15,14,.96);border:1px solid rgba(255,255,255,.12);border-radius:18px;padding:18px}
.card:hover{border-color:var(--lime)}
.rating{width:64px;height:64px;border-radius:16px;display:grid;place-items:center;background:linear-gradient(145deg,#eff6d9,#aeefff);color:#111;font-weight:900;font-size:25px}
.meta{color:var(--muted);font-weight:900;font-size:13px}
.mini{grid-column:1/-1;display:grid;grid-template-columns:repeat(3,1fr);gap:8px}
.mini span{background:#141917;border-radius:10px;text-align:center;padding:9px;font-weight:900;font-size:12px}
.pages{display:flex;gap:10px;align-items:center;justify-content:center;margin:24px 0}
button{background:var(--lime);border:0;border-radius:12px;padding:12px 16px;font-weight:900;color:#111}
.panel{background:rgba(10,12,11,.92);border:1px solid rgba(255,255,255,.12);border-radius:20px;padding:24px;margin-top:22px}
.player-layout{display:grid;grid-template-columns:450px 1fr;gap:22px;margin-top:22px}
.avatar{height:330px;background:#22272d;border:1px solid rgba(255,255,255,.16);border-radius:18px;position:relative;overflow:hidden}
.ovr,.pot{position:absolute;top:26px;font-size:30px;font-weight:900}.ovr{left:24px}.pot{right:24px;color:var(--lime)}
.block{position:absolute;width:250px;height:240px;left:50%;top:80px;transform:translateX(-50%)}
.head{position:absolute;left:82px;top:20px;width:92px;height:68px;background:#b9a486;z-index:3}.hair{position:absolute;left:86px;top:0;width:88px;height:34px;background:#050505;z-index:4}
.eye{position:absolute;top:32px;width:16px;height:6px;border-radius:8px;background:#080808}.eye.l{left:24px}.eye.r{right:24px}
.nose{position:absolute;left:43px;top:42px;width:8px;height:14px;background:#78634f}.mouth{position:absolute;left:30px;top:56px;width:36px;height:6px;background:#111}
.neck{position:absolute;left:106px;top:88px;width:44px;height:20px;background:var(--lime)}
.body{position:absolute;left:50px;top:108px;width:156px;height:112px;background:#060606;border-top:18px solid var(--lime)}
.arm{position:absolute;top:126px;width:52px;height:92px;background:#b9a486}.la{left:0}.ra{right:0}
.tiles{display:grid;grid-template-columns:repeat(6,1fr);gap:10px;margin-bottom:20px}
.tile{border:1px solid rgba(255,255,255,.12);border-radius:18px;padding:20px 10px;text-align:center}.num{font-size:28px;font-weight:900;color:var(--lime)}.lab{color:var(--muted);font-weight:900;font-size:12px;margin-top:8px}
.subgrid{display:grid;grid-template-columns:repeat(2,1fr);gap:18px}.row{display:flex;justify-content:space-between;padding:9px 0;color:#c4cac4;font-weight:900}.row b{min-width:54px;text-align:center;padding:8px 12px;border-radius:8px;color:#111}
.green{background:var(--green)}.yellow{background:var(--yellow)}.orange{background:var(--orange)}.gray{background:var(--muted)}
.table{width:100%;border-collapse:collapse}.table td,.table th{padding:13px;border-bottom:1px solid rgba(255,255,255,.1);text-align:left}.table th{color:var(--lime);text-transform:uppercase;font-size:12px}
@media(max-width:900px){header,.hero{flex-direction:column}.player-layout,.subgrid{grid-template-columns:1fr}.tiles{grid-template-columns:repeat(3,1fr)}main{padding:16px}}
'''
(assets / "style.css").write_text(css, encoding="utf-8")

js = r'''
const players=window.VOLTRA_PLAYERS||[];
const packs=window.VOLTRA_PACKS||[];
const campaign=window.VOLTRA_CAMPAIGN||[];
let page=1;
const size=120;

function e(v){return String(v??"").replace(/[&<>"']/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"}[m]))}
function stat(v){return v==null?"N/A":v}
function meta(p){return [p.meta?.nation,p.meta?.club,p.meta?.position].filter(Boolean).map(e).join(" / ")}
function cls(v){v=Number(v||0);return v>=84?"green":v>=72?"yellow":v>0?"orange":"gray"}

function card(p){
	return `<a class="card" href="player.html?id=${encodeURIComponent(p.uid)}">
		<div class="rating">${e(stat(p.top.OVR))}</div>
		<div><h3>${e(p.name)}</h3><div class="meta">${meta(p)}</div></div>
		<div class="mini">
			<span>PAC ${e(stat(p.top.PAC))}</span><span>SHO ${e(stat(p.top.SHO))}</span><span>PAS ${e(stat(p.top.PAS))}</span>
			<span>DRI ${e(stat(p.top.DRI))}</span><span>DEF ${e(stat(p.top.DEF))}</span><span>PHY ${e(stat(p.top.PHY))}</span>
		</div>
	</a>`
}

function renderPlayers(){
	const q=(document.querySelector("#search")?.value||"").toLowerCase();
	const sort=document.querySelector("#sort")?.value||"ovr";
	let list=players.filter(p=>(p.search||"").includes(q));
	if(sort==="name")list.sort((a,b)=>a.name.localeCompare(b.name));
	else list.sort((a,b)=>(b.top.OVR||0)-(a.top.OVR||0));
	const pages=Math.max(1,Math.ceil(list.length/size));
	page=Math.min(page,pages);
	const start=(page-1)*size;
	const view=list.slice(start,start+size);
	document.querySelector("#count").textContent=list.length.toLocaleString()+" Players";
	document.querySelector("#list").innerHTML=view.map(card).join("");
	document.querySelector("#page").textContent=`Page ${page} / ${pages}`;
}

function renderPlayer(){
	const id=new URLSearchParams(location.search).get("id");
	const p=players.find(x=>x.uid===id)||players[0];
	if(!p)return;
	document.title=p.name+" | VOLTRA Wiki";
	document.querySelector("#player").innerHTML=`<section class="hero"><div><div class="breadcrumb">VTR PLAYER DATABASE / ${e(p.meta.rarity||"Standard")}</div><h1>${e(p.name)}</h1><p class="meta">${meta(p)}</p></div><a class="button" href="players.html">Close</a></section>
	<section class="player-layout">
		<div>
			<div class="avatar"><div class="ovr">${e(stat(p.top.OVR))} OVR</div><div class="pot">${e(stat(p.top.POT))} POT</div><div class="block"><div class="hair"></div><div class="head"><div class="eye l"></div><div class="eye r"></div><div class="nose"></div><div class="mouth"></div></div><div class="neck"></div><div class="body"></div><div class="arm la"></div><div class="arm ra"></div></div></div>
			<div class="panel"><p class="meta">${e(p.meta.age||"N/A")} YEARS / ${e(p.meta.height||"N/A")} CM / ${e(p.meta.weight||"N/A")} KG / ${e(p.meta.foot||"N/A")}</p><p class="meta">Source: ${e(p.source)}</p></div>
		</div>
		<div>
			<div class="tiles">${["PAC","SHO","PAS","DRI","DEF","PHY"].map(k=>`<div class="tile"><div class="num">${e(stat(p.top[k]))}</div><div class="lab">${k}</div></div>`).join("")}</div>
			<div class="subgrid">${Object.entries(p.substats).map(([g,rows])=>`<div class="panel"><h2>${e(g)}</h2>${Object.entries(rows).filter(x=>x[1]!=null).map(([k,v])=>`<div class="row"><span>${e(k)}</span><b class="${cls(v)}">${e(v)}</b></div>`).join("")||"<p class='meta'>No stats found.</p>"}</div>`).join("")}</div>
		</div>
	</section>`;
}

function simplePage(kind,data){
	const node=document.querySelector("#records");
	if(!node)return;
	document.querySelector("#count").textContent=data.length.toLocaleString()+" "+kind;
	node.innerHTML=data.map(x=>`<div class="panel"><div class="breadcrumb">${e(x.rarity||kind)}</div><h2>${e(x.name)}</h2><p>${e(x.description||"")}</p><table class="table"><tr><td>Price</td><td>${e(x.price||"")}</td></tr><tr><td>Reward</td><td>${e(x.reward||"")}</td></tr><tr><td>Source</td><td>${e(x.source||"")}</td></tr></table></div>`).join("")||"<div class='panel'>No records found.</div>";
}

document.addEventListener("DOMContentLoaded",()=>{
	if(document.querySelector("#list")){
		document.querySelector("#search").addEventListener("input",()=>{page=1;renderPlayers()});
		document.querySelector("#sort").addEventListener("change",renderPlayers);
		document.querySelector("#prev").addEventListener("click",()=>{page=Math.max(1,page-1);renderPlayers()});
		document.querySelector("#next").addEventListener("click",()=>{page++;renderPlayers()});
		renderPlayers();
	}
	if(document.querySelector("#player"))renderPlayer();
	if(document.body.dataset.page==="packs")simplePage("Packs",packs);
	if(document.body.dataset.page==="campaign")simplePage("Campaign Entries",campaign);
	const total=document.querySelector("#totalPlayers");
	if(total)total.textContent=players.length.toLocaleString();
});
'''
(assets / "app.js").write_text(js, encoding="utf-8")

def shell(title, active, body, page=""):
	links = [
		("Home","index.html"),
		("Players","players.html"),
		("Packs","packs.html"),
		("Campaign","campaign.html"),
		("Controls","controls.html"),
		("Gameplay","gameplay.html"),
	]
	nav = "".join(f'<a class="{"active" if name==active else ""}" href="{href}">{name}</a>' for name, href in links)
	return f'''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{esc(title)} | VOLTRA Wiki</title><link rel="stylesheet" href="assets/style.css"></head><body data-page="{page}"><header><a class="brand" href="index.html">VOLTRA WIKI</a><nav>{nav}</nav></header><main>{body}</main><script src="assets/data.js"></script><script src="assets/app.js"></script></body></html>'''

(site / "index.html").write_text(shell("Home","Home",f'''<section class="hero"><div><div class="breadcrumb">PACKED STADIUM FOOTBALL</div><h1>VOLTRA Wiki</h1><p>Standalone website generated from your real database shards.</p></div><div class="count"><span id="totalPlayers">{len(players):,}</span><br>Players</div></section><section class="grid"><a class="panel" href="players.html"><h2>Player Database</h2><p>Search every parsed player and open detailed stat pages.</p></a><a class="panel" href="packs.html"><h2>Packs</h2><p>All detected packs and reward records.</p></a><a class="panel" href="campaign.html"><h2>Campaign</h2><p>Campaign, fixtures, objectives, and challenges.</p></a></section>'''), encoding="utf-8")

(site / "players.html").write_text(shell("Players","Players",'''<section class="hero"><div><div class="breadcrumb">VTR PLAYER DATABASE</div><h1>Player Database</h1><p>Search all players parsed from the database shards.</p></div><div class="count" id="count">0 Players</div></section><section class="toolbar"><input id="search" placeholder="Search player, club, nation, position, rarity"><select id="sort"><option value="ovr">Sort by OVR</option><option value="name">Sort by Name</option></select></section><section id="list" class="grid"></section><section class="pages"><button id="prev">Previous</button><span id="page"></span><button id="next">Next</button></section>'''), encoding="utf-8")

(site / "player.html").write_text(shell("Player","Players",'<div id="player"></div>'), encoding="utf-8")

(site / "packs.html").write_text(shell("Packs","Packs",'<section class="hero"><div><div class="breadcrumb">VOLTRA REWARDS</div><h1>Packs</h1><p>Pack and reward data parsed from the repo.</p></div><div class="count" id="count">0 Packs</div></section><section id="records" class="grid"></section>', "packs"), encoding="utf-8")

(site / "campaign.html").write_text(shell("Campaign","Campaign",'<section class="hero"><div><div class="breadcrumb">VOLTRA CAMPAIGN</div><h1>Campaign Games</h1><p>Campaign, fixtures, objectives, missions, and challenges parsed from the repo.</p></div><div class="count" id="count">0 Entries</div></section><section id="records" class="grid"></section>', "campaign"), encoding="utf-8")

(site / "controls.html").write_text(shell("Controls","Controls",'''<section class="hero"><div><div class="breadcrumb">VOLTRA MANUAL</div><h1>Controls</h1><p>Joystick - Move. Far Drag - Move faster. Double Tap Joystick - Sprint Burst. Pass Tap - Auto Pass. Pass Hold - Power Pass. Pass Drag - Manual Aim. Shoot Tap - Quick Shot. Shoot Hold - Power Shot. Shoot Drag - Aim. Lob/Cross Tap - Lob Pass or Cross. Defend Tap - Tackle. Defend Hold - Jockey. Defend Swipe Forward - Slide Tackle. Switch Tap - Best Player. Switch Drag - Manual Switch.</p></div></section>'''), encoding="utf-8")

(site / "gameplay.html").write_text(shell("Gameplay","Gameplay",'''<section class="hero"><div><div class="breadcrumb">VOLTRA MANUAL</div><h1>Gameplay</h1><p>VOLTRA includes ranked matches, Division Path, pack rewards, shooting, passing, tackling, fouls, free kicks, penalties, goalkeeper saves, goal kicks, broadcast cameras, and match presentation.</p></div></section><section class="grid"><div class="panel"><h2>Ranked</h2><p>Win games, climb divisions, and clear the Division Path.</p></div><div class="panel"><h2>Shooting</h2><p>Aim, power, keeper position, and target placement decide shots.</p></div><div class="panel"><h2>Rewards</h2><p>Earn packs, keep items, and send them to inventory.</p></div></section>'''), encoding="utf-8")

(site / "README.txt").write_text("Open index.html\nPlayers parsed: " + str(len(players)) + "\n", encoding="utf-8")

zip_path = root / "voltra_wiki_full"
if zip_path.with_suffix(".zip").exists():
	zip_path.with_suffix(".zip").unlink()

shutil.make_archive(str(zip_path), "zip", site)

print("players parsed:", len(players))
print("packs parsed:", len(packs))
print("campaign parsed:", len(campaign))
print("built:", site)
print("zip:", zip_path.with_suffix(".zip"))