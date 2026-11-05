/* LOCAL MARS — bilingual interface with Thai/English flag selector */
(()=>{'use strict';
let language='en',dictionaries={th:{},en:{}},ready=false;
const originalText=new WeakMap(),originalAttrs=new WeakMap();
const fallback={
'กำลังเชื่อมต่อ Marslocal…':'Connecting to Marslocal…',
'กำลังเชื่อมต่อเครือข่ายดาวอังคารทั่วโลกแล้ว':'Global Mars network connected',
'กรุณาเข้าสู่ระบบออนไลน์ก่อนซื้อพื้นที่':'Sign in to purchase a parcel',
'กรุณาเข้าสู่ระบบออนไลน์ก่อนก่อสร้าง':'Sign in to build structures',
'กรุณาเข้าสู่ระบบออนไลน์ก่อน':'Sign in to continue',
'ออกจากระบบแล้ว':'Signed out successfully',
'สมัครสมาชิกออนไลน์สำเร็จ':'Online account created successfully',
'เข้าสู่ระบบสำเร็จ':'Signed in successfully',
'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ':'Verify your email before signing in'
};
const clean=s=>String(s).replace(/\\s+/g,' ').trim();
let thToEn=new Map(),enToTh=new Map();
function rebuild(){
 thToEn=new Map();enToTh=new Map();
 for(const id of Object.keys(dictionaries.th)){
  const th=dictionaries.th[id],en=dictionaries.en[id];
  if(typeof th==='string'&&typeof en==='string'){
   if(!thToEn.has(th))thToEn.set(th,en);
   if(!enToTh.has(en))enToTh.set(en,th);
  }
 }
 for(const [th,en] of Object.entries(fallback)){if(!thToEn.has(th))thToEn.set(th,en);if(!enToTh.has(en))enToTh.set(en,th);}
}
function convert(value){
 if(!ready||!value)return value;
 const map=language==='th'?enToTh:thToEn;
 const key=clean(value);
 if(map.has(key))return value.replace(key,map.get(key));
 let out=value;
 const entries=[...map.entries()].sort((a,b)=>b[0].length-a[0].length);
 for(const [from,to] of entries){if(from.length>2&&out.includes(from))out=out.split(from).join(to);}
 return out;
}
function process(root=document){
 if(!ready||!root)return;
 const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nodes=[];
 while(walker.nextNode())nodes.push(walker.currentNode);
 for(const node of nodes){
  const parent=node.parentElement;
  if(!parent||['SCRIPT','STYLE','NOSCRIPT'].includes(parent.tagName)||parent.closest('#lmLanguage,#lmMenuLanguage'))continue;
  if(!originalText.has(node))originalText.set(node,node.nodeValue);
  const next=convert(originalText.get(node));if(node.nodeValue!==next)node.nodeValue=next;
 }
 const elements=root.nodeType===1?[root,...root.querySelectorAll('*')]:[...root.querySelectorAll('*')];
 for(const el of elements){
  if(el.closest?.('#lmMenuLanguage'))continue;
  for(const attr of ['placeholder','title','aria-label','alt']){
   if(!el.hasAttribute?.(attr))continue;
   let cache=originalAttrs.get(el);if(!cache){cache={};originalAttrs.set(el,cache);}
   if(!(attr in cache))cache[attr]=el.getAttribute(attr);
   const next=convert(cache[attr]);if(el.getAttribute(attr)!==next)el.setAttribute(attr,next);
  }
 }
}
function setLanguage(next){
 if(next!=='th'&&next!=='en')return false;
 language=next;
 try{localStorage.setItem('local-mars-language',language)}catch(_){}
 document.documentElement.lang=language;document.documentElement.dataset.language=language;
 if(ready)process(document);
 window.dispatchEvent(new CustomEvent('local-mars-language-change',{detail:{language}}));
 return true;
}
function t(thai,english){return language==='th'?thai:english;}
function formatDate(value,options){return new Intl.DateTimeFormat(language==='th'?'th-TH':'en-US',options||{dateStyle:'medium',timeStyle:'short'}).format(new Date(value));}
async function init(){
 try{const [th,en]=await Promise.all([
  fetch('./locales/th.json',{cache:'no-cache'}).then(r=>{if(!r.ok)throw Error('Thai locale unavailable');return r.json()}),
  fetch('./locales/en.json',{cache:'no-cache'}).then(r=>{if(!r.ok)throw Error('English locale unavailable');return r.json()})
 ]);dictionaries={th,en};rebuild();ready=true;setLanguage(language);process(document);
 const observer=new MutationObserver(records=>{
  for(const record of records){
   if(record.type==='childList')record.addedNodes.forEach(node=>{
    if(node.nodeType===1)process(node);
    else if(node.nodeType===3&&node.parentElement&&!['SCRIPT','STYLE'].includes(node.parentElement.tagName)){
     if(!originalText.has(node))originalText.set(node,node.nodeValue);
     const next=convert(originalText.get(node));if(node.nodeValue!==next)node.nodeValue=next;
    }
   });
   else if(record.type==='characterData'){
    const node=record.target;if(!originalText.has(node))originalText.set(node,node.nodeValue);
    const next=convert(originalText.get(node));if(node.nodeValue!==next)node.nodeValue=next;
   }
  }
 });
 observer.observe(document.body,{subtree:true,childList:true,characterData:true});
 }catch(error){console.error('LOCAL MARS bilingual localization failed:',error);}
}
try{language=localStorage.getItem('local-mars-language')==='th'?'th':'en'}catch(_){language='en'}
document.documentElement.lang=language;document.documentElement.dataset.language=language;
window.LOCAL_MARS_I18N={get language(){return language;},setLanguage,t,formatDate,refresh:()=>process(document)};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();