const headers = {'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff'};
const json=(data,status=200,extra={})=>new Response(JSON.stringify(data),{status,headers:{...headers,...extra}});
const day=86400000;
const digest=async s=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(s)))).map(x=>x.toString(16).padStart(2,'0')).join('');
const randomKey=()=> 'panther-y'+String(crypto.getRandomValues(new Uint32Array(1))[0] % 100000000).padStart(8,'0');
async function session(req,env){
 const token=/panther_session=([^;]+)/.exec(req.headers.get('Cookie')||'')?.[1];
 if(!token)return false;
 const r=await env.DB.prepare('SELECT expires_at FROM sessions WHERE token_hash=?').bind(await digest(token)).first();
 return !!r && r.expires_at>Date.now();
}
async function handle(req,env){
 const path=new URL(req.url).pathname;
 if(path==='/' || path==='/index.html')return new Response("<!doctype html><html lang=\"es\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"><title>Panther iOS · Servidor de prueba</title><style>\n:root{color-scheme:dark;font-family:system-ui,-apple-system,sans-serif}*{box-sizing:border-box}body{margin:0;background:radial-gradient(ellipse at top,#172440,#080b13 65%);color:#e8ecf5;min-height:100vh}.wrap{max-width:920px;margin:auto;padding:30px 18px}header{display:flex;justify-content:space-between;align-items:center;gap:15px;margin-bottom:35px}h1{font-size:clamp(26px,5vw,42px);margin:4px 0}h2{font-size:20px}small,.muted{color:#9ba9c0}.tag{color:#83e3b0;border:1px solid #37634d;border-radius:30px;padding:7px 12px;font-size:12px}.card{background:#151c2bcc;border:1px solid #344057;border-radius:18px;padding:22px;margin-bottom:20px;box-shadow:0 10px 30px #0003}.grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px}.metric{background:#0e1523;border-radius:12px;padding:18px}.metric b{font-size:28px;display:block}.metric span{font-size:12px;color:#a6b4ca}input,textarea{background:#0b1120;border:1px solid #44516a;border-radius:9px;color:white;padding:12px;width:100%;font:inherit}textarea{min-height:80px;resize:vertical}label{display:block;margin:10px 0 6px;color:#c5cee0;font-size:14px}button{border:0;border-radius:10px;background:#466bea;color:white;padding:12px 18px;cursor:pointer;font-weight:650}button.secondary{background:#303c54}button.danger{background:#673442}button:disabled{opacity:.5}button:hover{filter:brightness(1.12)}.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:16px}.patch{padding:16px;border:1px solid #344057;border-radius:12px;margin:12px 0}.patch-top{display:flex;align-items:center;justify-content:space-between;gap:10px}.patch-top b{overflow-wrap:anywhere}.error{color:#ff9a9a}.success{color:#86e8b5}#dashboard{display:none}@media(max-width:640px){.grid{grid-template-columns:repeat(2,1fr)}header{align-items:start;flex-direction:column}}\n</style></head><body><div class=\"wrap\"><header><div><small>SERVIDOR INDEPENDIENTE · MODO PRUEBA</small><h1>🐈‍⬛ Panther <span style=\"color:#7ea5ff\">iOS</span></h1><span class=\"muted\">Panel de control de claves y patches</span></div><span class=\"tag\">● Consola local</span></header>\n<section class=\"card\" id=\"login\"><h2>Acceso de administrador</h2><p class=\"muted\">Introduce la clave de administrador para administrar los patches. No publiques esta consola sin HTTPS.</p><form id=\"loginForm\"><label for=\"secret\">Clave</label><input id=\"secret\" type=\"password\" autocomplete=\"current-password\" required><div class=\"actions\"><button>Entrar al panel</button></div></form><p id=\"loginMsg\" class=\"error\" role=\"status\"></p></section>\n<div id=\"dashboard\"><section class=\"card\"><div class=\"patch-top\"><h2>Claves de prueba</h2><button class=\"secondary\" id=\"refresh\">Actualizar</button></div><div class=\"grid\"><div class=\"metric\"><b id=\"total\">—</b><span>Total</span></div><div class=\"metric\"><b id=\"unused\">—</b><span>Sin activar</span></div><div class=\"metric\"><b id=\"active\">—</b><span>Activas</span></div><div class=\"metric\"><b id=\"expired\">—</b><span>Vencidas</span></div></div><p class=\"muted\">Cada clave Panther dura 30 días desde su primera activación y se vincula al identificador proporcionado por la app.</p><div class=\"actions\"><label for=\"quantity\">Generar claves (máximo 10,000 por lote)</label><input id=\"quantity\" type=\"number\" min=\"1\" max=\"10000\" value=\"100\" style=\"max-width:150px\"><button type=\"button\" id=\"generate\">Generar y descargar TXT</button></div><p id=\"genMsg\" role=\"status\"></p><details><summary>Restablecer una clave (solo pruebas)</summary><label for=\"resetKey\">Clave Panther</label><input id=\"resetKey\" placeholder=\"panther-y12345678\"><div class=\"actions\"><button class=\"danger\" id=\"reset\" type=\"button\">Desvincular y reiniciar 30 días</button></div></details></section>\n<section class=\"card\"><div class=\"patch-top\"><h2>Patches publicados</h2><button id=\"add\" class=\"secondary\">+ Nuevo patch</button></div><p class=\"muted\">Edita el catálogo que la aplicación consulta en línea. Este panel no instala ni ejecuta archivos de patch.</p><div id=\"patches\"></div><div class=\"actions\"><button id=\"save\">Guardar cambios en el servidor</button><button id=\"logout\" class=\"secondary\">Cerrar sesión</button></div><p id=\"msg\" role=\"status\"></p></section></div><small>Panel de pruebas · Sin conexión a Lovable · Requiere alojamiento para uso entre teléfonos</small></div>\n<script>\nconst $=id=>document.getElementById(id);let patches=[];\nasync function req(path,method='GET',body){let r=await fetch(path,{method,credentials:'same-origin',headers:{'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});let d=await r.json();if(!r.ok)throw Error(d.error||'Error de servidor');return d}\nfunction show(ok){$('login').style.display=ok?'none':'block';$('dashboard').style.display=ok?'block':'none'}\nfunction render(){let el=$('patches');el.replaceChildren();patches.forEach((p,i)=>{let wrap=document.createElement('div');wrap.className='patch';let top=document.createElement('div');top.className='patch-top';let name=document.createElement('b');name.textContent=p.name;let del=document.createElement('button');del.className='danger';del.textContent='Eliminar';del.onclick=()=>{patches.splice(i,1);render()};top.append(name,del);wrap.append(top);for(let [field,title] of [['id','ID'],['name','Nombre'],['description','Descripción']]){let label=document.createElement('label');label.textContent=title;let input=document.createElement(field==='description'?'textarea':'input');input.value=p[field];input.oninput=()=>{p[field]=input.value;if(field==='name')name.textContent=input.value};wrap.append(label,input)}let label=document.createElement('label');let check=document.createElement('input');check.type='checkbox';check.style.width='auto';check.checked=p.enabled;check.onchange=()=>p.enabled=check.checked;label.append(check,document.createTextNode(' Habilitado'));wrap.append(label);el.append(wrap)})}\nasync function load(){try{let d=await req('/admin/state');show(true);for(let k of ['total','unused','active','expired'])$(k).textContent=d.keys[k];patches=d.patches;render()}catch(e){show(false)}}\n$('loginForm').onsubmit=async e=>{e.preventDefault();try{await req('/admin/login','POST',{key:$('secret').value});$('secret').value='';$('loginMsg').textContent='';await load()}catch(err){$('loginMsg').textContent=err.message}};\n$('refresh').onclick=load;$('add').onclick=()=>{patches.push({id:'nuevo_'+Date.now(),name:'Nuevo patch',description:'',enabled:true});render()};\n$('save').onclick=async()=>{try{await req('/admin/patches','POST',{patches});$('msg').className='success';$('msg').textContent='Catálogo guardado correctamente';await load()}catch(e){$('msg').className='error';$('msg').textContent=e.message}};\n$('generate').onclick=async()=>{try{let d=await req('/admin/generate-keys','POST',{count:Number($('quantity').value)});let blob=new Blob([d.keys.join('\\n')+'\\n'],{type:'text/plain'});let url=URL.createObjectURL(blob);let a=document.createElement('a');a.href=url;a.download='panther-keys-'+Date.now()+'.txt';a.click();setTimeout(()=>URL.revokeObjectURL(url),2000);$('genMsg').textContent=d.count+' claves generadas. Guarda el TXT en privado.';await load()}catch(e){$('genMsg').textContent=e.message}};\n$('reset').onclick=async()=>{if(!confirm('¿Restablecer esta clave y permitir que se active en otro dispositivo?'))return;try{await req('/admin/reset-key','POST',{key:$('resetKey').value.trim()});$('resetKey').value='';await load();alert('Clave restablecida')}catch(e){alert(e.message)}};\n$('logout').onclick=async()=>{await req('/admin/logout','POST',{});show(false)};load();\n</script></body></html>\n",{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Content-Security-Policy':"default-src 'self'; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'"}});
 if(path==='/health')return json({ok:true,service:'Panther Cloudflare test'});
 if(req.method==='GET' && path==='/admin/state'){
  if(!await session(req,env))return json({error:'login required'},401);
  const s=await env.DB.prepare("SELECT COUNT(*) total, SUM(CASE WHEN activated_at IS NULL THEN 1 ELSE 0 END) unused, SUM(CASE WHEN activated_at IS NOT NULL AND activated_at > ? THEN 1 ELSE 0 END) active, SUM(CASE WHEN activated_at IS NOT NULL AND activated_at <= ? THEN 1 ELSE 0 END) expired FROM license_keys").bind(new Date(Date.now()-30*day).toISOString(),new Date(Date.now()-30*day).toISOString()).first();
  const p=await env.DB.prepare('SELECT * FROM patches').all();
  return json({keys:{total:s.total||0,unused:s.unused||0,active:s.active||0,expired:s.expired||0},patches:p.results.map(x=>({...x,enabled:!!x.enabled}))});
 }
 if(req.method!=='POST')return json({error:'not found'},404);
 let data;try{if(Number(req.headers.get('Content-Length')||0)>65536)throw Error();data=await req.json();if(!data||typeof data!=='object'||Array.isArray(data))throw Error()}catch{return json({error:'invalid JSON'},400)}
 if(path==='/admin/login'){
  if(!env.ADMIN_KEY || data.key!==env.ADMIN_KEY)return json({error:'clave incorrecta'},403);
  const token=crypto.randomUUID()+crypto.randomUUID();
  await env.DB.prepare('INSERT INTO sessions(token_hash,expires_at) VALUES(?,?)').bind(await digest(token),Date.now()+3600000).run();
  return json({ok:true},200,{'Set-Cookie':`panther_session=${token}; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=3600`});
 }
 if(path==='/admin/logout'){
  const token=/panther_session=([^;]+)/.exec(req.headers.get('Cookie')||'')?.[1];
  if(token)await env.DB.prepare('DELETE FROM sessions WHERE token_hash=?').bind(await digest(token)).run();
  return json({ok:true},200,{'Set-Cookie':'panther_session=; HttpOnly; Secure; SameSite=Strict; Path=/; Max-Age=0'});
 }
 if(path.startsWith('/admin/')){
  if(!await session(req,env))return json({error:'login required'},401);
  if(req.headers.get('Origin')!==new URL(req.url).origin)return json({error:'origin mismatch'},403);
  if(path==='/admin/generate-keys'){
   const n=data.count;if(!Number.isInteger(n)||n<1||n>10000)return json({error:'Cantidad entre 1 y 10000'},400);
   const keys=[];let tries=0;
   while(keys.length<n && tries++<n*10){
    const key=randomKey();
    const r=await env.DB.prepare('INSERT OR IGNORE INTO license_keys(key) VALUES(?)').bind(key).run();
    if(r.meta.changes)keys.push(key);
   }
   return json({keys,count:keys.length});
  }
  if(path==='/admin/reset-key'){
   const r=await env.DB.prepare('UPDATE license_keys SET device=NULL,activated_at=NULL WHERE key=?').bind(data.key).run();
   return r.meta.changes?json({ok:true}):json({error:'key not found'},404);
  }
  if(path==='/admin/patches'){
   if(!Array.isArray(data.patches)||data.patches.length>100)return json({error:'invalid patches'},400);
   const ps=data.patches,ids=new Set();
   for(const p of ps){
    if(!p||typeof p.id!=='string'||!/^[a-zA-Z0-9_-]{1,64}$/.test(p.id)||ids.has(p.id)||typeof p.name!=='string'||p.name.length<1||p.name.length>100||typeof p.description!=='string'||p.description.length>500||typeof p.enabled!=='boolean')return json({error:'invalid patch'},400);
    ids.add(p.id);
   }
   await env.DB.prepare('DELETE FROM patches').run();
   for(const p of ps)await env.DB.prepare('INSERT INTO patches(id,name,description,enabled) VALUES(?,?,?,?)').bind(p.id,p.name,p.description,p.enabled?1:0).run();
   return json({ok:true});
  }
  return json({error:'not found'},404);
 }
 if(path==='/v1/activate'||path==='/v1/patches'){
  if(typeof data.key!=='string'||typeof data.device_id!=='string'||data.device_id.length<8||data.device_id.length>128)return json({error:'invalid request'},400);
  let role='patches';
  if(data.key===env.ADMIN_KEY && env.ADMIN_KEY)role='admin';
  else {
   const now=new Date().toISOString();
   // Atomic first activation; one key can be claimed by only one device.
   await env.DB.prepare('UPDATE license_keys SET device=?,activated_at=? WHERE key=? AND device IS NULL AND activated_at IS NULL').bind(data.device_id,now,data.key).run();
   const record=await env.DB.prepare('SELECT device,activated_at FROM license_keys WHERE key=?').bind(data.key).first();
   if(!record)return json({error:'invalid key'},403);
   if(record.device!==data.device_id)return json({error:'key bound to another device'},403);
   if(Date.now()-Date.parse(record.activated_at)>=30*day)return json({error:'key expired'},403);
  }
  if(path==='/v1/activate')return json({role});
  const p=await env.DB.prepare('SELECT * FROM patches').all();
  return json({patches:p.results.map(x=>({...x,enabled:!!x.enabled}))});
 }
 return json({error:'not found'},404);
}
export default {fetch(req,env){return handle(req,env).catch(()=>json({error:'server error'},500))}};