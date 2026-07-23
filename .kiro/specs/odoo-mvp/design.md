# Design: odoo-2-dbt MVP — Odoo Analytics Warehouse (Mock Package)

Status: DRAFT — under review
Last updated: 2026-07-22

## 1. Purpose & Deliverable

A dbt package that models raw Odoo ERP schemas (nominally Odoo 17/18) into an
analytics-ready warehouse. The MVP is a **mock**: every model compiles
(`dbt parse` green), sources are declared, and the generated dbt docs site +
DAG demonstrate the full architecture. No runnable data, no warehouse
connection required.

**The deliverable — start with the end in mind — is the Semantic Business
Reporting Layer**: plain, warehouse-agnostic dbt views presenting standardized
insights for non-technical business buyers. Everything upstream exists to feed
these reports.

- 6 **domain reports** (one per Knowledge Domain)
- 22 **subdomain reports** (one per Operational Subdomain)

See §7 for the full report catalog.

## 2. Business Taxonomy

Three **tiers** organize six **Knowledge Domains**, which contain
**Operational Subdomains** (Odoo schema groupings). Tiers are
documentation-only — they never appear in directory structure. **Domains are
the physical grouping** (directories, worktree ownership). Alignment:
TOGAF/Zachman-style separation of what you deliver (Business), how you deliver
(Operating), and what enables both (Technology).

| Tier | Domain | Operational Subdomains |
|---|---|---|
| Business | 1. Innovation | PLM; Product R&D / Engineering |
| Business | 2. Marketing | Multi-Channel Acquisition; Automation & Analytics |
| Business | 3. Sales | CRM Pipeline; Commercial Transactions; Recurring Revenue |
| Operating | 4. Fulfillment | Inventory & Logistics; Procurement; Production (MRP); Service Delivery; Post-Sale Service |
| Operating | 5. Finance | AR; AP; General Ledger; Workforce Finance |
| Technology | 6. Technology & Governance | Schema Introspection; IAM & Security; Process Orchestration; Environment Config; Telemetry & Storage; Internationalization |

Pipeline sequencing principle (for docs/README): Technology & Governance
tables load first — they carry the permission framework and metadata registry
— then transactional domains in the Business and Operating tiers.

## 3. Architecture — Data Vault 2.0

Five layers. Delineation is strict:

```
staging  →  raw vault  →  business vault  →  marts  →  reports
(hard rules) (restructure)  (soft rules)    (star)    (semantic)
```

1. **Staging** (`models/staging/`) — *hard rules only*. One view per raw Odoo
   table: type casting, date/timestamp normalization, column renames, hash key
   computation. Flat directory, no taxonomy, no business logic.
2. **Raw Vault** (`models/raw_vault/`) — source truth restructured by business
   key. Hubs (business keys), Links (relationships), Satellites (descriptive
   attributes + history via `hash_diff`). Insert-only, auditable, zero
   business rules. Organized **by domain**, not by structure type.
3. **Business Vault** (`models/business_vault/`) — *soft rules*. Derived
   satellites, computed metrics, standardization via mapping seeds
   (generalizing the `seed__account_mappings` pattern: account
   reclassification, stage mappings, metric formulas). Taxonomy starts here.
4. **Marts** (`models/marts/`) — star schema. Conformed dimensions in
   `core/`, domain facts + dims in domain dirs. Disposable, rebuildable from
   the vault.
5. **Reports** (`models/reports/`) — the Semantic Business Reporting Layer.
   Plain dbt views (warehouse-agnostic SQL), one per domain + one per
   subdomain.

### Why Data Vault for parallel development

Hubs are few and stable — owned by the core worktree. Multiple satellites
hang off one hub independently: the Sales worktree adds `sat_partner_sales`
on `hub_partner` while Finance adds `sat_partner_credit` on the same hub —
zero file overlap, zero coordination. The methodology is append-only across
teams by design.

## 4. Repository Layout

