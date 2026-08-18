<powershell>
# Bootstrap script for the mCloud Windows application server.
# Installs the prerequisites documented in the mCloud System Requirements and Installation guides.

Start-Transcript -Path "C:\UserData.log" -Append

# Ensure strong TLS for downloads
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

Install-WindowsFeature -Name $iisFeatures -IncludeManagementTools

# -----------------------------------------------------------------------------
# 2. Install Chocolatey to simplify third-party package installs
# -----------------------------------------------------------------------------
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

$env:Path = "$env:ChocolateyInstall\bin;$env:Path"
Import-Module "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
Update-SessionEnvironment

# -----------------------------------------------------------------------------
# 3. Install .NET 8 Hosting Bundle, URL Rewrite, Node.js LTS, and Git
# - .NET 8 Hosting Bundle = .NET 8 runtime + ASP.NET Core 8 runtime + ANCM for IIS
# - URL Rewrite 2.1 for the React SPA client-side routing
# - Node.js for building the React frontend
# - Git to clone the application repository
# -----------------------------------------------------------------------------
choco install dotnet-8.0-windowshosting -y
choco install dotnet-8.0-sdk -y
choco install urlrewrite -y
choco install nodejs-lts -y
choco install git -y

# -----------------------------------------------------------------------------
# 4. Install AWS CLI v2 and CloudWatch agent
# -----------------------------------------------------------------------------
Invoke-WebRequest -Uri https://awscli.amazonaws.com/AWSCLIV2.msi -OutFile C:\AWSCLIV2.msi
Start-Process msiexec.exe -ArgumentList '/i C:\AWSCLIV2.msi /qn /norestart' -Wait

Invoke-WebRequest -Uri https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/AmazonCloudWatchAgent.zip -OutFile C:\AmazonCloudWatchAgent.zip
Expand-Archive -Path C:\AmazonCloudWatchAgent.zip -DestinationPath C:\AmazonCloudWatchAgent -Force
C:\AmazonCloudWatchAgent\install.ps1 -Quiet

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
}
%{ endif }

# -----------------------------------------------------------------------------
# 6. Additional / optional tools
# Uncomment the next line if you want sqlcmd on the EC2 for testing RDS connectivity.
# SQL Server Management Studio is heavy; for quick sqlcmd tests use the MsSqlCmdLnUtils package instead.
# choco install sql-server-management-studio -y
# -----------------------------------------------------------------------------

Stop-Transcript
</powershell>
