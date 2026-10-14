const {app,BrowserWindow,protocol,net,globalShortcut,Menu}=require('electron');
const path=require('path'),{pathToFileURL}=require('url');
protocol.registerSchemesAsPrivileged([{scheme:'zm',privileges:{standard:true,secure:true,supportFetchAPI:true,corsEnabled:true,stream:true}}]);
app.commandLine.appendSwitch('ignore-gpu-blocklist');
app.commandLine.appendSwitch('enable-gpu-rasterization');
app.commandLine.appendSwitch('disable-frame-rate-limit');
const GAME=path.join(__dirname,'game');
app.whenReady().then(()=>{
  protocol.handle('zm',req=>{
    let p=decodeURIComponent(new URL(req.url).pathname);if(p==='/'||!p)p='/index.html';
    const f=path.normalize(path.join(GAME,p));
    if(!f.startsWith(GAME))return new Response('no',{status:403});
    return net.fetch(pathToFileURL(f).toString());
  });
  Menu.setApplicationMenu(null);
  const w=new BrowserWindow({fullscreen:true,autoHideMenuBar:true,backgroundColor:'#000',title:'Zona Muerta',webPreferences:{contextIsolation:true,backgroundThrottling:false}});
  w.loadURL('zm://juego/index.html');
  w.webContents.on('before-input-event',(e,i)=>{if(i.type==='keyDown'&&i.key==='F11'){w.setFullScreen(!w.isFullScreen());e.preventDefault()}});
});
app.on('window-all-closed',()=>app.quit());
