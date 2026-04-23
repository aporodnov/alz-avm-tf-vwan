#!/usr/bin/env bash
# auto-import.sh — Sync Terraform state with Azure
#
# Runs terraform plan, finds resources planned for "create" that already
# exist in Azure, writes import {} blocks to a temp .tf file, then
# re-plans. The import blocks are processed as part of the plan graph,
# which correctly resolves for_each / depends_on chains.
#
# Usage: auto-import.sh <var-file>
#        SKIP_REFRESH=true auto-import.sh <var-file>   # skip the refresh phase
# Requires: ARM_SUBSCRIPTION_ID env var, authenticated az CLI, terraform init done

set -euo pipefail

VAR_FILE="${1:?Usage: auto-import.sh <var-file>}"
SUB_ID="${ARM_SUBSCRIPTION_ID:?ARM_SUBSCRIPTION_ID must be set}"
SKIP_REFRESH="${SKIP_REFRESH:-false}"

# ── Helpers ──────────────────────────────────────────────────

# Filter AVM telemetry noise
tf_quiet() {
  grep -vE '(Reading\.\.\.|Read complete|modtm_module_source|azapi_client_config|azurerm_client_config\.telemetry)' || true
}

# Map a planned resource to its Azure resource ID
resolve_azure_id() {
  local type="$1" name="$2" rg="$3" parent_id="$4" azapi_type="$5"

  case "$type" in
    azurerm_resource_group)
      echo "/subscriptions/${SUB_ID}/resourceGroups/${name}"
      ;;
    azapi_resource)
      [[ -z "$parent_id" || "$parent_id" == "null" || -z "$azapi_type" ]] && return 1
      local segs child_type
      segs=$(echo "$azapi_type" | tr '/' '\n' | wc -l)
      if (( segs > 2 )); then
        child_type=$(echo "$azapi_type" | rev | cut -d/ -f1 | rev)
        echo "${parent_id}/${child_type}/${name}"
      else
        echo "${parent_id}/providers/${azapi_type}/${name}"
      fi
      ;;
    # ── Child resources under a known parent ──
    # The plan JSON includes the full computed ID for some resource types.
    # For these we can build the Azure ID directly without az resource list.
    azurerm_virtual_hub_connection)
      # parent_id is the virtual_hub_id, e.g. /subscriptions/.../virtualHubs/vHUB-Name
      [[ -z "$parent_id" || "$parent_id" == "null" ]] && return 1
      echo "${parent_id}/hubVirtualNetworkConnections/${name}"
      ;;
    azurerm_private_dns_resolver)
      [[ -z "$rg" || "$rg" == "null" ]] && return 1
      echo "/subscriptions/${SUB_ID}/resourceGroups/${rg}/providers/Microsoft.Network/dnsResolvers/${name}"
      ;;
    azurerm_private_dns_resolver_inbound_endpoint)
      [[ -z "$parent_id" || "$parent_id" == "null" ]] && return 1
      echo "${parent_id}/inboundEndpoints/${name}"
      ;;
    azurerm_private_dns_resolver_outbound_endpoint)
      [[ -z "$parent_id" || "$parent_id" == "null" ]] && return 1
      echo "${parent_id}/outboundEndpoints/${name}"
      ;;
    azurerm_private_dns_resolver_dns_forwarding_ruleset)
      [[ -z "$rg" || "$rg" == "null" ]] && return 1
      echo "/subscriptions/${SUB_ID}/resourceGroups/${rg}/providers/Microsoft.Network/dnsForwardingRulesets/${name}"
      ;;
    azurerm_private_dns_resolver_forwarding_rule)
      [[ -z "$parent_id" || "$parent_id" == "null" ]] && return 1
      echo "${parent_id}/forwardingRules/${name}"
      ;;
    azurerm_private_dns_resolver_virtual_network_link)
      [[ -z "$parent_id" || "$parent_id" == "null" ]] && return 1
      echo "${parent_id}/virtualNetworkLinks/${name}"
      ;;
    azurerm_private_dns_zone)
      [[ -z "$rg" || "$rg" == "null" ]] && return 1
      echo "/subscriptions/${SUB_ID}/resourceGroups/${rg}/providers/Microsoft.Network/privateDnsZones/${name}"
      ;;
    azurerm_private_dns_zone_virtual_network_link)
      [[ -z "$parent_id" || "$parent_id" == "null" ]] && return 1
      echo "${parent_id}/virtualNetworkLinks/${name}"
      ;;
    azurerm_subnet)
      [[ -z "$parent_id" || "$parent_id" == "null" ]] && return 1
      echo "${parent_id}/subnets/${name}"
      ;;
    azurerm_*)
      [[ -z "$rg" || "$rg" == "null" ]] && return 1
      az resource list --name "$name" -g "$rg" --subscription "$SUB_ID" \
        --query "[0].id" -o tsv 2>/dev/null | grep -v '^$' || return 1
      ;;
  esac
}

# Check if a resource exists in Azure
exists_in_azure() {
  local type="$1" az_id="$2" name="$3"
  if [[ "$type" == "azurerm_resource_group" ]]; then
    az group show --name "$name" --subscription "$SUB_ID" &>/dev/null
  else
    # Use generic REST GET — works for all resource types including children
    az rest --method GET \
      --url "https://management.azure.com${az_id}?api-version=2023-11-01" &>/dev/null \
    || az resource show --ids "$az_id" --subscription "$SUB_ID" &>/dev/null
  fi
}

