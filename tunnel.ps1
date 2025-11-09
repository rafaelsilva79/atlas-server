# Usage: .\tunnel.ps1 <service: pinggy|serveo> <type: http|tcp> <port>
# Example: .\tunnel.ps1 pinggy tcp 3000
#          .\tunnel.ps1 serveo http 8080

param (
    [Parameter(Mandatory=$true)][ValidateSet("pinggy", "serveo")] [string]$Service,
    [Parameter(Mandatory=$true)][ValidateSet("http", "tcp")] [string]$Type,
    [Parameter(Mandatory=$true)] [int]$Port
)

# GitHub Actions check
if ($env:ACTIONS_RUNNER_ACTION_ARCHIVE_CACHE -and [string]::IsNullOrEmpty($env:SSH_TUNNEL)) {
    Write-Warning "SSH_TUNNEL is missing or has no value"
    exit 1
}

# Validate unsupported combinations
if ($Service -eq "serveo" -and $Type -eq "tcp") {
    Write-Error "TCP mode is not supported with Serveo"
    exit 1
}

# Configure SSH destination and remote forwarding
$key = "${Service}:${Type}"
switch ($key) {
    "pinggy:http" {
        $SSHPort = 443
        $Dest = "free.pinggy.io"
        $Remote = "-R0:127.0.0.1:$Port"
    }
    "pinggy:tcp" {
        $SSHPort = 443
        $Dest = "tcp@free.pinggy.io"
        $Remote = "-R0:127.0.0.1:$Port"
    }
    "serveo:http" {
        $SSHPort = 22
        $Dest = "serveo.net"
        $Remote = "-R 80:127.0.0.1:$Port"
    }
}

# Create SSH key and log file
$UniqueSuffix = [guid]::NewGuid().ToString()
$KeyFile = "$env:TEMP\sshkey_$UniqueSuffix"
$LogFile = "$env:TEMP\sshtunnel_$UniqueSuffix.log"
ssh-keygen -t rsa -b 2048 -f $KeyFile -N "" | Out-Null

# Start SSH tunnel
Start-Process ssh -ArgumentList "-i", $KeyFile, "-T", "-p", $SSHPort, "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=NUL", $Remote, $Dest `
    -RedirectStandardOutput $LogFile `
    -WindowStyle Hidden

# Wait briefly for output
Start-Sleep -Seconds 3

# Extract and display URL
$Content = Get-Content $LogFile
if ($Service -eq "pinggy") {
    $URL = ($Content | Select-String -Pattern '(https|tcp)://[a-zA-Z0-9.-]+\.pinggy\.link(:[0-9]+)?').Matches.Value | Select-Object -First 1
} else {
    $URL = ($Content | Select-String -Pattern 'https://[a-zA-Z0-9.-]+\.serveo\.net').Matches.Value | Select-Object -First 1
}

if ([string]::IsNullOrEmpty($URL)) {
    Write-Error "Failed to retrieve tunnel URL."
} else {
    Write-Host "Tunnel URL: $URL"
}

# Clean up
#Remove-Item $LogFile

