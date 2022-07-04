# Azure Policy Remediation

# Introduction

Unfortunaltely, Azure Policy currently doesn't support auto-remediation of non-compliant resources. When working with Azure policy you'll regularly find yourself in a situation where you need to run manual remediation tasks to bring non-compliant resources back to a compliant state. 

To automate these tasks, I've created a sample pipeline and scripts that can be used to automate your policy remediation efforts.
<br>

# Table of Contents

- [Introduction](#introduction)
- [Approach](#approach)
- [Implementation](#implementation)


# Approach

My goal is to have a remediation solution that can be used for most common scenario's and has the flexibility to choose a target scope that varies between a management group to an individual resource.

# Implementation

The solution uses an Azure DevOps pipeline to run the remediation task(s), but the PowerShell script can also be used seperately. The solution first determines the main scope, Management Group or Subscription and then leverages filters to optionally narrow down the scope.

