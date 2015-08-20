# Requires AzureAD Powershell module msonline
# http://social.technet.microsoft.com/wiki/contents/articles/28552.microsoft-azure-active-directory-powershell-module-version-release-history.aspx

Clear

#setup provider
$providerCred = Get-Credential -Message "Please provide your CSP Partner credentials:"

#get the provider domain name, eg.: mcs1aztest.onmicrosoft.com
$providerDomain = $providerCred.UserName.Split("@")[1]

#setup tenant
$providerAD = Connect-MsolService -Credential $providerCred

#Get the list of Groups in the Provider AzureAD
Get-MsolGroup
Write-Output ""

Get-MsolGroup | ForEach-Object {
    Write-Output "Getting users that are members of: "$_.DisplayName
    Get-MsolGroupMember -GroupObjectId $_.ObjectId
    Write-Output ""
    }

#Now enumerate the tenant contracts
Get-MsolPartnerContract | fl *

#...and respective domains
Get-MsolPartnerContract | ForEach-Object {
    Get-MsolDomain -TenantId $_.TenantId | fl *
}

#...get tenant information
Get-MsolPartnerContract | ForEach-Object {
    Get-MsolCompanyInformation -TenantId $_.tenantId
}

$tenantContracts = Get-MsolPartnerContract
$tenant1Id = $tenantContracts[0].TenantId.Guid
$tenant1Name = $tenantContracts[0].DefaultDomainName
$tenant2Id = $tenantContracts[1].TenantId.Guid
$tenant2Name = $tenantContracts[1].DefaultDomainName

#and review tenant roles with partner members
Get-MsolRole -TenantId $tenant1Id | ForEach-Object {
    Write-Output $_.Name
    Get-MsolRoleMember -RoleObjectId $_.ObjectId
    Write-Output ""
}

Get-MsolRole -TenantId $tenant2Id | ForEach-Object {
    Write-Output $_.Name
    Get-MsolRoleMember -RoleObjectId $_.ObjectId
    Write-Output ""
}

#get "Company Administrator" role specific members for Tenant 1
Get-MsolRoleMember -RoleObjectId 62e90394-69f5-4237-9190-012177145e10