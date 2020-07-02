$script:author = 'Azrad'
# Write-Host $author

Import-Module WebAdministration
$nlbServerLevel = 'C:\Program Files\Herbalife\Configuration\NlbControl.Online'
$nlbAppData = 'App_Data\NLBControl.Online'
$isOnlineServerLevel = $False
# $siteStatusColor = 'Red'
# $scaleSetName = $env:COMPUTERNAME.Substring(0, 9)
$scaleSetName = $env:COMPUTERNAME.Substring(0, ($env:COMPUTERNAME.Length - 6))

$webSet = @{
    'serverGroup' = 'Web'
    'members' = @('ws')
    'appType' = 'Vertical'
}
$serviceSet = @{
    'serverGroup' = 'Svc'
    'members' = @('ss', 'ls', 'lr')
    'appType' = 'Service'
}
$adminSet = @{
    'serverGroup' = 'Admin'
    'members' = @('as')
    'appType' = 'Service'
}

$greenSet = @{
    'farm' = 'Green'
    'members' = @('wsg', 'ssg', 'lsg', 'lrg', 'asg')
}
$blackSet = @{
    'farm' = 'Black'
    'members' = @('wsb', 'ssb', 'lsb', 'lrb', 'asb')
}

$farmName = ''
$datacenterName = ''
@($greenSet, $blackSet) | foreach-object {
    # write-host "[$computerName]"
    $setName = $_.farm
    # write-host $setName
    
    $_.members | foreach-object {
        $member = $_
        if ([string]::isnullorempty($farmName)) {
            # write-host "...test for $member"
            $farmName = if ($env:COMPUTERNAME -match $member) { $setName }
            $datacenterName = ($env:COMPUTERNAME -split $member)[0]
            $datacenterName = $datacenterName.Substring(0,($datacenterName.Length-2))
        }
    }
}

$serverGroup = ''
$appType = ''
@($webSet, $serviceSet, $adminSet) | foreach-object {
    $setServerGroup = $_.serverGroup
    $setAppType = $_.appType
    # write-host "...serverGroup is $setServerGroup"
    $_.members | foreach-object {
        # write-host "...test for $_"
        if (-not $serverGroup) {
            $serverGroup = if ($env:COMPUTERNAME -match $_) { $setServerGroup }
            $appType = $setAppType
        }
    }
}

if (Test-Path -Path $nlbServerLevel) {
    $isOnlineServerLevel = $True
}

$OSVersion = [System.Environment]::OSVersion.Version

if ($OSVersion.Major -eq 10) {
    $sites = Get-IISSite
}
else {
    $sites = Get-ChildItem IIS:\Sites
}

$sites | ForEach-Object {
    $isOnline = $False
    $nlbStatus = 0
    $siteName = $_.Name

    $site = Get-Website -Name $siteName
    $physicalPath = $site.physicalPath
    $binPhysicalPath = "${physicalPath}\bin"
    $targetPath = if (Test-Path -Path $binPhysicalPath) { $binPhysicalPath } else { $physicalPath }

    if ($site.State -eq 'Started' -and (Test-Path -Path $physicalPath)) {
        if (Test-Path -Path $physicalPath\$nlbAppData) {
            $isOnline = $True
        }

        if ($isOnline -and $isOnlineServerLevel) {
            # $siteStatusColor = 'Green'
            $nlbStatus = 1
        }

        $webBindings = (Get-WebBinding -Name $siteName | Select-Object -First 1) -split ':'

        if (Test-Path -Path "$physicalPath\App_Data\build_info.json") {
            $buildVersionFile = "build_info.json"
            $buildVersionFilePath = "$physicalPath\App_Data\$buildVersionFile"
            $json = (Get-Content $buildVersionFilePath | ConvertFrom-Json)
            $fileVersion = $json.build_version
        }
        else {
            $buildVersionFiles = Get-ChildItem -Path "$targetPath" | Where-Object {$_.Extension -eq '.dll' -or $_.Extension -eq '.exe'} | Sort-Object LastWriteTime -Descending | Select-Object -First 10
            $fileVersion = ''

            $buildVersionFiles | ForEach-Object {
                $targetBuildVersionFilePath = "${targetPath}\$_"
                # Write-Host "... buildVersionFilePath: ${targetBuildVersionFilePath}"

                if ([string]::IsNullOrEmpty($fileVersion)) {
                    $fileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($targetBuildVersionFilePath).FileVersion
                    $buildVersionFile = $_
                    $buildVersionFilePath = "${targetPath}\${buildVersionFile}"
                    #Write-Host ">>> ${fileVersion} (${buildVersionFilePath})"
                }
            }

            if ([string]::IsNullOrEmpty($fileVersion)) {
                $buildVersionFile = Get-ChildItem -Path $targetPath | Where-Object {$_.Name -eq 'Version.txt'} | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                $buildVersionFilePath = "${targetPath}\${buildVersionFile}"
                $fileVersion = Get-Content $buildVersionFilePath
                #Write-Host ">>> ${fileVersion} (${buildVersionFilePath})"
            }
        }

        if ($fileVersion) {
            $object = Get-Item -Path $buildVersionFilePath
            $BuildLastWriteTime = $object.LastWriteTime

            $eventDate = Get-Date
            $eventText = "{0}: ServerGroup={12}, Datacenter={1}, Scaleset={7}, Hostname={2}, Farm={3}, {13}={4}, Port={9}, NLBStatus={5}, BuildVersion={6}, BuildVersionFile={8}, BuildLastWriteTime={10}, Path={11}" `
                -f $eventDate, $datacenterName, $env:COMPUTERNAME, $farmName, $siteName, $nlbStatus, $fileVersion, $scaleSetName, $buildVersionFile, $webBindings[1], $BuildLastWriteTime, $physicalpath, $serverGroup, $appType

            Write-Host $eventText
            Write-Host `r`n`n`r
        }
    }
}
