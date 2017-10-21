$BackupPath = "D:\BACKUP"
$CredentialFile = "C:\scripts\ps\qnap-hypervserver.credential"

#--

if(Test-Path -Path $CredentialFile) {
	$Credential = Import-Clixml -Path $CredentialFile
} else {
	Write-Error -Message "Credential file not found (create with 'Get-Credential | Export-Clixml -Path <filename>')" -ErrorAction Stop
}

New-PSDrive -Name "qnap" -PSProvider "FileSystem" -Root "\\qnap\hypervbackup" -Credential $Credential

$BackupDateTimeFolder = Get-Date -Format "yyyyMMdd_HHmmss"
Copy-Item -Path $BackupPath -Destination "qnap:\$BackupDateTimeFolder" -Recurse

if($(Get-ChildItem -Path "qnap:\" | where name -match "[0-9+]_[0-9+]").Count -gt 3) {
	Remove-Item -Path $(Get-ChildItem -Path "qnap:\" | where name -match "[0-9+]_[0-9+]" | sort LastWriteTime | select -first 1).FullName -Recurse -Confirm:$false
}

Remove-PSDrive qnap
