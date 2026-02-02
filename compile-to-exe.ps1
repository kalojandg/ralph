# Script to compile ralph.ps1 to ralph.exe
# Run this once to install ps2exe module:
# Install-Module -Name ps2exe -Scope CurrentUser

Write-Host "Installing ps2exe module (if not already installed)..."
if (!(Get-Module -ListAvailable -Name ps2exe)) {
    Install-Module -Name ps2exe -Scope CurrentUser -Force
}

Write-Host "Compiling ralph.ps1 to ralph.exe..."
Invoke-ps2exe -inputFile "ralph.ps1" -outputFile "ralph.exe" -noConsole:$false -noOutput:$false -noError:$false

if (Test-Path "ralph.exe") {
    Write-Host "✅ Success! ralph.exe has been created."
    Write-Host "You can now run: .\ralph.exe 10"
} else {
    Write-Host "❌ Compilation failed."
}
