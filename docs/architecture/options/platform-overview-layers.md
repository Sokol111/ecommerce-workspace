# Option B: Layered Platform

This version highlights the boundary between user-facing applications, domain services, and shared
platform capabilities.

```mermaid
flowchart TB
    classDef actor fill:#fef3c7,color:#78350f,stroke:#f59e0b,stroke-width:2px
    classDef ui fill:#ccfbf1,color:#134e4a,stroke:#14b8a6,stroke-width:2px
    classDef service fill:#dbeafe,color:#1e3a8a,stroke:#3b82f6,stroke-width:2px
    classDef query fill:#f3e8ff,color:#581c87,stroke:#a855f7,stroke-width:2px
    classDef platform fill:#f1f5f9,color:#334155,stroke:#94a3b8,stroke-width:2px

    subgraph users[People]
        direction LR
        operator[Platform operator]:::actor
        merchant[Store owner]:::actor
        shopper[Shopper]:::actor
    end

    subgraph apps[Applications]
        direction LR
        platformPortal[Platform Portal]:::ui
        admin[Admin Portal]:::ui
        storefront[Storefront]:::ui
    end

    subgraph services[Domain Services]
        direction LR
        tenant[Tenant Service<br/>store provisioning]:::service
        catalog[Catalog Service<br/>write model]:::service
        image[Image Service<br/>media workflow]:::service
        productQuery[Product Query Service<br/>read model]:::query
        categoryQuery[Category Query Service<br/>read model]:::query
    end

    subgraph foundation[Shared Platform Capabilities]
        direction LR
        auth[Logto<br/>authentication]:::platform
        events[Redpanda<br/>domain events]:::platform
        mongo[MongoDB<br/>isolated tenant databases]:::platform
        media[S3 storage + imgproxy]:::platform
    end

    operator --> platformPortal --> tenant
    merchant --> admin
    shopper --> storefront

    admin --> catalog
    admin --> image
    storefront --> productQuery
    storefront --> categoryQuery

    tenant -. context .-> catalog
    catalog -. events .-> events
    image -. events .-> events
    events -. projections .-> productQuery
    events -. projections .-> categoryQuery

    platformPortal -.- auth
    admin -.- auth
    storefront -.- auth
    tenant --- mongo
    catalog --- mongo
    productQuery --- mongo
    categoryQuery --- mongo
    image --- media
```

**Best for:** technical clients who want a concise systems-architecture view without deployment
details.
