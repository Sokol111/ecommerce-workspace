# How the Platform Works

The platform lets a merchant launch and operate an isolated online store while shoppers browse a
fast, read-optimized storefront.

```mermaid
flowchart LR
    classDef person fill:#172554,color:#ffffff,stroke:#60a5fa,stroke-width:2px
    classDef app fill:#0f766e,color:#ffffff,stroke:#5eead4,stroke-width:2px
    classDef write fill:#9f1239,color:#ffffff,stroke:#fda4af,stroke-width:2px
    classDef event fill:#7c2d12,color:#ffffff,stroke:#fdba74,stroke-width:2px
    classDef read fill:#6d28d9,color:#ffffff,stroke:#c4b5fd,stroke-width:2px
    classDef foundation fill:#374151,color:#ffffff,stroke:#d1d5db,stroke-width:2px

    shopper[Shopper]:::person
    merchant[Store owner]:::person
    operator[Platform operator]:::person

    subgraph setup[1. Launch a store]
        platformUI[Platform Portal]:::app
        tenant[Tenant Service<br/>creates an isolated tenant]:::write
        platformUI --> tenant
    end

    subgraph manage[2. Manage products]
        admin[Admin Portal]:::app
        catalog[Catalog Service<br/>products, categories, attributes]:::write
        image[Image Service<br/>uploads and delivery URLs]:::write
        admin --> catalog
        admin --> image
    end

    subgraph sell[3. Publish a fast storefront]
        events[Redpanda<br/>domain events]:::event
        queries[Product and Category Query Services<br/>read-optimized product catalog]:::read
        storefront[Storefront]:::app
        events --> queries --> storefront
    end

    operator --> platformUI
    merchant --> admin
    shopper --> storefront

    tenant -. tenant context .-> catalog
    tenant -. tenant context .-> image
    tenant -. tenant context .-> queries
    catalog -. product and category events .-> events
    image -. image events .-> events

    subgraph foundation[Shared platform foundation]
        identity[Logto<br/>authentication]:::foundation
        data[MongoDB<br/>one database per tenant]:::foundation
        media[S3 storage and imgproxy<br/>image storage and transformation]:::foundation
    end

    tenant --- data
    catalog --- data
    image --- media
```

**Tenant isolation:** A tenant is provisioned once and its context travels with every request.
Tenant data is stored in a dedicated MongoDB database, while the platform remains a shared SaaS
deployment.

**Fast storefronts:** Catalog changes are published as events and projected into dedicated query
services. Shoppers read from those optimized models rather than from the write service.
