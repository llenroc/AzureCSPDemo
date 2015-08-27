function Initialize-CSPVariables
{
#Resellers tenant id, locate this in https://Partnercenter.microsoft.com, Account settings,  Organization Profile, Microsoft ID
$providerAD = Connect-MsolService -Credential $providerCred
$global:ResellerTenantId = (Get-MsolPartnerInformation).ObjectId.Guid

#As configured in AD for my Service Provider tenant (or through CSP panel)
$global:ApplicationID=(Get-Credential -Message "Insert you CSP Partner Application ID:" -UserName "ApplicationId").GetNetworkCredential().Password

#Application secret as defined in AD for my ApplicationID
$global:ApplicationSecret= (Get-Credential -Message "Insert you CSP Partner API Key:" -UserName "API Key").GetNetworkCredential().Password

#Reseller domain name
$global:ResellerDomain = (Get-MsolDomain).name

$global:URI_AAD="https://login.windows.net/$ResellerDomain/oauth2/token?api-version=1.0"                    
$global:URI_GetCustomers="https://graph.windows.net/$ResellerDomain/contracts?api-version=1.5"
$global:URI_CSPAPI="https://api.cp.microsoft.com/"
$global:URI_GetSAToken=$URI_CSPAPI + "my-org/tokens"
$global:URI_GetReseller=$URI_CSPAPI+"customers/get-by-identity?provider=AAD&type=tenant&tid=" + $ResellerTenantId
$global:URI_CreateCustomer=$URI_CSPAPI + $ResellerTenantId + "/customers/create-reseller-customer"
}

# Get the Azure Active Directory application token https://msdn.microsoft.com/en-us/library/partnercenter/dn974935.aspx
# Cloud Solution Provider partners must generate their own authentication credentials— a client ID and a secret key—before they can work with the CREST APIs. They use these credentials to create an Azure Active Directory security token. 
function Get-AADToken
{
    $headers="" 
    $grantbody="grant_type=client_credentials&resource=https://graph.windows.net&client_id=$ApplicationID&client_secret=$ApplicationSecret"
    $AADTokenResponse=Invoke-Restmethod -Uri $URI_AAD -ContentType "application/x-www-form-urlencoded" -Body $grantbody -Method "POST" -verbose -Debug
    $global:AADToken = $AADTokenResponse.access_token
    $AADToken
}

#GET SA token https://msdn.microsoft.com/en-us/library/partnercenter/mt146414.aspx
#To use the CREST API, you must have an authorization token for the reseller’s account, which is generated using your Azure AD security token. This reseller token is called a Sales Agent Token, shortened to SA_Token.
#After you create an SA_Token, you can use it to get your cid-for-reseller. See Get a reseller id.

function Get-SAToken
{
$headers=@{Authorization="Bearer $AADToken"
        }
$SABody ="grant_type=client_credentials"
$SATokenResponse = Invoke-RestMethod -Uri $URI_GetSAToken -ContentType "application/x-www-form-urlencoded" -Headers $headers -Body $SABody -method "POST" -Debug -Verbose
$global:SAToken=$SATokenResponse.access_token
$SAToken
}
#Get a reseller id https://msdn.microsoft.com/en-us/library/partnercenter/mt427345.aspx
#You can get the Customer resource that represents you, the CSP partner. This Customer resource contains an id which is your {cid-for-reseller} value for CREST API calls.
#Before you can get a reseller ID, you must have an SA_Token. Get a reseller token. 
#
function Get-ResellerIdentity
{
    $TrackingGUID=[guid]::NewGuid()
    $CorrelationGUID=[guid]::NewGuid()
    $headers=@{Authorization="Bearer $SAToken"
            "Accept"="application/json"
            "api-version"="2015-03-31"
            "x-ms-correlation-id"=$CorrelationGUID
            "x-ms-tracking-id"=$TrackingGUID
            }

    $GetResellerResponse=Invoke-RestMethod -Uri $URI_GetReseller -ContentType "application/x-www-form-urlencoded" -Headers $headers -Method "GET" -Debug -Verbose
    $global:ResellerIdentity=$GetResellerResponse.id  #contains {cid-for-reseller}
    $ResellerIdentity
}

#get all my customer contracts
#
#
function Get-Contracts
{
    $headers=@{Authorization="Bearer $AADToken"
        }
    $SAGetCustomersResponse=Invoke-RestMethod -Uri $URI_GetCustomers -Headers $headers -ContentType "application/json" -Method "GET" -Debug -Verbose
    $SACustomers=$SAGetCustomersResponse.value
    $SACustomers
}


# Create a customer https://msdn.microsoft.com/en-us/library/partnercenter/mt146403.aspx
# Creates a new customer. As a CSP partner, you can place orders on behalf of this customer. It also creates the following:
#  •An Azure AD tenant object that represents the customer. 
#  •A Customer resource that represents the partner's security group in the customer's tenant. This is also the resource that is returned from the API. 
#  •Appropriate relationships to create a reseller-customer relationship. 
#  •A user name and password to login to the Microsoft Online Services Portal. 
# Note that you should save the customer ID and Azure AD identity for your own records, in a way that will persist beyond the current session. Otherwise you will not have the information required by the CREST API for later account management.
# If you do not have a customer's ID or identity, you can look up the ID in Partner Center by choosing the customer from the customers list, selecting Account, then saving their Microsoft ID.#

function Create-Customer([string]$DomainNamePrefix,[string]$UserName,[string]$Password,[string]$Email,[string]$CompanyName,[string]$FirstName,[string]$LastName)
{
    $customerdata= @{
	    domain_prefix = $DomainNamePrefix;
	    user_name = $UserName; 
	    password = $Password;
        profile=@{
            email = $Email
		    company_name = $CompanyName;
		    culture = "en-US";
		    language = "en";
            type = "organization";
            default_address=@{
			    first_name = $FirstName;
			    last_name = $LastName;
			    address_line1 = "Test Address";
			    city = "Bellevue";
			    region = "WA";
			    postal_code = "98005";
			    country = "US";
                phone_number = "4255551234"
            }
        
        }
    }

    $customerjson=$customerdata | ConvertTo-Json

    $TrackingGUID=[guid]::NewGuid()
    $CorrelationGUID=[guid]::NewGuid()
    $headers=@{Authorization="Bearer $SAToken"
            "Accept"="application/json"
            "api-version"="2015-03-31"
            "x-ms-correlation-id"=$CorrelationGUID
            "x-ms-tracking-id"=$TrackingGUID
            }

    $customer=Invoke-RestMethod -Uri $URI_CreateCustomer -Method "POST" -Headers $headers -Body $customerjson -ContentType "application/json"
    $customer
 }