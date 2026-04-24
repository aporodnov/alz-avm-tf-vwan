# Azure Virtual WAN — Config-Driven Deployment

Deploy a multi-hub Azure Virtual WAN topology using
[Azure Verified Modules (AVM)](https://registry.terraform.io/modules/Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm/latest),
Terraform `.tfvars` files, and a GitHub Actions CI/CD pipeline.

---

## What Gets Deployed

Everything below is toggled per hub in the `.tfvars` file — set a flag to `true`
and the resource appears; set it to `false` and it's skipped entirely.

### Core Networking

| Resource | Purpose |
|---|---|
| **Resource Groups** | `AVNM-RG` for networking, `DNS-RG` for DNS (optional) |
| **Virtual WAN** | The top-level vWAN container (`Standard` type) |
| **Virtual Hubs** | One per region (e.g. Canada Central + Canada East) — each gets its own address space |
| **Sidecar VNet** | A spoke VNet peered to the hub, hosts Bastion, DNS resolver subnets, and any future workloads |
| **Hub ↔ VNet Connection** | Automatic peering between the hub and its sidecar VNet |

### Gateways & Connectivity (opt-in per hub)

| Resource | Purpose |
|---|---|
| **ExpressRoute Gateway** | Connects the hub to on-premises via ExpressRoute circuits |
| **VPN Gateway** | Site-to-site VPN for branch offices |
| **VPN Sites & Connections** | Define branch devices (IP, BGP ASN, IPsec policies) and link them to the hub |
| **ExpressRoute Circuit Connections** | Link an existing ER circuit to the hub gateway |

### DNS (opt-in per hub)

| Resource | Purpose |
|---|---|
| **Private DNS Zones** | All Azure Private Link zones (90+), auto-created and linked to sidecar VNets |
| **Private DNS Resolver** | Inbound + outbound endpoints for hybrid DNS resolution |
| **Forwarding Rulesets** | Forward on-prem domains (e.g. `contoso.local`) to your DNS servers |
| **Additional VNet Links** | Link extra spoke VNets to all private DNS zones |

### Security & Operations (opt-in per hub)

| Resource | Purpose |
|---|---|
| **Azure Bastion** | Secure VM access without public IPs (Standard SKU with tunneling) |
| **Azure Firewall + Policy** | Hub firewall for routing intent (internet + private traffic inspection) |
| **DDoS Protection Plan** | Network-level DDoS protection for hub VNets |

---

## Repository Structure

```
main.tf                     # Orchestrator — creates RGs, calls the AVM module
variables.tf                # All input variables with descriptions and defaults
outputs.tf                  # vWAN, hub, and gateway resource IDs
providers.tf                # Provider versions + remote state backend config
config/
  prod.tfvars               # Prod profile (ExpressRoute, routing intent ready)
  lab.tfvars                # Lab profile  (multi-hub, VPN, Bastion, DNS)
.github/workflows/
  deploy-vwan.yml           # CI/CD — Plan or Plan & Apply, profile selector
  drift-report.yml          # Scheduled drift detection
```

---

## How to Configure

All configuration lives in `config/*.tfvars`. You never need to edit `main.tf`
or `variables.tf` — just adjust the values in your profile file.

### Global Settings (top of the tfvars file)

```hcl
networking_resource_group_name = "AVNM-RG"       # RG for vWAN + hubs + VNets
dns_resource_group_name        = "DNS-RG"         # RG for DNS zones + resolver (set to null to skip)
location                       = "canadacentral"  # Default region
virtual_wan_name               = "vwan01"
enable_ddos_protection_plan    = false             # true to deploy DDoS plan
```

### Adding a Hub

Each key under `virtual_hubs` is a hub. The key becomes the Terraform address
(e.g. `"cc-hub01"`) and must be stable — renaming it will destroy and recreate.

```hcl
virtual_hubs = {
  "cc-hub01" = {
    location = "canadacentral"

    # Toggle what gets deployed in this hub:
    enabled_resources = {
      firewall                              = false
      firewall_policy                       = false
      bastion                               = true   # ← Azure Bastion
      virtual_network_gateway_express_route = true   # ← ER gateway
      virtual_network_gateway_vpn           = true   # ← VPN gateway
      private_dns_zones                     = true   # ← 90+ Private Link zones
      private_dns_resolver                  = true   # ← DNS resolver + forwarding
      sidecar_virtual_network               = true   # ← Sidecar spoke VNet
    }

    hub = {
      name                                   = "vHUB-CC-Cloud"
      address_prefix                         = "10.58.128.0/21"
      hub_routing_preference                 = "ExpressRoute"
      virtual_router_auto_scale_min_capacity = 2  # Router scale units
    }

    # ... gateway, bastion, DNS, sidecar blocks follow
  }
}
```

### Common Tasks

| I want to… | Do this in the tfvars |
|---|---|
| **Add a new hub region** | Add a new key under `virtual_hubs` with the region's location and address prefix |
| **Enable ExpressRoute** | Set `virtual_network_gateway_express_route = true`, add the `virtual_network_gateways.express_route` block, uncomment `express_route_circuit_connections` |
| **Enable VPN** | Set `virtual_network_gateway_vpn = true`, define `vpn_sites` and `vpn_site_connections` with device IPs, BGP settings, and IPsec policies |
| **Enable Azure Firewall + routing intent** | Set `firewall = true` and `firewall_policy = true`, then uncomment the `routing_intents` block |
| **Add DNS forwarding rules** | Under `private_dns_resolver.outbound_endpoints.default.forwarding_ruleset`, add rules with domain name and destination IPs |
| **Link extra VNets to DNS zones** | Under `private_dns_zones.virtual_network_link_additional_virtual_networks`, add entries with the VNet resource ID |
| **Turn off Bastion** | Set `bastion = false` in `enabled_resources` |
| **Exclude a Private Link zone** | Add the zone key to `private_link_excluded_zones` list |

---

## How to Deploy

### Option A: GitHub Actions (recommended)

1. **Configure GitHub environment variables:**

   | Variable | Description |
   |---|---|
   | `AZURE_TENANT_ID` | Entra ID tenant ID |
   | `VWAN_SPN_CLIENT_ID` | App registration client ID (federated for OIDC) |
   | `PROD_AZURE_SUBSCRIPTION_ID` | Target subscription — Prod |
   | `LAB_AZURE_SUBSCRIPTION_ID` | Target subscription — Lab |
   | `PROD_TF_STATE_RG` / `LAB_TF_STATE_RG` | State file storage account resource group |
   | `PROD_TF_STATE_SA` / `LAB_TF_STATE_SA` | State file storage account name |

   The service principal needs **Contributor** on the target subscription.

2. **Run the workflow:**
   - Go to **Actions → 2 - Deploy vWAN Network**
   - Pick a **Profile** (`Prod` or `Lab`) and a **Mode** (`Plan` or `Plan & Apply`)
   - Review the Plan output, then re-run with `Plan & Apply` when ready

### Option B: Local Execution

```powershell
# Authenticate
az login --tenant <tenant-id>
az account set --subscription <subscription-id>

# Initialize (supply backend config for remote state)
terraform init `
  -backend-config="resource_group_name=terraform-rg" `
  -backend-config="storage_account_name=<sa-name>" `
  -backend-config="container_name=tfstate" `
  -backend-config="key=vwan-lab.tfstate" `
  -backend-config="subscription_id=<subscription-id>" `
  -backend-config="use_oidc=false" `
  -backend-config="use_azuread_auth=true"

# Plan
terraform plan -var-file="config/lab.tfvars"

# Apply
terraform apply -var-file="config/lab.tfvars"
```

> **Note:** The remote backend uses Azure AD auth — your identity needs the
> **Storage Blob Data Contributor** role on the state storage account.

---

## Design Decisions

| Decision | Why |
|---|---|
| **AVM pattern module** | Microsoft-maintained, versioned, inherits fixes automatically — no low-level resource management |
| **Single `terraform apply`** | The AVM module handles router scale units, routing intent, and DNS zones natively — no multi-stage bootstrap |
| **Config-driven (tfvars only)** | All customization is in `.tfvars` files; `main.tf` auto-injects resource group IDs so profiles stay portable |
| **Feature flags per hub** | `enabled_resources` map lets you enable/disable any capability without touching module code |
| **Routing intent is opt-in** | Firewall + routing policies only deploy when explicitly enabled |
| **OIDC auth (no secrets)** | GitHub Actions uses workload identity federation — no client secrets stored anywhere |
| **Separate DNS resource group** | DNS zones can have different RBAC/lifecycle from networking resources |

---

## Providers

| Provider | Version | Purpose |
|---|---|---|
| `azurerm` | `~> 4.0` | Core Azure resources |
| `azapi` | `~> 2.4` | Private DNS zone VNet links (used internally by the AVM module) |
| Terraform | `~> 1.9` | HCL engine |

---

## Outputs

After apply, these values are available:

| Output | Description |
|---|---|
| `virtual_wan_name` | Name of the Virtual WAN |
| `virtual_wan_resource_id` | Full resource ID of the vWAN |
| `virtual_hub_resource_ids` | Map of hub key → resource ID |
| `virtual_hub_resource_names` | Map of hub key → hub name |
| `express_route_gateway_resource_ids` | Map of ER gateway resource IDs |
| `firewall_resource_ids` | Map of firewall resource IDs |
| `networking_resource_group_name` | Name of the networking RG |
| `dns_resource_group_name` | Name of the DNS RG (null if not created) |

---

## Contributing

1. Create a branch
2. Edit the relevant `.tfvars` file or module code
3. Run a `Plan` via the workflow against a test subscription
4. Open a PR with the plan output

## License

MIT
