/* LOCAL MARS global member chat: Supabase Auth + Postgres Changes + Presence. */
(()=>{'use strict';
const $=id=>document.getElementById(id);
const overlay=$('lmChatOverlay'),openButton=$('lmChatOpen'),closeButton=$('lmChatClose'),messages=$('lmChatMessages'),form=$('lmChatForm'),input=$('lmChatInput'),send=$('lmChatSend'),notice=$('lmChatNotice'),signIn=$('lmChatSignIn'),connection=$('lmChatConnection'),online=$('lmChatOnline');
if(!overlay||!messages||!form)return;
let db=null,user=null,channel=null,connecting=false,sending=false,seen=new Set(),onlineUsers=new Set();
const lang=()=>window.LOCAL_MARS_I18N?.language||document.documentElement.lang||'en';
function state(){try{return window.MarsWorldServer?.getState?.()||null}catch(_){return null}}
function nameOf(u){const meta=u?.user_metadata||{};return String(meta.display_name||meta.full_name||u?.email?.split('@')[0]||'Explorer').trim().slice(0,48)||'Explorer';}
function status(text,ok=false){connection.textContent=(ok?'● ':'○ ')+text;connection.style.color=ok?'#9ce5bd':'#e9bd8d';}
function updateOnline(){online.textContent=onlineUsers.size+' ออนไลน์';}
function render(row){
 if(!row?.id||seen.has(row.id))return;seen.add(row.id);
 const empty=messages.querySelector('.lm-chat-empty');empty?.remove();
 const item=document.createElement('article');item.className='lm-chat-message'+(row.user_id===user?.id?' mine':'');
 const meta=document.createElement('div');meta.className='lm-chat-meta';
 const who=document.createElement('strong');who.textContent=row.user_id===user?.id?'คุณ':(row.display_name||'Explorer');
 const when=document.createElement('time');when.dateTime=row.created_at||'';when.textContent=row.created_at?new Intl.DateTimeFormat(lang()==='th'?'th-TH':'en-US',{hour:'2-digit',minute:'2-digit'}).format(new Date(row.created_at)):'';
 const body=document.createElement('div');body.className='lm-chat-body';body.textContent=row.body||'';
 meta.append(who,when);item.append(meta,body);messages.append(item);
 while(messages.children.length>100)messages.firstElementChild.remove();
 messages.scrollTop=messages.scrollHeight;
}
function empty(text){messages.replaceChildren();const el=document.createElement('div');el.className='lm-chat-empty';el.textContent=text;messages.append(el);}
function controls(){
 const signed=!!user;
 input.disabled=!signed||!channel;send.disabled=!signed||!channel||sending;
 signIn.style.display=signed?'none':'block';
 notice.textContent=signed?'ส่งข้อความถึงสมาชิก LOCAL MARS ได้ทันที':'กรุณาเข้าสู่ระบบสมาชิกก่อนเริ่มสนทนา';
}
async function loadRecent(){
 if(!db||!user)return;
 const result=await db.from('mars_chat_messages').select('id,user_id,display_name,body,created_at').order('created_at',{ascending:false}).limit(60);
 if(result.error){status('โหลดข้อความไม่สำเร็จ',false);notice.textContent='ไม่สามารถโหลดประวัติแชตได้: '+result.error.message;return;}
 const rows=(result.data||[]).reverse();rows.forEach(render);
 if(!rows.length)empty('ยังไม่มีข้อความ เริ่มทักทายสมาชิกคนแรกได้เลย');
}
function countPresence(){
 const state=channel?.presenceState?.()||{},ids=new Set();
 Object.values(state).flat().forEach(p=>{if(p?.userId)ids.add(p.userId);});
 onlineUsers=ids;updateOnline();
}
async function disconnect(){
 if(channel&&db){const old=channel;channel=null;try{await db.removeChannel(old)}catch(_){}}
 onlineUsers.clear();updateOnline();
}
async function connect(){
 const s=state();db=s?.db||db;user=s?.user||null;controls();
 if(!overlay.classList.contains('open'))return;
 if(!db){status('รอการเชื่อมต่อฐานข้อมูล');return;}
 if(!user){await disconnect();status('ต้องเข้าสู่ระบบสมาชิก');empty('เข้าสู่ระบบเพื่อดูและส่งข้อความในห้องสนทนา');controls();return;}
 if(channel||connecting)return;
 connecting=true;status('กำลังเชื่อมต่อห้องสนทนา');
 const ch=db.channel('localmars-global-chat',{config:{presence:{key:user.id}}});
 ch.on('postgres_changes',{event:'INSERT',schema:'public',table:'mars_chat_messages'},payload=>render(payload.new));
 ch.on('presence',{event:'sync'},countPresence);
 ch.on('presence',{event:'join'},countPresence);
 ch.on('presence',{event:'leave'},countPresence);
 ch.subscribe(async(st,err)=>{
  if(st==='SUBSCRIBED'){
   channel=ch;status('เชื่อมต่อแล้ว · LIVE',true);
   try{await ch.track({userId:user.id,displayName:nameOf(user),onlineAt:new Date().toISOString()});}catch(_){}
   controls();await loadRecent();
  }else if(st==='CHANNEL_ERROR'||st==='TIMED_OUT'||st==='CLOSED'){
   status('การเชื่อมต่อขัดข้อง');notice.textContent=err?.message||'กำลังรอการเชื่อมต่อใหม่';channel=null;controls();
  }
 });
 connecting=false;
}
async function sendMessage(event){
 event.preventDefault();if(sending||!user||!channel)return;
 const body=input.value.trim();if(!body)return;
 if(body.length>1000){notice.textContent='ข้อความยาวเกิน 1,000 ตัวอักษร';return;}
 sending=true;send.disabled=true;
 const result=await db.from('mars_chat_messages').insert({user_id:user.id,display_name:nameOf(user),body}).select('id,user_id,display_name,body,created_at').single();
 sending=false;controls();
 if(result.error){notice.textContent='ส่งไม่สำเร็จ: '+result.error.message;return;}
 input.value='';render(result.data);
}
function show(){overlay.classList.add('open');overlay.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';connect();closeButton.focus();}
async function hide(){overlay.classList.remove('open');overlay.setAttribute('aria-hidden','true');document.body.style.overflow='';await disconnect();}
openButton?.addEventListener('click',show);
closeButton?.addEventListener('click',hide);
overlay.addEventListener('click',e=>{if(e.target===overlay)hide();});
signIn.addEventListener('click',()=>{hide();document.querySelector('.lm-command-dock [data-tab="account"]')?.click();});
form.addEventListener('submit',sendMessage);
input.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();form.requestSubmit();}});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&overlay.classList.contains('open'))hide();});
document.addEventListener('mars-auth-state',async e=>{user=e.detail?.user||null;await disconnect();controls();if(overlay.classList.contains('open'))connect();else if(!user)empty('เข้าสู่ระบบเพื่อดูและส่งข้อความในห้องสนทนา');});
let attempts=0;const wait=setInterval(()=>{const s=state();if(s?.db){clearInterval(wait);db=s.db;user=s.user||null;controls();}else if(++attempts>100)clearInterval(wait);},250);
})();
