<#
.DESCRIPTION
This Azure Automation Runbook, named "Sync-FileShareToBlobContainer," continuously monitors files and directories in recursive mode
within a specified Azure File Share. When changes are detected, it synchronizes the data to a designated Blob Container using the AzCopy tool.
The synchronization process runs within an Azure Container Instance, utilizing a Service Principal in Azure Entra for authentication.

.NOTES
Filename : Sync-FileShareToBlobContainer
Author   : KOOSH4
Version  : 1
Date     : 13-Nov-2023
Tested   : Az.ContainerInstance PowerShell module version 2.1 and above

#>

Param (
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $AzureSubscriptionId,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $sourceStorageAccountRG,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $sourceStorageAccountName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $sourceStorageFileShareName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $destinationStorageAccountRG,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $destinationStorageAccountName,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()]
    [String] $destinationFileShareName
)

# Ensure you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity (automation account)
Connect-AzAccount -Identity

# SOURCE Azure Subscription
Set-AzContext -Subscription $AzureSubscriptionId

# Get Source Storage Account Key
$sourceStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $sourceStorageAccountRG -AccountName $sourceStorageAccountName).Value[0]

# Set Source AzStorageContext
$sourceContext = New-AzStorageContext -StorageAccountName $sourceStorageAccountName -StorageAccountKey $sourceStorageAccountKey

# Generate File Share SAS URI Token, valid for 60 minutes ONLY, with read and list permission
$fileShareSASURI = New-AzStorageShareSASToken -Context $sourceContext `
    -ExpiryTime (Get-Date).AddSeconds(3600) -FullUri -ShareName $sourceStorageFileShareName -Permission rl

# Get Destination Storage Account Key
$destinationStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $destinationStorageAccountRG -AccountName $destinationStorageAccountName).Value[0]

# Set Destination AzStorageContext
$destinationContext = New-AzStorageContext -StorageAccountName $destinationStorageAccountName -StorageAccountKey $destinationStorageAccountKey

# Generate File Share SAS URI Token for destination storage account
$destinationFileShareSASURI = New-AzStorageShareSASToken -Context $destinationContext `
 -ExpiryTime(get-date).AddSeconds(3600) -FullUri -ShareName $destinationFileShareName -Permission rwld

# AzCopy command to sync files from source file share to destination file share
$command = "azcopy","sync",$fileShareSASURI,$destinationFileShareSASURI,"--recursive=true","--delete-destination=true"

# Container Group Name
$jobName = "sync-job"

# Set the AZCOPY_BUFFER_GB value at 2 GB, preventing the container from crashing
$envVars = New-AzContainerInstanceEnvironmentVariableObject -Name "AZCOPY_BUFFER_GB" -Value "2"

# Create Azure Container Instance Object and run the AzCopy job
$container = New-AzContainerInstanceObject -Name $jobName -Image "peterdavehello/azcopy:latest" `
    -RequestCpu 2 -RequestMemoryInGb 4 -Command $command -EnvironmentVariable $envVars

# The container will be created in the $location variable based on the destination storage account location
$location = (Get-AzResourceGroup -Name $destinationStorageAccountRG).location
$containerGroup = New-AzContainerGroup -ResourceGroupName $destinationStorageAccountRG -Name $jobName `
    -Container $container -OsType Linux -Location $location -RestartPolicy never

Write-Output ("")
