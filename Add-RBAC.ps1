###############################################################################
#
# .SYNOPSIS
#    Add RBAC Permission to Share
#
# .DESCRIPTION
#     Add RBAC Permission to Share
#
# .EXAMPLE
#    ./Add-RBAC -UPN testuser@domain.com -Share testshare
#
# .PARAMETER UPN
#    The username of the user whom will be given permission to access 
#    the share
#
###############################################################################

#******************************************************************************
# 
# START Webhook Data
#
#******************************************************************************
[CmdletBinding()]
Param
([object]$WebhookData) 
$VerbosePreference = 'continue'

# If runbook was called from Webhook, WebhookData will not be null.
if ($WebHookData){

    # Collect properties of WebhookData
    $WebhookName     =     $WebHookData.WebhookName
    $WebhookHeaders  =     $WebHookData.RequestHeader
    $WebhookBody     =     $WebHookData.RequestBody

    # Collect individual headers. Input converted from JSON.
    $From = $WebhookHeaders.From
    $Input = (ConvertFrom-Json -InputObject $WebhookBody)
    Write-Verbose "WebhookBody: $Input"
    Write-Output -InputObject ('Runbook started from webhook {0} by {1}.' -f $WebhookName, $From)
}
else
{
   Write-Error -Message 'Runbook was not started from Webhook' -ErrorAction stop
}
#******************************************************************************
# 
# END Webhook Data
#
#******************************************************************************

#******************************************************************************
# 
# START Define all Variables for the Script
#
#******************************************************************************
$UPN = $Input.UPN
$Subscription = 'Pay-As-You-Go - MPH Analytics' #UPDATE
$subscriptionID = "922f7410-42b9-42d6-986b-b7b8f30d75ad" #UPDATE
$ResourceGroupName = "MPH-Analytics-RG" #UPDATE
$aadTenantId = "50225b46-8a5b-4a27-b140-349ac9c7b83c" #UPDATE
$Region = "eastus2" #UPDATE
$share = $Input.Share
#******************************************************************************
# 
# END Define all Variables
#
#******************************************************************************

#******************************************************************************
# 
# START Connect to Azure AZ using AzureRunasConnection to create Azure Resources,
#       select Subscription, and register resource providers
#
#******************************************************************************
# Function to register Resource Providers
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Output "Registering resource provider '$ResourceProviderNamespace'"
    Register-AzResourceProvider -ProviderNamespace $ResourceProviderNamespace
}



try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'
    Write-Output "Logging in to Azure..."
    $connectionResult =  Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
                             -ApplicationId $servicePrincipalConnection.ApplicationID   `
                             -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                             -ServicePrincipal
    Write-Output "Logged in." 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Select subscription
Write-Output "Selecting subscription '$Subscription'"
Select-AzSubscription -Subscription $Subscription

# Register RPs
$resourceProviders = @("microsoft.resources","microsoft.compute")
if($resourceProviders.length) {
    Write-Output "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider)
    }
}
#******************************************************************************
# 
# END Connecting to Azure AZ
#
#******************************************************************************

#******************************************************************************
# 
# START User Share Changes
#
#******************************************************************************
# Get Username
$username = $UPN
$position = $username.IndexOf("@")
$username = $username.Substring(0, $position)

# User Share Block
$storageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name "mphdatastaging"

# Configure RBAC for User
$FileShareContributorRole = Get-AzRoleDefinition "Storage File Data SMB Share Contributor" 
$scope = "/subscriptions/" + $subscriptionID + "/resourceGroups/" + $ResourceGroupName + "/providers/Microsoft.Storage/storageAccounts/" + $storageAccount.StorageAccountName + "/fileServices/default/fileshares/" + $share

Write-Output "Adding Role Assignment to '$share' for '$username'"
New-AzRoleAssignment -SignInName $UPN -RoleDefinitionName $FileShareContributorRole.Name -Scope $scope

#******************************************************************************
# 
# END User Share Changes
#
#******************************************************************************