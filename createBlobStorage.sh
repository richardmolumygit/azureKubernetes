#!/usr/bin/env bash
# Create the backend storage
# This needs to exist before terraform can consume it.
# Run these before this script
# az login (richardmolumby2026@gmail.com)
# next get the subscription name, id, tenant id for the subscription
# az account list --output table
# az account set --subscription "<SUBSCRIPTION_ID>"
#
export STATE_RG="tfstate-rg"
export STATE_STORAGE="aksterraformstorage"
export STATE_CONTAINER="tfstate"
export LOCATION="eastus"

echo "Setting GITHUB_ACTIONS_CLIENT_ID"
export GITHUB_ACTIONS_CLIENT_ID=$(
  az ad app list \
    --display-name "github-actions-terraform" \
    --query "[0].appId" \
    --output tsv
)

echo "Show User, subscription"
az account show \
  --query "{user:user.name,type:user.type,subscription:id}" \
  --output table

echo "Show user type"
az account show --query "user.type" --output tsv

echo "Setting LOCAL_USER_OBJECT_ID"
LOCAL_USER_OBJECT_ID=$(az ad signed-in-user show \
  --query id \
  --output tsv)

echo "Local user object ID: $LOCAL_USER_OBJECT_ID"

echo "Creating resource group, storage account and container for terraform state"

az group create \
  --name "$STATE_RG" \
  --location "$LOCATION"

echo "Created resource group $STATE_RG in $LOCATION"
echo "Creating Storage account: $STATE_STORAGE"

az storage account create \
  --name "$STATE_STORAGE" \
  --resource-group "$STATE_RG" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false

echo "Storage account created: $STATE_STORAGE"
echo "Creating storage container $STATE_CONTAINER in $STATE_STORAGE"

az storage container create \
  --account-name "$STATE_STORAGE" \
  --name "$STATE_CONTAINER" \
  --auth-mode login

echo "Created storage container $STATE_CONTAINER in $STATE_STORAGE"
echo "Creating STORAGE_ID"

# Grant your local Azure identity access:
STORAGE_ID=$(az storage account show \
  --name "$STATE_STORAGE" \
  --resource-group "$STATE_RG" \
  --query id \
  --output tsv)

echo "Storage account ID: $STORAGE_ID"
echo "Granting Storage Blob Data Contributor role to your local Azure identity"

az role assignment create \
  --assignee-object-id "$LOCAL_USER_OBJECT_ID" \
  --assignee-principal-type User \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"

echo "Granted Storage Blob Data Contributor role to your local Azure identity"
echo "Granting Storage Blob Data Contributor role to GitHub Actions service principal"

# Resolve the application client ID to its service principal object ID.
GITHUB_ACTIONS_SP_OBJECT_ID=$(az ad sp show \
  --id "$GITHUB_ACTIONS_CLIENT_ID" \
  --query id \
  --output tsv)

az role assignment create \
  --assignee-object-id "$GITHUB_ACTIONS_SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$STORAGE_ID"

echo "Granted Storage Blob Data Contributor role to GitHub Actions service principal"
