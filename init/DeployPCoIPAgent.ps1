# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Make sure this file has Windows line endings
<#
    .SYNOPSIS
        Configure Windows 10 Workstation with Teradici PCoIP.

    .DESCRIPTION
        Configure Windows 10 Workstation with Avid Media Composer.
        Example command line: .\setupMachine.ps1 Avid Media Composer

#>

[CmdletBinding(DefaultParameterSetName = "_AllParameterSets")]
param(

    [Parameter(Mandatory=$false)]
    [string]
    $storage_account,

    [Parameter(Mandatory=$false)]
    [string]
    $storage_container,

    [Parameter(Mandatory=$false)]
    [string]
    $storage_access_key,

    [Parameter(Mandatory=$true)]
    [string]
    $TeraRegKey,

    [Parameter(Mandatory=$true)]
    [string]
    $PCoIPAgentURI,

    [Parameter(Mandatory=$true)]
    [string]
    $PCoIPAgentEXE,

    [Parameter(Mandatory=$true)]
    [string]
    $WallPaperURI,

    [Parameter(Mandatory=$true)]
    [string]
    $domain_name,

    [Parameter(Mandatory=$true)]
    [string]
    $ad_service_account_username,

    [Parameter(Mandatory=$true)]
    [string]
    $ad_service_account_password,

    [Parameter(Mandatory=$false)]
    [string]
    $application_id,

    [Parameter(Mandatory=$false)]
    [string]
    $tenant_id,

    [Parameter(Mandatory=$false)]
    [string]
    $aad_client_secret,

    [Parameter(Mandatory=$false)]
    [string]
    $pcoip_secret_id,

    [Parameter(Mandatory=$false)]
    [string]
    $ad_pass_secret_id
)

#Install/Test Configuration
$AgentDestinationPath = 'C:\Installer\'
$AgentLocation ='C:\Program Files\Teradici\PCoIP Agent\'

$AgentDestination = $AgentDestinationPath + $PCoIPAgentEXE
$PCoIPAgentURL = $PCoIPAgentUri

Write-Output "TeraRegKey:                  $TeraRegKey"
Write-Output "PCoIPAgentURI:               $PCoIPAgentURI"
Write-Output "PCoIPAgentEXE:               $PCoIPAgentEXE"
Write-Output "AgentDestination:            $AgentDestination"
Write-Output "PCoIPAgentURL:               $PCoIPAgentURL"
Write-Output "WallPaperURI:                $WallPaperURI"
Write-Output "domain_name:                 $domain_name"
Write-Output "ad_service_account_username: $ad_service_account_username"
Write-Output "ad_service_account_password: $ad_service_account_password"

#Disable Scheulded Tasks: ServerManager
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose

Function Mount-Disk
(
  [string]$storage_name,
  [string]$container,
  [string]$storage_password
)
{
  $connectTestResult = Test-NetConnection -ComputerName "$storage_name.file.core.windows.net" -Port 445
  if ($connectTestResult.TcpTestSucceeded) {
    # Save the password so the drive will persist on reboot
    cmd.exe /C "cmdkey /add:$storage_name.file.core.windows.net /user:Azure\$storage_name /pass:$storage_password"
    # Mount the drive
    New-PSDrive -Name Z -PSProvider FileSystem -Root "\\$storage_name.file.core.windows.net\$container" -Scope Global -Persist
  } else {
    Write-Error -Message "Unable to reach the Azure storage account via port 445. Check to make sure your organization or ISP is not blocking port 445, or use Azure P2S VPN, Azure S2S VPN, or Express Route to tunnel SMB traffic over a different port."
  }
}

Function Get-AccessToken
(
  [string]$application_id,
  [string]$aad_client_secret,
  [string]$oath2Uri
)
{
  $body = 'grant_type=client_credentials'
  $body += '&client_id=' + $application_id
  $body += '&client_secret=' + [Uri]::EscapeDataString($aad_client_secret)
  $body += '&resource=' + [Uri]::EscapeDataString("https://vault.azure.net")

  $response = Invoke-RestMethod -Method POST -Uri $oath2Uri -Headers @{} -Body $body

  return $response.access_token
}

Function Get-Secret
(   
  [string]$application_id,
  [string]$aad_client_secret,
  [string]$tenant_id,
  [string]$secret_identifier
)
{
  $oath2Uri = "https://login.microsoftonline.com/$tenant_id/oauth2/token"

  $accessToken = Get-AccessToken $application_id $aad_client_secret $oath2Uri

  $queryUrl = "$secret_identifier" + '?api-version=7.0'

  $headers = @{ 'Authorization' = "Bearer $accessToken"; "Content-Type" = "application/json" }

  $response = Invoke-RestMethod -Method GET -Ur $queryUrl -Headers $headers

  $result = $response.value

  return $result
}

