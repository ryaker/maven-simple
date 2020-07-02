param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

$azureAplicationId = "9e2e6e1f-121b-47f7-9d7a-98388729eb88"
$azureTenantId = "101f87a7-6d6b-4c6c-9d9c-223592a2ba50"
$azurePassword = ConvertTo-SecureString ".gyJPJpj:Kihx+Q*MgyKY3Yui2fJKo81" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($azureAplicationId , $azurePassword)
Add-AzAccount -Credential $psCred -TenantId $azureTenantId  -ServicePrincipal 

$allDataCenters = @(
    @{scaleset="zuswpwssg";resourceGroup="zusw-prod-web-rg"},
    @{scaleset="zus2pwssg";resourceGroup="zusw2-prod-web-vmss-rg"},
    @{scaleset="zeuwpwsg2";resourceGroup="zeuw-prod-web-vmss-rg"},
    @{scaleset="zseapwsg2";resourceGroup="zsea-prod-web-vmss-rg"},
    @{scaleset="zuswpwssb";resourceGroup="zusw-prod-web-rg"},
    @{scaleset="zus2pwssb";resourceGroup="zusw2-prod-web-vmss-rg"},
    @{scaleset="zeuwpwsb2";resourceGroup="zeuw-prod-web-vmss-rg"},
    @{scaleset="zseapwsb2";resourceGroup="zsea-prod-web-vmss-rg"},
    @{scaleset="zuswpsssg";resourceGroup="zusw-prod-svc-rg"},
    @{scaleset="zus2psssg";resourceGroup="zusw2-prod-svc-rg"},
    @{scaleset="zuswpsssb";resourceGroup="zusw-prod-svc-rg"},
    @{scaleset="zus2psssb";resourceGroup="zusw2-prod-svc-rg"},
    @{scaleset="zus2pwssr";resourceGroup="zusw2-prod-web-rg"}
)

function GetServers {
    param
    (
        [string]$vmssName,
        [string]$rgName
    )
    $servers = @() 
    $VMs = Get-AzVmssVM -ResourceGroupName $rgName -name $vmssName  

    foreach ( $vmInstance in $VMs ) {
        $vmName = $vmInstance.OSProfile.ComputerName
        $status= (Get-AzVmssVM -InstanceView  -ResourceGroupName $rgName -name $vmssName  -InstanceId $vmInstance.InstanceId).Statuses.DisplayStatus[1]
		
		if(($status.ToUpper() -eq "VM STARTING") -or ($status.ToUpper() -eq "STARTING"))
		{
			Write-Host "Server Status STARTING : $vmName" $status -foregroundcolor "red"
			throw "Exception VM Starting Status $vmName : $status"
		}
		
		if(-Not(($status.ToUpper() -eq "VM STOPPING") -or ($status.ToUpper() -eq "VM STOPPED")-or ($status.ToUpper() -eq "VM DEALLOCATING")-or ($status.ToUpper() -eq "VM DEALLOCATED")))
        {
            $servers += $vmName    
			Write-Host "Server Status: $vmName" $status -foregroundcolor "Green"
        }
        else
        {
            Write-Host "STOPPED STOPPING DEALLOCATED DEALLOCATING Server Status: $vmName" $status -foregroundcolor "red"
        }
    }

    return $servers
}

Write-Host "StartTime: " $(Get-Date -Format "dd/MM/yyyy HH:mm:ss" ) -foregroundcolor "green"

# Path to find .bat and .vbs files
$pathToPurge = "C:\inetpub\logs\LogFiles\*"
$allDataCenters | % {
if($_.scaleset -eq $vmssname)
{
    $scaleset = $_.scaleset
    $resourceGroup = $_.resourceGroup
    
    # Step 1: Get Servers
    $servers = GetServers -vmssName $scaleset -rgName $resourceGroup    

    # Step 2: Execute bat
   Invoke-Command -ComputerName $servers -ScriptBlock {
      Get-ChildItem –Path "c:\inetpub\logs\LogFiles\*" -Recurse | Where-Object {($_.LastWriteTime -lt (Get-Date).AddHours(-2))} | Remove-Item -Force
      Write-Output "$env:COMPUTERNAME : Cleanup of log files on Older than $((get-date).AddHours(-2)) completed..." 
      }
}
   
}

Write-Host "EndTime: " $(Get-Date -Format "dd/MM/yyyy HH:mm:ss") -foregroundcolor "green"

# Exit azure rm
Remove-AzAccount