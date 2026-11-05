/* MARS LAND shared Supabase client. Publishable key only; never put service_role in browser. */
(function(){
'use strict';
const CONFIG={url:'https://tppgfxsdeuujidcjnfdl.supabase.co',key:'sb_publishable_xQ0_NkSu2TMeIyJnAE94kw_WWQT2T3E'};
const $=id=>document.getElementById(id);
const S={db:null,user:null,channel:null,reconnectTimer:null,refreshTimer:null,reconnectAttempt:0,lifecycleBound:false,presenceKey:null,onlineCount:0,parcels:[],claims:[],structures:[],events:[],mlcMarket:[]};
function status(message,ok=false){const el=$('worldServerStatus');if(el){el.textContent=(ok?'● ONLINE · ':'○ SERVER · ')+message;el.style.color=ok?'#a8e4bd':'#e9bd8d';}}
function emitAuth(){document.dispatchEvent(new CustomEvent('mars-auth-state',{detail:{user:S.user}}));}
function authView(){const el=$('worldServerUser');if(el)el.textContent=S.user?'สมาชิกออนไลน์: '+(S.user.email||S.user.id):'ยังไม่ได้เข้าสู่ระบบ';const out=$('worldServerLogout');if(out)out.style.display=S.user?'block':'none';}
function counts(){const el=$('worldServerCounts');if(el)el.textContent='🌐 ผู้เชื่อมต่อทั่วโลก '+S.onlineCount+' เซสชัน · พื้นที่จอง '+S.claims.length+' · อาคาร '+S.structures.length;}
function presenceKey(){if(S.presenceKey)return S.presenceKey;try{S.presenceKey=sessionStorage.getItem('mars-presence-key');if(!S.presenceKey){S.presenceKey=globalThis.crypto?.randomUUID?.()||('guest-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2));sessionStorage.setItem('mars-presence-key',S.presenceKey);}}catch(_){S.presenceKey='guest-'+Date.now().toString(36)+'-'+Math.random().toString(36).slice(2);}return S.presenceKey;}
async function trackPresence(channel){try{await channel.track({client_type:S.user?'member':'guest',last_seen_at:new Date().toISOString()});}catch(error){console.warn('LOCAL MARS presence tracking:',error);}}
async function refresh(){
 if(!S.db)return;
 const [p,a,b,c]=await Promise.all([
  S.db.from('world_parcels').select('id,latitude,longitude,area_sqm,terrain,resource,base_price,sale_price_usd,is_for_sale'),
  S.db.from('world_claims').select('parcel_id,owner_id,claimed_at'),
  S.db.from('world_structures').select('id,parcel_id,owner_id,structure_type,level,created_at'),
  S.db.from('world_events').select('id,event_type,parcel_id,payload,created_at').order('created_at',{ascending:false}).limit(30)
 ]);
 if(p.error && /sale_price_usd|is_for_sale|column/i.test(p.error.message||'')){const legacy=await S.db.from('world_parcels').select('id,latitude,longitude,area_sqm,terrain,resource,base_price');if(!legacy.error)p={data:(legacy.data||[]).map(row=>({...row,sale_price_usd:null,is_for_sale:false})),error:null};}
 const err=p.error||a.error||b.error||c.error;if(err){status(err.message);return {error:err};}
 S.parcels=p.data||[];S.claims=a.data||[];S.structures=b.data||[];S.events=c.data||[];const market=await S.db.from('mars_mlc_parcel_market').select('parcel_id,price_mlc,is_listed');S.mlcMarket=market.error?[]:(market.data||[]);if(market.error)console.warn('MLC parcel market is not ready:',market.error.message);counts();
 document.dispatchEvent(new CustomEvent('mars-world-updated',{detail:{parcels:S.parcels,claims:S.claims,structures:S.structures,events:S.events,mlcMarket:S.mlcMarket,user:S.user}}));
 return {data:{parcels:S.parcels,claims:S.claims,structures:S.structures,events:S.events,mlcMarket:S.mlcMarket}};
}
function scheduleRefresh(){
 if(S.refreshTimer)clearTimeout(S.refreshTimer);
 S.refreshTimer=setTimeout(()=>{S.refreshTimer=null;refresh().catch(err=>console.warn('LOCAL MARS refresh failed:',err));},180);
}
function scheduleReconnect(){
 if(!S.db||S.reconnectTimer)return;
 const delay=Math.min(1000*Math.pow(2,Math.min(S.reconnectAttempt,5)),30000);
 S.reconnectAttempt++;
 status('Realtime หลุด · กำลังเชื่อมต่อใหม่ใน '+Math.ceil(delay/1000)+' วินาที');
 S.reconnectTimer=setTimeout(()=>{S.reconnectTimer=null;if(S.db)subscribe();},delay);
}
function bindLifecycle(){
 if(S.lifecycleBound)return;
 S.lifecycleBound=true;
 window.addEventListener('online',()=>{S.reconnectAttempt=0;subscribe();});
 document.addEventListener('visibilitychange',()=>{
  if(document.visibilityState!=='visible'||!S.db)return;
  if(!S.channel||S.channel.state!=='joined')subscribe();
  else scheduleRefresh();
 });
}
function subscribe(){
 if(!S.db)return;
 if(S.reconnectTimer){clearTimeout(S.reconnectTimer);S.reconnectTimer=null;}
 const previous=S.channel;S.channel=null;
 if(previous)S.db.removeChannel(previous).catch(err=>console.warn('LOCAL MARS channel cleanup:',err));
 const channel=S.db.channel('mars-land-global',{config:{presence:{key:presenceKey()}}})
 .on('presence',{event:'sync'},()=>{if(S.channel!==channel)return;S.onlineCount=Object.keys(channel.presenceState()).length;counts();})
 .on('postgres_changes',{event:'*',schema:'public',table:'world_parcels'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'world_claims'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'world_structures'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'world_events'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'mars_mlc_parcel_market'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'mars_city_national_flags'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'mars_cities'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'mars_city_buildings'},scheduleRefresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'mars_city_resources'},scheduleRefresh);
 S.channel=channel;
 channel.subscribe(st=>{
  if(S.channel!==channel)return;
  if(st==='SUBSCRIBED'){
   S.reconnectAttempt=0;status('เชื่อมต่อเครือข่ายดาวอังคารทั่วโลกแล้ว',true);trackPresence(channel);scheduleRefresh();
  }else if(st==='CHANNEL_ERROR'||st==='TIMED_OUT'||st==='CLOSED'){
   scheduleReconnect();
  }
 });
}
async function connect(){
 if(!window.supabase){status('โหลด Supabase client ไม่สำเร็จ');return {error:'client_missing'};}
 S.db=window.supabase.createClient(CONFIG.url,CONFIG.key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});bindLifecycle();
 const {data,error}=await S.db.auth.getSession();if(error){status(error.message);return {error};}
 S.user=data.session?.user||null;authView();emitAuth();subscribe();if(S.user)walletBalances();
 S.db.auth.onAuthStateChange((_event,session)=>{S.user=session?.user||null;authView();emitAuth();if(S.channel)trackPresence(S.channel);refresh();if(S.user)walletBalances();});
 return {data:{user:S.user}};
}
async function auth(mode){
 if(!S.db)return {error:{message:'เซิร์ฟเวอร์ยังไม่พร้อม'}};
 const email=($('email')?.value||'').trim(),password=$('password')?.value||'',name=($('username')?.value||'').trim();
 if(!email||password.length<8)return {error:{message:'กรอกอีเมลและรหัสผ่านอย่างน้อย 8 ตัวอักษร'}};
 let result;
 if(mode==='signup'){
  // Return confirmed users to the deployed GitHub Pages app, never the local Vite server.
  const emailRedirectTo=new URL('./',window.location.href).href;
  result=await S.db.auth.signUp({email,password,options:{emailRedirectTo,data:{display_name:name||'Explorer'}}});
 }
 else result=await S.db.auth.signInWithPassword({email,password});
 if(result.error){status(result.error.message);return {error:result.error};}
 S.user=result.data.session?.user||null;authView();emitAuth();
 if(S.user&&name){const p=await S.db.from('mars_profiles').upsert({user_id:S.user.id,display_name:name,updated_at:new Date().toISOString()},{onConflict:'user_id'});if(p.error){status('เข้าสู่ระบบแล้ว แต่บันทึกชื่อไม่สำเร็จ: '+p.error.message);return {error:p.error};}}
 if(mode==='signup'&&!result.data.session){status('สมัครแล้ว กรุณายืนยันอีเมลก่อนเข้าสู่ระบบ');return {data:{needsEmailConfirmation:true}};}
 status(mode==='signup'?'สมัครสมาชิกออนไลน์สำเร็จ':'เข้าสู่ระบบสำเร็จ',true);await refresh();return {data:{user:S.user}};
}
async function logout(){if(S.db)await S.db.auth.signOut();S.user=null;authView();emitAuth();status('ออกจากระบบแล้ว');}
async function claim(parcel){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อนซื้อพื้นที่'}};
 return {error:{message:'ปิดการชำระ PromptPay สำหรับการซื้อพื้นที่ใหม่แล้ว กรุณาใช้ USD Checkout'}};
}
async function claimUsd(parcel){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อนซื้อพื้นที่'}};
 const {data,error}=await S.db.functions.invoke('create-usd-checkout',{body:{parcel_id:parcel}});
 if(error){const message=error.message||'ยังไม่สามารถเริ่ม USD Checkout ได้';status(message);return {error:{message}};}
 if(!data?.checkout_url||String(data.currency).toLowerCase()!=='usd'){const message=data?.error||'ข้อมูล USD Checkout ไม่ถูกต้อง';status(message);return {error:{message}};}
 status('กำลังเปิดหน้า Stripe USD Checkout…',true);
 window.location.assign(data.checkout_url);
 return {data};
}
async function build(parcel,type){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อนก่อสร้าง'}};
 if(!parcel||!type)return {error:{message:'ข้อมูลแปลงหรือประเภทอาคารไม่ครบ'}};
 const r=await S.db.rpc('build_world_structure',{p_parcel_id:parcel,p_type:type});
 if(r.error){status(r.error.message);return r;}
 if(!r.data?.ok){const error={message:'ฐานข้อมูลยังไม่ยืนยันการก่อสร้าง'};status(error.message);return {error};}
 status('บันทึกอาคารลงฐานข้อมูลออนไลน์บน '+parcel+' แล้ว',true);
 const synced=await refresh();if(synced?.error)return {data:r.data,syncWarning:synced.error.message};
 return r;
}
async function m003Access(action,password='',confirmPassword=''){if(!S.db||!S.user)return {error:{message:'Sign in is required'}};const {data,error}=await S.db.functions.invoke('m003-access',{body:{action,password,confirm_password:confirmPassword}});if(error)return {error:{message:data?.error||error.message||'M-003 security request failed'}};if(data?.error)return {error:{message:data.error}};return {data};}

async function walletBalances(){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อน'}};
 const {data,error}=await S.db.rpc('mars_wallet_balances');
 if(error)return {error};
 const balances={credits:0,energy:0,metal:0,mlc:0};
 (data||[]).forEach(row=>{if(Object.prototype.hasOwnProperty.call(balances,row.resource))balances[row.resource]=Number(row.balance)||0;});
 document.dispatchEvent(new CustomEvent('mars-wallet-updated',{detail:balances}));
 return {data:balances};
}
async function grantMlcStarter(){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อน'}};
 const result=await S.db.rpc('mars_wallet_mlc_grant_starter');
 if(result.error)return result;
 return await walletBalances();
}
async function transferMlc(recipient,amount){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อน'}};
 const id=globalThis.crypto?.randomUUID?.()||('tx'+Date.now()+Math.random().toString(36).slice(2));
 const result=await S.db.rpc('mars_wallet_mlc_transfer',{p_recipient:recipient,p_amount:Number(amount),p_idempotency_key:'mlc:'+id});
 if(result.error)return result;
 const refreshed=await walletBalances();
 return refreshed.error?{data:result.data,syncWarning:refreshed.error.message}:result;
}


async function reserveParcel(parcel){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบก่อนจองแปลง'}};
 const result=await S.db.rpc('mars_mlc_reserve_parcel',{p_parcel_id:parcel});
 if(result.error)return result;
 const synced=await refresh();
 return synced?.error?{data:result.data,syncWarning:synced.error.message}:result;
}
async function purchaseParcel(parcel){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบก่อนซื้อแปลง'}};
 const result=await S.db.rpc('mars_mlc_purchase_parcel',{p_parcel_id:parcel});
 if(result.error)return result;
 const [synced,wallet]=await Promise.all([refresh(),walletBalances()]);
 return {data:result.data,syncWarning:synced?.error?.message||wallet?.error?.message||null};
}
async function setParcelListing(parcel,isListed,price){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบก่อนจัดการประกาศขาย'}};
 const result=await S.db.rpc('mars_mlc_set_parcel_listing',{
  p_parcel_id:parcel,p_is_listed:!!isListed,
  p_price_mlc:isListed?Number(price):null
 });
 if(result.error)return result;
 const synced=await refresh();
 return synced?.error?{data:result.data,syncWarning:synced.error.message}:result;
}

window.MarsWorldServer={connect,auth,logout,refresh,claim,claimUsd,build,m003Access,walletBalances,grantMlcStarter,transferMlc,reserveParcel,purchaseParcel,setParcelListing,getState:()=>({user:S.user,parcels:S.parcels,claims:S.claims,structures:S.structures,events:S.events,mlcMarket:S.mlcMarket,db:S.db})};
document.addEventListener('DOMContentLoaded',connect);
})();