$BackupPath = "D:\BACKUP"
$HyperVFolderName = "HyperV"
$BackupHyperVPath = Join-Path -Path $BackupPath -ChildPath $HyperVFolderName

#--

if(-not (Test-Path -Path $BackupHyperVPath)) {
	New-Item -Path $BackupPath -Name $HyperVFolderName -ItemType Directory
}

$VmArray = Get-VM
foreach($Vm in $VmArray) {
    $VmExportPath = Join-Path -Path $BackupHyperVPath -ChildPath $($Vm.Name)
    if(Test-Path -LiteralPath $VmExportPath) {
        Remove-Item -LiteralPath $VmExportPath -Recurse -Confirm:$false
    }
    Export-VM -Name $($Vm.Name) -Path $BackupHyperVPath
}
