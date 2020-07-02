#zus2psssb000000 - C:\Program Files\Herbalife\Configuration\externalAppSettings.config
#zuswpwssb000000 - C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config\externalAppSettings.config

param(
    [Parameter(Mandatory = $true)]
    [string]$vmssname
)

Select-AzSubscription -SubscriptionName "MTS Development and QA - Prod (0602)"
#Select-AzSubscription -SubscriptionName "MTS Development and QA - Non Prod (0602)"
$vmssrg = ""
$servers = @()
$source = ""
$sourcepath = ""
$destinationpath = ""

switch ($vmssname) {
    "zuswpwssb" { $vmssrg = "zusw-prod-web-rg"; $source = "zuswpwssb000000"; $sourcepath = "\\zuswpwssb000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config" }
    "zuswpwssg" { $vmssrg = "zusw-prod-web-rg"; $source = "zuswpwssg000000"; $sourcepath = "\\zuswpwssg000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"  }
    "zus2pwssb" { $vmssrg = "zusw2-prod-web-vmss-rg"; $source = "zuswpwssg000000"; $sourcepath = "\\zuswpwssg000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"  }
    "zus2pwssg" { $vmssrg = "zusw2-prod-web-vmss-rg"; $source = "zus2pwssg000000"; $sourcepath = "\\zus2pwssg000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"  }
    "Zeuwpwsg2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $source = "Zeuwpwsg2000000"; $sourcepath = "\\Zeuwpwsg2000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"  }
    "Zeuwpwsb2" { $vmssrg = "zeuw-prod-web-vmss-rg"; $source = "Zeuwpwsb2000000"; $sourcepath = "\\Zeuwpwsb2000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"  }
    "Zseapwsg2" { $vmssrg = "zsea-prod-web-vmss-rg"; $source = "Zseapwsg2000000"; $sourcepath = "\\Zseapwsg2000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"  }
    "Zseapwsb2" { $vmssrg = "zsea-prod-web-vmss-rg"; $source = "Zseapwsb2000000"; $sourcepath = "\\Zseapwsb2000000\c$\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"; $destinationpath = "c:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"  }
    "zuswpsssb" { $vmssrg = "zusw-prod-svc-rg"; $source = "zuswpsssb000000"; $sourcepath = "\\zuswpsssb000000\c$\Program Files\Herbalife\Configuration"; $destinationpath = "c:\Program Files\Herbalife\Configuration"  }
    "zuswpsssg" { $vmssrg = "zusw-prod-svc-rg"; $source = "zuswpsssg000000"; $sourcepath = "\\zuswpsssg000000\c$\Program Files\Herbalife\Configuration"; $destinationpath = "c:\Program Files\Herbalife\Configuration" }
    "zus2psssb" { $vmssrg = "zusw2-prod-svc-rg"; $source = "zus2psssb000000"; $sourcepath = "\\zus2psssb000000\c$\Program Files\Herbalife\Configuration"; $destinationpath = "c:\Program Files\Herbalife\Configuration"  }
    "zus2psssg" { $vmssrg = "zusw2-prod-svc-rg"; $source = "zus2psssg000000"; $sourcepath = "\\zus2psssg000000\c$\Program Files\Herbalife\Configuration"; $destinationpath = "c:\Program Files\Herbalife\Configuration"  }
}
 
$vmss = Get-AzVmss -ResourceGroupName $vmssrg -VMScaleSetName $vmssname

for ( $i = $vmss.Sku.Capacity/2; $i -lt $vmss.Sku.Capacity; $i++ ) {  
    $vm = Get-AzVMssVM -ResourceGroupName $vmssrg -VMScaleSetName $vmssname -InstanceId $i
    $servername = $vm.OSProfile.ComputerName
    $servers += $servername
}

[scriptblock]$scriptblock = {
    $Date = (Get-Date).ToString('dd-MM-yyyy-hhmm')
    $sourcepath = $args[0]
    $destinationpath = $args[1]
    if(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online")
    {
        Rename-Item -Path "C:\Program Files\Herbalife\Configuration\NLBControl.Online" -NewName "NLBControl.OnlineX" -Force -Verbose
        Write-Host "$env:COMPUTERNAME is taken offline"
        Rename-Item -Path "$destinationpath\externalAppSettings.config" -NewName "externalAppSettings-$Date.config" -Force
        sleep 5
        Copy-Item -Path "$sourcepath\externalAppSettings.config" -Destination $destinationpath -Force
        sleep 5
        iisreset.exe
        sleep 10
        $W3SVC = (Get-Service -Name W3SVC).Status
        $WAS = (Get-Service -Name WAS).Status
        if($W3SVC -eq "Running" -and $WAS -eq "Running" -and (Test-Path -Path "$destinationpath\externalAppSettings.config"))
        { 
            Write-Host "Exap file updated on $env:COMPUTERNAME"
        }
        else
        {
            Write-Host "Exap file update failed on $env:COMPUTERNAME"
        }
    }
    elseif(Test-Path -Path "C:\Program Files\Herbalife\Configuration\NLBControl.OnlineX")
    {
        Write-Host "$env:COMPUTERNAME is already offline"
        Rename-Item -Path "$destinationpath\externalAppSettings.config" -NewName "externalAppSettings-$Date.config" -Force
        sleep 5
        Copy-Item -Path "$sourcepath\externalAppSettings.config" -Destination $destinationpath -Force
        sleep 5
        iisreset.exe
        sleep 10
        $W3SVC = (Get-Service -Name W3SVC).Status
        $WAS = (Get-Service -Name WAS).Status
        if($W3SVC -eq "Running" -and $WAS -eq "Running" -and (Test-Path -Path "$destinationpath\externalAppSettings.config"))
        { 
            Write-Host "Exap file updated on $env:COMPUTERNAME"
        }
        else
        {
            Write-Host "Exap file update failed on $env:COMPUTERNAME"
        }
    }
}

Write-Host "Exap file is getting copied from $source"

$servers | % {
    Invoke-Command -ComputerName $_ -ScriptBlock $scriptBlock -ArgumentList $sourcepath,$destinationpath -AsJob
}

do {
    $runningJobs = Get-Job | Where-Object {$_.State -ne 'Completed'}
    #$runningJobs 
    sleep 10
} while ( $runningJobs.Count -gt 0 )

write-host "Exap file copied to $vmssname"