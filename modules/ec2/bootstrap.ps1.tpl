# Bootstrap script for the mCloud Windows application server.
# Installs the prerequisites documented in the mCloud System Requirements and
# Installation guides.
#
# This script is IDEMPOTENT: it detects what is already installed and only
# installs the missing pieces, so it is safe to re-run on an existing EC2 or
# to run manually after a partial first boot.
#
# When used as EC2 user-data it is wrapped with <powershell>...</powershell>
# by main.tf (see the user_data block). When run manually just execute it from
# an elevated PowerShell prompt.

$ErrorActionPreference = "Continue"
$ProgressPreference    = "SilentlyContinue"

Start-Transcript -Path "C:\UserData.log" -Append

# Make sure strong TLS is used for all downloads.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------------------------------------------------------------------------
# Helper: log a step result
# ---------------------------------------------------------------------------
function Write-Step  { param([string]$Msg) Write-Host "[STEP ] $Msg" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Msg) Write-Host "[OK   ] $Msg" -ForegroundColor Green }
function Write-Skip  { param([string]$Msg) Write-Host "[SKIP ] $Msg - already installed" -ForegroundColor Yellow }
function Write-Fail  { param([string]$Msg) Write-Host "[FAIL ] $Msg" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. IIS and required role services
# ---------------------------------------------------------------------------
Write-Step "IIS role services"
$iisFeatures = @(
  "Web-Server","Web-Common-Http","Web-Default-Doc","Web-Dir-Browsing",
  "Web-Http-Errors","Web-Static-Content","Web-Http-Redirect","Web-Health",
  "Web-Http-Logging","Web-Request-Monitor","Web-Http-Tracing","Web-Performance",
  "Web-Stat-Compression","Web-Dyn-Compression","Web-Security","Web-Filtering",
  "Web-Basic-Auth","Web-Windows-Auth","Web-App-Dev","Web-Asp-Net45",
  "Web-Net-Ext45","Web-ISAPI-Ext","Web-ISAPI-Filter","Web-WebSockets",
  "Web-Mgmt-Tools","Web-Mgmt-Console","Web-Mgmt-Compat","Web-Metabase"
)
$missing = Get-WindowsFeature -Name $iisFeatures | Where-Object { -not $_.Installed }
if ($missing) {
  $r = Install-WindowsFeature -Name $missing.Name -IncludeManagementTools
  if ($r.Success) { Write-Ok  "IIS features installed" }
  else            { Write-Fail "IIS feature install reported issues" }
} else {
  Write-Skip "IIS features"
}

# ---------------------------------------------------------------------------
# 2. Chocolatey
# ---------------------------------------------------------------------------
Write-Step "Chocolatey"
if (Get-Command choco -ErrorAction SilentlyContinue) {
  Write-Skip "Chocolatey"
} else {
  Set-ExecutionPolicy Bypass -Scope Process -Force
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
  if ($LASTEXITCODE -eq 0) { Write-Ok "Chocolatey installed" } else { Write-Fail "Chocolatey install" }
}
$env:Path = "$env:ChocolateyInstall\bin;$env:Path"
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" -ErrorAction SilentlyContinue
Update-SessionEnvironment 2>$null

# Helper: install a choco package only if its install/state file is missing.
function Install-ChocoIfMissing {
  param(
    [string]$Package,
    [string]$TestCmd,      # command used to detect existing install
    [string]$DisplayName
  )
  if ($TestCmd -and (Get-Command $TestCmd -ErrorAction SilentlyContinue)) {
    Write-Skip $DisplayName
    return
  }
  Write-Step "Installing $DisplayName via Chocolatey"
  choco install $Package -y --no-progress
  if ($LASTEXITCODE -eq 0) { Write-Ok $DisplayName } else { Write-Fail $DisplayName }
}

# ---------------------------------------------------------------------------
# 3. .NET 8 Hosting Bundle (runtime + ASP.NET Core + ANCM for IIS)
# ---------------------------------------------------------------------------
Write-Step ".NET 8 Hosting Bundle (ANCM)"
$ancm = $false
try {
  Import-Module WebAdministration -ErrorAction Stop
  if (Get-WebGlobalModule -Name "AspNetCoreModuleV2" -ErrorAction SilentlyContinue) { $ancm = $true }
} catch { }
if ($ancm) {
  Write-Skip ".NET 8 Hosting Bundle"
} else {
  choco install dotnet-8.0-windowshosting -y --no-progress
  if ($LASTEXITCODE -eq 0) { Write-Ok ".NET 8 Hosting Bundle" } else { Write-Fail ".NET 8 Hosting Bundle" }
}

# ---------------------------------------------------------------------------
# 4. .NET 8 SDK
# ---------------------------------------------------------------------------
Write-Step ".NET 8 SDK"
if ((Get-Command dotnet -ErrorAction SilentlyContinue) -and (dotnet --list-sdks 2>$null | Select-String "8\.")) {
  Write-Skip ".NET 8 SDK"
} else {
  choco install dotnet-8.0-sdk -y --no-progress
  if ($LASTEXITCODE -eq 0) { Write-Ok ".NET 8 SDK" } else { Write-Fail ".NET 8 SDK" }
}

# ---------------------------------------------------------------------------
# 5. IIS URL Rewrite 2.1
# ---------------------------------------------------------------------------
Write-Step "IIS URL Rewrite"
$rewrite = $false
try {
  Import-Module WebAdministration -ErrorAction Stop
  if (Get-WebGlobalModule -Name "RewriteModule" -ErrorAction SilentlyContinue) { $rewrite = $true }
} catch { }
if ($rewrite) {
  Write-Skip "IIS URL Rewrite"
} else {
  choco install urlrewrite -y --no-progress
  if ($LASTEXITCODE -eq 0) { Write-Ok "IIS URL Rewrite" } else { Write-Fail "IIS URL Rewrite" }
}

# ---------------------------------------------------------------------------
# 6. Node.js LTS
# ---------------------------------------------------------------------------
Install-ChocoIfMissing -Package "nodejs-lts" -TestCmd "node" -DisplayName "Node.js LTS"

# ---------------------------------------------------------------------------
# 7. Git
# ---------------------------------------------------------------------------
Install-ChocoIfMissing -Package "git" -TestCmd "git" -DisplayName "Git"

# ---------------------------------------------------------------------------
# 8. AWS CLI v2
# ---------------------------------------------------------------------------
Write-Step "AWS CLI v2"
if (Get-Command aws -ErrorAction SilentlyContinue) {
  Write-Skip "AWS CLI v2"
} else {
  Invoke-WebRequest -Uri https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile C:\AWSCLIV2.msi
  $p = Start-Process msiexec.exe -ArgumentList '/i C:\AWSCLIV2.msi /qn /norestart' -Wait -PassThru
  if ($p.ExitCode -eq 0) { Write-Ok "AWS CLI v2" } else { Write-Fail "AWS CLI v2 (exit $($p.ExitCode))" }
}

# ---------------------------------------------------------------------------
# 9. CloudWatch Agent
# ---------------------------------------------------------------------------
Write-Step "CloudWatch Agent"
if (Get-Service -Name "AmazonCloudWatchAgent" -ErrorAction SilentlyContinue) {
  Write-Skip "CloudWatch Agent"
} else {
  Invoke-WebRequest -Uri https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/AmazonCloudWatchAgent.zip -OutFile C:\AmazonCloudWatchAgent.zip
  Expand-Archive -Path C:\AmazonCloudWatchAgent.zip -DestinationPath C:\AmazonCloudWatchAgent -Force
  C:\AmazonCloudWatchAgent\install.ps1 -Quiet
  if (Get-Service -Name "AmazonCloudWatchAgent" -ErrorAction SilentlyContinue) {
    Write-Ok "CloudWatch Agent"
  } else {
    Write-Fail "CloudWatch Agent"
  }
}

# ---------------------------------------------------------------------------
# 10. SQL Server Management Studio (SSMS) + sqlcmd
# Required to execute client SQL scripts and verify data via the SSMS UI.
# ---------------------------------------------------------------------------
Write-Step "SSMS"
$ssmsExe = "C:\Program Files (x86)\Microsoft SQL Server Management Studio*\Common7\IDE\Ssms.exe"
if (Test-Path $ssmsExe) {
  Write-Skip "SSMS"
} else {
  choco install sql-server-management-studio -y --no-progress
  if ($LASTEXITCODE -eq 0) { Write-Ok "SSMS" } else { Write-Fail "SSMS" }
}

# sqlcmd (the standalone Go-based sqlcmd Utility, ships separately from SSMS).
Write-Step "sqlcmd Utility"
if (Get-Command sqlcmd -ErrorAction SilentlyContinue) {
  Write-Skip "sqlcmd Utility"
} else {
  choco install sqlcmd -y --no-progress
  if ($LASTEXITCODE -eq 0) { Write-Ok "sqlcmd Utility" } else { Write-Fail "sqlcmd Utility" }
}

# ---------------------------------------------------------------------------
# 11. Application folder C:\MA
# ---------------------------------------------------------------------------
Write-Step "C:\MA application folder"
if (Test-Path "C:\MA") {
  Write-Skip "C:\MA"
} else {
  New-Item -ItemType Directory -Path "C:\MA" -Force | Out-Null
  Write-Ok "C:\MA created"
}

# ---------------------------------------------------------------------------
# 12. Optional data volume (Terraform passes data_volume_drive = "" when none)
# ---------------------------------------------------------------------------
if ("${data_volume_drive}" -ne "") {
  Write-Step "Data volume ${data_volume_drive}:"
  $raw = Get-Disk | Where-Object { $_.PartitionStyle -eq 'RAW' -and $_.Number -ne 0 } | Select-Object -First 1
  if ($raw) {
    Initialize-Disk -Number $raw.Number -PartitionStyle GPT
    New-Partition -DiskNumber $raw.Number -UseMaximumSize -DriveLetter "${data_volume_drive}"
    Format-Volume -DriveLetter "${data_volume_drive}" -FileSystem NTFS -NewFileSystemLabel "MAData" -Confirm:$false
    New-Item -ItemType Directory -Path "${data_volume_drive}:\MA" -Force | Out-Null
    Write-Ok "Data volume initialized as ${data_volume_drive}:"
  } else {
    Write-Fail "No RAW data disk found for ${data_volume_drive}:"
  }
}

# ---------------------------------------------------------------------------
# 13. Refresh PATH so newly installed tools are visible in this session
# ---------------------------------------------------------------------------
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

Write-Ok "Bootstrap complete. Review C:\UserData.log for details."
Stop-Transcript
