import * as THREE from "https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js";
import {GLTFLoader} from "https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/loaders/GLTFLoader.js";

const $=id=>document.getElementById(id);
const scene=new THREE.Scene(); scene.background=new THREE.Color(0x070a0f); scene.fog=new THREE.FogExp2(0x070a0f,.008);
const camera=new THREE.PerspectiveCamera(65,innerWidth/innerHeight,.1,900);
const renderer=new THREE.WebGLRenderer({antialias:true}); renderer.setPixelRatio(Math.min(devicePixelRatio,2)); renderer.setSize(innerWidth,innerHeight); renderer.shadowMap.enabled=true; renderer.shadowMap.type=THREE.PCFSoftShadowMap; renderer.outputColorSpace=THREE.SRGBColorSpace; renderer.toneMapping=THREE.ACESFilmicToneMapping; renderer.toneMappingExposure=1.15; renderer.shadowMap.type=THREE.PCFSoftShadowMap; document.body.appendChild(renderer.domElement);

const hemi=new THREE.HemisphereLight(0x9aa9c4,0x1c1a16,1.8); scene.add(hemi);
const sun=new THREE.DirectionalLight(0xffe7c2,2.2); sun.position.set(-80,120,60); sun.castShadow=true; sun.shadow.mapSize.set(2048,2048); scene.add(sun);


const world=new THREE.Group(); scene.add(world);
const gltfLoader=new GLTFLoader();
const loadedAssets=new Map();
const ASSET_MANIFEST={
  joseph:"assets/glb/joseph.glb",
  civilian:"assets/glb/civilian.glb",
  politician:"assets/glb/politician.glb",
  mafiaBoss:"assets/glb/mafia_boss.glb",
  police:"assets/glb/police.glb",
  sedan:"assets/glb/sedan.glb",
  suv:"assets/glb/suv.glb",
  policeCar:"assets/glb/police_car.glb",
  cityBuilding:"assets/glb/city_building.glb",
  office:"assets/glb/office_interior.glb",
  palace:"assets/glb/presidential_palace.glb",
  parliament:"assets/glb/parliament.glb",
  warehouse:"assets/glb/warehouse.glb",
  streetProps:"assets/glb/street_props.glb"
};
function loadOptionalGLB(key, position=new THREE.Vector3(), scale=1){
  const url=ASSET_MANIFEST[key]; if(!url) return;
  gltfLoader.load(url, gltf=>{
    const root=gltf.scene; root.position.copy(position); root.scale.setScalar(scale);
    root.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}});
    world.add(root); loadedAssets.set(key,root);
  }, undefined, ()=>{ /* Missing assets intentionally fall back to procedural art. */ });
}
// Atmospheric dome.
const sky=new THREE.Mesh(
  new THREE.SphereGeometry(500,32,16),
  new THREE.MeshBasicMaterial({color:0x0b1019,side:THREE.BackSide})
); scene.add(sky);

const colliders=[]; const interactables=[];
const mat=(c,r=.6,m=0)=>new THREE.MeshStandardMaterial({color:c,roughness:r,metalness:m});
function box(name,x,y,z,w,h,d,color){let m=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),mat(color,.7));m.name=name;m.position.set(x,y+h/2,z);m.castShadow=true;m.receiveShadow=true;world.add(m);colliders.push(new THREE.Box3().setFromObject(m));return m}
function cyl(x,y,z,r,h,color){let m=new THREE.Mesh(new THREE.CylinderGeometry(r,r,h,16),mat(color,.75));m.position.set(x,y+h/2,z);m.castShadow=true;world.add(m);return m}
function label(text,pos){let c=document.createElement("canvas"),x=c.getContext("2d");c.width=512;c.height=96;x.fillStyle="#fff";x.font="bold 32px Arial";x.fillText(text,20,58);let t=new THREE.CanvasTexture(c),s=new THREE.Sprite(new THREE.SpriteMaterial({map:t,transparent:true}));s.scale.set(8,1.5,1);s.position.copy(pos);world.add(s)}
function road(x,z,w,d){box("road",x,-.08,z,w,.16,d,0x171b20)}
function lamp(x,z){cyl(x,0,z,.12,5,0x252b34);let l=new THREE.PointLight(0xffd6a0,5,18);l.position.set(x,5,z);world.add(l);cyl(x,4.8,z,.22,.22,0xffd6a0)}
function tree(x,z){cyl(x,0,z,.22,2.5,0x3a2a20);let a=cyl(x,2,z,.9,2.3,0x16351f);a.scale.y=1.3}

