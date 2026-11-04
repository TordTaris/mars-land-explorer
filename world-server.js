/* MARS LAND shared Supabase client. Publishable key only; never put service_role in browser. */
(function(){
'use strict';
const CONFIG={url:'https://tppgfxsdeuujidcjnfdl.supabase.co',key:'sb_publishable_xQ0_NkSu2TMeIyJnAE94kw_WWQT2T3E'};
const $=id=>document.getElementById(id);
const S={db:null,user:null,channel:null,claims:[],structures:[],events:[]};
function status(message,ok=false){const el=$('worldServerStatus');if(el){el.textContent=(ok?'● ONLINE · ':'○ SERVER · ')+message;el.style.color=ok?'#a8e4bd':'#e9bd8d';}}
function emitAuth(){document.dispatchEvent(new CustomEvent('mars-auth-state',{detail:{user:S.user}}));}
function authView(){const el=$('worldServerUser');if(el)el.textContent=S.user?'สมาชิกออนไลน์: '+(S.user.email||S.user.id):'ยังไม่ได้เข้าสู่ระบบ';const out=$('worldServerLogout');if(out)out.style.display=S.user?'block':'none';}
function counts(){const el=$('worldServerCounts');if(el)el.textContent='พื้นที่จอง '+S.claims.length+' · อาคาร '+S.structures.length;}
async function refresh(){
 if(!S.db)return;
 const [a,b,c]=await Promise.all([
  S.db.from('world_claims').select('parcel_id,owner_id,claimed_at'),
  S.db.from('world_structures').select('id,parcel_id,owner_id,structure_type,level,created_at'),
  S.db.from('world_events').select('id,event_type,parcel_id,payload,created_at').order('created_at',{ascending:false}).limit(30)
 ]);
 const err=a.error||b.error||c.error;if(err){status(err.message);return {error:err};}
 S.claims=a.data||[];S.structures=b.data||[];S.events=c.data||[];counts();
 document.dispatchEvent(new CustomEvent('mars-world-updated',{detail:{claims:S.claims,structures:S.structures,events:S.events,user:S.user}}));
 return {data:{claims:S.claims,structures:S.structures,events:S.events}};
}
function subscribe(){
 if(S.channel)S.db.removeChannel(S.channel);
 S.channel=S.db.channel('mars-land-global')
 .on('postgres_changes',{event:'*',schema:'public',table:'world_claims'},refresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'world_structures'},refresh)
 .on('postgres_changes',{event:'*',schema:'public',table:'world_events'},refresh)
 .subscribe(st=>{if(st==='SUBSCRIBED'){status('เชื่อมต่อโลกออนไลน์แล้ว',true);refresh();}else if(st==='CHANNEL_ERROR'||st==='TIMED_OUT')status('Realtime ขาดการเชื่อมต่อ');});
}
async function connect(){
 if(!window.supabase){status('โหลด Supabase client ไม่สำเร็จ');return {error:'client_missing'};}
 S.db=window.supabase.createClient(CONFIG.url,CONFIG.key,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
 const {data,error}=await S.db.auth.getSession();if(error){status(error.message);return {error};}
 S.user=data.session?.user||null;authView();emitAuth();subscribe();
 S.db.auth.onAuthStateChange((_event,session)=>{S.user=session?.user||null;authView();emitAuth();refresh();});
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
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อนดำเนินการ'}};
 // Paid parcel checkout is not activated yet. Never grant a parcel from the browser.
 const message='ระบบซื้อพื้นที่ผ่าน PromptPay กำลังตั้งค่าอยู่ ขณะนี้ยังไม่มีการเรียกเก็บเงินหรือโอนสิทธิ์แปลง';
 status(message);
 return {error:{message}};
}
async function build(parcel,type){
 if(!S.db||!S.user)return {error:{message:'กรุณาเข้าสู่ระบบออนไลน์ก่อนก่อสร้าง'}};
 const r=await S.db.rpc('build_world_structure',{p_parcel_id:parcel,p_type:type});if(r.error){status(r.error.message);return r;}
 status('สร้างสิ่งปลูกสร้างบน '+parcel+' แล้ว',true);await refresh();return r;
}
window.MarsWorldServer={connect,auth,logout,refresh,claim,build,getState:()=>({user:S.user,claims:S.claims,structures:S.structures,events:S.events,db:S.db})};
document.addEventListener('DOMContentLoaded',connect);
})();