```
models/
  staging/                     # flat; stg_odoo__<table>.sql
  raw_vault/
    core/                      # shared hubs + base sats — core worktree ONLY
    innovation/  marketing/  sales/  fulfillment/  finance/  technology/
  business_vault/
    core/  innovation/  marketing/  sales/  fulfillment/  finance/  technology/
  marts/
    core/                      # conformed dims: dim_partner, dim_product,
                               # dim_user, dim_company, dim_date
    innovation/  marketing/  sales/  fulfillment/  finance/  technology/
  reports/
    innovation/  marketing/  sales/  fulfillment/  finance/  technology/
seeds/                         # mapping seeds (account, stage, ...)
.kiro/specs/odoo-mvp/          # this spec: requirements.md, design.md, tasks/
AGENTS.md                      # agent entry point (OpenCode/Claude Code)
docs/parallel-workflow.md      # worktree conventions
```

## 5. Source Table Map (representative, 2–4 per subdomain)

Breadth over exhaustiveness: enough tables per subdomain to prove the
modeling approach. All declared in one `__odoo__sources.yml`. Tables marked
(E) are Odoo Enterprise / paid apps — included to demonstrate coverage,
flagged in docs. Version-sensitive tables noted.

### Core (shared entities — core worktree)
`res_partner`, `product_template`, `product_product`, `res_users`,
`res_company`, `res_currency`

### 1. Innovation
- **PLM**: `mrp_eco` (E), `mrp_bom`, `mrp_bom_line`
- **Product R&D / Engineering**: `product_template`*, `product_product`*,
  `mrp_routing_workcenter`  (*staged by core; domain adds sats)

### 2. Marketing
- **Multi-Channel Acquisition**: `utm_campaign`, `utm_source`,
  `mailing_mailing`, `event_event`
- **Automation & Analytics**: `mailing_trace`, `survey_survey`,
  `survey_user_input`, `website_visitor`

### 3. Sales
- **CRM Pipeline**: `crm_lead`, `crm_stage`, `crm_team`
- **Commercial Transactions**: `sale_order`, `sale_order_line`, `pos_order`,
  `pos_order_line`
- **Recurring Revenue**: `sale_subscription` (E; v16+ folds into
  `sale_order` recurrence — modeled as logical source), `sale_subscription_line` (E)

### 4. Fulfillment
- **Inventory & Logistics**: `stock_picking`, `stock_move`, `stock_quant`,
  `stock_warehouse`
- **Procurement**: `purchase_order`, `purchase_order_line`,
  `product_supplierinfo`
- **Production (MRP)**: `mrp_production`, `mrp_workorder`, `mrp_workcenter`,
  `quality_check` (E)
- **Service Delivery**: `project_project`, `project_task`,
  `account_analytic_line` (timesheets)
- **Post-Sale Service**: `helpdesk_ticket` (E), `helpdesk_sla` (E)

### 5. Finance
- **AR**: `account_move` (move_type = out_invoice/out_refund),
  `account_move_line`, `account_payment`
- **AP**: `account_move` (in_invoice/in_refund), `hr_expense`
- **General Ledger**: `account_account`, `account_journal`, `account_tax`,
  `account_bank_statement_line`
- **Workforce Finance**: `hr_payslip` (E), `hr_salary_rule` (E)

Note: `account_move` / `account_move_line` are staged **once**; AR/AP/GL
delineation is a business-vault soft rule (filter on `move_type` /
journal), not a staging concern.

### 6. Technology & Governance
- **Schema Introspection**: `ir_model`, `ir_model_fields`
- **IAM & Security**: `res_groups`, `ir_model_access`, `ir_rule`
- **Process Orchestration**: `ir_cron`, `ir_actions_server`, `base_automation`
- **Environment Config**: `ir_config_parameter`, `ir_mail_server`
- **Telemetry & Storage**: `ir_logging`, `ir_attachment`, `mail_message`
- **Internationalization**: `res_lang`, `ir_translation` (≤v15; v16+ uses
  JSONB column translations — noted in docs), `account_fiscal_position`

Total: ~60 staging models.

