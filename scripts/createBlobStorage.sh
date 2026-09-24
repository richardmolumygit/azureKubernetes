#!/usr/bin/env bash
set -euo pipefail

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

echo "Setting GITHUB_ACTIONS_CLIENT_ID if is not passed in"
if [ -z "${GITHUB_ACTIONS_CLIENT_ID:-}" ]; then
   export GITHUB_ACTIONS_CLIENT_ID=$(
     az ad app list \
       --display-name "github-actions-terraform" \
       --query "[0].appId" \
       --output tsv | tr -d '\r\n'
   )
fi

if [[ ! "$GITHUB_ACTIONS_CLIENT_ID" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  echo "GitHub Actions client ID was not found or is invalid" >&2
  exit 1
fi

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
#echo "Granting Storage Blob Data Contributor role to your local Azure identity"

#az role assignment create \
#  --assignee-object-id "$LOCAL_USER_OBJECT_ID" \
#  --assignee-principal-type User \
#  --role "Storage Blob Data Contributor" \
#  --scope "$STORAGE_ID"

echo "Show LOCAL_USER_OBJECT_ID"
echo "$LOCAL_USER_OBJECT_ID"

# Verify theobject ID belongs to the current tenant
echo "Show signed in user"
az ad signed-in-user show \
  --query "{id:id,name:userPrincipalName,tenant:tenantId}" \
  --output json

echo "Show account info"
az account show \
  --query "{tenant:tenantId,subscription:id,user:user.name}" \
  --output json

echo "Retrieve ROLE_ID"
ROLE_ID=$(az role definition list \
  --name "Storage Blob Data Contributor" \
  --query "[0].name" \
  --output tsv)
echo "ROLE_ID: $ROLE_ID"

SUBSCRIPTION_ID=$(az account show --query id --output tsv)
ROLE_DEFINITION_ID="/subscriptions/$SUBSCRIPTION_ID/providers/Microsoft.Authorization/roleDefinitions/$ROLE_ID"

grant_blob_role() {
  local principal_id="$1"
  local principal_type="$2"
  local assignment_count
  local assignment_id

  assignment_count=$(az rest \
    --method get \
    --url "https://management.azure.com${STORAGE_ID}/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01" \
    --query "length(value[?properties.principalId=='$principal_id' && properties.roleDefinitionId=='$ROLE_DEFINITION_ID'])" \
    --output tsv)

  if [[ "$assignment_count" != "0" ]]; then
    echo "Role assignment already exists for $principal_type $principal_id"
    return 0
  fi

  assignment_id=$(uuidgen)
  az rest \
    --method put \
    --url "https://management.azure.com${STORAGE_ID}/providers/Microsoft.Authorization/roleAssignments/${assignment_id}?api-version=2022-04-01" \
    --body "{\"properties\":{\"roleDefinitionId\":\"$ROLE_DEFINITION_ID\",\"principalId\":\"$principal_id\",\"principalType\":\"$principal_type\"}}" \
    --output none

  echo "Granted Storage Blob Data Contributor role to $principal_type $principal_id"
}

echo "Granting Storage Blob Data Contributor role to your local Azure identity"
grant_blob_role "$LOCAL_USER_OBJECT_ID" "User"

echo "Granted Storage Blob Data Contributor role to your local Azure identity"
echo "Granting Storage Blob Data Contributor role to GitHub Actions service principal"

# Resolve the application client ID to its service principal object ID.
if [ -z "${GITHUB_ACTIONS_SP_OBJECT_ID:-}" ]; then
   GITHUB_ACTIONS_SP_OBJECT_ID=$(az ad sp show \
     --id "$GITHUB_ACTIONS_CLIENT_ID" \
     --query id \
     --output tsv | tr -d '\r\n')
fi

if [[ ! "$GITHUB_ACTIONS_SP_OBJECT_ID" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  echo "GitHub Actions service principal object ID was not found or is invalid" >&2
  exit 1
fi

echo "GitHub Actions service principal object ID: $GITHUB_ACTIONS_SP_OBJECT_ID"

grant_blob_role "$GITHUB_ACTIONS_SP_OBJECT_ID" "ServicePrincipal"

echo
echo "Completed granting Storage Blob Data Contributor role to GitHub Actions service principal"
echo "Terraform backend storage is ready"
echo "Resource group: $STATE_RG"
echo "Storage account: $STATE_STORAGE"
echo "Container: $STATE_CONTAINER"
