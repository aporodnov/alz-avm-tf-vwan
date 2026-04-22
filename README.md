# Azure Virtual WAN — Config-Driven Deployment with AVM & Terraform

Deploy a production-ready Azure Virtual WAN topology using
[Azure Verified Modules (AVM)](https://azure.github.io/Azure-Verified-Modules/),
Terraform variable files, and a GitHub Actions CI/CD pipeline.

## Problem

Setting up Azure Virtual WAN is complex: you need a vWAN resource, virtual hubs,
gateways (ExpressRoute / VPN), routing intent, and router scaling — often across
multiple environments. Most teams end up with brittle, click-ops configurations
that are hard to review and reproduce.

## What This Repo Does

| Capability | How |
|---|---|
| **vWAN + Virtual Hub + Gateways** | [AVM pattern module `avm-ptn-alz-connectivity-virtual-wan`](https://registry.terraform.io/modules/Azure/avm-ptn-alz-connectivity-virtual-wan/azurerm/latest) — battle-tested, Microsoft-maintained |
| **Router scale & routing intent** | Native module support — no separate bootstrap needed |
| **Multi-profile support** | Separate `.tfvars` files per environment (hybrid / cloud) — switch profiles with a single dropdown |
| **Safe deployments** | GitHub Actions workflow with `plan` preview before any real change |
| **Identity** | Workload identity federation (OIDC) — no secrets stored in the repo |

## Repository Structure

```
config/
  hybrid.tfvars             # Hybrid profile  (ExpressRoute + optional routing intent)
  cloud.tfvars              # Cloud profile   (no on-prem connectivity)
main.tf                     # Orchestrator — RG + AVM module call
variables.tf                # Input variables
outputs.tf                  # Key outputs
providers.tf                # Provider & backend config
.github/workflows/
  deploy-vwan.yml           # CI/CD — Plan or Apply, profile selector
```

## Quick Start

### 1. Fork & configure GitHub environment

Create a GitHub environment (`Prod` or `Lab`) with these **variables**:

| Variable | Value |
|---|---|
| `AZURE_TENANT_ID` | Your Entra ID tenant |
| `VWAN_SPN_CLIENT_ID` | App registration client ID (federated credential for OIDC) |
| `HYBRID_AZURE_SUBSCRIPTION_ID` | Target subscription for Hybrid profile |
| `CLOUD_AZURE_SUBSCRIPTION_ID` | Target subscription for Cloud profile |

The service principal needs **Contributor** (or scoped Network Contributor + RG
Contributor) on the target subscription.

### 2. Customise a variable file

Edit `config/hybrid.tfvars` (or `config/cloud.tfvars`):

- Set the vWAN name, hub name, address prefix, and location.
- Uncomment the `express_route_circuit_connections` block and supply your circuit
  peering resource ID + authorization key.
- To enable routing intent, set `firewall = true` in `enabled_resources` and
  uncomment the `routing_intents` block.

### 3. Run the workflow

1. Go to **Actions → Deploy - vWAN Network**
2. Pick a **Profile** (`Hybrid` or `Cloud`) and a **Mode** (`Plan` or `Apply`)
3. Review the Plan output, then re-run with `Apply` when ready

### Local execution

```bash
terraform init
terraform plan  -var-file="config/hybrid.tfvars"
terraform apply -var-file="config/hybrid.tfvars"
```

## Key Design Decisions

- **AVM module over custom code** — Leverages Microsoft's verified, versioned
  registry module so you inherit ongoing fixes and best practices without
  maintaining low-level resources.
- **No bootstrap step** — Unlike the Bicep version, the Terraform AVM module
  handles router scale units and routing intent natively, so a single
  `terraform apply` deploys everything.
- **`default_parent_id` injected automatically** — `main.tf` merges the
  resource-group ID into every hub, so `.tfvars` files stay clean and portable.
- **Routing intent is opt-in** — Routing policies deploy only when the
  `routing_intents` block is uncommented and `firewall` is enabled.

## Remote State (recommended for production)

Uncomment the `backend "azurerm"` block in `providers.tf` and set the storage
account details. For per-profile state isolation you can override the key at
init time:

```bash
terraform init -backend-config="key=hybrid.terraform.tfstate"
```

## Contributing

Issues and PRs are welcome. Please run a `Plan` against a test subscription
before submitting changes.

## License

MIT
