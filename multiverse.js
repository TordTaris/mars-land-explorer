/* LOCAL MARS — Underground Multiverse Simulator
 * Independent fictional colony instances. Data is stored locally in this browser.
 * This module does not claim cross-device or shared online synchronization.
 */
(() => {
  'use strict';
  const STORE = 'localMarsUndergroundMultiverseV1';
  const ACTIVE = 'localMarsUndergroundActiveUniverseV1';
  const defaults = [
    {id:'prime',name:'PRIME-01',theme:'ต้นแบบอาณานิคม',desc:'จักรวาลหลัก · ฐานมาตรฐาน 24 ชั้น',color:'#68ddec',crew:18,resources:{oxygen:98,water:96,power:91,food:88,metal:72},status:'STABLE'},
    {id:'ares',name:'ARES-02',theme:'เขตพายุทราย',desc:'จักรวาลทะเลทราย · ระบบป้องกันฝุ่นขั้นสูง',color:'#ff9b69',crew:24,resources:{oxygen:94,water:82,power:86,food:79,metal:68},status:'CAUTION'},
    {id:'gaia',name:'GAIA-03',theme:'ชีวนิเวศใต้พิภพ',desc:'จักรวาลเกษตร · ฟาร์มและระบบน้ำหมุนเวียน',color:'#80e2a5',crew:32,resources:{oxygen:99,water:98,power:82,food:96,metal:61},status:'STABLE'},
    {id:'helios',name:'HELIOS-04',theme:'พลังงานขั้นสูง',desc:'จักรวาลพลังงาน · โครงข่ายไฟฟ้าและแบตเตอรี่',color:'#e6c47b',crew:20,resources:{oxygen:96,water:90,power:99,food:84,metal:76},status:'STABLE'}
  ];
  const clone = x => JSON.parse(JSON.stringify(x));
  let worlds;
  try { worlds = JSON.parse(localStorage.getItem(STORE) || 'null') || clone(defaults); } catch (_) { worlds = clone(defaults); }
  let active = localStorage.getItem(ACTIVE) || 'prime';
  if (!worlds.some(w => w.id === active)) active = worlds[0].id;
  const persist = () => { try { localStorage.setItem(STORE, JSON.stringify(worlds)); localStorage.setItem(ACTIVE, active); } catch (_) {} };
  const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const style = document.createElement('style');
  style.textContent = `
  #mvLauncher{position:fixed;z-index:80;right:18px;top:76px;border:1px solid #d6b778;border-radius:11px;padding:10px 13px;background:linear-gradient(135deg,#172c40,#091725);color:#f4dfb2;font-weight:800;box-shadow:0 8px 25px #0008}
  #mvOverlay{display:none;position:fixed;z-index:2000;inset:0;background:#020711eF;backdrop-filter:blur(16px);overflow:auto;padding:clamp(12px,3vw,34px)}
  #mvOverlay.open{display:block}
  #mvShell{max-width:1120px;margin:0 auto;border:1px solid #b99b65;border-radius:20px;background:radial-gradient(ellipse at 10% 0,#273c50,#091522 65%);box-shadow:0 25px 90px #000b;overflow:hidden;color:#edf5fb}
  #mvShell *{box-sizing:border-box}
  .mv-head{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:18px 20px;border-bottom:1px solid #ffffff20}
  .mv-eyebrow{font-size:9px;letter-spacing:2.5px;color:#dfc184;font-weight:900}
  .mv-title{font-size:clamp(21px,4vw,32px);font-weight:900;margin:5px 0}
  .mv-sub{font-size:11px;color:#9db2c5}
  .mv-close,.mv-btn{border:1px solid #526d83;border-radius:9px;background:#13283b;color:#eaf5fb;padding:9px 12px}
  .mv-body{padding:18px}
  .mv-banner{padding:14px 16px;border:1px solid #47718a;border-radius:12px;background:linear-gradient(100deg,#122c42,#101b2b);font-size:11px;color:#c2d4e2;line-height:1.6;margin-bottom:14px}
  .mv-grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}
  .mv-world{border:1px solid #39566d;border-radius:14px;padding:14px;background:linear-gradient(145deg,#11283d,#0a1725);min-width:0}
  .mv-world.active{border-color:#e3c17c;box-shadow:0 0 0 1px #e3c17c55,0 0 25px #e3c17c22}
  .mv-world-top{display:flex;align-items:center;justify-content:space-between;gap:8px}
  .mv-world h3{font-size:15px;margin:0;color:#f4e6c7;letter-spacing:1px}
  .mv-tag{font-size:8px;border:1px solid #54758d;border-radius:20px;padding:4px 7px;color:#b8d1df}
  .mv-world p{font-size:10px;color:#9eb5c8;min-height:30px}
  .mv-stats{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin:10px 0}
  .mv-stat{background:#071522;border:1px solid #2c465b;border-radius:8px;padding:7px}
  .mv-stat small{display:block;font-size:8px;color:#8fa9bd}
  .mv-stat b{display:block;font-size:14px;color:#f4e8cf;margin-top:3px}
  .mv-meter{height:5px;background:#26394b;border-radius:8px;overflow:hidden;margin-top:5px}
  .mv-meter i{display:block;height:100%;background:var(--mv-accent);border-radius:8px}
  .mv-actions{display:flex;gap:7px;flex-wrap:wrap;margin-top:10px}
  .mv-btn.primary{background:linear-gradient(120deg,#d6b16c,#936c39);color:#1b140a;border:0;font-weight:900}
  .mv-btn:disabled{opacity:.45}
  .mv-footer{border-top:1px solid #ffffff1c;padding:12px 18px;color:#91a9bc;font-size:9px;display:flex;justify-content:space-between;gap:8px;flex-wrap:wrap}
  @media(max-width:650px){#mvLauncher{top:auto;right:8px;bottom:68px;padding:8px 10px;font-size:10px}#mvOverlay{padding:7px}.mv-head{padding:13px}.mv-body{padding:10px}.mv-grid{grid-template-columns:1fr}.mv-stats{grid-template-columns:repeat(4,minmax(0,1fr))}.mv-world{padding:11px}}
  `;
  document.head.appendChild(style);
  const launcher = document.createElement('button');
  launcher.id = 'mvLauncher';
  launcher.type = 'button';
  launcher.textContent = '✧ MULTIVERSE';
  const overlay = document.createElement('div');
  overlay.id = 'mvOverlay';
  overlay.innerHTML = '<section id="mvShell" role="dialog" aria-modal="true" aria-label="Underground Multiverse"><div class="mv-head"><div><div class="mv-eyebrow">LOCAL MARS / PARALLEL COLONY NETWORK</div><div class="mv-title">UNDERGROUND MULTIVERSE</div><div class="mv-sub">ศูนย์จำลองฐานใต้ดินหลายจักรวาล · 24 LEVELS EACH</div></div><button class="mv-close" id="mvClose" type="button">✕ ปิด</button></div><div class="mv-body"><div class="mv-banner">แต่ละจักรวาลมีฐาน ลูกเรือ และทรัพยากรแยกจากกัน คุณสามารถสลับโลกและสร้างจักรวาลทดลองใหม่ได้ โดยไม่เขียนทับข้อมูลฐานเดิม <b>ข้อมูลเวอร์ชันนี้จัดเก็บในเบราว์เซอร์เครื่องนี้</b> ยังไม่ใช่ระบบซิงค์ออนไลน์ข้ามผู้ใช้</div><div class="mv-grid" id="mvWorldGrid"></div><div class="mv-actions"><button class="mv-btn primary" id="mvCreate" type="button">＋ สร้างจักรวาลใหม่</button><button class="mv-btn" id="mvAdvance" type="button">⏱ เดินเวลาจำลอง 1 วัน</button></div></div><div class="mv-footer"><span>SIMULATION INSTANCE MANAGER · 24 FLOORS PER WORLD</span><span id="mvActiveLabel"></span></div></section>';
  document.body.appendChild(launcher);
  document.body.appendChild(overlay);
  const grid = overlay.querySelector('#mvWorldGrid');
  const current = () => worlds.find(w => w.id === active);
  function render(){
    grid.innerHTML = worlds.map(w => {
      const r = w.resources;
      const entries = [['O₂',r.oxygen],['น้ำ',r.water],['ไฟฟ้า',r.power],['อาหาร',r.food]];
      return '<article class="mv-world '+(w.id===active?'active':'')+'" style="--mv-accent:'+esc(w.color)+'"><div class="mv-world-top"><h3>'+esc(w.name)+'</h3><span class="mv-tag">'+(w.id===active?'ACTIVE UNIVERSE':esc(w.status))+'</span></div><p>'+esc(w.theme)+' · '+esc(w.desc)+'</p><div class="mv-stats">'+entries.map(e=>'<div class="mv-stat"><small>'+e[0]+'</small><b>'+Math.round(e[1])+'%</b><div class="mv-meter"><i style="width:'+Math.max(0,Math.min(100,e[1]))+'%"></i></div></div>').join('')+'</div><div class="mv-world-top"><span class="mv-sub">👩‍🚀 '+w.crew+' คน · B01–B24</span><span class="mv-sub">5 ระบบทรัพยากร</span></div><div class="mv-actions"><button class="mv-btn '+(w.id===active?'primary':'')+'" data-switch="'+esc(w.id)+'" type="button">'+(w.id===active?'จักรวาลที่ใช้งาน':'เข้าสู่จักรวาล')+'</button><button class="mv-btn" data-rename="'+esc(w.id)+'" type="button">เปลี่ยนชื่อ</button></div></article>';
    }).join('');
    overlay.querySelector('#mvActiveLabel').textContent = 'ACTIVE: '+current().name;
    grid.querySelectorAll('[data-switch]').forEach(b=>b.addEventListener('click',()=>{active=b.dataset.switch;persist();render();}));
    grid.querySelectorAll('[data-rename]').forEach(b=>b.addEventListener('click',()=>{const w=worlds.find(x=>x.id===b.dataset.rename);const n=prompt('ตั้งชื่อจักรวาลใหม่',w.name);if(n&&n.trim()){w.name=n.trim().slice(0,28);persist();render();}}));
  }
  launcher.addEventListener('click',()=>{overlay.classList.add('open');render();});
  overlay.querySelector('#mvClose').addEventListener('click',()=>overlay.classList.remove('open'));
  overlay.addEventListener('click',e=>{if(e.target===overlay)overlay.classList.remove('open');});
  document.addEventListener('keydown',e=>{if(e.key==='Escape')overlay.classList.remove('open');});
  overlay.querySelector('#mvCreate').addEventListener('click',()=>{
    const n=worlds.length+1, id='world-'+Date.now().toString(36);
    const name='WORLD-'+String(n).padStart(2,'0');
    worlds.push({id,name,theme:'จักรวาลทดลองใหม่',desc:'ฐานใต้ดินอิสระ · ปรับแต่งได้',color:'#bba4ff',crew:12,resources:{oxygen:100,water:100,power:100,food:100,metal:50},status:'NEW'});
    active=id;persist();render();
  });
  overlay.querySelector('#mvAdvance').addEventListener('click',()=>{
    const w=current();
    const d={oxygen:-0.6,water:-0.8,power:-1.1,food:-0.7};
    Object.keys(d).forEach(k=>{w.resources[k]=Math.max(0,Math.min(100,w.resources[k]+d[k]));});
    if(Object.values(w.resources).some(v=>v<25))w.status='LOW RESOURCES';
    else w.status='STABLE';
    persist();render();
  });
  persist();
})();
