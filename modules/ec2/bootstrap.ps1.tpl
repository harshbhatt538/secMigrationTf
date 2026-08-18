<powershell>
# Bootstrap script for the mCloud Windows application server.
# Installs the prerequisites documented in the mCloud System Requirements and Installation guides.

Start-Transcript -Path "C:\UserData.log" -Append

# Do not stop the whole script on a single error so we can log every step.
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

# Ensure strong TLS for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Test-ExitCode {
  param([string]$Step)
  if ($LASTEXITCODE -and ($LASTEXITCODE -ne 0)) {
    Write-Host "ERROR: $Step failed with exit code $LASTEXITCODE" -ForegroundColor Red
  } else {
    Write-Host "OK: $Step completed" -ForegroundColor Green
  }
}

# -----------------------------------------------------------------------------
# 1. Install IIS and required role services
# Based on MA - mCloud - Requirements and Masterwork Automodules - mCloud - Installation.
# -----------------------------------------------------------------------------
$iisFeatures = @(
  "Web-Server",
  "Web-Common-Http",
  "Web-Default-Doc",
  "Web-Dir-Browsing",
  "Web-Http-Errors",
  "Web-Static-Content",
  "Web-Http-Redirect",
  "Web-Health",
  "Web-Http-Logging",
  "Web-Request-Monitor",
  "Web-Http-Tracing",
  "Web-Performance",
  "Web-Stat-Compression",
  "Web-Dyn-Compression",
  "Web-Security",
  "Web-Filtering",
  "Web-Basic-Auth",
  "Web-Windows-Auth",
  "Web-App-Dev",
  "Web-Asp-Net45",
  "Web-Net-Ext45",
  "Web-ISAPI-Ext",
  "Web-ISAPI-Filter",
  "Web-WebSockets",
  "Web-Mgmt-Tools",
  "Web-Mgmt-Console",
  "Web-Mgmt-Compat",
  "Web-Metabase"
)

$iisResult = Install-WindowsFeature -Name $iisFeatures -IncludeManagementTools
if (-not $iisResult.Success) {
  Write-Host "WARNING: IIS feature install reported one or more issues." -ForegroundColor Yellow
} else {
  Write-Host "OK: IIS features installed" -ForegroundColor Green
}

# -----------------------------------------------------------------------------
# 2. Install Chocolatey to simplify third-party package installs
# -----------------------------------------------------------------------------
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
Test-ExitCode -Step "Chocolatey install"

$env:Path = "$env:ChocolateyInstall\bin;$env:Path"
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" -ErrorAction SilentlyContinue
Update-SessionEnvironment

# -----------------------------------------------------------------------------
# 3. Install .NET 8 Hosting Bundle, URL Rewrite, Node.js LTS, and Git
# - .NET 8 Hosting Bundle = .NET 8 runtime + ASP.NET Core 8 runtime + ANCM for IIS
# - URL Rewrite 2.1 for the React SPA client-side routing
# - Node.js for building the React frontend
# - Git to clone the application repository
# -----------------------------------------------------------------------------
# NOTE: If 'dotnet-8.0-windowshosting' is not found in Chocolatey, uncomment the
# direct download fallback below or install the hosting bundle manually after launch.
choco install dotnet-8.0-windowshosting -y --no-progress
Test-ExitCode -Step ".NET 8 Hosting Bundle"

choco install dotnet-8.0-sdk -y --no-progress
Test-ExitCode -Step ".NET 8 SDK"

choco install urlrewrite -y --no-progress
Test-ExitCode -Step "IIS URL Rewrite"

choco install nodejs-lts -y --no-progress
Test-ExitCode -Step "Node.js LTS"

choco install git -y --no-progress
Test-ExitCode -Step "Git"

# -----------------------------------------------------------------------------
# 4. Install AWS CLI v2 and CloudWatch agent
# -----------------------------------------------------------------------------
Invoke-WebRequest -Uri https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile C:\AWSCLIV2.msi
$awsCliProc = Start-Process msiexec.exe -ArgumentList '/i C:\AWSCLIV2.msi /qn /norestart' -Wait -PassThru
if ($awsCliProc.ExitCode -ne 0) {
  Write-Host "ERROR: AWS CLI install failed with exit code $($awsCliProc.ExitCode)" -ForegroundColor Red
} else {
  Write-Host "OK: AWS CLI installed" -ForegroundColor Green
}

Invoke-WebRequest -Uri https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/AmazonCloudWatchAgent.zip -OutFile C:\AmazonCloudWatchAgent.zip
Expand-Archive -Path C:\AmazonCloudWatchAgent.zip -DestinationPath C:\AmazonCloudWatchAgent -Force
C:\AmazonCloudWatchAgent\install.ps1 -Quiet
Test-ExitCode -Step "CloudWatch agent"

# -----------------------------------------------------------------------------
# 5. Prepare the application folder
# The mCloud installation documentation recommends C:\MA as the installation root.
# -----------------------------------------------------------------------------
New-Item -ItemType Directory -Path "C:\MA" -Force

# If a data volume was attached, initialize and format it as D:\
%{ if data_volume_drive != "" }
$rawDisk = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Number -ne 0 } | Select-Object -First 1
if ($rawDisk) {
  Initialize-Disk -Number $rawDisk.Number -PartitionStyle GPT
  New-Partition -DiskNumber $rawDisk.Number -UseMaximumSize -DriveLetter "${data_volume_drive}"
  Format-Volume -DriveLetter "${data_volume_drive}" -FileSystem NTFS -NewFileSystemLabel "MAData" -Confirm:$false
  New-Item -ItemType Directory -Path "${data_volume_drive}:\MA" -Force
  Write-Host "OK: Data volume initialized as ${data_volume_drive}:"
} else {
  Write-Host "WARNING: No RAW data disk found for data volume" -ForegroundColor Yellow
}
%{ endif }

# -----------------------------------------------------------------------------
# 6. Additional / optional tools
# Uncomment the next line if you want sqlcmd / SSMS on the EC2 for testing RDS
# connectivity from the server. The RDS guide uses sqlcmd.
# choco install sql-server-management-studio -y --no-progress
# -----------------------------------------------------------------------------

Write-Host "Bootstrap complete. Review C:\UserData.log for details." -ForegroundColor Green
Stop-Transcript
</powershell>
