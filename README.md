# Azure-fileshare-sync-automation

## Description
This Azure Automation Runbook (Powershell script)" continuously monitors files and directories in recursive mode within a specified Azure File Share. When changes are detected, it synchronizes the data to a designated Blob Container using the AzCopy tool. The synchronization process runs within an Azure Container Instance, utilizing a Service Principal in Azure Entra for authentication.

## Version
- 1

## Date
- 13-Nov-2023

## Tested
- Az.ContainerInstance PowerShell module version 2.1 and above

## Parameters
- **AzureSubscriptionId:** [Your Azure Subscription ID]
- **sourceStorageAccountRG:** [Resource Group of the source storage account]
- **sourceStorageAccountName:** [Name of the source storage account]
- **sourceStorageFileShareName:** [Name of the source storage file share]
- **destinationStorageAccountRG:** [Resource Group of the destination storage account]
- **destinationStorageAccountName:** [Name of the destination storage account]
- **destinationFileShareName:** [Name of the destination storage file share]
