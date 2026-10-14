const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('zm',{update:()=>ipcRenderer.invoke('zm-update'),quit:()=>ipcRenderer.send('zm-quit'),version:()=>ipcRenderer.invoke('zm-version')});
