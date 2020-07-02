param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

$servers = New-Object System.Collections.Generic.List[System.Object]

function GetInstances{
    param
    (
    [string]$vmssName,
    [string]$rgName
    )
    
    $VMs = Get-AzureRmVmssVM -ResourceGroupName $rgName -name $vmssName
    $servers = New-Object System.Collections.Generic.List[System.Object]
    
    foreach( $vmInstance in $VMs ) {
        $vmName = $vmInstance.OSProfile.ComputerName
        $status = (Get-AzureRmVmssVM -InstanceView  -ResourceGroupName $rgName -name $vmssName  -InstanceId $vmInstance.InstanceId).Statuses.DisplayStatus[1]
        if ($status -eq "VM running") {
                $servers.Add($vmName)
              Write-Host "Status: $vmName" $status
            }
            else {
                Write-Host "Status: $vmName" $status
            }
    
        }
    
        return $servers
    }

Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"

$rgName = ""
$Date = (Get-Date).ToString('dd-MM-yyyy-hhmm')

switch ($vmssname) {
    "zuswpwssb" { $rgName = "zusw-prod-web-rg"}
    "zuswpwssg" { $rgName = "zusw-prod-web-rg"}
}

$servers  = GetInstances -vmssName $vmssName -rgName $rgName

$scriptblock = {
        Import-Module WebAdministration
        $appPoolName = "ArticlesManager.Web"
        $pvvalue = Get-ItemProperty IIS:\AppPools\$appPoolName -Name recycling.periodicrestart.privateMemory.Value
        Write-Host "$env:COMPUTERNAME has $appPoolName with Private memory set to $pvvalue"

    }

$servers | % {
Invoke-Command -scriptblock $scriptblock -computername $_
}