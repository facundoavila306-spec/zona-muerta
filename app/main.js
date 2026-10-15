const {app,BrowserWindow,protocol,net,Menu,ipcMain}=require('electron');
const fs=require('fs'),cp=require('child_process');
const path=require('path'),{pathToFileURL}=require('url');
protocol.registerSchemesAsPrivileged([{scheme:'zm',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true,stream:true}}]);
app.commandLine.appendSwitch('ignore-gpu-blocklist');
app.commandLine.appendSwitch('enable-gpu-rasterization');
app.commandLine.appendSwitch('disable-frame-rate-limit');
const GAME=path.join(__dirname,'game');
const REPO='facundoavila306-spec/zona-muerta',VF=path.join(__dirname,'version.txt');
const localV=()=>{try{return fs.readFileSync(VF,'utf8').trim()}catch(e){return ''}};
ipcMain.handle('zm-version',()=>localV());
ipcMain.on('zm-quit',()=>app.quit());
ipcMain.handle('zm-update',async()=>{
  let sha;try{const r=await net.fetch('https://api.github.com/repos/'+REPO+'/commits/main',{headers:{Accept:'application/vnd.github.sha','User-Agent':'zona-muerta'}});if(!r.ok)throw 0;sha=(await r.text()).trim()}catch(e){return{ok:0,msg:'No hay conexión con GitHub'}}
  if(sha&&sha===localV())return{ok:1,msg:'Ya tenés la última versión'};
  if(process.platform!=='win32')return{ok:0,msg:'Actualización solo en Windows'};
  const ps="$ProgressPreference='SilentlyContinue';$t=Join-Path $env:TEMP 'zm_upd';if(Test-Path $t){Remove-Item $t -Recurse -Force};New-Item -ItemType Directory $t|Out-Null;Invoke-WebRequest 'https://github.com/"+REPO+"/archive/refs/heads/main.zip' -OutFile \"$t\\j.zip\";Expand-Archive \"$t\\j.zip\" -DestinationPath $t -Force;robocopy \"$t\\zona-muerta-main\\app\" \"$env:ZMAPP\" /E /XF version.txt /NFL /NDL /NJH /NJS|Out-Null;Remove-Item $t -Recurse -Force;exit 0";
  const ok=await new Promise(res=>cp.execFile('powershell',['-NoProfile','-Command',ps],{env:Object.assign({},process.env,{ZMAPP:__dirname}),timeout:300000},err=>res(!err)));
  if(!ok)return{ok:0,msg:'Falló la descarga, probá de nuevo'};
  try{fs.writeFileSync(VF,sha)}catch(e){}
  setTimeout(()=>{app.relaunch();app.exit(0)},1500);
  return{ok:1,msg:'Actualizado. Reiniciando…'}});
app.whenReady().then(()=>{
  protocol.handle('zm',req=>{
    let p=decodeURIComponent(new URL(req.url).pathname);if(p==='/'||!p)p='/index.html';
    const f=path.normalize(path.join(GAME,p));
    if(!f.startsWith(GAME))return new Response('no',{status:403});
    return net.fetch(pathToFileURL(f).toString());
  });
  Menu.setApplicationMenu(null);
  const w=new BrowserWindow({fullscreen:true,autoHideMenuBar:true,backgroundColor:'#000',title:'Zona Muerta',webPreferences:{preload:path.join(__dirname,'preload.js'),contextIsolation:true,backgroundThrottling:false}});
  w.loadURL('zm://juego/index.html');
  w.webContents.on('before-input-event',(e,i)=>{if(i.type==='keyDown'&&i.key==='F11'){w.setFullScreen(!w.isFullScreen());e.preventDefault()}});
});
app.on('window-all-closed',()=>app.quit());
