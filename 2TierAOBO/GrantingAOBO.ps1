#Dependencies
#ConnectAzureAD,EnumerateSubscriptions

# Check that you are operating on the right subscription
Get-AzureSubscription

# Assign Owner role to AdminAgents group of Advisor partner for a subscription
#New-AzureRoleAssignment –ObjectId <ObjectId of AdminAgents group> -RoleDefinitionName “Owner”
# Assign Contributor role to AdminAgents group of Advisor partner for a subscription
#New-AzureRoleAssignment –ObjectId <ObjectId of AdminAgents group> -RoleDefinitionName “Contributor”
# Assign Reader role to AdminAgents group of Advisor partner for a subscription
#New-AzureRoleAssignment –ObjectId <ObjectId of AdminAgents group> -RoleDefinitionName “Reader”
# Assign Reader role to AdminAgents group of Advisor partner for a specific ResourceGroup/Resource
#New-AzureRoleAssignment –ObjectId <ObjectId of AdminAgents group> -RoleDefinitionName “Owner” – Scope "/ResourceGroups/ResourceGroup1"

#Get the ObjectId of HelpDeskAgents as an example, should be any objectId from another partner/reseller.
Get-MsolGroup | ? DisplayName -eq "HelpDeskAgents"
$oidHelpDeskAgents = (Get-MsolGroup | ? DisplayName -eq "HelpDeskAgents").ObjectId.Guid

#Add HelpDeskAgents as Subscription Owner and compare
Get-AzureRoleAssignment
New-AzureRoleAssignment –ObjectId $oidHelpDeskAgents -RoleDefinitionName “Owner”
Get-AzureRoleAssignment

#Remove HelpDeskAgents from Subscription Owners
Remove-AzureRoleAssignment -ObjectId $oidHelpDeskAgents -RoleDefinitionName "Owner" -Force -Scope ("/subscriptions/" + (Get-AzureSubscription | ? isDefault -eq true).SubscriptionId)