function marking(x,z,w,d,rot=0){
  const m=box("road marking",x,.02,z,w,.025,d,0xd4d7d2); m.rotation.y=rot; return m;
}
function car(x,z,color=0x1b2028,rot=0){
  const g=new THREE.Group(); g.position.set(x,0,z); g.rotation.y=rot;
  const base=new THREE.Mesh(new THREE.BoxGeometry(3.4,.75,6.4),mat(color,.45,.35)); base.position.y=.75; base.castShadow=true; g.add(base);
  const cabin=new THREE.Mesh(new THREE.BoxGeometry(2.7,.8,3.2),mat(0x222a33,.3,.25)); cabin.position.set(0,1.35,-.2); cabin.castShadow=true; g.add(cabin);
  world.add(g);
}
function makeCity(){
  box("ground",0,-.5,0,260,1,220,0x25272a);
  for(let x=-120;x<=120;x+=28) for(let z=-95;z<=95;z+=28){
    if(Math.abs(x)<18||Math.abs(z)<14) continue;
    let h=THREE.MathUtils.randFloat(7,25), w=THREE.MathUtils.randFloat(12,22);
    let b=box("building",x,-.0,z,w,h,20, new THREE.Color().setHSL(.59,.12,THREE.MathUtils.randFloat(.12,.23)));
    label(["APARTMENTS","BANK","NEWS","HOTEL","MINISTRY"][Math.floor(Math.random()*5)],new THREE.Vector3(x,h+.8,z-10));
  }
  road(0,0,240,14); road(0,0,14,190); road(-56,0,10,190); road(56,0,10,190);
  for(let z=-85;z<=85;z+=18){lamp(-10,z);lamp(10,z)} for(let x=-110;x<=110;x+=18){lamp(x,-10);lamp(x,10)}
  for(let i=0;i<80;i++){let x=THREE.MathUtils.randFloat(-120,120),z=THREE.MathUtils.randFloat(-95,95);if(Math.abs(x)<18||Math.abs(z)<14)continue;tree(x,z)}
  // OOO tower
  box("OOO CORPORATION",0,0,-82,36,38,26,0x24303b); label("OOO CORPORATION",new THREE.Vector3(0,40,-82));
  // campaign HQ
  box("CAMPAIGN HQ",-70,0,-5,28,10,20,0x343b44); label("PEOPLE'S MOVEMENT",new THREE.Vector3(-70,11,-5));
  // parliament
  box("PARLIAMENT",72,0,-48,42,18,30,0x3b3a38); label("PARLIAMENT",new THREE.Vector3(72,19,-48));
  // palace
  box("PRESIDENTIAL PALACE",0,0,82,54,24,36,0x4a4034); label("PRESIDENTIAL PALACE",new THREE.Vector3(0,25,82));
  // warehouse / shadow network
  box("WAREHOUSE",-82,0,60,28,9,24,0x24282c); label("WAREHOUSE",new THREE.Vector3(-82,10,60));
  for(let z=-80;z<=80;z+=12) marking(0,z,.22,5,0);
  for(let x=-105;x<=105;x+=12) marking(x,0,5,.22,0);
  car(-4,-35,0x27303a,.02); car(4,42,0x3a2e2b,Math.PI);
  loadOptionalGLB("cityBuilding",new THREE.Vector3(105,0,-35),1.0);
  loadOptionalGLB("palace",new THREE.Vector3(0,0,82),1.0);
  loadOptionalGLB("parliament",new THREE.Vector3(72,0,-48),1.0);
  loadOptionalGLB("warehouse",new THREE.Vector3(-82,0,60),1.0);
  loadOptionalGLB("streetProps",new THREE.Vector3(0,0,0),1.0);
}
makeCity();

const player=new THREE.Group(); world.add(player);
const body=new THREE.Mesh(new THREE.CapsuleGeometry(.55,1.25,6,12),mat(0x1d2733,.9));
loadOptionalGLB("joseph",new THREE.Vector3(0,0,55),1.0);body.position.y=1.25;body.castShadow=true;player.add(body);
const head=new THREE.Mesh(new THREE.SphereGeometry(.42,16,12),mat(0xc68f68));head.position.y=2.35;head.castShadow=true;player.add(head);
player.position.set(0,0,55);
camera.position.set(0,5,63);

