# NOTE: When running this script inside of PS ISE, you need to log on with Add-AzureAccount first
$websitename = "MyTenant1WebSite"
$hostingPlanName = "MyTenant1HostingPlan"
$siteLocation = "North Europe"
$sku = "Standard"
$workSize = "0"
$subscriptionId = (Get-AzureSubscription | ? IsCurrent -eq True).SubscriptionId
$resourceGroupName = "rgMyTenant1WebApp"
$storageAcctName = "saMyTenant1"
#$sqlSvrName = "Mytenant1sql" #>Will make deploy fail
$sqlSvrName = "ricardmat1sql"
$sqlAdmin = "Password1!"
$sqlLogin = "ricardma"
$sqlDBName = "MyTenant1Db"
$sqlDBEdition = "Web"


# There are two modes for Azure, ARM and Azure Service Management
Switch-Azuremode -Name AzureResourceManager

#Gets a list of all resource groups currently in the Azure gallery
Get-AzureResourceGroupGalleryTemplate | ft -AutoSize
Get-AzureResourceGroupGalleryTemplate | Where-Object{$_.Identity -like '*websitesql*'} | Select Identity


#If you just want to look at the specific ones for Microsoft
Get-AzureResourceGroupGalleryTemplate -Publisher Microsoft

# Get the latest website template
Get-AzureResourceGroupGalleryTemplate -Identity Microsoft.WebSiteSQLDatabase.0.4.0

#Download the file to the directory where your command prompt is
Save-AzureResourceGroupGalleryTemplate -Identity Microsoft.WebSiteSQLDatabase.0.4.0

#determine what parameters are required by the template
$t = Get-Content -Raw -Path '.\Microsoft.WebSiteSQLDatabase.0.4.0.json' | ConvertFrom-Json

#print the name of the parameters out to the console
Write-Host $t.parameters


#create a hashtable of the parameters
[System.Collections.Hashtable]`
$params = @{`
siteName=$websitename; `
hostingPlanName = $hostingPlanName; `
sku = $sku; `
siteLocation=$siteLocation; `
serverName= $sqlSvrName; `
serverLocation = $siteLocation; `
workerSize = "0"; `
administratorLogin = $sqlLogin; `
administratorLoginPassword = $sqlAdmin; `
databaseName= $sqlDBName; `
edition = $sqlDBEdition; `
serverfarmResourceGroup = $resourceGroupName`
}

$params

#create a new resource group that contains a website
#New-AzureResourceGroup –Name $resourceGroupName –Location $siteLocation -DeploymentName WebDeploy01 -TemplateFile '.\Microsoft.WebSiteSQLDatabase.0.3.12-preview.json' -TemplateParameterObject $params
New-AzureResourceGroup –Name $resourceGroupName –Location $siteLocation -TemplateFile '.\Microsoft.WebSiteSQLDatabase.0.4.0.json' -TemplateParameterObject $params -Force

Get-AzureResourceGroup

#remove the resource group and everything in it
Get-AzureResourceGroup -Name $resourceGroupName | Remove-AzureResourceGroup -Verbose -Force

New-AzureResourceGroup -Name $resourceGroupName -Location "West Europe"
New-AzureResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name "ProductionDeployment" -TemplateFile .\Microsoft.WebSiteSQLDatabase.0.4.0.json -TemplateParameterObject $params