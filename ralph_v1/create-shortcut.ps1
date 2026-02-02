# Creates a desktop shortcut for ralph.ps1

$WshShell = New-Object -comObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("$Home\Desktop\Ralph.lnk")
$Shortcut.TargetPath = "powershell.exe"
$Shortcut.Arguments = "-ExecutionPolicy Bypass -NoProfile -File `"$PSScriptRoot\ralph.ps1`" 10"
$Shortcut.WorkingDirectory = $PSScriptRoot
$Shortcut.IconLocation = "powershell.exe,0"
$Shortcut.Description = "Ralph Wiggum Algorithm (10 iterations)"
$Shortcut.Save()

Write-Host "✅ Shortcut created on Desktop: Ralph.lnk"
Write-Host "Note: It's configured for 10 iterations by default."
Write-Host "Edit the shortcut to change the number."