const keys={}; addEventListener("keydown",e=>{keys[e.key.toLowerCase()]=true;if(e.key.toLowerCase()==="e") interact(); if(e.key.toLowerCase()==="m")toggleMap()}); addEventListener("keyup",e=>keys[e.key.toLowerCase()]=false);
let yaw=0,pitch=-.15,drag=false,lastX=0,lastY=0;
renderer.domElement.addEventListener("pointerdown",e=>{drag=true;lastX=e.clientX;lastY=e.clientY}); addEventListener("pointerup",()=>drag=false);
addEventListener("pointermove",e=>{if(!drag)return;yaw-= (e.clientX-lastX)*.004;pitch-= (e.clientY-lastY)*.003;pitch=Math.max(-.9,Math.min(.5,pitch));lastX=e.clientX;lastY=e.clientY});
let touchX=0,touchY=0; const stick=$("stick"); if(stick){stick.addEventListener("pointermove",e=>{if(e.buttons){let r=stick.getBoundingClientRect();touchX=(e.clientX-(r.left+r.width/2))/(r.width/2);touchY=(e.clientY-(r.top+r.height/2))/(r.height/2)}});stick.addEventListener("pointerup",()=>{touchX=touchY=0})}
document.querySelectorAll("[data-key]").forEach(b=>{b.addEventListener("pointerdown",()=>keys[b.dataset.key.toLowerCase()]=true);b.addEventListener("pointerup",()=>keys[b.dataset.key.toLowerCase()]=false)});$("mapBtn").onclick=()=>toggleMap();

const chapters=[
 {name:"PROLOGUE",mission:"The Last Day",objective:"Go to OOO Corporation.",target:new THREE.Vector3(0,0,-82),lines:[
  ["Joseph","I thought if I kept my head down and did honest work, the system couldn't touch me."],
  ["Manager","We're restructuring. Your position is being eliminated."],
  ["Joseph","Restructuring. Right."],
  ["Friend","Then why don't you change it?"]
 ]},
 {name:"ACT I",mission:"The Candidate",objective:"Reach the People's Movement HQ.",target:new THREE.Vector3(-70,0,-5),lines:[
  ["Joseph","No more excuses. If the system is broken, I'll enter it and fix it."],
  ["Crowd","The People's Candidate!"],
  ["Joseph","Doing the right thing isn't enough. I need to understand how power works."]
 ]},
 {name:"ACT II",mission:"The Rise",objective:"Go to Parliament.",target:new THREE.Vector3(72,0,-48),choice:true,lines:[
  ["Adviser","You don't have to become corrupt. You just have to understand how the game works."],
  ["Joseph","I can take their support without becoming one of them."]
 ]},
 {name:"ACT III",mission:"The President",objective:"Reach the Presidential Palace.",target:new THREE.Vector3(0,0,82),choice:true,lines:[
  ["Joseph","If I lose power, everything I built will disappear."],
  ["Journalist","Your government is becoming the thing it promised to destroy."],
  ["Joseph","It's temporary. It's necessary. I'm doing this for the country."]
 ]},
 {name:"ACT IV",mission:"The Shadow Government",objective:"Investigate the warehouse.",target:new THREE.Vector3(-82,0,60),choice:true,lines:[
  ["Fixer","We can make problems disappear."],
  ["Joseph","I'm using them. They aren't using me."]
 ]},
 {name:"ACT V",mission:"The Mafia",objective:"Return to OOO Corporation.",target:new THREE.Vector3(0,0,-82),choice:true,lines:[
  ["Mafia Boss","The Boss has arrived."],
  ["OOO CEO","Funny how things change."],
  ["Joseph","..."]
 ]},
 {name:"ACT VI",mission:"The Man in the Mirror",objective:"Go to the Presidential Palace.",target:new THREE.Vector3(0,0,82),lines:[
  ["Friend","You think I wanted this?"],
  ["Joseph","You think I wanted this?"],
  ["Friend","No. You just kept choosing it."]
 ]},
 {name:"ACT VII",mission:"Collapse",objective:"Return to Parliament.",target:new THREE.Vector3(72,0,-48),choice:true,lines:[
  ["Joseph","The same methods that helped me rise are tearing everything down."]
 ]},
 {name:"FINAL ACT",mission:"The President",objective:"Sit alone in the Presidential Office.",target:new THREE.Vector3(0,0,82),final:true,lines:[
  ["Joseph","I didn't defeat the system."],
  ["Joseph","I became the system."]
 ]}
];
let ci=0,li=0,playing=false,money=1200,choices=0;
function updateUI(){let c=chapters[ci];$("chapter").textContent=c.name;$("mission").textContent=c.mission;$("objective").textContent=c.objective;$("money").textContent="₹ "+money.toLocaleString("en-IN")}
function distanceToTarget(){let t=chapters[ci].target;return player.position.distanceTo(t)}
function startChapter(){li=0;playing=false;updateUI(); if(ci===0){player.position.set(0,0,55)}}
function interact(){if(playing){advanceDialogue();return} if(distanceToTarget()<10){playLines()}}
function playLines(){playing=true;li=0;$("dialogue").classList.remove("hidden");showLine()}
function showLine(){let l=chapters[ci].lines[li];$("speaker").textContent=l[0].toUpperCase();$("line").textContent=l[1];$("next").textContent=li===chapters[ci].lines.length-1?"Continue":"Next"}
function advanceDialogue(){li++;if(li<chapters[ci].lines.length){showLine();return}$("dialogue").classList.add("hidden");playing=false;if(chapters[ci].choice)showChoice();else finishChapter()}
$("next").onclick=()=>advanceDialogue();
function showChoice(){let c=chapters[ci];$("choiceTitle").textContent="A DECISION";$("choiceText").textContent="Joseph faces a compromise. The choice changes his path, but every path moves the story forward.";let d=$("choices");d.innerHTML="";["Reject the offer","Accept the support","Use the network"].slice(0,c.name==="ACT II"?2:3).forEach((txt,i)=>{let b=document.createElement("button");b.className="choiceBtn";b.textContent=txt;b.onclick=()=>{choices++;money+=i?15000:0;$("choice").classList.add("hidden");finishChapter()};d.appendChild(b)});$("choice").classList.remove("hidden")}
function finishChapter(){if(chapters[ci].final){showEnding();return}ci++;startChapter()}
function showEnding(){$("endingText").innerHTML='The city falls silent behind the glass.<br><br><span class="ending-line">“The man Joseph hated was never his enemy.<br>He was his destination.”</span>';$("ending").classList.remove("hidden")}
function toggleMap(){$("map").classList.toggle("hidden");drawMap()}
window.game={toggleMap};

