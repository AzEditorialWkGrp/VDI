# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

# Make sure this file has Windows line endings

$LOG_FILE = "C:\Teradici\provisioning.log"

$METADATA_HEADERS = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$METADATA_HEADERS.Add("Metadata-Flavor", "Google")

$METADATA_BASE_URI = "http://metadata.google.internal/computeMetadata/v1/instance"
$METADATA_AUTH_URI = "$($METADATA_BASE_URI)/service-accounts/default/token"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("safe_mode_admin_password", "${safe_mode_admin_password}")

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

Start-Transcript -path $LOG_FILE -append

if ([string]::IsNullOrWhiteSpace("${application_id}") -or [string]::IsNullOrWhiteSpace("${aad_client_secret}") -or [string]::IsNullOrWhiteSpace("${tenant_id}")) {
    Write-Output "Not calling Get-Secret"
} else {
    Write-Output "Calling Get-Secret"
    $DATA."safe_mode_admin_password" = Get-Secret "${application_id}" "${aad_client_secret}" "${tenant_id}"  "${safe_admin_pass_secret_id}"
}

$DomainName = "${domain_name}"
$DomainMode = "7"
$ForestMode = "7"
$DatabasePath = "C:\Windows\NTDS"
$SysvolPath = "C:\Windows\SYSVOL"
$LogPath = "C:\Logs"

Write-Output "================================================================"
Write-Output "Installing AD-Domain-Services..."
Write-Output "================================================================"

# Installs the AD DS server role and installs the AD DS and AD LDS server
# administration tools, including GUI-based tools such as Active Directory Users
# and Computers and command-line tools such as dcdia.exe. No reboot required.
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

Write-Output "================================================================"
Write-Output "Install a new forest..."
Write-Output "================================================================"
Install-ADDSForest -CreateDnsDelegation:$false `
    -SafeModeAdministratorPassword (ConvertTo-SecureString $DATA."safe_mode_admin_password" -AsPlainText -Force) `
    -DatabasePath $DatabasePath `
    -SysvolPath $SysvolPath `
    -DomainName $DomainName `
    -DomainMode $DomainMode `
    -ForestMode $ForestMode `
    -InstallDNS:$true `
    -NoRebootOnCompletion:$true `
    -Force:$true

Write-Output "================================================================"
Write-Output "Configuring LDAPS..."
Write-Output "================================================================"
$DnsName = "${virtual_machine_name}.$DomainName"
Write-Output "Using DNS Name $DnsName"
$certStoreLoc = 'HKLM:\Software\Microsoft\Cryptography\Services\NTDS\SystemCertificates\My\Certificates';
$params = @{
  DnsName = "dns.internal Root Cert"
  NotAfter = (Get-Date).AddYears(5)
  CertStoreLocation = 'Cert:\LocalMachine\My'
  KeyUsage = 'CertSign','CRLSign' #fixes invalid certificate error
}
$rootCA = New-SelfSignedCertificate @params
$thumbprint=($rootCA.Thumbprint | Out-String).Trim()
if (!(Test-Path $certStoreLoc)) {
  New-Item $certStoreLoc -Force
}
Write-Output "$thumbprint"
Copy-Item -Path "HKLM:\Software\Microsoft\SystemCertificates\My\Certificates\$thumbprint" -Destination $certStoreLoc
$CertStore = New-Object -TypeName `
  System.Security.Cryptography.X509Certificates.X509Store(
  [System.Security.Cryptography.X509Certificates.StoreName]::Root,
  'LocalMachine')
$CertStore.open('MaxAllowed')
$CertStore.add($rootCA)
$CertStore.close()

$params = @{
  DnsName = "$DnsName"
  NotAfter = (Get-Date).AddYears(5)
  CertStoreLocation = 'Cert:\LocalMachine\My'
  Signer = $rootCA
}
$myCert = New-SelfSignedCertificate @params
$thumbprint=($myCert.Thumbprint | Out-String).Trim()
Write-Output "$thumbprint"
Copy-Item -Path "HKLM:\Software\Microsoft\SystemCertificates\My\Certificates\$thumbprint" -Destination $certStoreLoc

# Service account needs to be in Domain Admins group for realm join to work on CentOS
Add-ADGroupMember -Identity "Domain Admins" -Members "${account_name}"

Write-Output "================================================================"
Write-Output "Delay Active Directory Web Service (ADWS) start to avoid 1202 error..."
Write-Output "================================================================"
sc.exe config ADWS start= delayed-auto 

Write-Output "================================================================"
Write-Output "Restarting computer..."
Write-Output "================================================================"

Restart-Computer -Force
