# Option C: From Merchant Action to Shopper Experience

This version focuses on the platform's value chain: a merchant changes the catalog and shoppers
receive an optimized storefront experience.

```mermaid
flowchart LR
    classDef person fill:#e0e7ff,color:#1e1b4b,stroke:#6366f1,stroke-width:2px
    classDef app fill:#ccfbf1,color:#134e4a,stroke:#14b8a6,stroke-width:2px
    classDef command fill:#fee2e2,color:#7f1d1d,stroke:#ef4444,stroke-width:2px
    classDef event fill:#ffedd5,color:#7c2d12,stroke:#f97316,stroke-width:2px
    classDef query fill:#f3e8ff,color:#581c87,stroke:#a855f7,stroke-width:2px
    classDef support fill:#f1f5f9,color:#334155,stroke:#94a3b8,stroke-width:2px

    merchant[Store owner]:::person
    shopper[Shopper]:::person

    admin[Admin Portal]:::app
    catalog[Catalog Service<br/>authoritative catalog]:::command
    image[Image Service<br/>product media]:::command
    events[Redpanda<br/>durable domain events]:::event
    projection[Product and Category<br/>Query Services]:::query
    storefront[Storefront<br/>fast product discovery]:::app

    merchant --> admin
    admin -->|product and category changes| catalog
    admin -->|image uploads| image
    catalog -. publish changes .-> events
    image -. publish image URLs .-> events
    events -. update views .-> projection
    shopper --> storefront
    storefront -->|search, browse, filter| projection

    subgraph trust[Platform safeguards]
        direction TB
        tenant[Tenant Service<br/>isolated store context]:::support
        database[(MongoDB<br/>one database per tenant)]:::support
        identity[Logto<br/>secure sign-in]:::support
    end

    tenant -. context .-> catalog
    tenant -. context .-> projection
    catalog --- database
    projection --- database
    admin -.- identity
    storefront -.- identity
```

**Best for:** Upwork proposals where the main message is business impact: independent stores,
reliable catalog updates, and fast shopper-facing reads.
