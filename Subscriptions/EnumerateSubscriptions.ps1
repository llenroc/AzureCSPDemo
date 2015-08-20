#Dependencies
#ConnectAzureAD

#Switch to ARM Mode
Switch-AzureMode -Name AzureResourceManager

#add the provider account
Add-AzureAccount -Credential $providerCred

#enumerate subscriptions and notice that no tenants are there
Get-AzureSubscription

#add tenant subscriptions, notice the -Tenant parameter
Add-AzureAccount -Credential $providerCred -Tenant $tenant1Name

#Enumerate Subscriptions
Get-AzureSubscription

#Select the Tenant 1 Subscription
Get-AzureSubscription | ? TenantId -eq $tenant1Name | Select-AzureSubscription

#review the owner of the subscription - Owner = ObjectId AdminAgents
Get-MsolGroup
Get-AzureRoleAssignment