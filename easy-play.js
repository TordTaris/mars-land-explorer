/* LOCAL MARS — Easy Play Layer
 * Adds a consistent quick guide and page navigation without replacing existing systems.
 */
(()=>{'use strict';
if(document.getElementById('lmEasyPlay'))return;
const path=location.pathname.split('/').pop()||'index.html';
const pages=[
 {file:'index.html',icon:'🌍',th:'สำรวจดาวอังคาร',en:'Explore Mars',desc:'ดูดาวเคราะห์ เลือกพื้นที่ และเริ่มต้นสำรวจ'},
 {file:'city.html',icon:'🏗️',th:'เมืองและการก่อสร้าง',en:'City Builder',desc:'เดินสำรวจ วางสิ่งปลูกสร้าง และจัดการวัสดุ'},
 {file:'underground.html',icon:'🛰️',th:'ฐานใต้ดิน 24 ชั้น',en:'Underground 24',desc:'เลือกชั้น ดูระบบยังชีพ และเปิด Multiverse'},
 {file:'m003-base.html',icon:'🔐',th:'ฐานส่วนตัว M-003',en:'M-003 Private Base',desc:'พื้นที่ควบคุมสิทธิ์สำหรับเจ้าของ M-003'},
 {file:'civilization.html',icon:'🌐',th:'เครือข่ายอารยธรรม',en:'Civilization Network',desc:'ติดตามเมือง โครงสร้าง และกิจกรรมออนไลน์'}
];
const isTh=()=>((window.LOCAL_MARS_I18N?.language)||document.documentElement.lang||'th').toLowerCase().startsWith('th');
const t=(th,en)=>isTh()?th:en;
const css=document.createElement('style');css.id='lmEasyPlayStyle';css.textContent=`
#lmEasyPlay{position:fixed;z-index:150;right:14px;top:66px}
#lmEasyPlay button,#lmEasyPlay a{font:inherit}
#lmEasyPlayTrigger{display:flex;align-items:center;gap:7px;padding:9px 12px;border:1px solid #d8b979;border-radius:11px;background:linear-gradient(135deg,#1b344b,#091827);color:#f7e8c6;font-weight:800;font-size:11px;box-shadow:0 8px 24px #0008;cursor:pointer}
#lmEasyPlayPanel{display:none;position:fixed;z-index:3000;inset:0;background:#020711eF;backdrop-filter:blur(13px);padding:12px;overflow:auto;place-items:center}
#lmEasyPlayPanel.open{display:grid}
#lmEasyPlayCard{width:min(560px,100%);max-height:min(88dvh,780px);overflow:auto;border:1px solid #b99b65;border-radius:18px;background:linear-gradient(145deg,#142a40,#071321);color:#edf5fb;box-shadow:0 24px 80px #000b;padding:18px}
#lmEasyPlayCard h2{margin:0 0 5px;color:#f1d49b;font-size:21px}
#lmEasyPlayCard p{margin:5px 0 13px;color:#a9bfd1;font-size:12px;line-height:1.6}
#lmEasyPlayClose{float:right;border:1px solid #526d83;border-radius:9px;background:#13283b;color:#fff;padding:7px 10px;cursor:pointer}
.lm-easy-steps{display:grid;gap:8px;margin:14px 0}
.lm-easy-step{display:flex;gap:10px;align-items:flex-start;padding:10px;border:1px solid #ffffff19;border-radius:11px;background:#091a2a}
.lm-easy-step b{display:block;color:#f2dfbd;font-size:12px;margin-bottom:3px}
.lm-easy-step small{color:#9db4c8;font-size:10px;line-height:1.45}
.lm-easy-num{flex:0 0 25px;width:25px;height:25px;display:grid;place-items:center;border-radius:8px;background:#b58d50;color:#17120b;font-weight:900}
.lm-easy-links{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}
.lm-easy-links a{display:flex;align-items:center;gap:8px;padding:11px 9px;border:1px solid #45627a;border-radius:10px;background:#10243a;color:#e8f3fb;text-decoration:none;font-size:11px;min-height:44px}
.lm-easy-links a[aria-current="page"]{border-color:#e2c17d;background:#27354a}
.lm-easy-footer{margin-top:12px;padding-top:10px;border-top:1px solid #ffffff1c;color:#8fa9bd;font-size:9px;line-height:1.5}
#lmEasyPlay button:focus-visible,#lmEasyPlayPanel a:focus-visible,#lmEasyPlayPanel button:focus-visible{outline:2px solid #f1d49b;outline-offset:3px}
@media(max-width:650px){#lmEasyPlay{top:56px;right:8px}#lmEasyPlayTrigger{padding:7px 9px;font-size:10px}#lmEasyPlayCard{padding:13px}.lm-easy-links{grid-template-columns:1fr 1fr}.lm-easy-links a{font-size:10px;padding:9px 7px}}
`;document.head.appendChild(css);
const root=document.createElement('div');root.id='lmEasyPlay';root.innerHTML='<button id="lmEasyPlayTrigger" type="button" aria-haspopup="dialog" aria-expanded="false">✦ <span data-th="คู่มือ / เมนู" data-en="Guide / Menu">คู่มือ / เมนู</span></button>';
const panel=document.createElement('div');panel.id='lmEasyPlayPanel';panel.innerHTML='<section id="lmEasyPlayCard" role="dialog" aria-modal="true" aria-labelledby="lmEasyTitle"><button id="lmEasyPlayClose" type="button" aria-label="Close">✕</button><div style="font-size:9px;letter-spacing:2px;color:#cbb17e;font-weight:900">LOCAL MARS · QUICK START</div><h2 id="lmEasyTitle"></h2><p id="lmEasyIntro"></p><div class="lm-easy-steps" id="lmEasySteps"></div><h3 id="lmEasyNavTitle" style="font-size:11px;color:#e5c88e;margin:14px 0 8px"></h3><nav class="lm-easy-links" id="lmEasyLinks"></nav><div class="lm-easy-footer" id="lmEasyFoot"></div></section>';
document.body.append(root,panel);
const $=s=>panel.querySelector(s),trigger=root.querySelector('button');
const stepsFor=()=>({
 'index.html':[['หมุนดาว','ลากเพื่อหมุนดาวเคราะห์ และใช้นิ้วบีบเพื่อซูม'],['เลือกพื้นที่','แตะพื้นที่หรือแปลงที่ต้องการเพื่อดูรายละเอียด'],['เริ่มทำงาน','ใช้เมนูด้านล่างเพื่อเข้าเมือง ฐานใต้ดิน และระบบอื่น']],
 'city.html':[['เดินสำรวจ','ใช้ปุ่มทิศทางบนหน้าจอเพื่อเคลื่อนที่'],['เลือกเครื่องมือ','เลือกประเภทอาคารก่อนแตะตำแหน่งวาง'],['ตรวจสอบงาน','ดูแถบวัสดุและความคืบหน้าก่อนยืนยันก่อสร้าง']],
 'underground.html':[['เลือกชั้น','แตะหมายเลขชั้นเพื่อดูห้องและระบบของชั้นนั้น'],['เปิดจักรวาล','กด MULTIVERSE เพื่อสลับหรือสร้างจักรวาลจำลอง'],['ติดตามทรัพยากร','ตรวจค่าออกซิเจน น้ำ ไฟฟ้า และอาหาร']],
 'm003-base.html':[['ยืนยันบัญชี','เข้าสู่ระบบด้วยบัญชีที่ได้รับสิทธิ์เจ้าของ M-003'],['เลือกชั้น','แตะรายการ LEVEL เพื่อดูรายละเอียด'],['ความปลอดภัย','หน้านี้จำกัดสิทธิ์ ไม่เปิดข้อมูลฐานให้ผู้ใช้ทั่วไป']],
 'civilization.html':[['ดูสถานะออนไลน์','ตรวจสถานะการเชื่อมต่อและการซิงค์'],['ตรวจสิ่งปลูกสร้าง','ดูรายการโครงสร้างและพื้นที่ที่มีข้อมูล'],['รีเฟรช','กดรีเฟรชเมื่ออยากดึงข้อมูลล่าสุด']]
});
function render(){
 const th=isTh(),steps=stepsFor()[path]||stepsFor()['index.html'];
 $('#lmEasyTitle').textContent=t('เริ่มเล่น LOCAL MARS','Start playing LOCAL MARS');
 $('#lmEasyIntro').textContent=t('ทำตาม 3 ขั้นตอนของหน้านี้ได้เลย ไม่ต้องจำเมนูทั้งหมด','Follow these three steps for this page. You do not need to memorize every menu.');
 $('#lmEasySteps').innerHTML=steps.map((s,i)=>'<div class="lm-easy-step"><span class="lm-easy-num">'+(i+1)+'</span><div><b>'+t(s[0],['Rotate the planet','Choose a location','Open a feature'][i]||s[0])+'</b><small>'+t(s[1],['Drag to rotate the planet and pinch to zoom','Tap a parcel to see its details','Use the bottom menu to open other systems'][i]||s[1])+'</small></div></div>').join('');
 $('#lmEasyNavTitle').textContent=t('เมนูทางลัด','Quick navigation');
 $('#lmEasyLinks').innerHTML=pages.map(p=>'<a href="./'+p.file+'" '+(path===p.file?'aria-current="page"':'')+'><span>'+p.icon+'</span><span><b>'+t(p.th,p.en)+'</b><br><small style="color:#9db4c8">'+p.desc+'</small></span></a>').join('');
 $('#lmEasyFoot').textContent=t('หมายเหตุ: บางฟังก์ชันต้องเข้าสู่ระบบหรือเชื่อมต่อฐานข้อมูลก่อนใช้งาน การจำลอง Multiverse ปัจจุบันเก็บข้อมูลในเบราว์เซอร์เครื่องนี้ ไม่ใช่การซิงค์ข้ามผู้ใช้','Note: Some features require sign-in or database connectivity. The current Multiverse simulation is stored in this browser and is not shared online.');
 trigger.querySelector('span').textContent=t('คู่มือ / เมนู','Guide / Menu');
}
function open(){render();panel.classList.add('open');trigger.setAttribute('aria-expanded','true');$(' #lmEasyPlayClose'.trim()).focus();}
function close(){panel.classList.remove('open');trigger.setAttribute('aria-expanded','false');trigger.focus();}
trigger.addEventListener('click',open);$('#lmEasyPlayClose').addEventListener('click',close);panel.addEventListener('click',e=>{if(e.target===panel)close()});document.addEventListener('keydown',e=>{if(e.key==='Escape'&&panel.classList.contains('open'))close();if(e.key==='?'&&!/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName))open()});document.addEventListener('localmars:languagechange',render);render();
})();