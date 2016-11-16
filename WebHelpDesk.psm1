<#
  .SYNOPSIS
    This module contains functions for working with the SolarWinds WebHelpDesk API in PowerShell
  
  .DESCRIPTION
    
  .LINK
    API Documentation Here: http://www.solarwinds.com/documentation/webhelpdesk/docs/whd_api_12.1.0/web%20help%20desk%20api.html#common-parameters-paging
  .NOTES
    Authors: Charles Crossan
  
  .VERSION 
    1.0.0

#>

function Connect-WHDService {
<#
    .PARAMETER username
        API UserName
    .PARAMETER Password
        API Password
    .PARAMETER WHDURL
        WebHelpDesk Base URL
#>
    param (
        [parameter(Mandatory=$true)]
        [String]
        $username,
        [String]
        $Password,
        [String]
        $apiKey,
        [Parameter(Mandatory=$true)]
        [String]
        $WHDURL
    )
    if ($apiKey)
    {
        $URI = "$($WHDURL)/helpdesk/WebObjects/Helpdesk.woa/ra/Session?username=$($username)&apiKey=$($apiKey)"
    }
    elseif ( $Password) {
        $URI = "$($WHDURL)/helpdesk/WebObjects/Helpdesk.woa/ra/Session?username=$($username)&password=$($Password)"
    }
    else {
        throw "APIKey or Password required"
    }

    $Response = Invoke-RestMethod -Uri $URI  -Method GET
    Set-Variable -Scope Global -Name "WHDURL" -Value $WHDURL
    Set-Variable -Scope Global -Name "WHDSessionKey" -Value $Response.sessionKey
    Set-Variable -Scope Global -Name "WHDUsername" -Value $username
    Set-Variable -Scope Global -Name "WHDPassword" -Value $Password
    Set-Variable -Scope Global -Name "WHDapikey" -Value $apiKey
    Set-Variable -Scope Global -Name "WHDSessionKeyExpiration" -Value $(Get-Date).AddSeconds(1800)
}

Function Invoke-WHDRESTMethod
{
    param(
        $EndpointURL,
        $Method = "GET",
        $Page=1,
        [System.Collections.Hashtable]
        $Parameters=@{}
    )
    if ( test-path variable:global:"WHDURL")
    {
        if ( test-path variable:global:"WHDUsername")
        {
             $Parameters.username=$($(Get-Variable -Name "WHDUsername").value)
        }
        else 
        {
            throw "WHDUsername required"
        }

        if ((test-path variable:global:"WHDapikey") -and -not ([string]::IsNullOrEmpty($($(Get-Variable -Name "WHDapikey").value))))
        {
            $Parameters.apiKey=$($(Get-Variable -Name "WHDapikey").value)
        }
        elseif (test-path variable:global:"WHDPassword") 
        {
            $Parameters.password=$($(Get-Variable -Name "WHDPassword").value)
        }
        else 
        {
            throw "APIKey or Password required"
        }
    }
    else 
    {
        throw "WHDURL Required"
    }
    $parameters.page=$Page
    $URI = "$($(Get-Variable -Name "WHDURL").Value)/helpdesk/WebObjects/Helpdesk.woa/ra/$($EndpointURL)"
    $parameterString = ($Parameters.GetEnumerator() | % { "$($_.Key)=$($_.Value)" }) -join '&'
    if ($parameterString)
    {
        $URI +="?$($parameterString)"
    }
    write-host $URI
    Invoke-RestMethod -uri $URI -Method $Method
    
    
}

function Get-WHDTicket 
{
    param(
        $TicketNumber,
        [ValidateSet('mine','group','flagged','recent')]
        $TicketList="mine",
        $RequestTypePartialName,
        $TicketStatusType,
        $QualifierString,
        $limit =10
    )

    $parameters=@{}
    if ($ticketNumber)
    {
        $URI = "Tickets/$($ticketNumber)"
    }
    elseif ($RequestTypePartialName -or $TicketStatusType)
    {
       
        $QualifierStrings = @()
        $QualifierStrings += $([System.Web.HttpUtility]::UrlEncode("(problemtype.problemTypeName caseInsensitiveLike '$RequestTypePartialName')"))
        $QualifierStrings += $([System.Web.HttpUtility]::UrlEncode("(statustype.statusTypeName caseInsensitiveLike '$TicketStatusType')"))
        $parameters.qualifier= $QualifierStrings -join "and"
        $URI = "Tickets"
    }
    elseif ($QualifierString)
    {
        $parameters.qualifier= $([System.Web.HttpUtility]::UrlEncode($QualifierString))
        $URI = "Tickets"
    }
    else {
        $URI =  "Tickets/$($ticketList)" 
    }

    $responses=@()
    $page = 1;
    $hasMore = $true
    while($hasMore -and $responses.count -lt $limit)
    {
        $temp = Invoke-WHDRESTMethod -EndpointURL $URI -Parameters $parameters -Page $page
        if ($temp -isnot [system.array] -or $temp.count -eq 0 )
        {
            $hasMore = $false
        }
        $responses+=$temp
        $page += 1 
    }


     foreach($ticket in $responses ) 
    {
        if ($ticket.shortDetail)
        {
            $ticket = Get-WHDTicket -TicketNumber $ticket.id
        }
        $ticket
    }
}

function Get-WHDRequestTypes 
{
    param(
        $limit
    )
    if ($limit)
    {
        $parameters=@{}
        $parameters.style="details"
        $parameters.list = "all"
        Invoke-WHDRESTMethod -EndpointURL "RequestTypes" -Parameters $parameters
    }
    else {
        Invoke-WHDRESTMethod -EndpointURL "RequestTypes"
    }
}

Function Get-WHDClient
{
   param(
       $UserName
    )
    $parameters = @{}
    $parameters.qualifier =$([System.Web.HttpUtility]::UrlEncode( "(email caseInsensitiveLike '$UserName')"))
    
    Invoke-WHDRESTMethod -EndpointURL "Clients" -Parameters $parameters
}

Function Get-WHDStatusTypes
{
      Invoke-WHDRESTMethod -EndpointURL "StatusTypes"
}