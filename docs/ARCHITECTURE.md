# LicenseGuard Platform - System Architecture

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Status:** Production Ready

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture Layers](#architecture-layers)
3. [Frontend Layer](#frontend-layer)
4. [API Gateway](#api-gateway)
5. [Backend Services](#backend-services)
6. [Shared Packages](#shared-packages)
7. [Data Layer](#data-layer)
8. [Infrastructure](#infrastructure)
9. [Communication Patterns](#communication-patterns)
10. [Deployment Architecture](#deployment-architecture)

---

## System Overview

LicenseGuard is a modern multi-tenant SaaS platform built with a **microservices architecture**. The system is organized into logical layers with clear separation of concerns:

- **Frontend Layer**: React-based admin interfaces
- **API Gateway**: Traefik reverse proxy with domain-based routing
- **Backend Services**: 6 independent microservices (Node.js/Express)
- **Shared Packages**: 4 npm packages for code reuse
- **Data Layer**: PostgreSQL database with Redis caching
- **Infrastructure**: Docker-based containerized deployment

### High-Level Architecture

```mermaid
graph TB
    subgraph "Frontend Layer"
        Admin[lg-admin<br/>Vite/React SPA<br/>Port: 3000]
    end

    subgraph "API Gateway"
        Traefik[Traefik Reverse Proxy<br/>Ports: 80, 443, 8080]
    end

    subgraph "Backend Services"
        UserSvc[lg-user-service<br/>User & Auth<br/>Port: 3002]
        MenuSvc[lg-menu-service<br/>Menu Management<br/>Port: 3005]
        PermSvc[lg-permissions-service<br/>RBAC & DAG<br/>Port: 3003]
        APIKeySvc[lg-api-keys-service<br/>API Key Validation<br/>Port: 3001]
        SecretSvc[lg-secrets-service<br/>Secrets Management<br/>Port: 3007]
        TourSvc[lg-tour-service<br/>NextStepjs Integration<br/>Port: 3004]
    end

    subgraph "Shared Packages"
        Types[lg-types<br/>TypeScript Definitions]
        BackendCommon[lg-backend-common<br/>Shared Utilities]
        MenuRegistry[lg-menu-registry<br/>Menu System]
        AdminUI[lg-admin-ui<br/>UI Components]
    end

    subgraph "Data Layer"
        Postgres[(PostgreSQL<br/>Database)]
        Redis[(Redis<br/>Cache)]
    end

    subgraph "Infrastructure"
        Verdaccio[Verdaccio<br/>NPM Registry<br/>Port: 4873]
        DynamoDB[DynamoDB Local<br/>NoSQL DB]
    end

    Admin --> Traefik
    Traefik --> UserSvc
    Traefik --> MenuSvc
    Traefik --> PermSvc
    Traefik --> APIKeySvc
    Traefik --> SecretSvc
    Traefik --> TourSvc

    UserSvc --> Postgres
    MenuSvc --> Postgres
    PermSvc --> Postgres
    APIKeySvc --> Postgres
    SecretSvc --> Postgres
    TourSvc --> Postgres

    UserSvc -.uses.-> BackendCommon
    UserSvc -.uses.-> Types
    MenuSvc -.uses.-> MenuRegistry
    MenuSvc -.uses.-> BackendCommon
    MenuSvc -.uses.-> Types
    PermSvc -.uses.-> BackendCommon
    PermSvc -.uses.-> Types
    APIKeySvc -.uses.-> BackendCommon
    APIKeySvc -.uses.-> Types
    SecretSvc -.uses.-> BackendCommon
    SecretSvc -.uses.-> Types
    TourSvc -.uses.-> BackendCommon
    TourSvc -.uses.-> Types

    Admin -.uses.-> AdminUI
    AdminUI -.uses.-> Types

    UserSvc -.-> Redis
    SecretSvc -.-> Redis

    style Admin fill:#61dafb,stroke:#333,stroke-width:2px
    style Traefik fill:#37a0cc,stroke:#333,stroke-width:2px
    style Postgres fill:#336791,stroke:#333,stroke-width:2px,color:#fff
    style Redis fill:#d82c20,stroke:#333,stroke-width:2px,color:#fff
```

---

## Architecture Layers

### Layered Architecture Overview

```mermaid
graph TB
    subgraph "Presentation Layer"
        UI[React UI Components]
    end

    subgraph "Application Layer"
        Gateway[API Gateway - Traefik]
    end

    subgraph "Business Logic Layer"
        Services[Microservices<br/>User | Menu | Permissions | API Keys | Secrets | Tour]
    end

    subgraph "Data Access Layer"
        ORM[Data Models & Repositories]
    end

    subgraph "Data Storage Layer"
        DB[(PostgreSQL + Redis)]
    end

    UI --> Gateway
    Gateway --> Services
    Services --> ORM
    ORM --> DB

    style UI fill:#61dafb
    style Gateway fill:#37a0cc
    style Services fill:#68a063
    style ORM fill:#f1e05a
    style DB fill:#336791,color:#fff
```

### Layer Responsibilities

| Layer | Responsibility | Technologies |
|-------|----------------|--------------|
| **Presentation** | User interface, user interactions | React, Vite, lg-admin-ui |
| **Application** | Request routing, load balancing, SSL termination | Traefik |
| **Business Logic** | Core business rules, service logic | Node.js, Express, TypeScript |
| **Data Access** | Database queries, ORM, caching | Knex.js, PostgreSQL, Redis |
| **Data Storage** | Persistent data storage | PostgreSQL 16, Redis |

---

## Frontend Layer

### Admin UI (lg-admin)

**Technology Stack:**
- React 18
- Vite (build tool)
- TypeScript
- lg-admin-ui (shared components)

**Key Features:**
- Single Page Application (SPA)
- Server-Side Routing via Traefik
- JWT-based authentication
- Role-based UI rendering

**Access:**
- Development: `http://admin.lg.local`
- Production: `https://admin.licenseguard.com`

**Component Architecture:**

```mermaid
graph TB
    subgraph "lg-admin"
        App[App.tsx<br/>Main Application]
        Router[React Router<br/>Client-side Routing]
        Pages[Pages/<br/>Dashboard, Users, Settings]
        Components[Components/<br/>Forms, Tables, Modals]
        Hooks[Hooks/<br/>useAuth, useAPI]
        Utils[Utils/<br/>API Client, Auth]
    end

    subgraph "lg-admin-ui Package"
        UIComponents[Shared UI Components<br/>Button, Input, Card]
        UITheme[Theme System<br/>Colors, Typography]
    end

    subgraph "lg-types Package"
        TypeDefs[TypeScript Types<br/>User, Menu, Permission]
    end

    App --> Router
    Router --> Pages
    Pages --> Components
    Pages --> Hooks
    Components --> UIComponents
    Components --> TypeDefs
    Hooks --> Utils
    Utils --> TypeDefs

    style App fill:#61dafb
    style UIComponents fill:#f1e05a
    style TypeDefs fill:#3178c6,color:#fff
```

---

## API Gateway

### Traefik Reverse Proxy

**Role:** Centralized entry point for all HTTP requests

**Key Features:**
- Domain-based routing (admin.lg.local, api.lg.local)
- Automatic HTTPS with Let's Encrypt
- Load balancing (round-robin)
- Health checks
- Request/response middleware
- Access logs

### Routing Configuration

```mermaid
graph LR
    Client[HTTP Client] --> Traefik[Traefik<br/>:80, :443]

    Traefik -->|admin.lg.local| Admin[lg-admin:3000]
    Traefik -->|api.lg.local/user| UserSvc[user-service:3002]
    Traefik -->|api.lg.local/menu| MenuSvc[menu-service:3005]
    Traefik -->|api.lg.local/permissions| PermSvc[permissions-service:3003]
    Traefik -->|api.lg.local/rbac| PermSvc
    Traefik -->|api.lg.local/v1| APIKeySvc[api-keys-service:3001]
    Traefik -->|api.lg.local/secrets| SecretSvc[secrets-service:3007]
    Traefik -->|api.lg.local/tour| TourSvc[tour-service:3004]

    style Traefik fill:#37a0cc
```

### Routing Rules

| Domain Pattern | Target Service | Port | Path Prefix |
|----------------|----------------|------|-------------|
| `admin.lg.local` | lg-admin | 3000 | / |
| `api.lg.local/user` | lg-user-service | 3002 | /user |
| `api.lg.local/menu` | lg-menu-service | 3005 | /menu |
| `api.lg.local/permissions` | lg-permissions-service | 3003 | /permissions |
| `api.lg.local/rbac` | lg-permissions-service | 3003 | /rbac |
| `api.lg.local/v1` | lg-api-keys-service | 3001 | /v1 |
| `api.lg.local/secrets` | lg-secrets-service | 3007 | /secrets |
| `api.lg.local/tour` | lg-tour-service | 3004 | /tour |
| `traefik.lg.local` | Traefik Dashboard | 8080 | / |

---

## Backend Services

### Service Overview

| Service | Purpose | Port | Database | Dependencies |
|---------|---------|------|----------|--------------|
| **lg-user-service** | User management, authentication | 3002 | PostgreSQL | backend-common, types |
| **lg-menu-service** | Hierarchical menu management | 3005 | PostgreSQL | menu-registry, backend-common, types |
| **lg-permissions-service** | RBAC & DAG permissions | 3003 | PostgreSQL | backend-common, types |
| **lg-api-keys-service** | Public API key validation | 3001 | PostgreSQL | backend-common, types |
| **lg-secrets-service** | Encrypted secrets storage | 3007 | PostgreSQL, Redis | backend-common, types |
| **lg-tour-service** | NextStepjs integration | 3004 | PostgreSQL | backend-common, types |

### Service Architecture Pattern

All backend services follow a consistent architecture:

```mermaid
graph TB
    subgraph "Service Architecture"
        Entry[server.ts<br/>Entry Point]
        App[app.ts<br/>Express App Config]
        Routes[routes/<br/>API Routes]
        Controllers[controllers/<br/>Business Logic]
        Models[models/<br/>Data Models]
        DB[database/<br/>Knex.js]
        Middleware[middleware/<br/>Auth, Logging]
    end

    subgraph "External Dependencies"
        BackendCommon[lg-backend-common<br/>Shared Utilities]
        Types[lg-types<br/>Type Definitions]
    end

    Entry --> App
    App --> Routes
    App --> Middleware
    Routes --> Controllers
    Controllers --> Models
    Models --> DB

    Controllers --> BackendCommon
    Models --> Types
    Middleware --> BackendCommon

    style Entry fill:#68a063
    style BackendCommon fill:#f1e05a
    style Types fill:#3178c6,color:#fff
```

### Service Responsibilities

#### lg-user-service
- User registration and authentication
- JWT token generation and validation
- Password hashing (bcrypt)
- User profile management
- Session management

#### lg-menu-service
- Hierarchical menu CRUD operations
- Menu item ordering
- Permission-based menu filtering
- Menu cache management

#### lg-permissions-service
- Role-based access control (RBAC)
- Directed Acyclic Graph (DAG) permissions
- Permission inheritance
- Role assignment and revocation

#### lg-api-keys-service
- Public API key generation
- API key validation
- Rate limiting
- Usage tracking

#### lg-secrets-service
- Encrypted secret storage
- AES-256 encryption
- Secret versioning
- Access audit logging

#### lg-tour-service
- NextStepjs integration
- Guided tour management
- User progress tracking
- Tour analytics

---

## Shared Packages

### Package Dependency Graph

```mermaid
graph TB
    subgraph "Services"
        UserSvc[lg-user-service]
        MenuSvc[lg-menu-service]
        PermSvc[lg-permissions-service]
        APIKeySvc[lg-api-keys-service]
        SecretSvc[lg-secrets-service]
        TourSvc[lg-tour-service]
    end

    subgraph "UI"
        Admin[lg-admin]
    end

    subgraph "Packages"
        Types[lg-types<br/>Base Types]
        BackendCommon[lg-backend-common<br/>Utilities]
        MenuRegistry[lg-menu-registry<br/>Menu System]
        AdminUI[lg-admin-ui<br/>UI Components]
    end

    UserSvc --> BackendCommon
    UserSvc --> Types
    MenuSvc --> MenuRegistry
    MenuSvc --> BackendCommon
    MenuSvc --> Types
    PermSvc --> BackendCommon
    PermSvc --> Types
    APIKeySvc --> BackendCommon
    APIKeySvc --> Types
    SecretSvc --> BackendCommon
    SecretSvc --> Types
    TourSvc --> BackendCommon
    TourSvc --> Types

    BackendCommon --> Types
    MenuRegistry --> Types
    AdminUI --> Types

    Admin --> AdminUI

    style Types fill:#3178c6,color:#fff
    style BackendCommon fill:#68a063
    style MenuRegistry fill:#f1e05a
    style AdminUI fill:#61dafb
```

### Package Descriptions

#### lg-types
**Purpose:** Shared TypeScript type definitions

**Exports:**
- User types (User, UserRole, UserSession)
- Menu types (MenuItem, MenuPermission)
- Permission types (Permission, Role, RolePermission)
- API types (APIKey, APIResponse)
- Secret types (Secret, SecretVersion)

**Dependents:** All services + UI

#### lg-backend-common
**Purpose:** Shared backend utilities and middleware

**Exports:**
- Authentication middleware (JWT validation)
- Logging utilities (Winston)
- Error handling middleware
- Database helpers (Knex utilities)
- Validation helpers (Joi schemas)

**Dependents:** All backend services

#### lg-menu-registry
**Purpose:** Menu system configuration and types

**Exports:**
- Menu definitions
- Menu item schemas
- Menu permissions mapping
- Menu validation

**Dependents:** lg-menu-service, potentially lg-admin

#### lg-admin-ui
**Purpose:** Shared React UI components

**Exports:**
- Button, Input, Select components
- Form components
- Table components
- Modal, Dialog components
- Theme provider

**Dependents:** lg-admin

---

## Data Layer

### Database Schema Overview

```mermaid
erDiagram
    USERS {
        uuid id PK
        string email UK
        string password_hash
        string first_name
        string last_name
        boolean is_active
        timestamp created_at
        timestamp updated_at
    }

    ROLES {
        uuid id PK
        string name UK
        string description
        timestamp created_at
    }

    USER_ROLES {
        uuid user_id FK
        uuid role_id FK
        timestamp assigned_at
    }

    PERMISSIONS {
        uuid id PK
        string resource
        string action
        timestamp created_at
    }

    ROLE_PERMISSIONS {
        uuid role_id FK
        uuid permission_id FK
    }

    MENU_ITEMS {
        uuid id PK
        string title
        string icon
        string path
        uuid parent_id FK
        int order
        timestamp created_at
        timestamp updated_at
    }

    MENU_PERMISSIONS {
        uuid menu_id FK
        uuid permission_id FK
    }

    API_KEYS {
        uuid id PK
        string key_hash UK
        string name
        uuid user_id FK
        boolean is_active
        timestamp expires_at
        timestamp created_at
    }

    SECRETS {
        uuid id PK
        string key UK
        text encrypted_value
        int version
        uuid created_by FK
        timestamp created_at
        timestamp updated_at
    }

    TOURS {
        uuid id PK
        string tour_id
        string name
        json steps
        timestamp created_at
    }

    USER_TOUR_PROGRESS {
        uuid user_id FK
        uuid tour_id FK
        int current_step
        boolean completed
        timestamp last_viewed_at
    }

    USERS ||--o{ USER_ROLES : has
    ROLES ||--o{ USER_ROLES : assigned_to
    ROLES ||--o{ ROLE_PERMISSIONS : has
    PERMISSIONS ||--o{ ROLE_PERMISSIONS : granted_by
    PERMISSIONS ||--o{ MENU_PERMISSIONS : controls
    MENU_ITEMS ||--o{ MENU_PERMISSIONS : requires
    MENU_ITEMS ||--o{ MENU_ITEMS : parent-child
    USERS ||--o{ API_KEYS : owns
    USERS ||--o{ SECRETS : creates
    USERS ||--o{ USER_TOUR_PROGRESS : tracks
    TOURS ||--o{ USER_TOUR_PROGRESS : has
```

### Database Technologies

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Primary Database** | PostgreSQL | 16 | Relational data storage |
| **Query Builder** | Knex.js | 3.x | SQL query construction |
| **Migrations** | Knex Migrations | - | Schema versioning |
| **Cache** | Redis | 7 | Session storage, caching |

---

## Infrastructure

### Infrastructure Components

```mermaid
graph TB
    subgraph "Container Orchestration"
        DockerCompose[Docker Compose<br/>Orchestration]
    end

    subgraph "Infrastructure Services"
        Postgres[PostgreSQL 16<br/>Primary Database]
        Redis[Redis 7<br/>Cache & Sessions]
        Traefik[Traefik 2.x<br/>Reverse Proxy]
        Verdaccio[Verdaccio<br/>NPM Registry]
        DynamoDB[DynamoDB Local<br/>NoSQL Testing]
    end

    subgraph "Networks"
        PublicNet[lg-public<br/>External]
        InternalNet[lg-internal<br/>Internal Only]
    end

    DockerCompose --> Postgres
    DockerCompose --> Redis
    DockerCompose --> Traefik
    DockerCompose --> Verdaccio
    DockerCompose --> DynamoDB

    Traefik --> PublicNet
    Postgres --> InternalNet
    Redis --> InternalNet

    style DockerCompose fill:#2496ed,color:#fff
    style Postgres fill:#336791,color:#fff
    style Redis fill:#d82c20,color:#fff
    style Traefik fill:#37a0cc
```

### Network Architecture

| Network | Type | Purpose | Connected Services |
|---------|------|---------|-------------------|
| **lg-public** | Bridge | External access | Traefik, Frontend |
| **lg-internal** | Bridge | Service communication | All backend services, databases |

---

## Communication Patterns

### Service-to-Service Communication

```mermaid
sequenceDiagram
    participant Client
    participant Traefik
    participant UserSvc
    participant PermSvc
    participant MenuSvc
    participant Postgres

    Client->>Traefik: GET /api/menu
    Traefik->>MenuSvc: Forward request
    MenuSvc->>MenuSvc: Validate JWT
    MenuSvc->>UserSvc: GET /user/validate-token
    UserSvc-->>MenuSvc: User info
    MenuSvc->>PermSvc: GET /permissions/user/:id
    PermSvc->>Postgres: Query user permissions
    Postgres-->>PermSvc: Permissions data
    PermSvc-->>MenuSvc: User permissions
    MenuSvc->>Postgres: Query menu items
    Postgres-->>MenuSvc: All menu items
    MenuSvc->>MenuSvc: Filter by permissions
    MenuSvc-->>Traefik: Filtered menu
    Traefik-->>Client: JSON response
```

### Authentication Flow

```mermaid
sequenceDiagram
    participant Client
    participant Admin UI
    participant Traefik
    participant UserSvc
    participant Postgres
    participant Redis

    Client->>Admin UI: Enter credentials
    Admin UI->>Traefik: POST /api/user/login
    Traefik->>UserSvc: Forward request
    UserSvc->>Postgres: Query user by email
    Postgres-->>UserSvc: User record
    UserSvc->>UserSvc: Verify password (bcrypt)
    UserSvc->>UserSvc: Generate JWT
    UserSvc->>Redis: Store session
    Redis-->>UserSvc: OK
    UserSvc-->>Traefik: {token, user}
    Traefik-->>Admin UI: JSON response
    Admin UI->>Admin UI: Store token in localStorage
    Admin UI-->>Client: Redirect to dashboard
```

---

## Deployment Architecture

### Development Environment

```mermaid
graph TB
    subgraph "Developer Machine"
        Repos[repos/<br/>Git Clones]
        DevSync[Hot-Reload<br/>Dev-Sync Mode]
    end

    subgraph "Docker Desktop"
        Containers[Docker Containers<br/>All Services]
    end

    subgraph "Local Access"
        Browser[Browser<br/>admin.lg.local<br/>api.lg.local]
    end

    Repos --> DevSync
    DevSync --> Containers
    Browser --> Containers

    style DevSync fill:#68a063
    style Containers fill:#2496ed,color:#fff
```

### Production Environment (Future)

```mermaid
graph TB
    subgraph "Load Balancer"
        LB[AWS ALB / CloudFlare]
    end

    subgraph "Application Cluster"
        FE1[Frontend Instance 1]
        FE2[Frontend Instance 2]
        BE1[Backend Services 1]
        BE2[Backend Services 2]
    end

    subgraph "Data Layer"
        RDS[(AWS RDS PostgreSQL)]
        ElastiCache[(AWS ElastiCache Redis)]
    end

    subgraph "Storage"
        S3[AWS S3<br/>Static Assets]
    end

    LB --> FE1
    LB --> FE2
    FE1 --> BE1
    FE2 --> BE2
    BE1 --> RDS
    BE2 --> RDS
    BE1 --> ElastiCache
    BE2 --> ElastiCache
    FE1 --> S3
    FE2 --> S3

    style LB fill:#ff9900,color:#fff
    style RDS fill:#336791,color:#fff
    style ElastiCache fill:#d82c20,color:#fff
```

---

## Performance Considerations

### Caching Strategy

| Layer | Cache Type | TTL | Use Case |
|-------|-----------|-----|----------|
| **API Gateway** | HTTP Cache | 60s | Static assets |
| **Application** | Redis | 300s | User sessions |
| **Database** | Query Cache | 60s | Frequently accessed data |
| **CDN** | Edge Cache | 3600s | Public assets |

### Scalability

**Horizontal Scaling:**
- All services are stateless (except database)
- Can scale by adding more container instances
- Load balancing via Traefik

**Vertical Scaling:**
- Database can scale to higher-tier instances
- Redis can use clustered mode

---

## Security Architecture

### Security Layers

```mermaid
graph TB
    Internet[Internet] --> WAF[Web Application Firewall]
    WAF --> SSL[SSL/TLS Termination]
    SSL --> Auth[JWT Authentication]
    Auth --> RBAC[RBAC Authorization]
    RBAC --> API[API Endpoints]
    API --> Validation[Input Validation]
    Validation --> Encryption[Data Encryption at Rest]
    Encryption --> DB[(Database)]

    style WAF fill:#ff6b6b,color:#fff
    style Auth fill:#51cf66
    style RBAC fill:#339af0,color:#fff
    style Encryption fill:#ff9900,color:#fff
```

### Security Features

| Feature | Implementation | Layer |
|---------|---------------|-------|
| **Authentication** | JWT tokens (RS256) | Application |
| **Authorization** | RBAC + DAG permissions | Application |
| **Encryption in Transit** | TLS 1.3 | Gateway |
| **Encryption at Rest** | AES-256 (secrets) | Application |
| **SQL Injection Protection** | Parameterized queries (Knex.js) | Data Access |
| **XSS Protection** | Content Security Policy | Frontend |
| **CSRF Protection** | SameSite cookies | Frontend |
| **Rate Limiting** | API key throttling | API Gateway |

---

## Monitoring & Observability

### Logging

```mermaid
graph LR
    Services[All Services] --> Winston[Winston Logger]
    Winston --> Console[Console Output]
    Winston --> File[Log Files]
    File --> ELK[ELK Stack<br/>Future]

    style Winston fill:#68a063
    style ELK fill:#fec006,color:#333
```

### Health Checks

All services expose:
- `GET /health` - Basic health check
- `GET /metrics` - Prometheus metrics (future)

---

## Directory Structure

See [Project Root README](../README.md) for complete directory structure.

```
repos/
├── services/          # Backend microservices (6 services)
├── packages/          # Shared npm packages (4 packages)
├── ui/                # Frontend applications (1 app)
└── infrastructure/    # Infrastructure components (5 components)
```

---

## Related Documentation

- **[DEPENDENCIES.md](./DEPENDENCIES.md)** - Package dependency graph and version management
- **[DOCKER.md](./DOCKER.md)** - Docker architecture and best practices
- **[TESTING.md](./TESTING.md)** - Testing strategy and guidelines
- **[RBAC.md](./RBAC.md)** - RBAC and DAG permissions implementation
- **Service Documentation:**
  - [lg-user-service/ARCHITECTURE.md](../repos/services/lg-user-service/ARCHITECTURE.md)
  - [lg-menu-service/ARCHITECTURE.md](../repos/services/lg-menu-service/ARCHITECTURE.md)
  - [lg-permissions-service/ARCHITECTURE.md](../repos/services/lg-permissions-service/ARCHITECTURE.md)
  - [lg-api-keys-service/ARCHITECTURE.md](../repos/services/lg-api-keys-service/ARCHITECTURE.md)
  - [lg-secrets-service/ARCHITECTURE.md](../repos/services/lg-secrets-service/ARCHITECTURE.md)
  - [lg-tour-service/ARCHITECTURE.md](../repos/services/lg-tour-service/ARCHITECTURE.md)

---

## Glossary

| Term | Definition |
|------|------------|
| **DAG** | Directed Acyclic Graph - Permission inheritance structure |
| **JWT** | JSON Web Token - Authentication token format |
| **RBAC** | Role-Based Access Control - Permission model |
| **SPA** | Single Page Application - Client-side rendered web app |
| **TTL** | Time To Live - Cache expiration time |

---

**Next Steps:**
1. Review service-specific ARCHITECTURE.md files for detailed implementation
2. Check DEPENDENCIES.md for package dependency graph
3. See DOCKER.md for local development setup
