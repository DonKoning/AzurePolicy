<#
.SYNOPSIS
    Based in the parameters passed, this script will remediate all non-compliant resources in scope.

.DESCRIPTION
    This script gets all non-compliant resources in scope (management group or subscription), apply a filter
    based on the optional parameters and creates a remediation job for each individual non-compliant resource.
    It uses multiple passes if there are resources that have multiple non-compliancies to prevent failed jobs.

.PARAMETER ManagementGroupName
    Target management group if scope is management group.

.PARAMETER SubscriptionId
    Target subscription if scope is subscription.

.PARAMETER ResourceGroup (optional)
    Resource group to filter on.

.PARAMETER ResourceId (optional)
    Resource ID to filter on.

.PARAMETER PolicyAssignmentName (optional)
    Policy assignment name to filter on.

.PARAMETER PolicyDefinitionName (optional)
    Policy definition name to filter on.

.PARAMETER PolicyDefinitionReferenceId (optional)
    Policy definition reference ID to filter on.

.PARAMETER Verbose (optional)
    Display verbose output.

.NOTES
  Version:        1.0
  Author:         Don Koning
  Creation Date:  29-5-2022
#>


[CmdletBinding()]
Param(
        [Parameter(Mandatory = $true,
        ParameterSetName="mg",
        HelpMessage = "Name of the management group to scope the remediations.")]
        [ValidateNotNullorEmpty()]
        [String]$ManagementGroupName,

        [Parameter(Mandatory = $true, 
        ParameterSetName="sub",
        HelpMessage = "Id of the subscription to scope the remediations.")]
        [ValidateNotNullorEmpty()]
        [String]$SubscriptionId,

        [Parameter(Mandatory = $false,
        ParameterSetName="mg",
        HelpMessage = "Optionally filter on ResourceGroup.")]
        [parameter(Mandatory = $false, ParameterSetName = "sub")]
        [String]$ResourceGroup,

        [Parameter(Mandatory = $false,
        ParameterSetName="sub",
        HelpMessage = "Optionally filter on ResourceId.")]
        [String]$ResourceId,

        [Parameter(Mandatory = $false,
        ParameterSetName="mg",
        HelpMessage = "Optionally filter on PolicyAssignmentName.")]
        [parameter(Mandatory = $false, ParameterSetName = "sub")]
        [String]$PolicyAssignmentName,

        [Parameter(Mandatory = $false,
        ParameterSetName="mg",
        HelpMessage = "Optionally filter on PolicyDefinitionName.")]
        [parameter(Mandatory = $false, ParameterSetName = "sub")]
        [String]$PolicyDefinitionName,

        [Parameter(Mandatory = $false,
        ParameterSetName="mg",
        HelpMessage = "Optionally filter on PolicyDefinitionReferenceId.")]
        [parameter(Mandatory = $false, ParameterSetName = "sub")]
        [String]$PolicyDefinitionReferenceId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

##################################################################################################################
###### Functions
##################################################################################################################
function Start-AzPolicyRemediationPerResource {
    param (
        [Parameter(Mandatory = $true)][String] $PolicyAssignmentId,
        [Parameter(Mandatory = $true)][String] $PolicyDefinitionId,
        [Parameter(Mandatory = $false)][String] $PolicyReferenceId = $null,
        [Parameter(Mandatory = $true)][String] $ResourceId
    )

    Write-Verbose "`tStart Function Start-AzPolicyRemediationPerResource"

    # Variables
    [int]$NoOfRemediationTasks = 0
    $PolicyName = $($PolicyDefinitionId.Split('/'))[$($PolicyDefinitionId.Split('/')).count - 1]

    # Process assigned policy
    if (-not $PolicyReferenceId) {
        # PolicyDefinitionReferenceId is null, so applies to assigned policy

        Write-Verbose "`tProcess resourceId '$ResourceId'..."

        Write-Verbose "`tCreate parameter object"
        $ParameterHashTable = @{ 
            'Name'               = "Automated-remediation-$PolicyName-$PolicyDefinitionId"
            'PolicyAssignmentId' = "$PolicyAssignmentId"
            'Scope'              = "$ResourceId"
        }   

        Write-Verbose "`tStart Policy Remediation task for Policy Definition '$PolicyName'..."

        $ParameterHashTable

        try {
            $Job = Start-AzPolicyRemediation @ParameterHashTable -AsJob 

            Write-Verbose "`tStarted Policy Remediation task with JobId '$($Job.Id)' for Policy Definition '$PolicyName'"
            $NoOfRemediationTasks++
        }
        catch {
            Write-Error "$_.Exception.Message"
        }
    }
    elseif ($PolicyReferenceId) {
        # PolicyDefinitionReferenceId is not null, so applies to assigned policy set
        #Write-Verbose "`tFound '$($NonCompliantResources.Count)' non-compliant resource(s) that can be remediated for Policy Definition '$($PolicyDefinition.Properties.DisplayName)'" -Verbose

        # Should result in a single resource match based on PolicyReferenceId

        Write-Verbose "`tProcess resourceId '$ResourceId'..."  -Verbose

        Write-Verbose "`tCreate parameter object"  -Verbose
        $ParameterHashTable = @{ 
            'Name'                        = "Automated-remediation-$PolicyName-$($PolicyReferenceId)"
            'PolicyAssignmentId'          = "$PolicyAssignmentId"
            'PolicyDefinitionReferenceId' = "$PolicyReferenceId"
            'Scope'                       = "$ResourceId"
        }

        try {
            $Job = Start-AzPolicyRemediation @ParameterHashTable -AsJob

            Write-Verbose "`tStarted Policy Remediation task with JobId '$($Job.Id)' for Policy Definition '$PolicyName' with ReferenceId '$PolicyReferenceId'" -Verbose
            $NoOfRemediationTasks++
        }
        catch {
            Write-Error "$_.Exception.Message"
        }
    }
    else {
        Write-Warning "`tNo matching condition found"    
    }

    Write-Verbose "`tExit function Start-AzPolicyRemediationPerResource" -Verbose
    Write-Verbose "" -Verbose
    return $NoOfRemediationTasks
}

##################################################################################################################
###### Main
##################################################################################################################

# Variables
$SupportedEffects = @('deployifnotexists','modify')
$FilteredNonCompliantResources = @()
$Filter = @{}
$FilterStr = $Null

# Initialize counters
$TotalNoOfNonCompliantResources = 0
$FilteredNoOfNonCompliantResources = 0
$NoOfRemediationTasksCreated = 0

# For testing only (clean up previous jobs in same session
$jobstoremove = get-job   
foreach($job in $jobstoremove) {remove-job -Job $job -Force}

# Get Policy State based on scope selected
switch ($PSCmdlet.ParameterSetName) 
{
    mg 
    {  

        Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
        Write-Verbose " Selected scope Management Group '$ManagementGroupName'" -Verbose
        Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose

        $ManagementGroupObj = Get-AzManagementGroup -GroupName $ManagementGroupName -ErrorAction SilentlyContinue
        if($ManagementGroupObj) 
        {
            $NonCompliantResources = Get-AzPolicyState -ManagementGroupName $ManagementGroupObj.Name -Filter " `
                (PolicyAssignmentName eq '$($PolicyAssignmentName)' or PolicyDefinitionName eq '$($PolicyDefinitionName)') `
                and ComplianceState eq 'NonCompliant' `
                "
        }
        else
        {
            Write-Warning " Management Group '$ManagementGroupName' not found."
            exit    
        }

        $TotalNoOfNonCompliantResources = $NonCompliantResources | Measure-Object
    }
    sub 
    {

        Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
        Write-Verbose " Selected scope SubscriptionId '$SubscriptionId'" -Verbose
        Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
        
        $SubscriptionObj = Get-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction SilentlyContinue
        if($SubscriptionObj) 
        {
            $NonCompliantResources = Get-AzPolicyState -SubscriptionId $SubscriptionObj.Id -Filter " `
                (PolicyAssignmentName eq '$($PolicyAssignmentName)' or PolicyDefinitionName eq '$($PolicyDefinitionName)') `
                and ComplianceState eq 'NonCompliant' `
            "
        }
        else
        {
            Write-Warning " SubscriptionId '$SubscriptionId' not found."
            exit    
        }

        $TotalNoOfNonCompliantResources = $NonCompliantResources | Measure-Object
    }
}
# end region

# Report on parameters
Write-Verbose " Parameters passed:" -Verbose

Foreach($Object in $PSBoundParameters.GetEnumerator()) 
{
    Write-Verbose " -$($Object.Key.PadRight(28,' ')) : $($Object.Value)" -Verbose
}
# end region

# Output selected filters
Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
Write-Verbose " Selected filters:" -Verbose
Foreach($Object in $PSBoundParameters.GetEnumerator()) 
{

    if($($Object.Key) -ne "ManagementGroupName" -and $($Object.Key) -ne "SubscriptionId" -and $($Object.Key) -ne "Verbose")
    {
        Write-Verbose " -$($Object.Key.PadRight(28,' ')) : $($Object.Value)" -Verbose

        $Filter.Add($($Object.Key), $($Object.Value))
    }
}
Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
# end region

# Display Non-Compliant resources found
if($PSBoundParameters['Verbose'])
{
    $NonCompliantResources | Format-Table ResourceGroup, PolicyAssignmentName, PolicyDefinitionName, PolicyDefinitionReferenceId, ResourceId -AutoSize
    Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
}
Write-Verbose " Total number of Non-Compliant resources found           : $($TotalNoOfNonCompliantResources.Count)" -Verbose
# end region

# Convert HT to FilterStr
if($Filter.Count -eq 0) {$Filter.Add("ComplianceState", "NonCompliant")}

foreach($item in $Filter.GetEnumerator())
{

$FilterStr = $FilterStr + "(" + "`$_.$($item.Name)" + ' -eq ' +  "`"$($item.Value)`""+ ")"

}
$FilterStr = $FilterStr.Replace(")(",") -and (")
# end region

# Applying the filters to the TotalNonCompliantResources
[ScriptBlock]$Filter = [ScriptBlock]::Create($FilterStr)
$FilteredNonCompliantResources = $NonCompliantResources | Where-Object -FilterScript $Filter

$FilteredNoOfNonCompliantResources = $FilteredNonCompliantResources | Measure-Object
# end region

# Display Non-Compliant resources found after filtering
if($PSBoundParameters['Verbose'])
{
    $FilteredNonCompliantResources | Format-Table SubscriptionId, ResourceGroup, PolicyAssignmentName, PolicyDefinitionName, PolicyDefinitionReferenceId, ResourceId -AutoSize
    Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
}
Write-Verbose " Total number of Non-Compliant resources after filtering : $($FilteredNoOfNonCompliantResources.Count)" -Verbose
# end region

# Check remaining resources after filtering
if($FilteredNoOfNonCompliantResources.Count -eq 0)
{
    Write-Warning " No resources found to remediate that match the criteria. Exiting script..."
    exit
}
# end region

# Start remediation tasks
Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
Write-Verbose " Start remediation task(s) for $($FilteredNoOfNonCompliantResources.Count) non-compliant resources..." -Verbose
Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose

# Throttling remediation of resources that have multiple non-compliancies to prevent tasks from failing
do{

    $ResourcesProcessed = @()
    $DuplicateResources = @()

    foreach($NonCompliantResource in $FilteredNonCompliantResources){

        if([bool]$NonCompliantResource.PolicyDefinitionReferenceId)
        {   
            Write-Verbose " Processing Policy Set" -Verbose

            if($NonCompliantResource.ResourceId -in $ResourcesProcessed){
                Write-Verbose " Add item '$($NonCompliantResource.ResourceId)' to DuplicateResources list" -Verbose
                $DuplicateResources += $NonCompliantResource
            }
            else{
                Write-Verbose " Process item '$($NonCompliantResource.ResourceId)'" -Verbose

                $NoOfRemediationTasks = Start-AzPolicyRemediationPerResource -PolicyAssignmentId $NonCompliantResource.PolicyAssignmentId -PolicyDefinitionId $NonCompliantResource.PolicyDefinitionId -PolicyReferenceId $NonCompliantResource.PolicyDefinitionReferenceId -ResourceId $NonCompliantResource.ResourceId
                $NoOfRemediationTasksCreated += $NoOfRemediationTasks
                
                $ResourcesProcessed += $NonCompliantResource.ResourceId
            }
        }
        else 
        {
            Write-Verbose " Processing Policy"

            $NoOfRemediationTasks = Start-AzPolicyRemediationPerResource -PolicyAssignmentId $NonCompliantResource.PolicyAssignmentId -PolicyDefinitionId $NonCompliantResource.PolicyDefinitionId -ResourceId $NonCompliantResource.ResourceId
            $NoOfRemediationTasksCreated += $NoOfRemediationTasks
        }

    }

    $FilteredNonCompliantResources = $DuplicateResources
    
    if($($DuplicateResources.Count) -gt 0){
        Write-Verbose " Remaining: $($DuplicateResources.Count)"

        # Wait untill processing remaining list of resources 
        switch ($PSCmdlet.ParameterSetName) 
        {
            mg{
                do{
                    Start-Sleep 30
                }
                while ([bool]$(Get-AzPolicyRemediation -scope $ManagementGroupObj.Id | where-Object {$_.ProvisioningState -eq "In Progress"}))   
            }
            sub{
                do{
                    Start-Sleep 30
                }
                while ([bool]$(Get-AzPolicyRemediation -scope "/subscriptions/$subscriptionId" | where-Object {$_.ProvisioningState -eq "In Progress"}))  
            }
        }
    }

} until ($DuplicateResources.Count -eq 0)
# end region

if ($NoOfRemediationTasksCreated -gt 0) {
    Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
    Write-Verbose " Waiting for remediation task(s) to complete..." -Verbose
    Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose

    while (Get-Job -State 'Running') {
        Write-Verbose "`tWaiting for '$($(Get-Job -State 'Running' | Measure-Object).count)' jobs to complete..." -Verbose
        Start-Sleep -Seconds 20
    }
}

Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
Write-Verbose " Job(s) Report" -Verbose 
Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
Write-Verbose " TotalNoOfNonCompliantResources    : $(($NonCompliantResources | Measure-Object).Count)" -Verbose
Write-Verbose " FilteredNoOfNonCompliantResources : $($FilteredNoOfNonCompliantResources.Count)" -Verbose
Write-Verbose " NoOfRemediationTasksCreated       : $NoOfRemediationTasksCreated" -Verbose
Write-Verbose "-------------------------------------------------------------------------------------------------------------------" -Verbose
