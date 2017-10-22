$ScriptsPath = "C:\scripts"
$BackupPath = "D:\BACKUP\scripts"

#--

if(Test-Path -Path $BackupPath) {
	Remove-Item -Path $BackupPath -Recurse -Force
}

Copy-Item -Path $ScriptsPath -Destination $BackupPath -Recurse