## 6. Vault Design (high-level; task-level detail in tasks/)

### Core hubs (core worktree only)
`hub_partner` (business key: partner ref/id), `hub_product` (default_code /
template id), `hub_user` (login), `hub_company` (company registry), plus base
sats `sat_partner`, `sat_product`, `sat_user`, `sat_company`.

### Domain vault entities (owned by domain worktrees)
Each domain builds, in its own directory:
- Domain hubs for entities born in that domain (e.g. `hub_sales_order`,
  `hub_campaign`, `hub_stock_move`, `hub_gl_account`, `hub_ir_model`)
- Links joining domain hubs to core hubs (e.g.
  `link_order__partner__product`)
- Sats on domain hubs AND domain-specific sats on core hubs (e.g.
  `sat_partner_sales` off `hub_partner`)

### Business vault per domain
Derived/computed structures feeding the marts: e.g.
`bv_lead_stage_durations`, `bv_bom_cost_rollup`, `bv_gl_period_balances`,
`bv_inventory_aging`. Standardization seeds:
`seed__account_mappings` (exists), `seed__crm_stage_mappings`,
`seed__report_metric_definitions` (as needed per domain).

## 7. Report Catalog (the deliverable)

Naming: domain rollup `rpt_<domain>`, subdomain `rpt_<domain>__<subdomain>`.
All plain views in `models/reports/<domain>/`.

### Innovation
| View | Level | Target metrics |
|---|---|---|
| `rpt_innovation` | Domain | BOM std vs actual cost, scrap rate, design-to-release cycle time |
| `rpt_innovation__plm` | Sub | ECO cycle time, BOM version churn, change-order backlog |
| `rpt_innovation__product_engineering` | Sub | active SKUs, variant proliferation, routing step counts |

### Marketing
| View | Level | Target metrics |
|---|---|---|
| `rpt_marketing` | Domain | CAC, ROAS, stage conversion rate |
| `rpt_marketing__acquisition` | Sub | leads by channel/campaign, cost per lead, email open/click rates |
| `rpt_marketing__automation_analytics` | Sub | nurture conversion, survey NPS, visitor-to-lead rate |

### Sales
| View | Level | Target metrics |
|---|---|---|
| `rpt_sales` | Domain | deal stage duration, rep win-rate, MRR/ARR, quote-to-order ratio |
| `rpt_sales__crm_pipeline` | Sub | pipeline value by stage, win/loss reasons, velocity |
| `rpt_sales__transactions` | Sub | order volume/AOV by channel (B2B/POS/eComm), quote conversion |
| `rpt_sales__recurring_revenue` | Sub | MRR/ARR, churn, renewal rate, contract value |

### Fulfillment
| View | Level | Target metrics |
|---|---|---|
| `rpt_fulfillment` | Domain | days of inventory on hand, stockout risk, order fulfillment cycle time |
| `rpt_fulfillment__inventory_logistics` | Sub | DOH by warehouse, inventory aging buckets, transfer lead times |
| `rpt_fulfillment__procurement` | Sub | PO cycle time, vendor OTD, price variance |
| `rpt_fulfillment__production` | Sub | WO throughput, work-center utilization, quality pass rate |
| `rpt_fulfillment__service_delivery` | Sub | project margin, billable utilization, milestone slippage |
| `rpt_fulfillment__post_sale_service` | Sub | ticket volume, SLA compliance, first-response time |

### Finance
| View | Level | Target metrics |
|---|---|---|
| `rpt_finance` | Domain | net profit margin, AR aging, AP due, quick/current ratios |
| `rpt_finance__ar` | Sub | AR aging buckets, DSO, collection effectiveness |
| `rpt_finance__ap` | Sub | AP due schedule, DPO, expense trends |
| `rpt_finance__general_ledger` | Sub | trial balance, P&L, balance sheet, cash flow |
| `rpt_finance__workforce` | Sub | labor cost by dept, payroll trend, billable timesheet recovery |

