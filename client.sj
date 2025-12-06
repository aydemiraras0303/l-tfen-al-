const socket = io();
const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

let me = { x:400, y:300, speed:4, inMiniGame:false };
let keys = {};
let players = {};

document.addEventListener("keydown", e => keys[e.key]=true);
document.addEventListener("keyup", e => keys[e.key]=false);

// Hareket
function update(){
    if(keys["ArrowUp"]) me.y-=me.speed;
    if(keys["ArrowDown"]) me.y+=me.speed;
    if(keys["ArrowLeft"]) me.x-=me.speed;
    if(keys["ArrowRight"]) me.x+=me.speed;

    checkMiniGame();
    socket.emit("move",{x:me.x,y:me.y});
}

// Çizim
function draw(){
    ctx.clearRect(0,0,canvas.width,canvas.height);

    // Zemin
    ctx.fillStyle="#6c3"; ctx.fillRect(0,0,canvas.width,canvas.height);
    ctx.fillStyle="#ffea"; ctx.fillRect(350,250,100,100); // ev kapısı

    for(let id in players){
        const p = players[id];
        let color="#fff";
        if(p.skin==="red") color="#f00";
        else if(p.skin==="blue") color="#00f";
        else if(id===socket.id) color="#0f0";
        ctx.fillStyle=color;
        ctx.fillRect(p.x,p.y,40,40);
        ctx.fillStyle="#000";
        ctx.fillText(p.name,p.x,p.y-10);
    }
}

// Game Loop
function gameLoop(){ update(); draw(); requestAnimationFrame(gameLoop); }
gameLoop();

// Socket Events
socket.on("currentPlayers", data=>{ players=data; });
socket.on("playerMoved", data=>{ players=data; });
socket.on("playerDisconnected", id=>{ delete players[id]; });
socket.on("chatMessage", data=>{
    const div=document.createElement("div");
    div.textContent=data.name+": "+data.msg;
    document.getElementById("messages").appendChild(div);
});
socket.on("skinChanged", data=>{
    if(players[data.id]) players[data.id].skin=data.skin;
});

// Chat
const chatInput=document.getElementById("chatInput");
chatInput.addEventListener("keydown",e=>{
    if(e.key==="Enter" && chatInput.value.trim()!==""){
        socket.emit("chatMessage", chatInput.value);
        chatInput.value="";
    }
});

// Ev & Mobilya
const houseUI=document.getElementById("houseUI");
const exitHouse=document.getElementById("exitHouse");
let inHouse=false;

document.addEventListener("keydown", e=>{
    if(e.key==="E" && !inHouse){
        if(me.x>350 && me.x<450 && me.y>250 && me.y<350){
            inHouse=true; houseUI.style.display="block";
            socket.emit("requestFurniture");
            socket.emit("requestAllFurniture");
        }
    }
});
exitHouse.addEventListener("click",()=>{ inHouse=false; houseUI.style.display="none"; });

// Furniture Drag
let selectedFurniture=null, offsetX=0, offsetY=0;
document.querySelectorAll(".furniture").forEach(f=>{
    f.addEventListener("mousedown", e=>{
        selectedFurniture=f; offsetX=e.offsetX; offsetY=e.offsetY;
        f.style.cursor="grabbing";
    });
});
document.addEventListener("mousemove", e=>{
    if(selectedFurniture){
        const parent=selectedFurniture.parentElement.getBoundingClientRect();
        selectedFurniture.style.left=(e.clientX-parent.left-offsetX)+"px";
        selectedFurniture.style.top=(e.clientY-parent.top-offsetY)+"px";
    }
});
document.addEventListener("mouseup", ()=>{
    if(selectedFurniture){ selectedFurniture.style.cursor="grab"; selectedFurniture=null; }
});
document.getElementById("saveFurniture").addEventListener("click",()=>{
    const furnitures={};
    document.querySelectorAll(".furniture").forEach(f=>{
        furnitures[f.id]={ left:f.style.left, top:f.style.top };
    });
    socket.emit("saveFurniture", furnitures);
    alert("Mobilyalar kaydedildi!");
});
socket.on("loadFurniture", data=>{
    for(let id in data){
        const f=document.getElementById(id);
        if(f){ f.style.left=data[id].left; f.style.top=data[id].top; }
    }
});
socket.on("loadAllFurniture", data=>{
    for(let pid in data){
        if(pid===socket.id) continue;
        for(let fid in data[pid]){
            let f=document.createElement("div");
            f.className="furniture"; f.id=pid+"_"+fid;
            f.style.width="50px"; f.style.height="50px"; f.style.background="#ccc";
            f.style.position="absolute"; f.style.left=data[pid][fid].left;
            f.style.top=data[pid][fid].top; f.style.cursor="grab";
            document.getElementById("furnitureArea").appendChild(f);
        }
    }
});
socket.on("updateFurniture", data=>{
    for(let fid in data.furniture){
        let f=document.getElementById(data.playerId+"_"+fid);
        if(!f){ f=document.createElement("div"); f.className="furniture"; f.id=data.playerId+"_"+fid;
            f.style.width="50px"; f.style.height="50px"; f.style.background="#ccc";
            f.style.position="absolute"; f.style.cursor="grab";
            document.getElementById("furnitureArea").appendChild(f);
        }
        f.style.left=data.furniture[fid].left;
        f.style.top=data.furniture[fid].top;
    }
});

// Skin Market
const skinUI=document.getElementById("skinUI");
document.getElementById("openSkin").addEventListener("click", ()=>{
    skinUI.style.display = skinUI.style.display==="none"?"block":"none";
});
document.querySelectorAll(".skin").forEach(btn=>{
    btn.addEventListener("click", ()=>{
        const skin=btn.dataset.skin; const cost=parseInt(btn.dataset.cost||"50");
        if(players[socket.id].money>=cost){
            players[socket.id].money-=cost; players[socket.id].skin=skin;
            socket.emit("changeSkin", skin);
            document.getElementById("money").textContent=players[socket.id].money;
        } else alert("Paran yetmiyor!");
    });
});

// Mini oyun
function checkMiniGame(){
    if(me.x>600 && me.x<650 && me.y>100 && me.y<150 && !me.inMiniGame){
        me.inMiniGame=true;
        alert("Mini oyun başladı: topu yakala!");
        let caught=confirm("Topu yakaladın mı? (Tamam->Evet, İptal->Hayır)");
        if(caught){ players[socket.id].money+=100;
            document.getElementById("money").textContent=players[socket.id].money; }
        me.inMiniGame=false;
    }

}
