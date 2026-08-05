# How the Platform Works

The platform lets a merchant launch and operate an isolated online store while shoppers browse a
fast, read-optimized storefront.

```mermaid
flowchart TB
    classDef person fill:#e0e7ff,color:#1e1b4b,stroke:#6366f1,stroke-width:2px
    classDef app fill:#ccfbf1,color:#134e4a,stroke:#14b8a6,stroke-width:2px
    classDef core fill:#dbeafe,color:#1e3a8a,stroke:#3b82f6,stroke-width:2px
    classDef event fill:#ffedd5,color:#7c2d12,stroke:#f97316,stroke-width:2px
    classDef read fill:#f3e8ff,color:#581c87,stroke:#a855f7,stroke-width:2px
    classDef foundation fill:#f1f5f9,color:#334155,stroke:#94a3b8,stroke-width:2px

    subgraph people[People]
        direction LR
        operator[Platform operator]:::person
        merchant[Store owner]:::person
        shopper[Shopper]:::person
    end

    subgraph journey[One platform, three simple experiences]
        direction LR

        subgraph setup[1. Launch a store]
            direction TB
            platformUI[Platform Portal]:::app
            tenant[Tenant Service<br/>creates an isolated tenant]:::core
            platformUI --> tenant
        end

        subgraph manage[2. Manage products]
            direction TB
            admin[Admin Portal]:::app
            catalog[Catalog Service<br/>products, categories, attributes]:::core
            image[Image Service<br/>uploads and delivery URLs]:::core
            admin --> catalog
            admin --> image
        end

        subgraph sell[3. Publish a fast storefront]
            direction TB
            events[Redpanda<br/>domain events]:::event
            queries[Product and Category Query Services<br/>read-optimized product catalog]:::read
            storefront[Storefront]:::app
            events --> queries --> storefront
        end
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
        direction LR
        identity[Logto<br/>authentication]:::foundation
        data[MongoDB<br/>one database per tenant]:::foundation
        media[S3 storage and imgproxy<br/>image storage and transformation]:::foundation
    end

    identity -.- platformUI
    identity -.- admin
    identity -.- storefront
    tenant --- data
    catalog --- data
    image --- media
```

**Tenant isolation:** A tenant is provisioned once and its context travels with every request.
Tenant data is stored in a dedicated MongoDB database, while the platform remains a shared SaaS
deployment.

**Fast storefronts:** Catalog changes are published as events and projected into dedicated query
services. Shoppers read from those optimized models rather than from the write service.
