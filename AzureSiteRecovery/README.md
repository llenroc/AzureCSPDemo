# Automating ASR with Azure PowerShell in Azure Resource Manager.

## Overview

This article shows you how to use Microsoft Azure PowerShell for  Azure Resource Manager to automate common tasks for deploying Azure Site Recovery, including orchestrating and automating protection for workloads running on virtual machines on Hyper-V host servers that are located in VMM private clouds. In this scenario, virtual machines are replicated from a primary VMM site to Secondary VMM site using Hyper-V Replica.

The article includes prerequisites for the scenario, and shows you how to set up a Site Recovery vault, install the Azure Site Recovery Provider on the source VMM server, register the server in the vault configure protection settings for VMM clouds that will be applied to all protected virtual machines, and then enable protection for those virtual machines. Finish up by testing the failover to make sure everything's working as expected.

If you run into problems setting up this scenario, post your questions on the [Azure Recovery Services Forum][1].

## Prerequisites

To complete this tutorial, you must have Azure PowerShell version 0.9.6 or later. To install the latest version and associate it with your Azure subscription, see [How to install and configure Azure PowerShell][2].

This tutorial is designed for PowerShell beginners, but it assumes that you understand the basic concepts, such as modules, cmdlets, and sessions. For more information about Windows PowerShell, see [Getting Started with Windows PowerShell][3].
To know more on how to leverage Azure PowerShell with Azure Resource manager see [Using Azure PowerShell with Azure Resource Manager][4].

## Step 1: Setup the subscription

1. Start PowerShell. You can use any host program that you like, such as the Azure PowerShell console or Windows PowerShell ISE.
2. Use the *Switch-AzureMode* cmdlet to import the cmdlets in the AzureResourceManager and AzureProfile modules.
````powershell
Switch-AzureMode AzureResourceManager
````

3. To add your Azure account to the Windows PowerShell session, use the *Add-AzureAccount* cmdlet. If you are a CSP partner and working on behalf of a tenant, you need to specify the customer as a tenant while adding the Azure account.
````powershell
Add-AzureAccount -Tenant "customer"
````

4. An account can have several subscriptions. To select the subscription to operate on use the *Select-AzureSubscription* cmdlet.
````powershell
Select-AzureSubscription -SubscriptionName $SubscriptionName
````

5. If you are using Azure Site Recovery cmdlets for the first time in the given subscription, you need to register Azure provider for Site Recovery.
````powershell
Register-AzureProvider -ProviderNamespace Microsoft.SiteRecovery
````

## Step 2: Setup the vault context
1. To access the Azure Site Recovery vault  in your Azure subscription use the *Get-AzureSiteRecoveryVault* cmdlet.
````powershell
$Vault = Get-AzureSiteRecoveryVault -ResouceGroupName ````

2. You can download the vault settings file to  local machines torage using *Get-AzureSiteRecoveryVaultSettingsFile* cmdlet.
````powershell
Get-AzureSiteRecoveryVaultSettingsFile -Vault $Vault -Path $OutputPathForSettingsFile
````

3. You can setup the context for the Azure Site Recovery vault using *Import-AzureSiteRecoveryVaultSettingsFile* cmdlet. Post this all cmdlets will execute under given vault context.
````powershell
Import-AzureSiteRecoveryVaultSettingsFile -Path $VaultSetingsFile.FilePath
````

## Step 3: Configure the Clouds for protection
After the System Center Virtual Machine Manager server is registered, you can configure cloud protection settings. When you install the ASR Provider on the VMM server you can select the option Synchronize cloud data with the vault after which the clouds will be available as protection containers in the vault.
1. To access the primary and secondary protection container execute the *Get-AzureSiteRecoveryProtectionContainer* cmdlet.
````powershell
$PrimaryContainer = Get-AzureSiteRecoveryProtectionContainer -FriendlyName  $PrimaryCloudName
$RecoveryContainer = Get-AzureSiteRecoveryProtectionContainer -FriendlyName  $RecoveryCloudName
````
2. Create a protection profile for protection by running the *New-AzureSiteRecoveryProtectionProfile* cmdlet.
````powershell
New-AzureSiteRecoveryProtectionProfile -Name $ProtectionProfileName `
  -ReplicationProvider HyperVReplica `
  -ReplicationMethod Online `
  -ReplicationFrequencyInSeconds 30 `
  -RecoveryPoints 1 `
  -ApplicationConsistentSnapshotFrequencyInHours 0 `
  -ReplicationPort 8083 `
  -Authentication Kerberos `
  -AllowReplicaDeletion
$ProtectionProfile = Get-AzureSiteRecoveryProtectionProfile -Name $ProtectionProfileName
````
3. To complete the configuration of the protection container start the association of the protection container and profile using `*Start-AzureSiteRecoveryProtectionProfileAssociationJob* cmdlet.
````powershell
Start-AzureSiteRecoveryProtectionProfileAssociationJob `
  -ProtectionProfile $ProtectionProfile `
  -PrimaryProtectionContainer $PrimaryContainer `
  -RecoveryProtectionContainer $RecoveryContainer
````

## Step 4: Enable Protection of the VM
After the cloud is configured correctly server is registered, you can enable protection for virtual machines in the cloud using following steps
1. Select the virtual Machine on which protection need to be enabled using *Get-AzureSiteRecoveryProtectionEntity* cmdlet.
````powershell
$VM = Get-AzureSiteRecoveryProtectionEntity `
  -ProtectionContainer $PrimaryContainer `
  -FriendlyName $VMName
````

2. Enable the protection on the virtual machine using the *Set-AzureSiteRecoveryProtectionEntity* cmdlet.
````powershell
Set-AzureSiteRecoveryProtectionEntity -ProtectionEntity $VM -Protection Enable
````

## Step 5:  Test Failover the VM
Once protection is setup, you can test your deployment by running a a test failover for a single virtual machine. Test failover simulates your failover and recovery mechanism
1. Select the virtual Machine on which protection need to be enabled using *Get-AzureSiteRecoveryProtectionEntity* cmdlet.
````powershell
$VM = Get-AzureSiteRecoveryProtectionEntity `
  -ProtectionContainer $PrimaryContainer`
  -FriendlyName  $VMName
````

2. To start the test failover of the VM use *Start-AzureSiteRecoveryTestFailoverJob* cmdlet.
````powershell
$currentJob = Start-AzureSiteRecoveryTestFailoverJob `
  -ProtectionEntity $VM `
  -Direction PrimaryToRecovery
````
3. Once the VM functionality is been validated you can be complete the failover using below cmdlet.
````powershell
Resume-AzureSiteRecoveryJob -Id $currentJob.Name
````

[1]: (http://go.microsoft.com/fwlink/?LinkId=313628)
[2]: (https://azure.microsoft.com/en-us/documentation/articles/powershell-install-configure/)
[3]: (http://technet.microsoft.com/library/hh857337.aspx)
[4]: (https://azure.microsoft.com/en-us/documentation/articles/powershell-azure-resource-manager/)
