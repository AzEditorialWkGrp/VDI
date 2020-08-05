$path = "${gpo_backups_path}"
$archivePath = "${gpo_backups_archive_path}"

$gpo = @{
	"users" = "Production Users"
	"workstations" = "Workstations"
}

Function Create-OU
(
    [string]$name
)
{
    Write-Output "================================================================"
    Write-Output "Creating OU: $name"
    Write-Output "================================================================"

    try
    {
        Get-ADOrganizationalUnit -Identity "OU=$name,DC=tera,DC=dns,DC=internal"
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] 
    {
        New-ADOrganizationalUnit -Name $name -Path "DC=tera,DC=dns,DC=internal"
    }
}

Function Get-GPO-Backup-ID
(
    [string]$gpoPath
)
{
    $backupId = (Get-ChildItem -Directory $gpoPath | Where-Object Name -Match "^\{.+\}$")[0].Name
    return $backupId.trimstart("{").trimend("}")
}

Function Create-AD-GPO
(
  [string]$path,
  [string]$target
)
{
    $name = Split-Path $path -leaf
    $backupId = Get-GPO-Backup-ID $path

    Import-GPO -BackupId $backupId -TargetName $name -path $path -CreateIfNeeded
    New-GPLink -Name $name -Target "OU=$target,DC=tera,DC=dns,DC=internal" -LinkEnabled Yes
}

Function Create-AD-GPO-For
(
  [string]$folderName,
  [string]$target
)
{
    Write-Output "================================================================"
    Write-Output "Creating GPO: $target"
    Write-Output "================================================================"

    $policies = Get-ChildItem -Directory "$path\$folderName"

    ForEach ($policy in $policies)
    {
        Create-AD-GPO $policy.FullName $target
    }
}

Expand-Archive -Path $archivePath -DestinationPath $path

ForEach ($key in $gpo.Keys)
{
    Create-OU $gpo[$key]
    Create-AD-GPO-For $key $gpo[$key]
}