function Join-Domain 
(
    [string]$domain_name,
    [string]$ad_service_account_username,
    [string]$ad_service_account_password
)
{
    Write-Output "Passed Variables $domain_name ; $ad_service_account_username ; $ad_service_account_password"
    $obj = Get-WmiObject -Class Win32_ComputerSystem

    if ($obj.PartOfDomain) {
        if ($obj.Domain -ne "$domain_name") {
            "ERROR: Trying to join '$domain_name' but computer is already joined to '$obj.Domain'"
            continue
        }

        "Computer already part of the '$obj.Domain' domain."
        return
    } 

    "Computer not part of a domain. Joining $domain_name..."

    $username = "$ad_service_account_username" + "@" + "$domain_name"
    $password = ConvertTo-SecureString $ad_service_account_password -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($username, $password)

    # Looping in case Domain Controller is not yet available
    $Interval = 10
    $Timeout = 3600
    $Elapsed = 0

    do {
        Try {
            $Retry = $false
            # Don't do -Restart here because there is no log showing the restart
            Add-Computer -DomainName "$domain_name" -Credential $cred -Verbose -Force -ErrorAction Stop -OUPath "OU=Workstations,DC=tera,DC=dns,DC=internal"
        }

        # The same Error, System.InvalidOperationException, is thrown in these cases: 
        # - when Domain Controller not reachable (retry waiting for DC to come up)
        # - when password is incorrect (retry because user might not be added yet)
        # - when computer is already in domain
        Catch [System.InvalidOperationException] {
            $_.Exception.Message
            if (($Elapsed -ge $Timeout) -or ($_.Exception.GetType().FullName -match "AddComputerToSameDomain,Microsoft.PowerShell.Commands.AddComputerCommand")) {
                exit 1
            }

            "Retrying in $Interval seconds... (Timeout in $($Timeout-$Elapsed) seconds)"
            $Retry = $true
            Start-Sleep -Seconds $Interval
            $Elapsed += $Interval
        }
        Catch {
            $_.Exception.Message
            exit 1
        }
    } while ($Retry)

    $obj = Get-WmiObject -Class Win32_ComputerSystem
    if (!($obj.PartOfDomain) -or ($obj.Domain -ne "$domain_name") ) {
        "ERROR: failed to join $domain_name"
        exit 1
    }

    "Successfully joined $domain_name"
    $global:restart = $true
}

function DownloadFileOverHttp($Url, $DestinationPath) {
    $secureProtocols = @()
    $insecureProtocols = @([System.Net.SecurityProtocolType]::SystemDefault, [System.Net.SecurityProtocolType]::Ssl3)

    foreach ($protocol in [System.Enum]::GetValues([System.Net.SecurityProtocolType])) {
        if ($insecureProtocols -notcontains $protocol) {
            $secureProtocols += $protocol
        }
    }
    [System.Net.ServicePointManager]::SecurityProtocol = $secureProtocols

    # make Invoke-WebRequest go fast: https://stackoverflow.com/questions/14202054/why-is-this-powershell-code-invoke-webrequest-getelementsbytagname-so-incred
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -UseBasicParsing "${Url}" -OutFile $DestinationPath -Verbose 
    Write-Output "$DestinationPath updated"
}

try {
    #Change empty disk letter to Y
    Get-Partition -DriveLetter E | Set-Partition -NewDriveLetter Y
    Write-Output "Disk E is renamed to Y"

    #Join Domain Controller
    Write-Output "Joining Domain"
    Join-Domain $domain_name $ad_service_account_username $ad_service_account_password

    #Mount file sharing storage container
    Mount-Disk $storage_account $storage_container $storage_access_key

    #Decrypt Teradici Reg Key and AD Service Account Password
    if (!($application_id -eq $null -or $application_id -eq "") -and !($aad_client_secret -eq $null -or $aad_client_secret -eq "") -and !($tenant_id -eq $null -or $tenant_id -eq "")) {
    Write-Output "Running Get-Secret!"
    $TeraRegKey = Get-Secret $application_id $aad_client_secret $tenant_id $pcoip_secret_id
    $ad_service_account_password = Get-Secret $application_id $aad_client_secret $tenant_id $ad_pass_secret_id
    }

    #Set the Agent's destination 
    If(!(test-path $AgentDestinationPath))  {
        New-Item -ItemType Directory -Force -Path $AgentDestinationPath
    }
    Set-Location -Path $AgentDestinationPath

    #Download Agent
    Write-Output "Downloading latest PCoIP standard agent from $PCoIPAgentURL"
    DownloadFileOverHttp $PCoIPAgentURL $AgentDestination

    
    #Install Agent from Agent Destination 
    Write-Output "Install Teradici with Destination Path: $AgentDestination"
    $ArgumentList = ' /S /NoPostReboot _?"' + $AgentDestination +'"'

    Write-Output "Teradici Argument list at: $ArgumentList"
    $process =  Start-Process -FilePath $AgentDestination -ArgumentList $ArgumentList -Wait -PassThru;     
    Write-Output "Installed PCoIP Agent with Exit Code:" $process.ExitCode
    
    #Registering Agent with Licence Server
    Set-Location -Path  $AgentLocation

    $Registered = & .\pcoip-register-host.ps1 -RegistrationCode $TeraRegKey
    Write-Output "Registering Teradici Host returned this result: $Registered"

    #Validate Licence 
    $Validate =& .\pcoip-validate-license.ps1
    Write-Output "Validate Teradici Licence returned: $Validate"       
    
    # Set the Wallpaper
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallPaper -Value "$workdir\$wallpapername"
    Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name TileWallpaper -Value "0"
	Set-ItemProperty -Path 'HKCU:\Control Panel\Desktop' -Name WallpaperStyle -Value "2" -Force
    for ($i=0; $i -le 25; $i++) {
    RUNDLL32.EXE USER32.DLL ,UpdatePerUserSystemParameters
    }
    Write-Output = "Updated Registry and Forced Update with RUNDLL32.EXE"
    Get-ItemProperty -Path 'HKCU:\Control Panel\Desktop'
    
    Write-Output "Restart VM..."   
    Restart-Computer -Force

}
catch [Exception]{
    Write-Output $_.Exception.Message
    Write-Error $_.Exception.Message
}
