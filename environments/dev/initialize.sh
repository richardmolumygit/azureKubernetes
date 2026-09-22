#!/usr/bin/env bash

export ARM_USE_CLI=true
export ARM_USE_AZUREAD_AUTH=true

echo "Show blob list"
az storage blob list \
  --account-name aksterraformstorage \
  --container-name tfstate \
  --auth-mode login \
  --output table

