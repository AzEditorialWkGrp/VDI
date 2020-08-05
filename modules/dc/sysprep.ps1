# Copyright (c) 2019 Teradici Corporation
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

[CmdletBinding(DefaultParameterSetName = "Standard")]
param(
    [string]
    [ValidateNotNullOrEmpty()]
    $admin_password,

    [string]
    [ValidateNotNullOrEmpty()]
    $admin_username
)

$LOG_FILE = "C:\Teradici\provisioning.log"

Start-Transcript -path $LOG_FILE -append

Write-Output "admin_password: $admin_password"
Write-Output "admin_username: $admin_username"

$DATA = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$DATA.Add("admin_password", "$admin_password")

New-NetFirewallRule -DisplayName "AllowPort5986" -Direction Inbound -LocalPort 5986 -Protocol TCP -Action Allow

net user $admin_username $DATA."admin_password" /active:yes
Enable-PSRemoting -Force
if ($?) { Write-Output "Enable-PSRemote is successful... " }
winrm set winrm/config/service/auth '@{Basic="true"}'
if ($?) { Write-Output "winrm set is successful..." }
