/* LOCAL MARS — English-only interface */
(()=>{'use strict';
let language='en',dictionaries={th:{},en:{}},ready=false;
const originals=new WeakMap(),attrs=new WeakMap();
const scriptURL=document.currentScript?.src||new URL('i18n.js',location.href).href;
const clean=s=>String(s).replace(/\s+/g,' ').trim();
let enToTh=new Map(),thToEn=new Map();
function rebuild(){enToTh=new Map();thToEn=new Map();for(const id of Object.keys(dictionaries.en)){const en=dictionaries.en[id],th=dictionaries.th[id];if(typeof en==='string'&&typeof th==='string'){if(!enToTh.has(en))enToTh.set(en,th);if(!thToEn.has(th))thToEn.set(th,en);}}}
function convert(value){if(!ready||!value)return value;const map=language==='th'?enToTh:thToEn,key=clean(value);if(map.has(key))return value.replace(key,map.get(key));let out=value;for(const [from,to] of [...map.entries()].sort((a,b)=>b[0].length-a[0].length)){if(from.length>2&&out.includes(from))out=out.split(from).join(to);}return out;}
function process(root=document){if(!ready||!root)return;if(root.nodeType===3){const parent=root.parentElement;if(!parent||['SCRIPT','STYLE','NOSCRIPT'].includes(parent.tagName)||parent.closest('#lmMenuLanguage'))return;if(!originals.has(root))originals.set(root,root.nodeValue);const translated=convert(originals.get(root));if(root.nodeValue!==translated)root.nodeValue=translated;return;}const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT),nodes=[];while(walker.nextNode())nodes.push(walker.currentNode);for(const node of nodes){const parent=node.parentElement;if(!parent||['SCRIPT','STYLE','NOSCRIPT'].includes(parent.tagName)||parent.closest('#lmMenuLanguage'))continue;if(!originals.has(node))originals.set(node,node.nodeValue);const translated=convert(originals.get(node));if(node.nodeValue!==translated)node.nodeValue=translated;}const elements=root.nodeType===1?[root,...root.querySelectorAll('*')]:[...root.querySelectorAll('*')];for(const el of elements){if(el.closest?.('#lmMenuLanguage'))continue;for(const attr of ['placeholder','title','aria-label','alt']){if(!el.hasAttribute?.(attr))continue;let cache=attrs.get(el);if(!cache){cache={};attrs.set(el,cache);}if(!(attr in cache))cache[attr]=el.getAttribute(attr);const translated=convert(cache[attr]);if(el.getAttribute(attr)!==translated)el.setAttribute(attr,translated);}}}
function syncButtons(){document.querySelectorAll('#lmMenuLanguage button[data-language]').forEach(b=>{b.setAttribute('aria-pressed',String(b.dataset.language==='en'));if(b.dataset.language!=='en')b.hidden=true;});const menu=document.getElementById('lmMenuLanguage');if(menu)menu.setAttribute('aria-label','Interface language: English');}
function setLanguage(next){if(next!=='en')return false;language='en';try{localStorage.setItem('local-mars-language','en')}catch(_){}document.documentElement.lang=language;document.documentElement.dataset.language=language;if(ready)process(document);syncButtons();window.dispatchEvent(new CustomEvent('local-mars-language-change',{detail:{language}}));return true;}
function t(thai,english){return language==='th'?thai:english;}
function formatDate(value,options){return new Intl.DateTimeFormat(language==='th'?'th-TH':'en-US',options||{dateStyle:'medium',timeStyle:'short'}).format(new Date(value));}
async function init(){try{const [th,en]=await Promise.all([fetch(new URL('locales/th.json',scriptURL),{cache:'no-cache'}).then(r=>{if(!r.ok)throw Error('Thai locale unavailable');return r.json()}),fetch(new URL('locales/en.json',scriptURL),{cache:'no-cache'}).then(r=>{if(!r.ok)throw Error('English locale unavailable');return r.json()})]);dictionaries={th,en};rebuild();ready=true;process(document);syncButtons();new MutationObserver(records=>records.forEach(record=>{if(record.type==='childList')record.addedNodes.forEach(node=>{if(node.nodeType===1||node.nodeType===3)process(node)});else if(record.type==='characterData'){const node=record.target;if(!originals.has(node))originals.set(node,node.nodeValue);const next=convert(originals.get(node));if(node.nodeValue!==next)node.nodeValue=next;}})).observe(document.body,{subtree:true,childList:true,characterData:true});}catch(error){console.error('LOCAL MARS English localization failed:',error);}}
try{localStorage.setItem('local-mars-language','en')}catch(_){}language='en';
document.documentElement.lang=language;document.documentElement.dataset.language=language;
window.LOCAL_MARS_I18N={get language(){return language;},setLanguage,t,formatDate,refresh:()=>process(document)};
function closeMenu(){const panel=document.getElementById('lmMenuDropdown'),toggle=document.getElementById('lmMenuToggle');if(panel)panel.hidden=true;if(toggle)toggle.setAttribute('aria-expanded','false');}
document.addEventListener('click',event=>{
 const languageButton=event.target.closest?.('#lmMenuLanguage button[data-language]');
 if(languageButton){setLanguage(languageButton.dataset.language);closeMenu();return;}
 const toggle=event.target.closest?.('#lmMenuToggle');
 if(toggle){const panel=document.getElementById('lmMenuDropdown');if(!panel)return;const opening=panel.hidden;panel.hidden=!opening;toggle.setAttribute('aria-expanded',String(opening));return;}
 if(!event.target.closest?.('#lmMenuDropdown'))closeMenu();
});
document.addEventListener('keydown',event=>{if(event.key==='Escape')closeMenu();});
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();