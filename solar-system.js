import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const $ = (id) => document.getElementById(id);
const openButton = $('lmSolarOpen');
// Keep the Solar System launcher in its own clear corner, outside the header and dock.
const launcherLayout = document.createElement('style');
launcherLayout.id = 'lm-solar-launcher-layout-fix';
launcherLayout.textContent = `
  #lmSolarOpen{
    position:fixed!important;top:68px!important;right:18px!important;left:auto!important;
    transform:none!important;z-index:95!important;width:46px!important;height:46px!important;
    min-width:46px!important;padding:0!important;display:grid!important;place-items:center!important;
    font-size:23px!important;line-height:1!important;border-radius:14px!important;
  }
  #lmSolarOpen:active{transform:scale(.96)!important}
  @media(max-width:760px){
    #lmSolarOpen{
      top:calc(env(safe-area-inset-top,0px) + 58px)!important;right:12px!important;
      width:42px!important;height:42px!important;min-width:42px!important;
      border-radius:13px!important;font-size:21px!important;
    }
  }
`;
document.head.appendChild(launcherLayout);
const overlay = $('lmSolarOverlay');
const closeButton = $('lmSolarClose');
const canvasHost = $('lmSolarCanvas');
const status = $('lmSolarStatus');
const detailName = $('lmSolarPlanetName');
const detailType = $('lmSolarPlanetType');
const detailText = $('lmSolarPlanetText');
const detailFacts = $('lmSolarPlanetFacts');
if (!openButton || !overlay || !canvasHost) {
  console.warn('LOCAL MARS Solar System: interface mount point missing');
} else {
  let renderer, scene, camera, controls, animationId;
  let initialized = false, paused = false, speed = 1, selected = null;
  const planetObjects = [];
  const orbitPivots = [];
  let simulationTimeMs = Date.now();
  const raycaster = new THREE.Raycaster();
  const pointer = new THREE.Vector2();
  const clock = new THREE.Clock();
  const planetData = [
    {name:'Mercury',thai:'ดาวพุธ',type:'Terrestrial planet',color:0xaaa49c,radius:.23,orbit:3.8,period:88,desc:'ดาวเคราะห์ที่อยู่ใกล้ดวงอาทิตย์ที่สุด พื้นผิวเต็มไปด้วยหลุมอุกกาบาตและมีอุณหภูมิเปลี่ยนแปลงรุนแรง',facts:['Mean diameter · 4,879 km','Mean distance · 57.9 million km','Orbital period · 88 Earth days']},
    {name:'Venus',thai:'ดาวศุกร์',type:'Terrestrial planet',color:0xe5bd82,radius:.34,orbit:5.2,period:224.7,desc:'ดาวเคราะห์ที่ร้อนที่สุดในระบบสุริยะ มีชั้นบรรยากาศหนาแน่นซึ่งประกอบด้วยคาร์บอนไดออกไซด์',facts:['Mean diameter · 12,104 km','Mean distance · 108.2 million km','Orbital period · 224.7 Earth days']},
    {name:'Earth',thai:'โลก',type:'Terrestrial planet',color:0x3288cf,radius:.36,orbit:6.6,period:365.25,desc:'บ้านของเรา โลกมีมหาสมุทร น้ำในสถานะของเหลว และเป็นดาวเคราะห์เดียวที่ยืนยันว่ามีสิ่งมีชีวิต',facts:['Mean diameter · 12,742 km','Mean distance · 149.6 million km','Orbital period · 365.25 days']},
    {name:'Mars',thai:'ดาวอังคาร',type:'Terrestrial planet · LOCAL MARS',color:0xc65d3e,radius:.29,orbit:8.2,period:687,desc:'ดาวเคราะห์สีแดงและศูนย์กลางของ LOCAL MARS สำรวจต่อไปยังโลกจำลองและแปลงพื้นที่ M-001 ถึง M-019 ได้',facts:['Mean diameter · 6,779 km','Mean distance · 227.9 million km','Orbital period · 687 Earth days']},
    {name:'Jupiter',thai:'ดาวพฤหัสบดี',type:'Gas giant',color:0xd4a77d,radius:1.02,orbit:11.5,period:4332.6,desc:'ดาวเคราะห์ที่ใหญ่ที่สุด มีแถบเมฆหลายชั้นและพายุขนาดมหึมา รวมถึงจุดแดงใหญ่',facts:['Mean diameter · 139,820 km','Mean distance · 778.6 million km','Orbital period · 11.86 Earth years']},
    {name:'Saturn',thai:'ดาวเสาร์',type:'Gas giant',color:0xd8c08c,radius:.83,orbit:15.0,period:10759,desc:'โดดเด่นด้วยระบบวงแหวนที่ประกอบด้วยอนุภาคน้ำแข็ง เศษหิน และฝุ่นจำนวนมาก',facts:['Mean diameter · 116,460 km','Mean distance · 1.43 billion km','Orbital period · 29.45 Earth years']},
    {name:'Uranus',thai:'ดาวยูเรนัส',type:'Ice giant',color:0x85d5d8,radius:.59,orbit:18.5,period:30687,desc:'ดาวเคราะห์น้ำแข็งยักษ์ที่มีแกนหมุนเอียงมากจนดูคล้ายกลิ้งไปตามวงโคจร',facts:['Mean diameter · 50,724 km','Mean distance · 2.87 billion km','Orbital period · 84 Earth years']},
    {name:'Neptune',thai:'ดาวเนปจูน',type:'Ice giant',color:0x416fe0,radius:.57,orbit:22.0,period:60190,desc:'ดาวเคราะห์ที่อยู่ไกลดวงอาทิตย์ที่สุดในบรรดาดาวเคราะห์ทั้งแปด มีลมแรงมากในชั้นบรรยากาศ',facts:['Mean diameter · 49,244 km','Mean distance · 4.50 billion km','Orbital period · 164.8 Earth years']}
  ];
  function makeStripeTexture(base, stripe) {
    const c=document.createElement('canvas'); c.width=512;c.height=256;
    const x=c.getContext('2d');
    x.fillStyle=base;x.fillRect(0,0,512,256);
    for(let y=0;y<256;y++){
      const wave=Math.sin(y*.12)*8+Math.sin(y*.037)*10;
      x.globalAlpha=.12+((Math.sin(y*.23)+1)*.12);
      x.fillStyle=stripe;x.fillRect(0,y,512,Math.max(1,2+wave*.12));
    }
    x.globalAlpha=1;
    const t=new THREE.CanvasTexture(c);t.colorSpace=THREE.SRGBColorSpace;return t;
  }
  function addStars() {
    const count=2400, positions=new Float32Array(count*3);
    for(let i=0;i<count;i++){
      const r=THREE.MathUtils.randFloat(42,95), u=THREE.MathUtils.randFloat(-1,1), a=Math.random()*Math.PI*2;
      const q=Math.sqrt(1-u*u);positions[i*3]=r*q*Math.cos(a);positions[i*3+1]=r*u;positions[i*3+2]=r*q*Math.sin(a);
    }
    const g=new THREE.BufferGeometry();g.setAttribute('position',new THREE.BufferAttribute(positions,3));
    scene.add(new THREE.Points(g,new THREE.PointsMaterial({color:0xcbdcf5,size:.12,transparent:true,opacity:.85,sizeAttenuation:true})));
  }
  // Approximate J2000 orbital elements (degrees, AU); updated continuously from the live clock.
  const orbitalElements = [
    {a:.3871,e:.2056,i:7.005,node:48.331,peri:77.457,L:252.251},
    {a:.7233,e:.0068,i:3.3947,node:76.680,peri:131.602,L:181.979},
    {a:1,e:.0167,i:0,node:0,peri:102.937,L:100.464},
    {a:1.5237,e:.0934,i:1.850,node:49.558,peri:336.040,L:355.453},
    {a:5.2026,e:.0485,i:1.303,node:100.464,peri:14.753,L:34.404},
    {a:9.5549,e:.0555,i:2.489,node:113.665,peri:92.432,L:49.944},
    {a:19.2184,e:.0463,i:.773,node:74.006,peri:170.964,L:313.232},
    {a:30.11,e:.009,i:1.770,node:131.784,peri:44.971,L:304.880}
  ];
  const AU_SCALE=6.6;
  const DEG=Math.PI/180;
  function orbitalPosition(elements, daysSinceJ2000) {
    const {a,e,i,node,peri,L}=elements;
    const meanAnomaly=((L-peri)+(360/planetData[orbitalElements.indexOf(elements)].period)*daysSinceJ2000)%360*DEG;
    let E=meanAnomaly;
    for(let k=0;k<8;k++)E-=(E-e*Math.sin(E)-meanAnomaly)/(1-e*Math.cos(E));
    const xv=a*(Math.cos(E)-e), yv=a*Math.sqrt(1-e*e)*Math.sin(E);
    const w=(peri-node)*DEG, O=node*DEG, inc=i*DEG;
    const x=(Math.cos(O)*Math.cos(w)-Math.sin(O)*Math.sin(w)*Math.cos(inc))*xv+(-Math.cos(O)*Math.sin(w)-Math.sin(O)*Math.cos(w)*Math.cos(inc))*yv;
    const y=(Math.sin(O)*Math.cos(w)+Math.cos(O)*Math.sin(w)*Math.cos(inc))*xv+(-Math.sin(O)*Math.sin(w)+Math.cos(O)*Math.cos(w)*Math.cos(inc))*yv;
    const z=(Math.sin(w)*Math.sin(inc))*xv+(Math.cos(w)*Math.sin(inc))*yv;
    return new THREE.Vector3(x*AU_SCALE,z*AU_SCALE,y*AU_SCALE);
  }
  function makeOrbit(elements,index) {
    const points=[];
    for(let day=0;day<planetData[index].period;day+=planetData[index].period/256)
      points.push(orbitalPosition(elements,day));
    const line=new THREE.LineLoop(new THREE.BufferGeometry().setFromPoints(points),new THREE.LineBasicMaterial({color:0x526984,transparent:true,opacity:.48}));
    scene.add(line);
  }
  function build() {
    if(initialized)return;
    try {
      scene=new THREE.Scene();scene.background=new THREE.Color(0x030711);
      const portrait=canvasHost.clientWidth/Math.max(1,canvasHost.clientHeight)<.72;
      camera=new THREE.PerspectiveCamera(portrait?58:45,1,.1,300);camera.position.set(0,portrait?26:22,portrait?75:39);
      renderer=new THREE.WebGLRenderer({antialias:true,alpha:false,powerPreference:'high-performance'});
      renderer.setPixelRatio(Math.min(window.devicePixelRatio||1,1.7));
      renderer.outputColorSpace=THREE.SRGBColorSpace;
      renderer.toneMapping=THREE.ACESFilmicToneMapping;
      renderer.toneMappingExposure=1.15;
      canvasHost.replaceChildren(renderer.domElement);
      controls=new OrbitControls(camera,renderer.domElement);
      controls.enableDamping=true;controls.dampingFactor=.07;controls.enablePan=true;
      controls.minDistance=5;controls.maxDistance=75;controls.maxPolarAngle=Math.PI*.92;
      controls.target.set(0,0,0);controls.update();
      scene.add(new THREE.AmbientLight(0x8799b8,.42));
      const sunLight=new THREE.PointLight(0xffd5a1,1900,0,1.6);sunLight.position.set(0,0,0);scene.add(sunLight);
      const sun=new THREE.Mesh(new THREE.SphereGeometry(1.55,64,48),new THREE.MeshBasicMaterial({color:0xffb23f}));
      scene.add(sun);
      const glow=new THREE.Mesh(new THREE.SphereGeometry(1.95,48,32),new THREE.MeshBasicMaterial({color:0xff8c28,transparent:true,opacity:.13,side:THREE.BackSide,depthWrite:false}));
      scene.add(glow);
      const corona=new THREE.Mesh(new THREE.SphereGeometry(2.35,48,32),new THREE.MeshBasicMaterial({color:0xff6a24,transparent:true,opacity:.045,side:THREE.BackSide,depthWrite:false}));
      scene.add(corona);
      addStars();
      planetData.forEach((p,i)=>{
        const elements=orbitalElements[i];
        makeOrbit(elements,i);
        const material=new THREE.MeshStandardMaterial({color:p.color,roughness:.88,metalness:.02});
        if(p.name==='Jupiter')material.map=makeStripeTexture('#bd8b62','#f3d2a5');
        if(p.name==='Saturn')material.map=makeStripeTexture('#c6aa78','#f0ddb0');
        const mesh=new THREE.Mesh(new THREE.SphereGeometry(p.radius,48,36),material);
        mesh.position.copy(orbitalPosition(elements,0));mesh.userData.planetIndex=i;mesh.userData.orbitalElements=elements;scene.add(mesh);
        if(p.name==='Saturn'){
          const ring=new THREE.Mesh(new THREE.RingGeometry(1.12,1.85,96),new THREE.MeshStandardMaterial({color:0xcdbb91,side:THREE.DoubleSide,transparent:true,opacity:.82,roughness:1}));
          ring.rotation.x=-Math.PI/2;ring.rotation.y=.12;mesh.add(ring);
        }
        if(p.name==='Uranus'){
          const ring=new THREE.Mesh(new THREE.RingGeometry(.78,1.02,80),new THREE.MeshStandardMaterial({color:0x9bcfd0,side:THREE.DoubleSide,transparent:true,opacity:.38}));
          ring.rotation.x=-Math.PI/2;ring.rotation.y=.25;mesh.add(ring);
        }
        if(p.name==='Earth'){
          const moonPivot=new THREE.Group();mesh.add(moonPivot);
          const moon=new THREE.Mesh(new THREE.SphereGeometry(.09,24,16),new THREE.MeshStandardMaterial({color:0xb9b8b3,roughness:1}));
          moon.position.set(.68,0,0);moonPivot.add(moon);mesh.userData.moonPivot=moonPivot;
        }
        planetObjects.push(mesh);
        orbitPivots.push({mesh,elements,period:p.period,index:i});
      });
      renderer.domElement.addEventListener('pointerup',event=>{
        if(event.button!==0)return;
        const rect=renderer.domElement.getBoundingClientRect();
        pointer.x=((event.clientX-rect.left)/rect.width)*2-1;
        pointer.y=-((event.clientY-rect.top)/rect.height)*2+1;
        raycaster.setFromCamera(pointer,camera);
        const hits=raycaster.intersectObjects(planetObjects,false);
        if(hits.length)selectPlanet(hits[0].object.userData.planetIndex);
      });
      $('lmSolarPause').addEventListener('click',()=>{
        paused=!paused;$('lmSolarPause').textContent=paused?'RESUME':'PAUSE';
        status.textContent=paused?'ORBIT SIMULATION PAUSED':'ORBIT SIMULATION RUNNING';
      });
      $('lmSolarSpeed').addEventListener('click',()=>{
        speed=speed===1?3:speed===3?10:1;$('lmSolarSpeed').textContent='SPEED · '+speed+'×';
      });
      $('lmSolarReset').addEventListener('click',()=>{
        controls.target.set(0,0,0);const portrait=canvasHost.clientWidth/Math.max(1,canvasHost.clientHeight)<.72;camera.position.set(0,portrait?26:22,portrait?75:39);camera.fov=portrait?58:45;camera.updateProjectionMatrix();controls.update();selectPlanet(3);
      });
      $('lmSolarBackMars').addEventListener('click',()=>{closeView();document.getElementById('navExplore')?.click();});
      document.querySelectorAll('[data-solar-planet]').forEach(b=>b.addEventListener('click',()=>selectPlanet(Number(b.dataset.solarPlanet))));
      initialized=true;resize();
      selectPlanet(3);
      status.textContent='MODELLED ORBITS · UTC · '+new Date(simulationTimeMs).toLocaleString('th-TH',{dateStyle:'medium',timeStyle:'medium'});
    } catch(err) {
      console.error('LOCAL MARS Solar System initialization failed',err);
      status.textContent='3D ENGINE ERROR · '+(err?.message||'Unable to initialize');
    }
  }
  function selectPlanet(i) {
    const p=planetData[i];if(!p)return;selected=i;
    detailName.textContent=p.thai+' · '+p.name;detailType.textContent=p.type;
    detailText.textContent=p.desc;
    detailFacts.innerHTML=p.facts.map(f=>'<div>'+f+'</div>').join('');
    document.querySelectorAll('[data-solar-planet]').forEach(b=>b.classList.toggle('selected',Number(b.dataset.solarPlanet)===i));
    status.textContent='SELECTED · '+p.name.toUpperCase();
    if(p.name==='Mars')$('lmSolarMarsLink').hidden=false;else $('lmSolarMarsLink').hidden=true;
  }
  function resize() {
    if(!renderer||!camera)return;
    const w=Math.max(1,canvasHost.clientWidth),h=Math.max(1,canvasHost.clientHeight);
    renderer.setSize(w,h,false);camera.aspect=w/h;camera.updateProjectionMatrix();
  }
  function tick() {
    animationId=requestAnimationFrame(tick);
    if(!overlay.classList.contains('open')||!renderer)return;
    const delta=Math.min(clock.getDelta(),.05);
    if(!paused)simulationTimeMs+=delta*1000*speed;
    const daysSinceJ2000=simulationTimeMs/86400000-10957.5;
    orbitPivots.forEach(({mesh,elements,index})=>{
      mesh.position.copy(orbitalPosition(elements,daysSinceJ2000));
      mesh.rotation.y+=delta*(index===0?.8:.34);
      if(mesh.userData.moonPivot)mesh.userData.moonPivot.rotation.y+=delta*1.8;
    });
    status.textContent=(paused?'PAUSED · ':'MODELLED ORBITS · UTC · ')+new Date(simulationTimeMs).toLocaleString('th-TH',{dateStyle:'medium',timeStyle:'medium'});
    controls.update();renderer.render(scene,camera);
  }
  function openView() {
    overlay.classList.add('open');overlay.setAttribute('aria-hidden','false');
    openButton.setAttribute('aria-expanded','true');
    build();resize();if(!animationId)tick();clock.getDelta();
  }
  function closeView() {
    overlay.classList.remove('open');overlay.setAttribute('aria-hidden','true');
    openButton.setAttribute('aria-expanded','false');
  }
  openButton.addEventListener('click',openView);
  closeButton.addEventListener('click',closeView);
  window.addEventListener('resize',resize);
  window.addEventListener('keydown',e=>{if(e.key==='Escape'&&overlay.classList.contains('open'))closeView();});
  $('lmSolarMarsLink').addEventListener('click',()=>{closeView();document.getElementById('navExplore')?.click();});
}
