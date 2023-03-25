Describe "Test-PolicyRemediationScript" {
    Context "When running the script" {
        It "Should get all non-compliant resources in scope and create a remediation job for each individual non-compliant resource." {
            # Set up test variables
            $ManagementGroupName = "TestMG"
            $SubscriptionId = "TestSub"
            $ResourceGroup = "TestRG"
            $ResourceId = "TestResource"
            $PolicyAssignmentName = "TestAssignment"
            $PolicyDefinitionName = "TestDefinition"
            $PolicyDefinitionReferenceId = "TestReference"

            # Mock Start-AzPolicyRemediation cmdlet
            Mock Start-AzPolicyRemediation {
                [PSCustomObject] @{
                    Id = "TestRemediationJob"
                }
            } -Verifiable

            # Run script
            . .\PolicyRemediationScript.ps1 -ManagementGroupName $ManagementGroupName -ResourceGroup $ResourceGroup -PolicyAssignmentName $PolicyAssignmentName -PolicyDefinitionName $PolicyDefinitionName

            # Verify that Start-AzPolicyRemediation was called
            Assert-MockCalled Start-AzPolicyRemediation -Exactly 1 -ParameterFilter { $PolicyAssignmentId -ne $null -and $PolicyDefinitionId -ne $null -and $ResourceId -eq $ResourceId }
        }
    }
}
