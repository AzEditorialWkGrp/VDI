$owner = "SupportPartners"
$repo_name = "microsoft-vdi"
$branch = "3.2"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$wc = New-Object System.Net.WebClient

Function AzureLogin
{
    Try
    {
        $accountsNumber = (az account list | ConvertFrom-Json).Length
    }
    Catch [System.Management.Automation.CommandNotFoundException]
    {
        Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi; Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'; rm .\AzureCLI.msi
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    If ($accountsNumber -le 1) {
        az login
    }

    $accounts = az account list --query "[].{Name: name, Id: id, TenantId: tenantId}" | ConvertFrom-Json
    $accounts | Foreach-Object { $index = 1 } {Add-Member -InputObject $_ -MemberType NoteProperty  -Name "Number" -Value $index; $index++}

    Write-Host ($accounts | Format-Table | Out-String)

    $minNumber = 1
    $maxNumber = $accounts.Length
    Do {
        Try {
            $numberIsParsed = $true
            [int]$chosenAccountNumber = Read-Host "Please choose the account number from $minNumber to $maxNumber"
        }
        Catch {
            Write-Warning "Incorrect number"
            $numberIsParsed = $false
        }
    }
    Until (($chosenAccountNumber -ge $minNumber -and $chosenAccountNumber -le $maxNumber) -and $numberIsParsed)

    $chosenAccount = $accounts[$chosenAccountNumber - 1]
    $subscriptionId = $chosenAccount.id
    az account set --subscription $subscriptionId
}

Function DownloadProject
{
    $uri = "https://github.com/$owner/$repo_name/archive/$branch.zip"
    $zip = Join-Path $PSScriptRoot "$branch.zip"
    $wc.DownloadFile($uri, $zip)
    Expand-Archive -Path $zip -DestinationPath $PSScriptRoot -Force
    Remove-Item -Path $zip
}

Function DownloadTerraform([string] $directory)
{
    $version = "0.12.24"
    $os = "windows"
    $arch = "amd64"
    $terraform_uri = "https://releases.hashicorp.com/terraform/${version}/terraform_${version}_${os}_${arch}.zip"
    $terraform_zip = Join-Path $directory "terraform.zip"
    $wc.DownloadFile($terraform_uri, $terraform_zip)
    Expand-Archive -Path $terraform_zip -DestinationPath $directory -Force
    Remove-Item -Path $terraform_zip
}

Function DownloadTerraformPlugins([string] $directory)
{
    $restApiProviderVersion = "1.13.0"
    $os = "windows"
    $arch = "amd64"

    $localName = "terraform-provider-restapi_v1.13.0"
    $name = "${localName}-${os}-${arch}"
    $uri = "https://github.com/Mastercard/terraform-provider-restapi/releases/download/v${restApiProviderVersion}/${name}"
    $path = "${directory}/terraform.d/plugins/windows_amd64"

    If(!(test-path $path))
    {
        New-Item -ItemType Directory -Force -Path $path
    }
    Invoke-WebRequest -Uri $uri -OutFile "$path/${localName}"
}

Function DownloadTools([string] $directory)
{
    $vdiwatcheruri = "https://stmsoftdemostoreprod.blob.core.windows.net/tools/VdiVhdWatcher-windows-amd64-1.0.exe"
    $vdiwatcherpath = Join-Path $directory "VdiVhdWatcher.exe"
    $wc.DownloadFile($vdiwatcheruri, $vdiwatcherpath)
}

Function CreateUsers
{
    if ((Test-Path ".\domain_users_list.csv") -eq $False) {
        $users = @()

        Write-Host "In order to create workstations you need to create at list one user. Each user will be assigned to the single workstation. Max 5 users"
        Do {
            $username = Read-Host "Username"
            $password = Read-Host "Password"
            $firstname = Read-Host "Firstname"
            $lastname = Read-Host "Lastname"
            # $isadmin =  Read-Host "Is admin? true/false"

            $users += [pscustomobject]@{
                username = $username
                password = $password
                firstname = $firstname
                lastname = $lastname
                # isadmin = $isadmin
            }
            if ($users.Count -gt 4) {
                break;
            }
            $doContinue = Read-Host "Do you want to add another user? y/N"
        }
        While ($doContinue -eq "y")

        $users | Export-Csv -NoTypeInformation -Path ".\domain_users_list.csv"
    }
}

Function CreateCAMDeployment([string] $registrationCode)
{
    $cam_token_request_body = @{
        username = Read-Host "CAM Service account username"
        apiKey = Read-Host "CAM Service account API key"
    } | ConvertTo-Json
    $cam_token = ((Invoke-WebRequest "https://cam.teradici.com/api/v1/auth/signin" -ContentType "application/json" -Method POST -Body $cam_token_request_body) | ConvertFrom-Json).data.token
    $deployment_request_body = @{
        deploymentName = "vdi-automated-$((Get-Date).ToString("MMMM-dd-HH-mm", [System.Globalization.CultureInfo]::InvariantCulture).ToLowerInvariant())"
        registrationCode = $registrationCode
    } | ConvertTo-Json
    $deployment_id = ((Invoke-WebRequest "https://cam.teradici.com/api/v1/deployments" -ContentType "application/json" -Headers @{"Authorization"=$cam_token} -Method POST -Body $deployment_request_body) | ConvertFrom-Json).data.deploymentId
    $deployment_service_account_request_body = @{
        deploymentId = $deployment_id
    } | ConvertTo-Json
    $deployment_service_account = ((Invoke-WebRequest "https://cam.teradici.com/api/v1/auth/keys" -ContentType "application/json" -Headers @{"Authorization"=$cam_token} -Method POST -Body $deployment_service_account_request_body) | ConvertFrom-Json).data
    $deployment_token_request_body = @{
        username = $deployment_service_account.username
        apiKey = $deployment_service_account.apiKey
    } | ConvertTo-Json
    $deployment_token = ((Invoke-WebRequest "https://cam.teradici.com/api/v1/auth/signin" -ContentType "application/json" -Method POST -Body $deployment_token_request_body) | ConvertFrom-Json).data.token
    return @{
        id = $deployment_id
        token = $deployment_token
    }
}

$loggedAccount = AzureLogin

$pcoip_registration_code = Read-Host "CAM PCOIP Registration code"
$deployment = CreateCAMDeployment($pcoip_registration_code)

$vars =
"pcoip_registration_code  = `"$pcoip_registration_code`"
cam_deployement_id          = `"$($deployment.id)`"
cam_service_token           = `"$($deployment.token)`"
"

DownloadProject

$repo_directory = Join-Path $PSScriptRoot "$repo_name-$branch"
pushd $repo_directory

CreateUsers

$tfvars_file = "user-vars.tfvars"
New-Item -Path . -Name $tfvars_file -ItemType "file" -Force -Value $vars

DownloadTerraform($repo_directory)
DownloadTerraformPlugins($repo_directory)
DownloadTools($repo_directory)

.\terraform.exe init
.\terraform.exe apply -var-file="$tfvars_file"

popd