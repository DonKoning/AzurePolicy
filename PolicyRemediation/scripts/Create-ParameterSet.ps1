<#
.SYNOPSIS
    Since YAML pipelines do not support conditional or optional parameters, this script takes the input from a yaml pipelne 
    and filters the parameters to pass to the next step in the pipeline.

.DESCRIPTION
    This script takes the input from a yaml pipeline and filters the parameters to pass to the next step in the pipeline.
    The script will only pass the parameters that are required by the next step in the pipeline.

.PARAMETER ManagementGroupName
    The management group name to filter the parameters for.

.PARAMETER SubscriptionId
    The subscription id to filter the parameters for.

.PARAMETER ResourceGroup (optional)
    The resource group to filter the parameters for.

.PARAMETER ResourceId (optional)
    The resource id to filter the parameters for.

.PARAMETER PolicyAssignmentName (optional)
    The policy assignment name to filter the parameters for.

.PARAMETER PolicyDefinitionName (optional)
    The policy definition name to filter the parameters for.

.PARAMETER PolicyDefinitionReferenceId (optional)
    The policy definition reference id to filter the parameters for.

.NOTES
  Version:        1.0
  Author:         Don Koning
  Creation Date:  29-5-2022
#>

[CmdletBinding()]
Param(
    [String] [Parameter(Mandatory = $true)] $scope,
    [String] [Parameter(Mandatory = $false)] $managementGroupName,
    [String] [Parameter(Mandatory = $false)] $subscriptionId,
    [String] [Parameter(Mandatory = $false)] $resourceGroup = "optional",
    [String] [Parameter(Mandatory = $false)] $resourceId  = "optional",
    [String] [Parameter(Mandatory = $false)] $policyAssignmentName  = "optional",
    [String] [Parameter(Mandatory = $false)] $policyDefinitionName  = "optional",
    [String] [Parameter(Mandatory = $false)] $policyDefinitionReferenceId = "optional"
)

$InformationPreference = "Continue"

# declare variables
$Parameters = @{}
$parameterSet = $Null

# qnd add parameters to parameter set based on scope    
Switch ($scope) {

    "managementGroup" {
        
        $Parameters.Add("managementGroupName", "$managementGroupName")
        if($resourceGroup -ne "optional") {$parameters.Add("resourcegroup","$resourceGroup")}
        if($policyAssignmentName -ne "optional") {$parameters.Add("policyAssignmentName","$policyAssignmentName")}
        if($policyDefinitionName -ne "optional") {$parameters.Add("policyDefinitionName","$policyDefinitionName")}
        if($policyDefinitionReferenceId -ne "optional") {$parameters.Add("policyDefinitionReferenceId","$policyDefinitionReferenceId")}
                
        }
    "subscription" {
        $Parameters.Add("subscriptionId", "$subscriptionId")
        if($resourceGroup -ne "optional") {$parameters.Add("resourcegroup","$resourceGroup")}
        if($resourceId -ne "optional") {$parameters.Add("resourceId","$resourceId")}
        if($policyAssignmentName -ne "optional") {$parameters.Add("policyAssignmentName","$policyAssignmentName")}
        if($policyDefinitionName -ne "optional") {$parameters.Add("policyDefinitionName","$policyDefinitionName")}
        if($policyDefinitionReferenceId -ne "optional") {$parameters.Add("policyDefinitionReferenceId","$policyDefinitionReferenceId")}
        
        }
    Default {

        Write-Error "Scope parameter contains invalid value '$scope'. Valid values are 'managementGroup' or 'subscription'"
        exit

    }
}

foreach($item in $Parameters.GetEnumerator())
{
    $parameterSet = $parameterSet + "-" + $($item.Name) + " " + "`"$($item.Value)`""
}

# enable verbose if system.debug parameter is set on pipeline
if($env:SYSTEM_DEBUG){
    $parameterSet = $parameterSet + "-Verbose"
}

# format paramater set
$parameterSet = $parameterSet.Replace("`"-","`" -")

Write-Information "ParameterSet is: '$parameterSet'"
Write-Information "##vso[task.setvariable variable=parameterSet;isOutput=true;]$parameterSet" | Out-Null
