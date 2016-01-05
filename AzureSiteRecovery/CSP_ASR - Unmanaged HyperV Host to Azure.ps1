#All variables must be provided. You will need to fill in all values in <>. 
#As the PowerShell components are under active development, there is currently a need to validate that the script is still valid. 
#This script was last validated on 4 Jan 2016.

#Author: Sacha Narinx @ Microsoft

#Please make sure you are running the latest version of Microsoft.SiteRecovery. Run ISE as Admin, and execute the following:
#Install-Module AzureRM.Profile -force -Repository PSGallery
#Install-Module AzureRM -force -Repository PSGallery
#Install-Module AzureRM.Resources -force -Repository PSGallery
#Install-Module AzureRM.SiteRecovery -force -Repository PSGallery
#Install-Module AzureRM.RecoveryServices -force -Repository PSGallery


#################################### Variables #######################################

#Replace all variables with values relevant to your requirements

$TenantID = '<GUID>' #CSP Customer ID
$SubscriptionID = '<GUID>' #CSP Customers Azure subscription ID

$ResourceGroupName = "MyASRRSG" #The name of the resource group
$VaultName = "MyASRVault" #The name of the ASR vault
$Location = 'West Europe' #Region to deploy to
$SiteName = "MyHyperVSite" #Hyper-V host site name
$StorageAccount = "<UniqueStorageAccountName>"

$OutputPathForSettingsFile = 'C:\ASR' #Local path where the vault settings get stored. Please make sure the path exists.


################################### Setup the ASR Vault ##############################

#New way to logon to ARM - Switch-AzureMode no longer supported.
Login-AzureRmAccount

Select-AzureRmSubscription -tenantid $TenantID -subscriptionid $SubscriptionID

Register-AzureRmResourceProvider -ProviderNamespace Microsoft.SiteRecovery

#Check if the Resource Provider is registered (optional)
#Get-AzureRmResourceProvider

#Create a new resource group
New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location

#Create the ASR vault
New-AzureRmSiteRecoveryVault -name $VaultName -ResouceGroupName $ResourceGroupName -Location $Location

#Load the vault into a variable for reuse
$Vault = Get-AzureRmSiteRecoveryVault -ResourceGroupName $ResourceGroupName | where { $_.Name -eq $VaultName }
#$Vault 

#To remove/delete the vault - this is currently the only way to delete a vault
#Remove-AzureRmSiteRecoveryVault -Vault $Vault

$VaultSetingsFile = Get-AzureRmSiteRecoveryVaultSettingsFile -Vault $Vault -Path $OutputPathForSettingsFile
#$VaultSetingsFile

#Import into the session in order to work with the vault directly, etc
Import-AzureRmSiteRecoveryVaultSettingsFile -Path $VaultSetingsFile.FilePath

################## Configuring ASR Settings - Hyper-V Site to Azure ##################

#Create a new Hyper-V Site in the ASR vault
New-AzureRmSiteRecoverySite -Name $SiteName
$Site = Get-AzureRmSiteRecoverySite -Name $SiteName

#Get the updated vault settings file (this is the vault settings file you need to use when installing the agents on Hyper-V hosts)
$SiteSettingsFile = Get-AzureRmSiteRecoveryVaultSettingsFile -Vault $Vault -SiteIdentifier $Site.SiteIdentifier -SiteFriendlyName $Site.FriendlyName -Path $OutputPathForSettingsFile

#Import the vault settings file so we can run commands against it in this session
Import-AzureRmSiteRecoveryVaultSettingsFile -Path $SiteSettingsFile.FilePath

#Load the server instance that is runnings VMs you want to protect (not currently a variable due to the fact that you may need to run this multiple times for multiple hosts)
$server = Get-AzureRmSiteRecoveryServer -FriendlyName '<ServerName>'

#Create a new storage account (only run this once)
New-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccount -Type Standard_GRS -Location $Location

