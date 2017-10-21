$BackupPath = "D:\BACKUP"
$SchuldedTasksFolderName = "ScheduledTasks"
$BackupScheduledTasksPath = Join-Path -Path $BackupPath -ChildPath $SchuldedTasksFolderName

#--

if(-not (Test-Path -Path $BackupScheduledTasksPath)) {
	New-Item -Path $BackupPath -Name $SchuldedTasksFolderName -ItemType Directory
} else {
    Remove-Item -Path "$BackupScheduledTasksPath\*" -Filter "*.xml"
}

$ScheduledTasksArray = Get-ScheduledTask | where TaskPath -eq "\"
foreach($ScheduledTask in $ScheduledTasksArray) {
	Export-ScheduledTask -TaskName $ScheduledTask.TaskName | Out-File -FilePath $(Join-Path -Path $BackupScheduledTasksPath -ChildPath $ScheduledTask.TaskName).Replace(".ps1",".xml")
}
