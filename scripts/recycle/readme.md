# Application Pool recycle

Two main files, recycle_farm and recycle_servers

## Usage Recycle Farm
```
recycle_farm.ps1 -scaleset $scaleset -port $port -tier [web|svc]
```
## Usage Recycle Servers
```
recycle_servers.ps1 -servers $servers -port $port
```

--------------------------------------------------------------------
https://tfs.dev.myhrbl.com/tfs/MTS/DevOps/_git/OpsTools?path=%2FPowershellScripts%2FIIS%2Frecycle&version=GBmaster
[12:59 PM] Daniel Lopez

C:\users\temp\Desktop\recycle_farm.ps1 -scaleset "zuswpsssg" -port 8235 -tier svc
Start-Sleep 15
C:\users\temp\Desktop\recycle_farm.ps1 -scaleset "zuswpsssb" -port 8235 -tier svc
Start-Sleep 15
C:\users\temp\Desktop\recycle_farm.ps1 -scaleset "zus2psssg" -port 8235 -tier svc
Start-Sleep 15
C:\users\temp\Desktop\recycle_farm.ps1 -scaleset "zus2psssb" -port 8235 -tier svc