function drawMap(){let c=$("mapCanvas"),x=c.getContext("2d");x.clearRect(0,0,c.width,c.height);x.fillStyle="#0b0e13";x.fillRect(0,0,c.width,c.height);x.strokeStyle="#313a46";for(let i=0;i<12;i++){x.beginPath();x.moveTo(i*45,0);x.lineTo(i*45,c.height);x.stroke();x.beginPath();x.moveTo(0,i*30);x.lineTo(c.width,i*30);x.stroke()}let pts=[["OOO",260,45],["HQ",120,180],["PAR",390,110],["PALACE",260,315],["WH",75,270]];x.fillStyle="#dce3eb";x.font="bold 12px Arial";pts.forEach(p=>{x.fillRect(p[1]-5,p[2]-5,10,10);x.fillText(p[0],p[1]+8,p[2]+4)});x.fillStyle="#fff";x.beginPath();x.arc(260+(player.position.x/220)*260,180+(player.position.z/180)*150,6,0,Math.PI*2);x.fill()}
$("map").querySelector("button").onclick=toggleMap;

let last=performance.now();function loop(now){let dt=Math.min(.04,(now-last)/1000);last=now;
 if(!playing&&!$("choice").classList.contains("hidden")===false){let f=(keys.w?1:0)-(keys.s?1:0)+(-touchY);let r=(keys.d?1:0)-(keys.a?1:0)+touchX;let len=Math.hypot(f,r);if(len){f/=len;r/=len;let speed=(keys.shift?10:5)*dt;let dir=new THREE.Vector3(Math.sin(yaw),0,Math.cos(yaw));let side=new THREE.Vector3(Math.cos(yaw),0,-Math.sin(yaw));player.position.addScaledVector(dir,f*speed);player.position.addScaledVector(side,r*speed);player.position.x=THREE.MathUtils.clamp(player.position.x,-122,122);player.position.z=THREE.MathUtils.clamp(player.position.z,-100,100)}}
 let target=player.position.clone().add(new THREE.Vector3(Math.sin(yaw)*-6,3.7,Math.cos(yaw)*-6));camera.position.lerp(target,.12);camera.lookAt(player.position.x,1.5,player.position.z);
 if(!playing&&!$("choice").classList.contains("hidden")){}; renderer.render(scene,camera);requestAnimationFrame(loop)}
requestAnimationFrame(loop);
startChapter();
setTimeout(()=>{$("loading").style.display="none"},1200);
addEventListener("resize",()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
