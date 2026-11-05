/* LOCAL MARS — English-primary, English-only interface */
(()=>{'use strict';
const language='en';
let dictionaries={th:{},en:{}},ready=false;
const originalText=new WeakMap(),originalAttrs=new WeakMap();
const fallbackTranslations={
'กำลังเชื่อมต่อ Marslocal…':'Connecting to Mars network…',
'กำลังเชื่อมต่อเครือข่ายดาวอังคารทั่วโลกแล้ว':'Global Mars network connected',
'กรุณาเข้าสู่ระบบออนไลน์ก่อนซื้อพื้นที่':'Sign in to purchase a parcel',
'กรุณาเข้าสู่ระบบออนไลน์ก่อนก่อสร้าง':'Sign in to build structures',
'กรุณาเข้าสู่ระบบออนไลน์ก่อน':'Sign in to continue',
'กรุณาเข้าสู่ระบบก่อนจองแปลง':'Sign in to reserve this parcel',
'กรุณาเข้าสู่ระบบก่อนซื้อแปลง':'Sign in to purchase this parcel',
'กรุณาเข้าสู่ระบบก่อนจัดการประกาศขาย':'Sign in to manage your listing',
'ยังไม่สามารถเริ่ม USD Checkout ได้':'USD Checkout could not be started',
'ข้อมูล USD Checkout ไม่ถูกต้อง':'Invalid USD Checkout response',
'กำลังเปิดหน้า Stripe USD Checkout…':'Opening secure Stripe USD Checkout…',
'ออกจากระบบแล้ว':'Signed out successfully',
'สมัครสมาชิกออนไลน์สำเร็จ':'Online account created successfully',
'เข้าสู่ระบบสำเร็จ':'Signed in successfully',
'กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ':'Verify your email before signing in',
'บันทึกอาคารลงฐานข้อมูลออนไลน์บน':'Structure saved to the online database at',
'ระบบยังไม่พร้อม':'The system is not ready yet'
};

const clean=s=>String(s).replace(/\\s+/g,' ').trim();
let thToEn=new Map();
function rebuild(){thToEn=new Map();for(const id of Object.keys(dictionaries.th)){const th=dictionaries.th[id],en=dictionaries.en[id];if(typeof th==='string'&&typeof en==='string'&&!thToEn.has(th))thToEn.set(th,en);}for(const [th,en] of Object.entries(fallbackTranslations))if(!thToEn.has(th))thToEn.set(th,en);}
function convert(value){if(!ready||!value)return value;const key=clean(value);if(thToEn.has(key))return value.replace(key,thToEn.get(key));let out=value;const entries=[...thToEn.entries()].sort((a,b)=>b[0].length-a[0].length);for(const [from,to] of entries){if(from.length>2&&out.includes(from))out=out.split(from).join(to);}return out;}
function process(root=document){if(!ready||!root)return;const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);const nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);for(const node of nodes){const parent=node.parentElement;if(!parent||['SCRIPT','STYLE','NOSCRIPT'].includes(parent.tagName)||parent.closest('#lmLanguage'))continue;if(!originalText.has(node))originalText.set(node,node.nodeValue);const next=convert(originalText.get(node));if(node.nodeValue!==next)node.nodeValue=next;}
const elements=root.nodeType===1?[root,...root.querySelectorAll('*')]:[...root.querySelectorAll('*')];for(const el of elements){for(const attr of ['placeholder','title','aria-label','alt']){if(!el.hasAttribute?.(attr))continue;let cache=originalAttrs.get(el);if(!cache){cache={};originalAttrs.set(el,cache);}if(!(attr in cache))cache[attr]=el.getAttribute(attr);const next=convert(cache[attr]);if(el.getAttribute(attr)!==next)el.setAttribute(attr,next);}}}
function setLanguage(){document.documentElement.lang='en';document.documentElement.dataset.language='en';}
function t(_thai,english){return english;}
function formatDate(value,options){return new Intl.DateTimeFormat('en-US',options||{dateStyle:'medium',timeStyle:'short'}).format(new Date(value));}
async function init(){document.documentElement.lang='en';document.documentElement.dataset.language='en';try{const [th,en]=await Promise.all([fetch('./locales/th.json',{cache:'no-cache'}).then(r=>{if(!r.ok)throw Error('Translation source unavailable');return r.json()}),fetch('./locales/en.json',{cache:'no-cache'}).then(r=>{if(!r.ok)throw Error('English locale unavailable');return r.json()})]);dictionaries={th,en};rebuild();ready=true;process(document);const observer=new MutationObserver(records=>{for(const record of records){if(record.type==='childList')record.addedNodes.forEach(node=>{if(node.nodeType===1)process(node);else if(node.nodeType===3&&node.parentElement&&!['SCRIPT','STYLE'].includes(node.parentElement.tagName)){if(!originalText.has(node))originalText.set(node,node.nodeValue);const next=convert(originalText.get(node));if(node.nodeValue!==next)node.nodeValue=next;}});else if(record.type==='characterData'){const node=record.target;if(!originalText.has(node))originalText.set(node,node.nodeValue);const next=convert(originalText.get(node));if(node.nodeValue!==next)node.nodeValue=next;}}});observer.observe(document.body,{subtree:true,childList:true,characterData:true});}catch(error){console.error('LOCAL MARS English localization failed:',error);}}
window.LOCAL_MARS_I18N={get language(){return language;},setLanguage,t,formatDate,refresh:()=>process(document)};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();