
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
