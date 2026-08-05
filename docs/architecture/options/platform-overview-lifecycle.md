# Option A: Store Lifecycle

This version presents the platform as a clear lifecycle: create a store, manage its catalog, then
serve shoppers through fast read models.

```mermaid
flowchart LR
    classDef actor fill:#eef2ff,color:#312e81,stroke:#818cf8,stroke-width:2px
    classDef ui fill:#ecfeff,color:#155e75,stroke:#22d3ee,stroke-width:2px
    classDef service fill:#eff6ff,color:#1e3a8a,stroke:#60a5fa,stroke-width:2px
    classDef event fill:#fff7ed,color:#9a3412,stroke:#fb923c,stroke-width:2px
    classDef query fill:#faf5ff,color:#6b21a8,stroke:#c084fc,stroke-width:2px
    classDef data fill:#f8fafc,color:#334155,stroke:#94a3b8,stroke-width:2px

    platformOperator[Platform operator]:::actor
    merchant[Store owner]:::actor
    shopper[Shopper]:::actor

    subgraph launch[Launch]
        platformPortal[Platform Portal]:::ui
        tenant[Tenant Service]:::service
        platformPortal -->|create tenant| tenant
    end

    subgraph operate[Operate]
        admin[Admin Portal]:::ui
        catalog[Catalog Service]:::service
        images[Image Service]:::service
        admin -->|manage catalog| catalog
        admin -->|upload images| images
    end

    subgraph shop[Shop]
        broker[Redpanda]:::event
        readModels[Product and Category<br/>Query Services]:::query
        storefront[Storefront]:::ui
        broker -->|build projections| readModels -->|fast reads| storefront
    end

    platformOperator --> platformPortal
    merchant --> admin
    shopper --> storefront

    tenant -. tenant context .-> catalog
    catalog -. product and category events .-> broker
    images -. image events .-> broker

    database[(MongoDB<br/>database per tenant)]:::data
    storage[(Object storage<br/>and imgproxy)]:::data
    tenant --- database
    catalog --- database
    readModels --- database
    images --- storage
```

**Best for:** clients who should understand the product in seconds, without needing to know CQRS.
