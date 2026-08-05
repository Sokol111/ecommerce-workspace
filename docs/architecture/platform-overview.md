# Platform Architecture

This multi-tenant SaaS platform combines Go microservices, Nuxt applications, CQRS read models,
and asynchronous domain events. Each tenant's data is isolated in its own MongoDB database while
all tenants share the same deployment.

```mermaid
flowchart LR
    classDef user fill:#172554,color:#ffffff,stroke:#60a5fa,stroke-width:2px
    classDef ui fill:#0f766e,color:#ffffff,stroke:#5eead4,stroke-width:2px
    classDef write fill:#9f1239,color:#ffffff,stroke:#fda4af,stroke-width:2px
    classDef read fill:#6d28d9,color:#ffffff,stroke:#c4b5fd,stroke-width:2px
    classDef service fill:#b45309,color:#ffffff,stroke:#fcd34d,stroke-width:2px
    classDef platform fill:#1e3a8a,color:#ffffff,stroke:#93c5fd,stroke-width:2px
    classDef data fill:#374151,color:#ffffff,stroke:#d1d5db,stroke-width:2px

    shopper[Shopper]:::user
    merchant[Store owner]:::user
    operator[Platform operator]:::user

    subgraph experience[Customer and Management Experiences]
        storefront[Storefront<br/>Nuxt]:::ui
        admin[Admin Portal<br/>Nuxt]:::ui
        platformUI[Platform Portal<br/>Nuxt]:::ui
    end

    subgraph application[Application Services]
        catalog[Catalog Service<br/>CQRS write side]:::write
        productQuery[Product Query Service<br/>CQRS read side]:::read
        categoryQuery[Category Query Service<br/>CQRS read side]:::read
        image[Image Service<br/>upload and delivery]:::service
        tenant[Tenant Service<br/>tenant lifecycle]:::service
    end

    subgraph platformServices[Platform Services]
        events[(Redpanda<br/>domain events)]:::platform
        mongo[(MongoDB<br/>tenant-isolated databases)]:::data
        storage[(S3 object storage<br/>MinIO / Cloudflare R2)]:::data
        proxy[imgproxy<br/>image transformations]:::platform
        identity[Logto<br/>identity and JWTs]:::platform
    end

    shopper --> storefront
    merchant --> admin
    operator --> platformUI

    storefront --> productQuery
    storefront --> categoryQuery
    admin --> catalog
    admin --> image
    platformUI --> tenant

    catalog --> mongo
    tenant --> mongo
    image --> mongo
    productQuery --> mongo
    categoryQuery --> mongo

    catalog -. domain events .-> events
    tenant -. tenant events .-> events
    events -. projections .-> productQuery
    events -. projections .-> categoryQuery
    events -. product events .-> image
    image -. image events .-> events

    image --> storage
    image --> proxy
    proxy --> storage

    storefront -. JWT validation .-> identity
    admin -. JWT validation .-> identity
    platformUI -. JWT validation .-> identity
```

**Why it matters:** Catalog writes are separated from storefront reads. Domain events build
independent, optimized query models, allowing the storefront to scale without synchronous calls to
