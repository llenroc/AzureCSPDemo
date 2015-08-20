#remove all subscriptions
Get-AzureSubscription | ForEach-Object {
    Remove-AzureSubscription -Name $_.SubscriptionName -Force
    }