#Setup the protection policy
$ReplicationFrequencyInSeconds = "300";     #options are 30,300,900
$PolicyName = “replicapolicy”
$Recoverypoints = 5                 #specify the number of recovery points
$storageaccountID = Get-AzureRmStorageAccount -Name $StorageAccount -ResourceGroupName $ResourceGroupName | Select -ExpandProperty Id 
$PolicyResult = New-AzureRmSiteRecoveryPolicy -Name $PolicyName -ReplicationProvider “HyperVReplicaAzure” -ReplicationFrequencyInSeconds $ReplicationFrequencyInSeconds  -RecoveryPoints $Recoverypoints -ApplicationConsistentSnapshotFrequencyInHours 1 -RecoveryAzureStorageAccountId $storageaccountID

#Get the protection container
$protectionContainer = Get-AzureRmSiteRecoveryProtectionContainer -FriendlyName $SiteName

#Get the protection policy
$Policy = Get-AzureRmSiteRecoveryPolicy -FriendlyName $PolicyName

#Run the process of applying the policy against the protection group/container
$associationJob  = Start-AzureRmSiteRecoveryPolicyAssociationJob -Policy $Policy -PrimaryProtectionContainer $protectionContainer

# Name of the VM to protect to Azure (will need to run this for each VM you want to protect) - rinse and repeat this next chunk of code for each VM on this same host
# You may want to define different protection policies against different VMs, in which case you will need to run "Setup the protection policy" above with changes.
$VMFriendlyName = "<NameOfVMtoProtectOnHost>"    #Name of the VM 
$protectionEntity = Get-AzureRmSiteRecoveryProtectionEntity -ProtectionContainer $protectionContainer -FriendlyName $VMFriendlyName
$Ostype = "Windows"             # "Windows" or "Linux"
$DRjob = Set-AzureRmSiteRecoveryProtectionEntity -ProtectionEntity $protectionEntity -Policy $Policy -Protection Enable -RecoveryAzureStorageAccountId $storageaccountID -OS $OStype -OSDiskName $protectionEntity.Disks[0].Name

# Check the status of the initial sync, wait for it to complete - will take time (hours/days) for each VM to complete initial sync (time depends on size of VM and bandwidth)
$DRjob = Get-AzureRmSiteRecoveryJob -Job $DRjob
$DRjob | Select-Object -ExpandProperty State
$DRjob | Select-Object -ExpandProperty StateDescription

################################### Test Failover ############################################

#Define/setup the virtual network you need for the VM to work. 
$VirtualNetworkName = "<VirtualNetworkName>" #Virtual network name
$subnet = New-AzureRmVirtualNetworkSubnetConfig -Name "Subnet-1" -AddressPrefix "10.25.3.0/24" #Choose subnet relevant to you, I've left my code to illustrate formats expected.
New-AzureRmVirtualNetwork -Name $VirtualNetworkName -Location $Location -ResourceGroupName $ResourceGroupName -Subnet $subnet -AddressPrefix "10.25.3.0/24"

#Attach the VM to the above virtual network, and define the recovery VM properties (this requires planning, ensure you are mapping local VM capacity to Azure appropriate sizes)
$nw1 = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName
$VM = Get-AzureRmSiteRecoveryVM -ProtectionContainer $protectionContainer -FriendlyName $VMFriendlyName
$UpdateJob = Set-AzureRmSiteRecoveryVM -VirtualMachine $VM -PrimaryNic $VM.NicDetailsList[0].NicId -RecoveryNetworkId $nw1.Id -RecoveryNicSubnetName $nw1.Subnets[0].Name -Size "A3"
$UpdateJob = Get-AzureRmSiteRecoveryJob -Job $UpdateJob

# Test Failover - execute a test failover - verify that the VMs start in Azure and you can connect
$nw = Get-AzureRmVirtualNetwork -Name $VirtualNetworkName -ResourceGroupName $ResourceGroupName #Specify Azure vnet name and resource group
$protectionEntity = Get-AzureRmSiteRecoveryProtectionEntity -FriendlyName $VMFriendlyName -ProtectionContainer $protectionContainer
$TFjob = Start-AzureRmSiteRecoveryTestFailoverJob -ProtectionEntity $protectionEntity -Direction PrimaryToRecovery -AzureVMNetworkId $nw.Id
$TFjob | Select-Object -ExpandProperty State

#After verifying VM started, run this to resume protection of the VM(s)
$TFjob = Resume-AzureRmSiteRecoveryJob -Job $TFjob