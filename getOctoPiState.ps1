$apiCred = Import-Clixml -Path c:\scripts\beehive-scripts\octopi-apikey.credential
$apiKey = $apiCred.GetNetworkCredential().Password

$apiUrl = "http://192.168.178.185/api/"
$apiUrlAppendix = "?apikey=$apiKey"

function Invoke-ApiRequest($apiOperation) {
	$apiRequestUrl = $apiUrl, $apiOperation, $apiUrlAppendix -join ""
	$apiRequestJson = Invoke-WebRequest -Uri $apiRequestUrl
	$apiRequestObject = ConvertFrom-Json -InputObject $apiRequestJson
	return $apiRequestObject
}

$jobObject = Invoke-ApiRequest "job"
$printerState = $jobObject.state
if($printerState -eq 'Printing') {
	$filename = $jobObject.job.file.name
	$completion = [Math]::Round($jobObject.progress.completion,2)
	$printTime = [TimeSpan]::fromseconds($jobObject.progress.printTime)
	$printTimeLeft = [TimeSpan]::fromseconds($jobObject.progress.printTimeLeft)
} else {
	$filename = '-'
	$completion = '-'
	$printTime = '-'
	$printTimeLeft = '-'
}

$printerObject = Invoke-ApiRequest "printer"
$printerState = $printerObject.state.text
$temperatureBedActual = $printerObject.temperature.bed.actual
$temperatureBedTarget = $printerObject.temperature.bed.target
$temperatureTool0Actual = $printerObject.temperature.tool0.actual
$temperatureTool0Target = $printerObject.temperature.tool0.target

$TempPath = "C:\scripts\temp"
$TempFile = Join-Path -Path $TempPath -ChildPath "updateMediaWikiOctoPiSectionStatus_current.txt"
$CompareFile = Join-Path -Path $TempPath -ChildPath "updateMediaWikiOctoPiSectionStatus_old.txt"
$CredentialFile = "C:\scripts\beehive-scripts\wiki-Rezeptionistin.credential"
$MediaWikiApiUri = "https://k4cg.org/api.php"

#--

Add-Type -AssemblyName System.Web

$MediaWikiPage = "Host:octopi.intern.k4cg.org"
$MediaWikiSection = "Status"

if(Test-Path $TempFile) {
    Move-Item -Path $TempFile -Destination $CompareFile -Confirm:$false -Force
}

$SectionContent = @"
==$MediaWikiSection==
===Drucker===
{| class="wikitable"
|-
! Status !! Bed Actual !! Bed Target !! Tool0 Actual !! Tool0 Target
|-
| $printerState || $temperatureBedActual °C || $temperatureBedTarget °C || $temperatureTool0Actual °C || $temperatureTool0Target °C
|}
===Job===
{| class="wikitable"
|-
! Datei !! Fortschritt !! Dauer !! Verbleibend
|-
| $filename || $completion % || $printTime || $printTimeLeft
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

