$TempPath = "C:\scripts\temp"
$TempFile = Join-Path -Path $TempPath -ChildPath "updateVespiaryMediaWikiSectionVms_current.txt"
$CompareFile = Join-Path -Path $TempPath -ChildPath "updateVespiaryMediaWikiSectionVms_old.txt"
$CredentialFile = "C:\scripts\vespiary-scripts\wiki-Rezeptionistin.credential"
$MediaWikiApiUri = "https://k4cg.org/api.php"

#--

Add-Type -AssemblyName System.Web

$MediaWikiPage = "Host:vespiary.intern.k4cg.org"
$MediaWikiSection = "VMs"

if(Test-Path $TempFile) {
    Move-Item -Path $TempFile -Destination $CompareFile -Confirm:$false -Force
}

$SectionContent = @"
==$MediaWikiSection==
{| class="wikitable sortable"
|-
! Name !! Nested !! CPUs !! RAM (MB) !! HDD (GB)
"@

foreach($Vm in $(Get-Vm)) {
	$VmName = $Vm.name
	
	$VmNested = $(Get-VMProcessor -VMName $Vm.Name | select ExposeVirtualizationExtensions).ExposeVirtualizationExtensions
	
	$VmCpus = $Vm.ProcessorCount
	
	if($Vm.DynamicMemoryEnabled) {
		$VmRam = $Vm.MemoryMaximum/1MB
	} else {
		$VmRam = $Vm.MemoryStartup/1MB
	}
	
	$VmHdd = 0
	foreach($Hdd in $(Get-VHD -VMId $Vm.Id)) {
		$VmHdd += $Hdd.Size/1GB
	}
    
	$SectionContent += @"

|-
| $VMName || $VmNested || $VmCpus || $VmRam || $VmHdd
"@
}
	
$SectionContent += @"

|}
"@

$SectionContent | Out-File -FilePath $TempFile

if(Test-Path -Path $CompareFile) {
	if(-not(Compare-Object -ReferenceObject (Get-Content -Path $TempFile) -DifferenceObject (Get-Content -Path $CompareFile))) {
		Write-Verbose -Message "Exiting because no changes found"
		Break
	}
}

$Credential = Import-Clixml $CredentialFile
$MediaWikiUsername = [System.Web.HttpUtility]::UrlEncode($($Credential.username).Replace("\", ""))
$MediaWikiPassword = [System.Web.HttpUtility]::UrlEncode($Credential.GetNetworkCredential().Password)
$Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$Body = @{}
$Body.action = 'login'
$Body.format = 'json'
$Body.lgname = $MediaWikiUsername
$Body.lgpassword = $MediaWikiPassword

$RestResultObject = Invoke-RestMethod -Method Post -Uri $MediaWikiApiUri -Body $Body -WebSession $Session

$Body.lgtoken = $RestResultObject.login.token

$RestResultObject = Invoke-RestMethod -Method Post -Uri $MediaWikiApiUri -Body $Body -WebSession $Session

if($RestResultObject.login.result -ne 'Success') {
	Write-Error "Wiki login failed" -ErrorAction Stop
}

$Body = @{}
$Body.action = 'parse'
$Body.format = 'json'
$Body.page = $MediaWikiPage
$Body.prop = 'sections'

$RestResultObject = Invoke-RestMethod -Method Post -Uri $MediaWikiApiUri -Body $Body -WebSession $Session

$SectionId = $null

foreach($Section in $RestResultObject.parse.sections) {
	if($Section.line -eq $MediaWikiSection) {
		$SectionId = $Section.index
		Break
	}
}

if([String]::IsNullOrEmpty($SectionId)) {
	Write-Error -Message "Section index not found" -ErrorAction Stop
}

$Body = @{}
$Body.action = 'query'
$Body.format = 'json'
$Body.meta = 'tokens'
$Body.type = 'csrf'

$RestResultObject = Invoke-RestMethod -Method Post -Uri $MediaWikiApiUri -Body $Body -WebSession $Session

$CsrfToken = $RestResultObject.query.tokens.csrftoken

$Body = @{}
$Body.action = 'edit'
$Body.format = 'json'
$Body.bot = '1'
$Body.title = $MediaWikiPage
$Body.section = $SectionId
$Body.summary = "Section 'VMs' updated"
$Body.text = $SectionContent
$Body.token = $CsrfToken

$RestResultObject = Invoke-RestMethod -Method Post -Uri $MediaWikiApiUri -Body $Body -WebSession $Session

$Body = @{}
$Body.action = 'logout'
$Body.format = 'json'

$RestResultObject = Invoke-RestMethod -Method Post -Uri $MediaWikiApiUri -Body $Body -WebSession $Session

