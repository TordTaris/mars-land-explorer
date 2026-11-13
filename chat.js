/* LOCAL MARS global member chat: Supabase Auth + Postgres Changes + Presence. */
(()=>{'use strict';
const $=id=>document.getElementById(id);
const overlay=$('lmChatOverlay'),openButton=$('lmChatOpen'),closeButton=$('lmChatClose'),messages=$('lmChatMessages'),form=$('lmChatForm'),input=$('lmChatInput'),send=$('lmChatSend'),notice=$('lmChatNotice'),signIn=$('lmChatSignIn'),connection=$('lmChatConnection'),online=$('lmChatOnline'),bar=$('lmChatBar');
if(!overlay||!messages||!form||!bar)return;
let db=null,user=null,channel=null,connecting=false,sending=false,reconnectTimer=null,reconnectAttempt=0,seen=new Set(),onlineUsers=new Set(),activeRoom='global',lastSentAt=0;
const rooms=[
 {id:'global',label:'GLOBAL COMMUNITY'},
 {id:'aaru',label:'A’ARU CITY · M-001'},
 {id:'command',label:'COMMAND HUB'},
 {id:'habitat',label:'HABITAT DISTRICT'},
 {id:'medical',label:'MEDICAL DISTRICT'},
 {id:'energy',label:'ENERGY DISTRICT'},
 {id:'logistics',label:'LOGISTICS DISTRICT'}
];
const lang=()=>window.LOCAL_MARS_I18N?.language||document.documentElement.lang||'en';
function state(){try{return window.MarsWorldServer?.getState?.()||null}catch(_){return null}}
function nameOf(u){const meta=u?.user_metadata||{};return String(meta.display_name||meta.full_name||u?.email?.split('@')[0]||'Explorer').trim().slice(0,48)||'Explorer';}
function status(text,ok=false){connection.textContent=(ok?'● ':'○ ')+text;connection.style.color=ok?'#9ce5bd':'#e9bd8d';}
function updateOnline(){online.textContent=onlineUsers.size+' online';}
function render(row){
 if(!row?.id||seen.has(row.id)||row.room_key!==activeRoom)return;
 seen.add(row.id);
 messages.querySelector('.lm-chat-empty')?.remove();
 const item=document.createElement('article');item.className='lm-chat-message'+(row.user_id===user?.id?' mine':'');
 const meta=document.createElement('div');meta.className='lm-chat-meta';
 const who=document.createElement('strong');who.textContent=row.user_id===user?.id?(lang()==='th'?'คุณ':'You'):(row.display_name||'Explorer');
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
 notice.textContent=signed?(lang()==='th'?'ส่งข้อความถึงสมาชิกในห้องนี้ได้ทันที':'You are ready to chat with members in this room.'):(lang()==='th'?'กรุณาเข้าสู่ระบบสมาชิกก่อนเริ่มสนทนา':'Sign in to join the global community chat.');
}
async function loadRecent(){
 if(!db||!user)return;
 const result=await db.from('mars_chat_messages').select('id,user_id,display_name,body,room_key,created_at').eq('room_key',activeRoom).order('created_at',{ascending:false}).limit(60);
 if(result.error){status('Unable to load messages');notice.textContent='Chat history could not be loaded: '+result.error.message;return;}
 const rows=(result.data||[]).reverse();rows.forEach(render);
 if(!rows.length)empty(lang()==='th'?'ยังไม่มีข้อความในห้องนี้ เริ่มสนทนาได้เลย':'No messages in this room yet. Start the conversation.');
}
function countPresence(){
 const state=channel?.presenceState?.()||{},ids=new Set();
 Object.values(state).flat().forEach(p=>{if(p?.userId)ids.add(p.userId);});
 onlineUsers=ids;updateOnline();
}
async function disconnect(){
 if(reconnectTimer){clearTimeout(reconnectTimer);reconnectTimer=null;}
 if(channel&&db){const old=channel;channel=null;try{await db.removeChannel(old)}catch(_){}}
 onlineUsers.clear();updateOnline();
}
function scheduleReconnect(){
 if(reconnectTimer||!overlay.classList.contains('open')||!user)return;
 const delay=Math.min(30000,1000*Math.pow(2,reconnectAttempt++));
 status(lang()==='th'?'สัญญาณขัดข้อง · กำลังเชื่อมต่อใหม่':'Connection interrupted · reconnecting');
 reconnectTimer=setTimeout(()=>{reconnectTimer=null;connect();},delay);
}
async function connect(){
 const s=state();db=s?.db||db;user=s?.user||null;controls();
 if(!overlay.classList.contains('open'))return;
 if(!db){status('Waiting for database connection');scheduleReconnect();return;}
 if(!user){await disconnect();status(lang()==='th'?'ต้องเข้าสู่ระบบสมาชิก':'Member sign-in required');empty(lang()==='th'?'เข้าสู่ระบบเพื่อดูและส่งข้อความ':'Sign in to view and send messages');controls();return;}
 if(channel||connecting)return;
 connecting=true;status('Connecting · '+rooms.find(r=>r.id===activeRoom).label);
 const ch=db.channel('localmars-chat-'+activeRoom,{config:{presence:{key:user.id}}});
 ch.on('postgres_changes',{event:'INSERT',schema:'public',table:'mars_chat_messages,filter:'room_key=eq.'+activeRoom},payload=>render(payload.new));
 ch.on('presence',{event:'sync'},countPresence);
 ch.on('presence',{event:'join'},countPresence);
 ch.on('presence',{event:'leave'},countPresence);
 ch.subscribe(async(st,err)=>{
  connecting=false;
  if(st==='SUBSCRIBED'){
   channel=ch;reconnectAttempt=0;status(lang()==='th'?'เชื่อมต่อแล้ว · LIVE':'Connected · LIVE',true);
   try{await ch.track({userId:user.id,displayName:nameOf(user),onlineAt:new Date().toISOString()});}catch(_){}
   controls();await loadRecent();
  }else if(st==='CHANNEL_ERROR'||st==='TIMED_OUT'||st==='CLOSED'){
   if(channel===ch)channel=null;
   try{await db.removeChannel(ch)}catch(_){}
   notice.textContent=err?.message||'Waiting for reconnection';controls();scheduleReconnect();
  }
 });
 connecting=false;
}
async function switchRoom(next){
 if(!rooms.some(r=>r.id===next)||next===activeRoom)return;
 activeRoom=next;roomSelect.value=next;seen.clear();
 await disconnect();empty(lang()==='th'?'กำลังเปิดห้องสนทนา…':'Opening room…');
 if(overlay.classList.contains('open'))connect();
}
async function sendMessage(event){
 event.preventDefault();if(sending||!user||!channel)return;
 const body=input.value.trim();if(!body)return;
 if(body.length>1000){notice.textContent='Messages are limited to 1,000 characters.';return;}
 const now=Date.now();if(now-lastSentAt<1200){notice.textContent='Please wait a moment before sending another message.';return;}
 lastSentAt=now;sending=true;send.disabled=true;
 const result=await db.from('mars_chat_messages').insert({user_id:user.id,display_name:nameOf(user),body,room_key:activeRoom}).select('id,user_id,display_name,body,room_key,created_at').single();
 sending=false;controls();
 if(result.error){notice.textContent='Message not sent: '+result.error.message;return;}
 input.value='';render(result.data);
}
function show(){overlay.classList.add('open');overlay.setAttribute('aria-hidden','false');document.body.style.overflow='hidden';connect();closeButton.focus();}
async function hide(){overlay.classList.remove('open');overlay.setAttribute('aria-hidden','true');document.body.style.overflow='';await disconnect();}
const roomBar=document.createElement('div');roomBar.id='lmChatRoomBar';
roomBar.innerHTML='<label for="lmChatRoomSelect">CHAT ROOM</label><select id="lmChatRoomSelect" aria-label="Choose chat room"></select>';
roomBar.querySelector('select').innerHTML=rooms.map(r=>'<option value="'+r.id+'">'+r.label+'</option>').join('');
bar.insertAdjacentElement('afterend',roomBar);
const roomSelect=roomBar.querySelector('select');
const style=document.createElement('style');style.textContent='#lmChatRoomBar{display:flex;align-items:center;gap:10px;padding:9px 14px;border-bottom:1px solid #7892a922;background:#0a1929}#lmChatRoomBar label{font-size:10px;letter-spacing:1px;color:#8da8bc;font-weight:800;white-space:nowrap}#lmChatRoomSelect{width:100%;min-width:0;border:1px solid #b58b4c88;border-radius:9px;background:#10253b;color:#f1dba9;padding:10px 12px;font:700 11px system-ui;outline-offset:2px}#lmChatRoomSelect:focus{outline:2px solid #69d9ec}';document.head.append(style);
roomSelect.addEventListener('change',()=>switchRoom(roomSelect.value));
openButton?.addEventListener('click',show);
closeButton?.addEventListener('click',hide);
overlay.addEventListener('click',e=>{if(e.target===overlay)hide();});
signIn.addEventListener('click',()=>{hide();document.getElementById('account')?.click();});
form.addEventListener('submit',sendMessage);
input.addEventListener('keydown',e=>{if(e.key==='Enter'&&!e.shiftKey){e.preventDefault();form.requestSubmit();}});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&overlay.classList.contains('open'))hide();});
document.addEventListener('mars-auth-state',async e=>{user=e.detail?.user||null;await disconnect();reconnectAttempt=0;controls();if(overlay.classList.contains('open'))connect();else if(!user)empty('Sign in to view and send messages');});
function resumeChat(){
 if(!overlay.classList.contains('open'))return;
 const s=state();if(s?.db)db=s.db;if(s?.user!==undefined)user=s.user;
 if(!navigator.onLine){status('Offline · waiting for network');return;}
 if(reconnectTimer){clearTimeout(reconnectTimer);reconnectTimer=null;}
 if(channel&&channel.state==='joined'){controls();return;}
 disconnect().finally(()=>{reconnectAttempt=0;connect();});
}
window.addEventListener('online',resumeChat);
window.addEventListener('pageshow',resumeChat);
document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')resumeChat();});
window.addEventListener('offline',()=>{if(overlay.classList.contains('open'))status('Offline · will reconnect automatically');});
let attempts=0;const wait=setInterval(()=>{const s=state();if(s?.db){clearInterval(wait);db=s.db;user=s.user||null;controls();}else if(++attempts>100)clearInterval(wait);},250);
})();