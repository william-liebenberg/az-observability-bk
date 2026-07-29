#!/usr/bin/env bash
set -euo pipefail

echo "Installing zip and unzip"
apt-get update && apt-get install -y zip unzip

environment="${1:?Usage: deploy-function.sh <dev|stage|prod>}"
case "$environment" in
  dev|stage|prod) ;;
  *)
    echo "Unsupported environment: ${environment}" >&2
    exit 2
    ;;
esac

prefix="$(printf '%s' "$environment" | tr '[:lower:]' '[:upper:]')"
function_app_var="${prefix}_FUNCTION_APP_NAME"
resource_group_var="${prefix}_RESOURCE_GROUP"
plan_sku_var="${prefix}_HOSTING_PLAN_SKU"
subscription_var="${prefix}_AZURE_SUBSCRIPTION_ID"

function_app="${!function_app_var:?Missing ${function_app_var}}"
resource_group="${!resource_group_var:?Missing ${resource_group_var}}"
expected_plan_sku="${!plan_sku_var:?Missing ${plan_sku_var}}"
expected_subscription="${!subscription_var:?Missing ${subscription_var}}"
package="artifacts/${APP_NAME:?APP_NAME is required}-${BUILDKITE_BUILD_NUMBER:?BUILDKITE_BUILD_NUMBER is required}.zip"

echo "Deploying Function App ${function_app} in resource group ${resource_group} to Azure subscription ${expected_subscription} with plan SKU ${expected_plan_sku}"

echo "Downloading the package and checksum from the build artifacts"
mkdir -p artifacts
buildkite-agent artifact download "$package" . --step package
buildkite-agent artifact download "${package}.sha256" . --step package
sha256sum --check "${package}.sha256"
unzip -Z1 "$package" host.json >/dev/null

echo "Checking Azure CLI version"
azure_cli_version="$(az version --query '"azure-cli"' --output tsv)"
if [[ "$(printf '%s\n' "2.60.0" "$azure_cli_version" | sort -V | head -n1)" != "2.60.0" ]]; then
  echo "Azure CLI 2.60.0 or later is required for Flex Consumption deployment; found ${azure_cli_version}" >&2
  exit 1
fi

echo "Validating Azure subscription"
active_subscription="$(az account show --query id --output tsv)"
if [[ "$active_subscription" != "$expected_subscription" ]]; then
  echo "Azure subscription mismatch: expected ${expected_subscription}, found ${active_subscription}" >&2
  exit 1
fi

echo "Validating Function App hosting plan SKU"
plan_id="$(az functionapp show \
  --resource-group "$resource_group" \
  --name "$function_app" \
  --query properties.serverFarmId \
  --output tsv)"
test -n "$plan_id"
actual_plan_sku="$(az appservice plan show --ids "$plan_id" --query sku.name --output tsv)"
if [[ "$actual_plan_sku" != "$expected_plan_sku" ]]; then
  echo "Function plan SKU mismatch: expected ${expected_plan_sku}, found ${actual_plan_sku}" >&2
  exit 1
fi

echo "Deploying the validated ZIP to Flex Consumption app ${function_app} with One Deploy"
az functionapp deployment source config-zip \
  --resource-group "$resource_group" \
  --name "$function_app" \
  --src "$package" \
  --only-show-errors