# Parse plan JSON → array of resources planned for creation
extract_creates() {
  terraform show -json tfplan | jq -c '
    [.resource_changes[]
     | select(.change.actions == ["create"])
     | select(.type | startswith("azurerm_") or . == "azapi_resource")
     | {
         addr:  .address,
         type:  .type,
         name:  (.change.after.name // null),
         rg:    (.change.after.resource_group_name // null),
         pid:   (.change.after.parent_id
                 // .change.after.private_dns_resolver_id
                 // .change.after.dns_forwarding_ruleset_id
                 // .change.after.private_dns_zone_id
                 // .change.after.virtual_network_id
                 // .change.after.virtual_hub_id
                 // null),
         atype: (if .type == "azapi_resource"
                 then (.change.after.type // "" | split("@")[0])
                 else null end)
       }
     | select(.name != null and .name != "")]'
}

# ── Main ─────────────────────────────────────────────────────

# Phase 0 — Refresh: detect resources deleted from Azure but still in state
if [[ "$SKIP_REFRESH" != "true" ]]; then
  echo ""
  echo "═══════════════════════════════════════"
  echo " Refreshing state against Azure..."
  echo "═══════════════════════════════════════"

  REFRESH_OUT=$(terraform plan -refresh-only -var-file="$VAR_FILE" -input=false -out=tfrefresh 2>&1)
  echo "$REFRESH_OUT" | tf_quiet

  # Check if refresh found any drift at all
  REFRESH_CHANGES=$(terraform show -json tfrefresh 2>/dev/null | jq '
    [.resource_changes[]
     | select(.change.actions != ["no-op"])
    ] | length' 2>/dev/null || echo "0")

  if [[ "$REFRESH_CHANGES" -gt 0 ]]; then
    echo "  ⚡ Refresh detected $REFRESH_CHANGES resource(s) with drift"
    echo "  Applying refresh to sync state with Azure..."
    terraform apply -refresh-only -var-file="$VAR_FILE" -input=false -auto-approve 2>&1 | tf_quiet
    echo "  ✅ State refreshed — removed stale entries"
  else
    echo "  ✅ State is consistent with Azure"
  fi

  rm -f tfrefresh
fi

# Phase 1 — Import: find resources in Azure not yet in state
IMPORTS_FILE="imports_auto.tf"
rm -f "$IMPORTS_FILE"

TOTAL_IMPORTS=0
MAX_PASSES=3

for PASS in $(seq 1 $MAX_PASSES); do
  echo ""
  echo "═══════════════════════════════════════"
  if [[ "$PASS" -eq 1 ]]; then
    echo " Planning..."
  else
    echo " Pass $PASS — re-planning after $TOTAL_IMPORTS import(s)..."
  fi
  echo "═══════════════════════════════════════"

  terraform plan -var-file="$VAR_FILE" -out=tfplan -input=false 2>&1 | tf_quiet

  CREATES=$(extract_creates)
  COUNT=$(echo "$CREATES" | jq 'length')

  if [[ "$COUNT" -eq 0 ]]; then
    echo "  ✅ No resources to create — state is in sync"
    break
  fi

  echo "  $COUNT resource(s) to create — checking Azure..."

  PASS_IMPORTS=0

  for i in $(seq 0 $((COUNT - 1))); do
    ROW=$(echo "$CREATES" | jq -c ".[$i]")
    ADDR=$(echo "$ROW" | jq -r '.addr')
    TYPE=$(echo "$ROW" | jq -r '.type')
    NAME=$(echo "$ROW" | jq -r '.name')
    RG=$(echo "$ROW"   | jq -r '.rg // empty')
    PID=$(echo "$ROW"  | jq -r '.pid // empty')
    AT=$(echo "$ROW"   | jq -r '.atype // empty')

    # Skip if already in imports file from a previous pass
    if [[ -f "$IMPORTS_FILE" ]] && grep -qF "to = ${ADDR}" "$IMPORTS_FILE"; then
      continue
    fi

    AZ_ID=$(resolve_azure_id "$TYPE" "$NAME" "$RG" "$PID" "$AT" 2>/dev/null) || continue
    exists_in_azure "$TYPE" "$AZ_ID" "$NAME" || continue

    echo "    🔄 $ADDR"
    echo "       → $AZ_ID"
    cat >> "$IMPORTS_FILE" <<EOF
import {
  to = ${ADDR}
  id = "${AZ_ID}"
}
EOF
    PASS_IMPORTS=$((PASS_IMPORTS + 1))
  done

  TOTAL_IMPORTS=$((TOTAL_IMPORTS + PASS_IMPORTS))

  # No new imports found — plan is final
  [[ "$PASS_IMPORTS" -eq 0 ]] && break
done

# Produce final plan if imports were written (need one more plan to include all)
if [[ "$TOTAL_IMPORTS" -gt 0 ]]; then
  echo ""
  echo "═══════════════════════════════════════"
  echo " Final plan with $TOTAL_IMPORTS import(s)..."
  echo "═══════════════════════════════════════"
  terraform plan -var-file="$VAR_FILE" -out=tfplan -input=false 2>&1 | tf_quiet
fi

# Plan summary
if [[ -f tfplan ]]; then
  PLAN_JSON=$(terraform show -json tfplan)
  IMPORT_N=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.change.importing != null)] | length')
  CREATE_N=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.change.actions == ["create"]) | select(.change.importing == null)] | length')
  UPDATE_N=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.change.actions == ["update"])] | length')
  DESTROY_N=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.change.actions | index("delete"))] | length')

  echo ""
  echo "  📥 Import: $IMPORT_N  ➕ Create: $CREATE_N  🔄 Update: $UPDATE_N  🗑️  Destroy: $DESTROY_N"

  [[ "$DESTROY_N" -gt 0 ]] && echo "::warning::⚠️ Plan will DESTROY $DESTROY_N resource(s) — review carefully!"

  echo ""
  terraform show tfplan 2>&1 | tf_quiet | tail -5
else
  echo ""
  echo "  ✅ No plan generated — nothing to do"
fi
