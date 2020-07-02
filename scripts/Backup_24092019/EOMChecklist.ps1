param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname,
    [Parameter(Mandatory = $true)]
    [Validateset("MemoryStatus","DiskStatus","RebootStatus","IISRecycleStatus")]
    [string]$Status
)

Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzureRmSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$servers = @()

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg" }
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg" }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg" }
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg" }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg" }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg" }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg" }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg" }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg" }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg" }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg" }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg" }
}
 
$vmss = Get-AzureRmVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

 
for ( $i = 0; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzureRmVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    $servers += "$servername.hrbl.net"
}

Function Check-Memory {
    $memoryCollection = @()
    foreach($computer in $servers)
    {
        $os = (Get-Ciminstance Win32_OperatingSystem -ComputerName $computer)
        $pctFree = [math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2)
        if ($pctFree -ge 45) {
            $Status = "OK"
        }
        elseif ($pctFree -ge 25 ) {
            $Status = "Warning"
        }
        else {
            $Status = "Critical"
        } 
 
        $memory = $os | Select-Object -Property @{n='Server Name' ;e={$os.PSComputerName}},@{n='Free Memory (%)' ;e={"{0:n2}" -f ([math]::Round(($os.FreePhysicalMemory/$os.TotalVisibleMemorySize)*100,2))}},@{n='Free Memory (GB)' ;e={"{0:n2}" -f ([math]::Round($_.FreePhysicalMemory/1mb,2))}}, `
        @{n='Available Memory (GB)' ;e={"{0:n2}" -f ([int]($_.TotalVisibleMemorySize/1mb))}},@{n="Status" ;e={$Status}} #| Where-Object {[decimal]$_.'Free Memory (%)' -lt [decimal]$memoryThreshold}
        $memoryCollection += $memory
    }
    $memoryCollection | Format-Table
}

Function Check-DiskSpace {
    $diskCollection = @()
        foreach($computer in $servers)
        {
            $os = (Get-WMIObject -ComputerName $computer Win32_LogicalDisk)
            for($i=0; $i -lt $os.count; $i=$i+1)
            {
                if($os[$i].DriveType -eq 3 -and $os[$i].VolumeName -ne "PageFile")
                {
                    $pctFree = [math]::Round($os[$i].freespace/$os[$i].size*100,2)
                    if ($pctFree -ge 45) {
                        $Status = "OK"
                    }
                    elseif ($pctFree -ge 25 ) {
                        $Status = "Warning"
                    }
                    else {
                        $Status = "Critical"
                    }
                    $disk = $os[$i] | select @{n='Server Name' ;e={$_.__SERVER}}, @{n='Drive Name' ;e={$_.Name}} , @{n='Total Space (GB)' ;e={"{0:n2}" -f ($_.size/1gb)}},@{n='Free Space (GB)';e={"{0:n2}" -f ($_.freespace/1gb)}},`
                     @{n='Free Space (%)';e={"{0:n2}" -f ($_.freespace/$_.size*100)}},@{n='Status' ;e={$Status}} #| Where-Object {[decimal]$_.'Free Space (%)' -lt [decimal]$diskThreshold}
                    $diskCollection += $disk
                }
            }
        }
    $diskCollection | Format-Table
}

Function Check-IISResetStatus {
    $resetCollection = @()
    foreach($computer in $servers)
    {
        #Event ID 3201 for IIS start and Event ID 3202 for IIS stop
        $getIISReset = (Get-EventLog -LogName System -ComputerName $computer -Newest 10000  | Where-Object { $_.EventID -Like "3201"}  | select -First 1 | Select-Object -Property TimeWritten)
        $getResetTime = $getIISReset.TimeWritten.ToString("dd-MM-yyyy hh:mm:ssss")
 
        $reset = $getResetTime | Select-Object -Property @{n='Server Name' ;e={$computer}},@{n='Last IIS Refresh Time' ;e={$getResetTime}}
        $reset
        #$resetCollection += $reset
    }
    #$resetFragment = $resetCollection | Format-Table
}

Function Check-RebootStatus {
    $rebootCollection = @()
        foreach($computer in $servers)
        {
            $os = (Get-CimInstance -ClassName win32_operatingsystem -ComputerName $computer)
            $reboot = $os | select @{n='Server Name' ;e={$_.csname}}, @{n='Last Boot Time' ;e={$_.lastbootuptime}}
            $reboot
            #$rebootCollection += $reboot           
        }
    #$rebootCollection | Format-Table
}

switch ($Status) {
    "MemoryStatus" { Check-Memory }
    "DiskStatus" { Check-DiskSpace }
    "RebootStatus" { Check-RebootStatus }
    "IISRecycleStatus" { Check-IISResetStatus }
}