### Technology & Governance
| View | Level | Target metrics |
|---|---|---|
| `rpt_technology` | Domain | DAU, scheduled sync success rates, ACL exception alerts |
| `rpt_technology__schema_introspection` | Sub | custom model/field counts, Studio additions |
| `rpt_technology__iam_security` | Sub | users per group, ACL coverage, record-rule exceptions |
| `rpt_technology__orchestration` | Sub | cron success rate, automation run volume, failure alerts |
| `rpt_technology__environment_config` | Sub | config drift, parameter inventory |
| `rpt_technology__telemetry_storage` | Sub | error-log rate, attachment storage growth, audit activity |
| `rpt_technology__internationalization` | Sub | active languages, translation coverage, localization footprint |

28 views total (6 domain + 22 subdomain).

## 8. Naming Conventions

| Layer | Pattern | Example |
|---|---|---|
| Staging | `stg_odoo__<table>` | `stg_odoo__account_move` |
| Hub | `hub_<entity>` | `hub_partner` |
| Link | `link_<a>__<b>[__<c>]` | `link_order__partner__product` |
| Satellite | `sat_<entity>[_<context>]` | `sat_partner_sales` |
| Business vault | `bv_<subject>` | `bv_gl_period_balances` |
| Dimension | `dim_<entity>` | `dim_product` |
| Fact | `fct_<subject>` | `fct_sales_orders` |
| Report | `rpt_<domain>[__<subdomain>]` | `rpt_finance__ar` |
| Seed | `seed__<subject>` | `seed__account_mappings` |
| Source | source `odoo`, table = raw name | `{{ source('odoo', 'account_move') }}` |

Macros reused: `hash_key`, `hash_diff`, `generate_schema_name`
(`macros/`).

## 9. Module Ownership Map (worktree boundaries)

One worktree = one owner per file. Domain worktrees never edit `core/` or
another domain's dirs; they `ref()` across boundaries.

| Worktree | Owns |
|---|---|
| `core` | `staging/` files for shared tables (res_partner, product_*, res_users, res_company, res_currency); `raw_vault/core/`; `business_vault/core/`; `marts/core/`; `seeds/` shared seeds; source yml for shared tables |
| `innovation` | `staging/` files for its tables; `raw_vault/innovation/`; `business_vault/innovation/`; `marts/innovation/`; `reports/innovation/` |
| `marketing` … `technology` | same pattern per domain |
| `assembly` (final) | `dbt_project.yml` model config, README, docs generation, `models/overview.md` |

Shared-table edge case: `account_move` staged by **finance** worktree (its
primary consumer); other domains `ref()` it.

Wave order: core first (wave 1), six domains parallel (wave 2), reports may
land with domain waves, assembly last (wave 3).

## 10. Project Config

Extend the existing `dbt_project.yml` pattern (materializations declared but
never run in the mock):

| Layer | Materialization | Schema |
|---|---|---|
| staging | view | staging |
| raw_vault | incremental | raw_vault |
| business_vault | table | business_vault |
| marts | table | marts |
| reports | view | reports |

This package lives in its own repo (`Rho-Lall/odoo-2-dbt`, public). The
SEC/Cybersyn POC stays in `Bulldozer-Engineering/analytics-engineering` —
its macros (`hash_key`, `hash_diff`, `generate_schema_name`) were copied
here as the package's DV toolkit.

## 11. Odoo Version Posture

Target Odoo 17/18 nominally; stay flexible. Enterprise-only tables included
and flagged (E). Version-sensitive structures (subscriptions,
translations) modeled as logical sources with a note. Principle:
demonstrate we've thought it through; adjust to whatever hand-raisers
actually run.

## 12. Open Questions

1. Docs publishing target (GitHub Pages vs committed HTML) — decide at
   assembly wave.

## 13. Out of Scope (MVP)

- Extraction/sync engine (Fivetran/Airbyte assumed upstream)
- Runnable demo data / seeds mimicking Odoo tables
- Snowflake semantic views / Cortex integration
- Incremental-load correctness (declared, not exercised)
- Exhaustive Odoo table coverage
