# Platform Overview for Portfolio

This diagram is a simplified, client-facing view of the platform. It focuses on what each user
can do and how the platform turns catalog changes into a fast storefront experience.

```mermaid
flowchart LR
    classDef person fill:#f0fdf4,color:#14532d,stroke:#4ade80,stroke-width:2px
    classDef app fill:#eff6ff,color:#1e3a8a,stroke:#60a5fa,stroke-width:2px
    classDef service fill:#f5f3ff,color:#581c87,stroke:#a78bfa,stroke-width:2px
    classDef platform fill:#fff7ed,color:#9a3412,stroke:#fb923c,stroke-width:2px

    operator[Platform operator]:::person
    merchant[Store owner]:::person
    shopper[Shopper]:::person

    platform[Platform portal<br/>Create and manage stores]:::app
    admin[Admin portal<br/>Manage products and images]:::app
    storefront[Storefront<br/>Browse and buy products]:::app

    tenant[Tenant service<br/>Creates isolated stores]:::service
    catalog[Catalog and image services<br/>Manage product data and media]:::service
    events[Event bus<br/>Keeps product data in sync]:::platform
    queries[Fast product and category APIs<br/>Optimized for storefront reads]:::service

    operator -->|creates a store| platform --> tenant
    merchant -->|manages the catalog| admin --> catalog
    catalog -->|publishes updates| events -->|builds read models| queries
    shopper -->|shops| storefront -->|reads products| queries

    tenant -.->|isolated tenant data| catalog
```

**Built-in platform capabilities:** tenant-isolated data, authentication, image processing,
observability, and Kubernetes deployment.

**Technical implementation:** Go microservices, Kafka/Redpanda events, MongoDB, gRPC/Protobuf,
Docker, Kubernetes, Grafana, Tempo, and Loki.
