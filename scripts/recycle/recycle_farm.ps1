Param(
    [CmdletBinding()]
    [string][Parameter(Mandatory=$true)]$scaleset,
    [Parameter(Mandatory=$true)][int]$port,
    [Parameter(Mandatory=$true)][ValidateSet("web","svc")][string]$tier
)

If($tier -eq "web"){
    #$csv = Import-Csv -Path "$($PSScriptRoot)\datacenter_web.csv"
    $csv = Import-Csv -Path "C:\rundeck\scripts\recycle\datacenter_web.csv"
}else {
    #$csv = Import-Csv -Path "$($PSScriptRoot)\datacenter_svc.csv"
    $csv = Import-Csv -Path "C:\rundeck\scripts\recycle\datacenter_svc.csv"
}

$farm = $csv | Where-Object {$_.VmScaleset -eq $scaleset}

# Grab all available ports that belong to farm base-server 
$AvailablePorts = Invoke-Command -ComputerName $farm.Base -ScriptBlock {
    Import-Module WebAdministration
    $regex = "\:\d+\:"
    ((Get-WebBinding).bindingInformation | ForEach-Object {([regex]::Match($_, $regex)).Value -replace ":",""} | Group-Object).Name
}

If ( !($port -in $AvailablePorts) ){
    throw 'Invalid port $port, verify $port exists on $($farm.Base)'
}

#Import-Module AzureRM

function GetServers {
    param
    (
        [string]$vmssName,
        [string]$rgName
    )
    $servers = @()
    $VMs = Get-AzVmssVM -ResourceGroupName $rgName -name $vmssName

    $vms | ForEach-Object {
        $vmName = $_.OSProfile.ComputerName
        $status= (Get-AzVmssVM -InstanceView  -ResourceGroupName $rgName -name $vmssName  -InstanceId $_.InstanceId).Statuses.DisplayStatus[1]

        if ($status -match 'running') {
            $servers += $vmName
        }
    }

    return $servers
}
#Run in Admin mode
$prodazureAplicationId = "9e2e6e1f-121b-47f7-9d7a-98388729eb88"
$prodazurePassword = ConvertTo-SecureString ".gyJPJpj:Kihx+Q*MgyKY3Yui2fJKo81" -AsPlainText -Force
$azureTenantId = "101f87a7-6d6b-4c6c-9d9c-223592a2ba50"

$azureAplicationId = "9e2e6e1f-121b-47f7-9d7a-98388729eb88"
$azurePassword = ConvertTo-SecureString ".gyJPJpj:Kihx+Q*MgyKY3Yui2fJKo81" -AsPlainText -Force
$azureSubscriptionId = "572e8311-5864-4e12-9268-70796994d12d"

$psCred = New-Object System.Management.Automation.PSCredential($azureAplicationId , $azurePassword)


Add-AzureRmAccount -Credential $psCred -TenantId $azureTenantId -Subscription $azureSubscriptionId -ServicePrincipal | Out-Null
$instances = GetServers -vmssName $farm.VmScaleset -rgName $farm.ResourceGroup

function GetCreds () {
    $value = "" | Select-Object -Property UserName, Password
    $value.UserName = "herbalifecorp\svc_dts_tfsbuild"
    $value.Password = "8x/A?D(G+KbPeShVkYp3s6v9y"
    return $value
}

$Creds = GetCreds
$PasswordSS = ConvertTo-SecureString $Creds.Password -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential($Creds.UserName, $PasswordSS);

$startTime = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
# Perform recycle

Invoke-Command -ComputerName $instances -ScriptBlock {
    $port = $args[0]

    Import-Module WebAdministration    
    
    $name = (Get-IISSite | Where-Object {$_.Bindings -like "*$port*"}).name
    $pool = (Get-ItemProperty IIS:\Sites\$name).applicationPool
    Restart-WebAppPool $pool 
    #Get-WebAppPoolState $pool

} -Credential $Credential -ArgumentList $port

$endTime = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

Write-Host "StartTime: " $startTime -foregroundcolor "green"
Write-Host "EndTime  : " $endTime -foregroundcolor "green"
Write-Host "Finished Farm $scaleset : $port"