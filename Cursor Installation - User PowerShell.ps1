# 1.Define the destination
$setup = "$env:USERPROFILE\Downloads\Cursor Setup.exe" 

# 2. Define the URL: and the User Agent 
$url = "https://downloader.cursor.sh/windows/installer/x64" 
$UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

# 3. Download using the User Agent 
Write-Host "Downloading Cursor Setup as a user and not admin"
try {
    Invoke-WebRequest -Uri $url -OutFile $setup -UserAgent $UserAgent -ErrorAction Stop
    Write-Host "Download completed successfully: $setup"
} catch {
    Write-Host "Failed to download Cursor Setup: $_"
    # If this fails, the domain itself must be hard-blocked by DNS or firewall
    return
}

# 4. Install silently
if (Test-Path $setup) {
    Write-Host "Installing Cursor Setup silently"
    Start-Process -FilePath $setup -ArgumentList "/S" -Wait
    Write-Host "Installation completed successfully"
} else {
    Write-Host "The setup file does not exist: $setup"
}

