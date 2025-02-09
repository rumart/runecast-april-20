 #Requires -Version 6.0
<#
    .SYNOPSIS
        Script for outputting VCSA info to Influx
    .DESCRIPTION
        This script will fetch build, version and uptime from 
        the VCSA REST API and post this data to a InfluxDB database

        This script is tested against vCenter 6.7U1, please note that 
        there might be differences in other version
        Note that this script is developed with PS Core and uses functionality
        not present in the desktop version of PS (v 5>=). A different version of the
        script that uses PS 5 can be found here, https://github.com/rumart/vmug-norway-dec-18
    .NOTES
        Author: Rudi Martinsen
        Created: 28/11-2018
        Version: 1.0.0
        Revised: 
        Changelog:
    .LINK
        https://www.rudimartinsen.com/2018/12/03/vsphere-performance-vcenter-server-appliance-vcsa-monitoring/
#>
#Function for generating correct timestamp for influx input
function Get-DBTimestamp($timestamp = (get-date)){
    if($timestamp -is [system.string]){
        $timestamp = [datetime]::ParseExact($timestamp,'dd.MM.yyyy HH:mm:ss',$null)
    }
    return $([long][double]::Parse((get-date $($timestamp).ToUniversalTime() -UFormat %s)) * 1000 * 1000 * 1000)
}

########################
## Environment params ##
########################
$vcenter = "vcenter-01.rhmlab.lab"
$username = "apiuser@vsphere.local"
$pass = "VMware1!"

$database = "vcsa_demo"
$influxServer = "192.168.100.131"
$influxPort = 8086

################
## End params ##
################

$BaseUri = "https://$vcenter/rest/"

#Authenticate to vCenter
$SessionUri = $BaseUri + "com/vmware/cis/session"
$auth = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($UserName+':'+$Pass))
$header = @{
  'Authorization' = "Basic $auth"
}
$token = (Invoke-RestMethod -Method Post -Headers $header -Uri $SessionUri -SkipCertificateCheck).Value
$sessionheader = @{'vmware-api-session-id' = $token}

#Create array for storing data
$tbl = @()

#Fetch timestamp
$timestamp = Get-DBTimestamp

#API Endpoints
$verUri = $BaseUri + "appliance/system/version"
$upUri = $BaseUri + "appliance/system/uptime"

#Fetch data
$verResponse = Invoke-RestMethod -Method Get -Headers $sessionheader -Uri $verUri -SkipCertificateCheck
$upResponse = Invoke-RestMethod -Method Get -Headers $sessionheader -Uri $upUri -SkipCertificateCheck

#Build variables for Influx
$version = $verResponse.value.version
$build = $verResponse.value.build
$uptime = $upResponse.value

#Add to array
$tbl += "appliance_info,server=$vcenter version=""$version"",build=$build,uptime=$uptime $timestamp"

#Post data to Influx API
$postUri = "http://$influxServer" + ":$influxPort/write?db=$database"
Invoke-RestMethod -Method Post -Uri $postUri -Body ($tbl -join "`n") 
