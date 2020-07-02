Param(
    [CmdletBinding()]
    [Parameter(Mandatory=$true)][array]$servers,
    [Parameter(Mandatory=$true)][int]$port
)

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

Invoke-Command -ComputerName $servers -ScriptBlock {
    $port = $args[0]

    Import-Module WebAdministration    
    
    $name = (Get-IISSite | Where-Object {$_.Bindings -like "*$port*"}).name
    $pool = (Get-ItemProperty IIS:\Sites\$name).applicationPool
    Restart-WebAppPool $pool 

} -Credential $Credential -ArgumentList $port

$endTime = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

Write-Host "StartTime: " $startTime -foregroundcolor "green"
Write-Host "EndTime  : " $endTime -foregroundcolor "green"
Write-Host "Finished servers - $servers : $port"