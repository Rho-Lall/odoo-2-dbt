# odoo-2-dbt

A dbt package that models raw Odoo ERP schemas (Odoo 17/18) into an
analytics-ready warehouse: Data Vault 2.0 core with a business-facing
**Semantic Reporting Layer** covering six business domains.

> **Status: design/MVP.** This repo currently contains the architecture,
> model DAG, and generated dbt documentation — a blueprint for the package.
> If your company is trying to solve Odoo analytics and wants early access,
> open an issue or reach out.

## The problem

Fivetran, Airbyte, and Meltano will happily land hundreds of raw, highly
normalized Odoo tables (`account_move`, `sale_order_line`, `stock_move`, …)
in your warehouse. Then the real work starts: months of hand-writing dbt
staging, vault, and dimensional models. No gold-standard package exists on
dbt Hub for Odoo. This is it.

## Architecture

```
staging  →  raw vault  →  business vault  →  marts  →  reports
(hard rules) (hubs/links/sats) (soft rules)   (star)   (semantic layer)
```

Six knowledge domains across three tiers:

| Tier | Domain | Example reports |
|---|---|---|
| Business | Innovation | Product Margin & BOM Cost Variance |
| Business | Marketing | Campaign ROI & Lead-to-Customer Pipeline |
| Business | Sales | Pipeline Velocity & Rep Performance |
| Operating | Fulfillment | Multi-Warehouse Logistics & Inventory Aging |
| Operating | Finance | Real-Time GL Balance Sheet & Cash Flow |
| Technology | Technology & Governance | Platform Telemetry & Security Audit |

28 report views total (6 domain rollups + 22 subdomain reports).

Full design: [`.kiro/specs/odoo-mvp/design.md`](.kiro/specs/odoo-mvp/design.md)

## Warehouse support

Warehouse-agnostic SQL (plain dbt views in the reporting layer). Developed
against Snowflake conventions; BigQuery/Redshift adaptation planned.
