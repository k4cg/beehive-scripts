$influxserver="http://192.168.178.15:8086"
$db="virtualization"

function post-influx {
    Param(
      [string]$data
      )

    $uri = $influxserver+"/write?db="+$db+'&precision=s'
    Invoke-RestMethod -Uri $uri -Method POST -Body $data
}

foreach($vm in Get-VM){
    $name=$vm.name
    $state=$vm.State
    $MemoryA=$vm.MemoryAssigned/1MB
    $MemoryD=$vm.MemoryDemand/1MB
    [uint64]$UnixTimestamp = [double]::Parse((Get-Date -UFormat %s))

    $postdata = "hyperv,VmName="+$name+" RamAssigned="+$MemoryA+",RamDemand="+$MemoryD+",State="""+$state+""" $UnixTimestamp"
    post-influx -data $postdata
}

