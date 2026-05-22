# Developer Onboarding Guide

**Welcome to LicenseGuard Development! 🚀**

This guide will help you set up your development environment and make your first contribution in under 2 hours.

**Version:** 1.0.0
**Last Updated:** 2026-01-25
**Estimated Setup Time:** 30 minutes
**Estimated First Commit:** 2 hours

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Environment Setup](#environment-setup)
3. [First-Time Setup](#first-time-setup)
4. [Architecture Tour](#architecture-tour)
5. [Development Workflows](#development-workflows)
6. [Common Tasks](#common-tasks)
7. [Code Conventions & Patterns](#code-conventions--patterns)
8. [Troubleshooting](#troubleshooting)
9. [Resources & Links](#resources--links)

---

## Prerequisites

### Required Software

#### macOS

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install git
brew install docker
brew install --cask docker  # Docker Desktop
brew install jq  # For smart restarts (optional but recommended)
brew install watch  # For live dashboard (optional)

# Verify installations
git --version        # Should be 2.40+
docker --version     # Should be 20.10+
docker-compose --version  # Should be 2.0+
```

#### Linux (Ubuntu/Debian)

```bash
# Update package index
sudo apt-get update

# Install Git
sudo apt-get install -y git

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER  # Add yourself to docker group
newgrp docker  # Activate the group

# Install Docker Compose
sudo apt-get install -y docker-compose-plugin

# Install optional tools
sudo apt-get install -y jq watch

# Verify installations
git --version
docker --version
docker-compose --version
```

#### Windows (WSL2 Required)

```powershell
# Install WSL2
wsl --install

# Install Ubuntu from Microsoft Store
# Then follow Linux instructions inside WSL2

# Install Docker Desktop for Windows
# Download from: https://www.docker.com/products/docker-desktop

# Configure Docker Desktop to use WSL2 backend
```

---

### GitHub Access

1. **GitHub Account**
   - Sign up at https://github.com if you don't have one

2. **SSH Key Setup**
   ```bash
   # Generate SSH key
   ssh-keygen -t ed25519 -C "your.email@example.com"

   # Start ssh-agent
   eval "$(ssh-agent -s)"

   # Add key to agent
   ssh-add ~/.ssh/id_ed25519

   # Copy public key
   cat ~/.ssh/id_ed25519.pub
   # Add this to GitHub: Settings → SSH and GPG keys → New SSH key
   ```

3. **GitHub CLI (Optional but Recommended)**
   ```bash
   # macOS
   brew install gh

   # Linux
   sudo apt-get install gh

   # Login
   gh auth login
   ```

4. **GitHub Personal Access Token**
   ```bash
   # Create token at: https://github.com/settings/tokens
   # Required scopes: repo, read:packages, write:packages

   # Export token
   export GITHUB_TOKEN=ghp_your_token_here

   # Add to shell profile (~/.zshrc or ~/.bashrc)
   echo 'export GITHUB_TOKEN=ghp_your_token_here' >> ~/.zshrc
   ```

---

## Environment Setup

### Step 1: Clone lg-development Repository

```bash
# Create projects directory
mkdir -p ~/Projects
cd ~/Projects

# Clone lg-development (orchestrator)
git clone git@github.com:WolfgangM81/lg-development.git
cd lg-development

# Verify structure
ls -la
# You should see: CLAUDE.md, README.md, docker-compose.yml, etc.
```

---

### Step 2: Configure Environment Variables

```bash
# Copy example .env file
cp .env.example .env

# Edit .env file
vi .env

# Required variables:
# POSTGRES_USER=licenseguard
# POSTGRES_PASSWORD=<strong-password>
# POSTGRES_DB=licenseguard
# REDIS_PASSWORD=<strong-password>
# JWT_SECRET=<min-32-char-random-string>
# INTERNAL_API_KEY=<random-uuid>
# MASTER_ENCRYPTION_KEY=<32-char-random-string>
# GITHUB_TOKEN=<your-github-token>

# Clone configuration (which repos to clone):
# CLONE_LG_USER_SERVICE=true
# CLONE_LG_PERMISSIONS_SERVICE=true
# CLONE_LG_API_KEYS_SERVICE=true
# CLONE_LG_TOUR_SERVICE=true
# CLONE_LG_MENU_SERVICE=true
# CLONE_LG_SECRETS_SERVICE=true
# CLONE_LG_ADMIN=true
# CLONE_LG_ADMIN_UI=true
# CLONE_LG_MENU_REGISTRY=true
# CLONE_LG_BACKEND_COMMON=true
# CLONE_LG_TYPES=true
```

**Generate secure values:**
```bash
# Generate JWT_SECRET (32+ chars)
openssl rand -base64 32

# Generate MASTER_ENCRYPTION_KEY (32 chars exactly)
openssl rand -hex 16

# Generate INTERNAL_API_KEY (UUID)
uuidgen
```

---

### Step 3: Clone All Repositories

```bash
# Run setup script (clones all repos from GitHub)
./scripts/dev/setup.sh

# This will:
# 1. Check your .env configuration
# 2. Clone all enabled repositories to repos/
# 3. Install dependencies in each repo
# 4. Set up npm registry authentication

# Wait for completion (2-5 minutes)
```

**What gets cloned:**
```
repos/
├── infrastructure/
│   ├── lg-postgres/
│   ├── lg-redis/
│   └── lg-traefik/
├── packages/
│   ├── lg-admin-ui/        # Shared UI components
│   ├── lg-backend-common/  # Shared backend utilities
│   ├── lg-menu-registry/   # Shared menu types
│   └── lg-types/           # Core TypeScript types
├── services/
│   ├── lg-api-keys-service/
│   ├── lg-menu-service/
│   ├── lg-permissions-service/
│   ├── lg-secrets-service/
│   ├── lg-tour-service/
│   └── lg-user-service/
└── ui/
    └── lg-admin/           # Admin UI (Vite)
```

---

### Step 4: Configure Proxy Domains

**Add to `/etc/hosts`:**
```bash
# Edit hosts file
sudo vi /etc/hosts

# Add these lines:
127.0.0.1 admin.lg.local
127.0.0.1 api.lg.local
127.0.0.1 traefik.lg.local
```

**Verify:**
```bash
ping -c 1 admin.lg.local
# Should resolve to 127.0.0.1
```

---

### Step 5: Start Docker Stack

```bash
# Start all services
./scripts/dev/start.sh

# Wait for services to be healthy (1-2 minutes)
# Watch logs:
docker-compose logs -f

# Press Ctrl+C to stop watching logs
```

---

### Step 6: Verify Installation

```bash
# Check service status
./scripts/dev/status.sh

# Should show all services as "Up (healthy)"

# Test endpoints
curl http://api.lg.local/user/health
# Expected: {"status":"healthy","timestamp":"..."}

curl http://api.lg.local/permissions/health
# Expected: {"status":"healthy","timestamp":"..."}

curl http://api.lg.local/v1/health
# Expected: {"status":"healthy","timestamp":"..."}

# Open Admin UI in browser
open http://admin.lg.local

# Open Traefik Dashboard
open http://traefik.lg.local
```

**All green?** ✅ You're ready to develop!

---

## Architecture Tour

### System Overview

**LicenseGuard** is a multi-tenant SaaS platform for managing software licenses, API keys, and user permissions using Role-Based Access Control (RBAC) with organizational units.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      Frontend Layer                          │
├─────────────────────────────────────────────────────────────┤
│  lg-admin (Vite)                                             │
│  - Admin Dashboard                                           │
│  - User Management                                           │
│  - RBAC Configuration                                        │
│  - API Key Management                                        │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP
                     ↓
┌─────────────────────────────────────────────────────────────┐
│                   Traefik (Reverse Proxy)                    │
│  - Routing: /user, /permissions, /v1, etc.                   │
│  - TLS termination                                           │
│  - Load balancing                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┬──────────────┬────────────┐
         ↓                       ↓              ↓            ↓
┌──────────────────┐   ┌──────────────────┐  ┌────────┐  ┌────────┐
│  User Service    │   │ Permissions Svc  │  │ Menu   │  │ Secrets│
│  Port: 3002      │   │ Port: 3003       │  │ 3005   │  │ 3007   │
│  - Auth & JWT    │   │ - RBAC & DAG     │  │        │  │        │
│  - User CRUD     │   │ - Org Units      │  │        │  │        │
└────────┬─────────┘   └────────┬─────────┘  └───┬────┘  └───┬────┘
         │                      │                 │           │
         └──────────────┬───────┴─────────────────┴───────────┘
                        │
                        ↓
            ┌───────────────────────┐
            │   PostgreSQL 16       │
            │   - Shared database   │
            │   - All service data  │
            │   - RBAC DAG table    │
            └───────────────────────┘
```

---

### Service Responsibilities

#### 1. lg-user-service (Port 3002)

**Purpose:** User authentication and management

**Key Features:**
- User registration and login
- JWT token generation
- Password hashing (bcrypt)
- Session management (Redis)
- Last login tracking

**Endpoints:**
- `POST /user/register` - Create new user
- `POST /user/login` - Authenticate user, get JWT
- `GET /user/me` - Get current user (requires auth)
- `PUT /user/me` - Update current user
- `POST /user/logout` - Invalidate session

**Database Tables:**
- `users` - User accounts

---

#### 2. lg-permissions-service (Port 3003)

**Purpose:** Role-Based Access Control (RBAC) with organizational units

**Key Features:**
- Organizational unit hierarchy (DAG)
- Role management
- Permission assignment
- Access control checks
- Closure table for efficient hierarchy queries

**Endpoints:**
- `GET /permissions/rbac/organizational-units` - List org units
- `POST /permissions/rbac/organizational-units` - Create org unit
- `GET /permissions/rbac/roles` - List roles
- `POST /permissions/rbac/roles` - Create role
- `GET /permissions/rbac/permissions` - Check permissions
- `POST /permissions/rbac/check-access` - Verify user has access

**Database Tables:**
- `organizational_units` - Org unit definitions
- `org_unit_closure` - DAG closure table (efficient hierarchy queries)
- `roles` - Role definitions
- `role_permissions` - Permission assignments
- `user_org_unit_roles` - User assignments

**See:** [RBAC.md](./RBAC.md) for detailed documentation

---

#### 3. lg-api-keys-service (Port 3001)

**Purpose:** Public API key validation

**Key Features:**
- API key generation
- API key validation (for public APIs)
- Rate limiting
- Usage tracking

**Endpoints:**
- `POST /v1/keys` - Generate new API key
- `POST /v1/validate` - Validate API key
- `GET /v1/usage` - Get key usage stats

**Database Tables:**
- `api_keys` - API key definitions

---

#### 4. lg-menu-service (Port 3005)

**Purpose:** Hierarchical menu management

**Key Features:**
- Multi-level menu structure
- Permission-based menu filtering
- Parent-child relationships
- Icons and metadata

**Endpoints:**
- `GET /menu` - Get menu tree (filtered by permissions)
- `POST /menu` - Create menu item
- `PUT /menu/:id` - Update menu item
- `DELETE /menu/:id` - Delete menu item

**Database Tables:**
- `menu_items` - Menu definitions

---

#### 5. lg-secrets-service (Port 3007)

**Purpose:** Encrypted secrets management

**Key Features:**
- AES-256 encryption
- Master key encryption
- Secret versioning
- Audit logging

**Endpoints:**
- `POST /secrets` - Store encrypted secret
- `GET /secrets/:id` - Retrieve decrypted secret
- `PUT /secrets/:id` - Update secret
- `DELETE /secrets/:id` - Delete secret

**Database Tables:**
- `secrets` - Encrypted values
- `secret_audit_log` - Access logs

---

### Shared Packages

#### lg-backend-common

**Purpose:** Shared backend utilities

**Exports:**
- `authMiddleware` - JWT authentication
- `errorHandler` - Centralized error handling
- `logger` - Winston logger configuration
- `validateRequest` - Request validation (Zod)
- `corsConfig` - CORS configuration

**Usage:**
```typescript
import { authMiddleware, errorHandler, logger } from '@wolfgangm81/lg-backend-common';

app.use(authMiddleware);
app.use(errorHandler);
logger.info('Service started');
```

---

#### lg-types

**Purpose:** Shared TypeScript types

**Exports:**
```typescript
export interface User {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  createdAt: Date;
  lastLogin?: Date;
}

export interface UserSession {
  userId: string;
  token: string;
  expiresAt: Date;
}

export interface Permission {
  resource: string;
  action: 'create' | 'read' | 'update' | 'delete';
}

export interface OrganizationalUnit {
  id: string;
  name: string;
  parent_id?: string;
  created_by: string;
}
```

---

#### lg-menu-registry

**Purpose:** Menu types and API client

**Exports:**
```typescript
export interface MenuItem {
  id: string;
  label: string;
  path: string;
  icon?: string;
  parent_id?: string;
  permissions?: string[];
}

export class MenuClient {
  async getMenu(userId: string): Promise<MenuItem[]>;
  async createMenuItem(item: MenuItem): Promise<MenuItem>;
  async updateMenuItem(id: string, item: Partial<MenuItem>): Promise<MenuItem>;
  async deleteMenuItem(id: string): Promise<void>;
}
```

---

### Data Flow Example: User Login

```
1. User enters credentials in lg-admin
   ↓
2. lg-admin sends POST /user/login to Traefik
   ↓
3. Traefik routes to lg-user-service:3002
   ↓
4. lg-user-service queries PostgreSQL for user
   ↓
5. lg-user-service verifies password (bcrypt)
   ↓
6. lg-user-service generates JWT token
   ↓
7. lg-user-service stores session in Redis
   ↓
8. lg-user-service updates last_login in PostgreSQL
   ↓
9. lg-user-service returns { user, token } to lg-admin
   ↓
10. lg-admin stores token in localStorage
```

---

### Database Schema Overview

**PostgreSQL Database:** `licenseguard`

**Tables by Service:**

**User Service:**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login TIMESTAMP
);
```

**Permissions Service:**
```sql
CREATE TABLE organizational_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  parent_id UUID REFERENCES organizational_units(id),
  created_by UUID REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE org_unit_closure (
  ancestor_id UUID REFERENCES organizational_units(id),
  descendant_id UUID REFERENCES organizational_units(id),
  depth INTEGER NOT NULL,
  PRIMARY KEY (ancestor_id, descendant_id)
);

CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE role_permissions (
  role_id UUID REFERENCES roles(id),
  resource VARCHAR(100) NOT NULL,
  action VARCHAR(50) NOT NULL,
  PRIMARY KEY (role_id, resource, action)
);

CREATE TABLE user_org_unit_roles (
  user_id UUID REFERENCES users(id),
  org_unit_id UUID REFERENCES organizational_units(id),
  role_id UUID REFERENCES roles(id),
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id, org_unit_id, role_id)
);
```

---

## Development Workflows

### Workflow 1: Add a New API Endpoint

**Scenario:** Add a password reset endpoint to user-service

**Steps:**

1. **Navigate to service:**
   ```bash
   cd repos/services/lg-user-service
   ```

2. **Create new route file:**
   ```bash
   vi src/routes/password-reset.ts
   ```

   ```typescript
   import express from 'express';
   import { validateRequest } from '@wolfgangm81/lg-backend-common';
   import { z } from 'zod';
   import User from '../models/User';
   import { sendEmail } from '../utils/email';

   const router = express.Router();

   const resetSchema = z.object({
     email: z.string().email()
   });

   router.post('/reset-password', validateRequest(resetSchema), async (req, res) => {
     const { email } = req.body;

     // Find user
     const user = await User.findByEmail(email);
     if (!user) {
       // Don't reveal if user exists (security)
       return res.json({ message: 'If account exists, reset email sent' });
     }

     // Generate reset token
     const resetToken = crypto.randomUUID();
     await User.setResetToken(user.id, resetToken);

     // Send email
     await sendEmail({
       to: email,
       subject: 'Password Reset',
       body: `Reset your password: http://admin.lg.local/reset/${resetToken}`
     });

     res.json({ message: 'If account exists, reset email sent' });
   });

   export default router;
   ```

3. **Register route in main server:**
   ```bash
   vi src/server.ts
   ```

   ```typescript
   import passwordResetRoutes from './routes/password-reset';

   // Add route
   app.use('/user', passwordResetRoutes);
   ```

4. **Add tests:**
   ```bash
   vi src/routes/password-reset.test.ts
   ```

   ```typescript
   import request from 'supertest';
   import app from '../server';

   describe('POST /user/reset-password', () => {
     it('should send reset email for valid user', async () => {
       const res = await request(app)
         .post('/user/reset-password')
         .send({ email: 'test@example.com' });

       expect(res.status).toBe(200);
       expect(res.body.message).toContain('reset email sent');
     });

     it('should not reveal if user does not exist', async () => {
       const res = await request(app)
         .post('/user/reset-password')
         .send({ email: 'nonexistent@example.com' });

       expect(res.status).toBe(200);
       expect(res.body.message).toContain('reset email sent');
     });
   });
   ```

5. **Update documentation (CRITICAL!):**
   ```bash
   vi ARCHITECTURE.md
   ```

   Add to API Endpoints table:
   ```markdown
   | POST | /user/reset-password | Send password reset email | None | { email } | 200 | { message } |
   ```

   Add sequence diagram:
   ```mermaid
   sequenceDiagram
     User->>API: POST /user/reset-password
     API->>Database: Find user by email
     API->>Database: Store reset token
     API->>EmailService: Send reset email
     API->>User: 200 OK
   ```

6. **Run tests (in Docker):**
   ```bash
   docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test
   ```

7. **Build and restart service:**
   ```bash
   cd ../../..  # Back to lg-development root
   docker-compose up -d --build user-service
   ```

8. **Test the endpoint:**
   ```bash
   curl -X POST http://api.lg.local/user/reset-password \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com"}'
   ```

9. **Commit changes (code + docs together!):**
   ```bash
   cd repos/services/lg-user-service
   git add src/routes/password-reset.ts
   git add src/routes/password-reset.test.ts
   git add src/server.ts
   git add ARCHITECTURE.md
   git commit -m "feat(user-service): Add password reset endpoint

   - Add POST /user/reset-password endpoint
   - Generate secure reset tokens
   - Send reset email
   - Update ARCHITECTURE.md: API endpoints & sequence diagram
   - Add unit tests (100% coverage)
   "
   git push origin main
   ```

**Time:** ~30-60 minutes

---

### Workflow 2: Add a Shared Package Function

**Scenario:** Add email utility to lg-backend-common

**Steps:**

1. **Navigate to package:**
   ```bash
   cd repos/packages/lg-backend-common
   ```

2. **Add new file:**
   ```bash
   mkdir -p src/utils
   vi src/utils/email.ts
   ```

   ```typescript
   import nodemailer from 'nodemailer';

   interface EmailOptions {
     to: string;
     subject: string;
     body: string;
   }

   export async function sendEmail(options: EmailOptions): Promise<void> {
     const transporter = nodemailer.createTransport({
       host: process.env.SMTP_HOST,
       port: Number(process.env.SMTP_PORT),
       auth: {
         user: process.env.SMTP_USER,
         pass: process.env.SMTP_PASS
       }
     });

     await transporter.sendMail({
       from: process.env.SMTP_FROM,
       to: options.to,
       subject: options.subject,
       html: options.body
     });
   }
   ```

3. **Export from index:**
   ```bash
   vi src/index.ts
   ```

   ```typescript
   export { sendEmail } from './utils/email';
   ```

4. **Add tests:**
   ```bash
   vi src/utils/email.test.ts
   ```

5. **Test locally (in Docker):**
   ```bash
   docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test
   ```

6. **Commit and push (semantic-release will handle versioning):**
   ```bash
   git add src/utils/email.ts
   git add src/utils/email.test.ts
   git add src/index.ts
   git commit -m "feat: Add sendEmail utility

   - Add email sending via nodemailer
   - Support SMTP configuration
   - Add unit tests
   "
   git push origin main
   ```

7. **GitHub Actions will:**
   - Run tests
   - Analyze commit message (`feat:` → minor bump)
   - Bump version (e.g., 1.0.0 → 1.1.0)
   - Publish to GitHub Packages
   - Create GitHub Release

8. **Update consumers (in services):**
   ```bash
   cd ../../services/lg-user-service

   # Update package version
   docker run --rm -v $(pwd):/app -w /app node:20-alpine sh -c "
     npm install @wolfgangm81/lg-backend-common@latest
   "

   # Rebuild service
   cd ../../..
   docker-compose up -d --build user-service
   ```

**Time:** ~20-30 minutes

---

### Workflow 3: Fix a Bug

**Scenario:** User login fails with wrong error message

**Steps:**

1. **Reproduce the bug:**
   ```bash
   curl -X POST http://api.lg.local/user/login \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"wrong"}'

   # Expected: {"error":{"code":"INVALID_CREDENTIALS",...}}
   # Actual: {"error":{"code":"INTERNAL_ERROR",...}}
   ```

2. **Check logs:**
   ```bash
   docker logs -f lg-backend-user
   # Look for stack trace
   ```

3. **Navigate to service:**
   ```bash
   cd repos/services/lg-user-service
   ```

4. **Fix the code:**
   ```bash
   vi src/routes/auth.ts
   ```

   ```typescript
   // Before (wrong):
   if (!user || !bcrypt.compareSync(password, user.password_hash)) {
     throw new Error('Login failed');  // Generic error
   }

   // After (correct):
   if (!user || !bcrypt.compareSync(password, user.password_hash)) {
     return res.status(401).json({
       error: {
         code: 'INVALID_CREDENTIALS',
         message: 'Email or password is incorrect'
       }
     });
   }
   ```

5. **Add test to prevent regression:**
   ```bash
   vi src/routes/auth.test.ts
   ```

   ```typescript
   it('should return INVALID_CREDENTIALS for wrong password', async () => {
     const res = await request(app)
       .post('/user/login')
       .send({ email: 'test@example.com', password: 'wrong' });

     expect(res.status).toBe(401);
     expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
   });
   ```

6. **Run tests:**
   ```bash
   docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test
   ```

7. **Rebuild and test:**
   ```bash
   cd ../../..
   docker-compose up -d --build user-service

   # Test fix
   curl -X POST http://api.lg.local/user/login \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"wrong"}'

   # Should now return: {"error":{"code":"INVALID_CREDENTIALS",...}}
   ```

8. **Commit:**
   ```bash
   cd repos/services/lg-user-service
   git add src/routes/auth.ts
   git add src/routes/auth.test.ts
   git commit -m "fix(user-service): Return correct error code for invalid credentials

   - Return 401 INVALID_CREDENTIALS instead of 500 INTERNAL_ERROR
   - Add test to prevent regression
   - Fixes #123
   "
   git push origin main
   ```

**Time:** ~15-30 minutes

---

### Workflow 4: Enable Hot-Reload for Package Development

**Scenario:** You're iterating on menu-registry types and want instant feedback

**Steps:**

1. **Enable hot-reload:**
   ```bash
   cd ~/Projects/lg-development
   make dev-sync
   ```

2. **Open live dashboard (in separate terminal):**
   ```bash
   make dev-sync-dashboard
   ```

   **Dashboard shows:**
   ```
   📦 Builders:
   lg-builder-menu-registry  Up (healthy)
   lg-builder-backend-common Up (healthy)
   lg-builder-types          Up (healthy)

   📁 Last Build Activity:
     ✅ menu-registry: Found 0 errors. Watching for file changes.
   ```

3. **Edit package:**
   ```bash
   vi repos/packages/lg-menu-registry/src/menu-types.ts
   ```

   Add new field:
   ```typescript
   export interface MenuItem {
     id: string;
     label: string;
     path: string;
     icon?: string;
     parent_id?: string;
     permissions?: string[];
     badge?: string;  // NEW FIELD
   }
   ```

4. **Watch dashboard:**
   ```
   ✅ menu-registry: Found 0 errors. Watching for file changes.
   🔄 menu-service restarting...
   ✅ Done in 2.3s
   ```

5. **Test changes immediately:**
   ```bash
   curl http://api.lg.local/menu/health
   # Service now has updated types!
   ```

6. **When done, disable hot-reload:**
   ```bash
   make dev-normal
   ```

**Time:** Real-time (2-3 second updates)

---

## Common Tasks

### Task 1: Run Tests for a Service

```bash
# Navigate to service
cd repos/services/lg-user-service

# Run all tests (in Docker)
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test

# Run specific test file
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test -- src/routes/auth.test.ts

# Run tests in watch mode
docker run --rm -it -v $(pwd):/app -w /app node:20-alpine npm test -- --watch

# Run with coverage
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm test -- --coverage
```

---

### Task 2: View Service Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f user-service

# Last 100 lines
docker-compose logs --tail=100 user-service

# Since timestamp
docker-compose logs --since 2026-01-25T10:00:00 user-service
```

---

### Task 3: Restart a Service

```bash
# Quick restart (no rebuild)
docker-compose restart user-service

# Rebuild and restart
docker-compose up -d --build user-service

# Force recreate (ignores cache)
docker-compose up -d --build --force-recreate user-service
```

---

### Task 4: Access Database

```bash
# Connect to PostgreSQL
docker exec -it lg-infra-postgres psql -U licenseguard -d licenseguard

# Run SQL query
docker exec lg-infra-postgres psql -U licenseguard -d licenseguard -c "SELECT * FROM users LIMIT 5;"

# Backup database
docker exec lg-infra-postgres pg_dump -U licenseguard licenseguard > backup.sql

# Restore database
cat backup.sql | docker exec -i lg-infra-postgres psql -U licenseguard -d licenseguard
```

---

### Task 5: Access Redis

```bash
# Connect to Redis
docker exec -it lg-infra-redis redis-cli -a changeme

# Inside Redis CLI:
AUTH changeme
PING
KEYS *
GET session:abc123
FLUSHALL  # DANGER: Clears all data!
```

---

### Task 6: Debug Network Issues

```bash
# List networks
docker network ls

# Inspect network
docker network inspect lg-internal

# Test connectivity between services
docker exec lg-backend-user ping postgres
docker exec lg-backend-user curl http://postgres:5432
docker exec lg-backend-user curl http://permissions-service:3003/health
```

---

### Task 7: Clean Up Docker Resources

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (DATA LOSS!)
docker-compose down -v

# Remove all stopped containers
docker container prune

# Remove all unused images
docker image prune -a

# Remove all unused volumes
docker volume prune

# Full cleanup (DANGER!)
docker system prune -a --volumes
```

---

### Task 8: Update Dependencies

```bash
# Update specific package in a service
cd repos/services/lg-user-service
docker run --rm -v $(pwd):/app -w /app node:20-alpine sh -c "
  npm install express@latest
"

# Update all dependencies (careful!)
docker run --rm -v $(pwd):/app -w /app node:20-alpine sh -c "
  npm update
"

# Check for outdated packages
docker run --rm -v $(pwd):/app -w /app node:20-alpine npm outdated
```

---

### Task 9: Create a Database Migration

```bash
cd repos/services/lg-user-service

# Create migration file
docker run --rm -v $(pwd):/app -w /app node:20-alpine npx knex migrate:make add_email_verified_column

# Edit migration
vi migrations/20260125120000_add_email_verified_column.js

exports.up = function(knex) {
  return knex.schema.table('users', table => {
    table.boolean('email_verified').defaultTo(false);
  });
};

exports.down = function(knex) {
  return knex.schema.table('users', table => {
    table.dropColumn('email_verified');
  });
};

# Run migration
docker run --rm -v $(pwd):/app -w /app node:20-alpine npx knex migrate:latest

# Rollback (if needed)
docker run --rm -v $(pwd):/app -w /app node:20-alpine npx knex migrate:rollback
```

---

### Task 10: Check Service Health

```bash
# Check all service health
./scripts/dev/status.sh

# Test individual endpoints
curl http://api.lg.local/user/health
curl http://api.lg.local/permissions/health
curl http://api.lg.local/v1/health
curl http://api.lg.local/menu/health
curl http://api.lg.local/secrets/health

# Check Traefik dashboard
open http://traefik.lg.local
```

---

## Code Conventions & Patterns

### File Structure

**Services:**
```
repos/services/lg-user-service/
├── src/
│   ├── index.ts                # Entry point
│   ├── server.ts               # Express app
│   ├── config/
│   │   └── database.ts         # DB connection
│   ├── models/
│   │   └── User.ts             # Data models
│   ├── routes/
│   │   ├── auth.ts             # /user/login, /user/register
│   │   └── profile.ts          # /user/me
│   ├── middleware/
│   │   └── errorHandler.ts    # Error handling
│   └── utils/
│       └── validators.ts       # Input validation
├── migrations/                  # Database migrations
├── tests/                       # Integration tests
├── Dockerfile
├── package.json
├── tsconfig.json
├── ARCHITECTURE.md             # Service documentation
└── CLAUDE.md                   # AI guidelines
```

**Packages:**
```
repos/packages/lg-backend-common/
├── src/
│   ├── index.ts               # Main export
│   ├── middleware/
│   │   ├── auth.ts
│   │   └── errorHandler.ts
│   ├── utils/
│   │   ├── logger.ts
│   │   └── validators.ts
│   └── types/
│       └── errors.ts
├── tests/
├── package.json
├── tsconfig.json
└── README.md
```

---

### Naming Conventions

**Files:**
- kebab-case: `password-reset.ts`, `user-model.ts`
- Test files: `*.test.ts` or `*.spec.ts`
- Types: `*.types.ts`

**Variables/Functions:**
- camelCase: `getUserById`, `validateEmail`
- Booleans: `isValid`, `hasPermission`

**Classes/Interfaces:**
- PascalCase: `User`, `MenuItem`, `OrganizationalUnit`

**Constants:**
- UPPER_SNAKE_CASE: `JWT_SECRET`, `MAX_LOGIN_ATTEMPTS`

**Database:**
- snake_case: `user_id`, `created_at`, `org_unit_closure`

---

### TypeScript Patterns

**Type Definitions:**
```typescript
// Use interfaces for objects
interface User {
  id: string;
  email: string;
  firstName: string;
}

// Use types for unions/intersections
type UserRole = 'admin' | 'user' | 'guest';
type UserWithPermissions = User & { permissions: string[] };

// Use enums for fixed sets
enum UserStatus {
  Active = 'active',
  Suspended = 'suspended',
  Deleted = 'deleted'
}
```

**Error Handling:**
```typescript
// Use custom error classes
class ValidationError extends Error {
  constructor(message: string, public field: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

// Throw typed errors
if (!email) {
  throw new ValidationError('Email is required', 'email');
}

// Catch and handle
try {
  await createUser(data);
} catch (error) {
  if (error instanceof ValidationError) {
    return res.status(400).json({ error: error.message });
  }
  throw error;  // Re-throw unknown errors
}
```

**Async/Await:**
```typescript
// Use async/await (not callbacks or .then())
async function getUser(id: string): Promise<User> {
  const user = await db.query('SELECT * FROM users WHERE id = $1', [id]);
  return user;
}

// Handle errors with try/catch
async function handleRequest(req: Request, res: Response) {
  try {
    const user = await getUser(req.params.id);
    res.json(user);
  } catch (error) {
    logger.error('Failed to get user', error);
    res.status(500).json({ error: 'Internal server error' });
  }
}
```

---

### Testing Patterns

**Unit Tests:**
```typescript
import { describe, it, expect, beforeEach } from 'vitest';
import User from './User';

describe('User Model', () => {
  beforeEach(() => {
    // Reset database or mocks
  });

  it('should create a new user', async () => {
    const user = await User.create({
      email: 'test@example.com',
      password: 'password123'
    });

    expect(user.id).toBeDefined();
    expect(user.email).toBe('test@example.com');
  });

  it('should hash password before saving', async () => {
    const user = await User.create({
      email: 'test@example.com',
      password: 'password123'
    });

    expect(user.password_hash).not.toBe('password123');
    expect(user.password_hash).toMatch(/^\$2[aby]\$/);  // bcrypt format
  });
});
```

**Integration Tests:**
```typescript
import request from 'supertest';
import app from '../server';

describe('POST /user/login', () => {
  it('should login with valid credentials', async () => {
    // Arrange
    await createTestUser({
      email: 'test@example.com',
      password: 'password123'
    });

    // Act
    const res = await request(app)
      .post('/user/login')
      .send({
        email: 'test@example.com',
        password: 'password123'
      });

    // Assert
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
    expect(res.body.user.email).toBe('test@example.com');
  });
});
```

---

### Git Commit Messages

**Format:** `<type>(<scope>): <subject>`

**Types:**
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Formatting, no code change
- `refactor:` - Code refactoring
- `perf:` - Performance improvement
- `test:` - Add missing tests
- `chore:` - Build/tooling changes

**Examples:**
```bash
git commit -m "feat(user-service): Add password reset endpoint"
git commit -m "fix(permissions): Resolve DAG closure table update issue"
git commit -m "docs(rbac): Update RBAC.md with new examples"
git commit -m "refactor(menu): Simplify menu tree builder"
git commit -m "perf(auth): Cache JWT verification results"
git commit -m "test(api-keys): Add validation tests"
git commit -m "chore(deps): Update TypeScript to 5.3"
```

---

## Troubleshooting

### "Cannot connect to Docker daemon"

**macOS:**
```bash
# Start Docker Desktop
open -a Docker

# Wait for Docker to start (check menu bar icon)
docker ps  # Should work after startup
```

**Linux:**
```bash
# Check if Docker is running
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker

# Check user is in docker group
groups $USER
# Should include 'docker'

# If not, add user to group
sudo usermod -aG docker $USER
newgrp docker
```

---

### "Port already in use"

```bash
# Find process using port
lsof -i :80
lsof -i :3002

# Kill process
kill -9 <PID>

# Or change port in docker-compose.yml
ports:
  - "8080:80"  # Use 8080 instead of 80
```

---

### "admin.lg.local does not resolve"

**Check /etc/hosts:**
```bash
cat /etc/hosts | grep lg.local

# If missing, add:
sudo sh -c "echo '127.0.0.1 admin.lg.local' >> /etc/hosts"
sudo sh -c "echo '127.0.0.1 api.lg.local' >> /etc/hosts"
sudo sh -c "echo '127.0.0.1 traefik.lg.local' >> /etc/hosts"

# Verify
ping -c 1 admin.lg.local
```

---

### "Service health check failing"

**Check logs:**
```bash
docker logs lg-backend-user --tail=50

# Common issues:
# - Database connection failed → Check DATABASE_URL in .env
# - Missing environment variable → Check .env
# - Port conflict → Check docker ps
```

**Check environment variables:**
```bash
docker exec lg-backend-user printenv | grep DATABASE_URL
docker exec lg-backend-user printenv | grep JWT_SECRET
```

**Restart service:**
```bash
docker-compose restart user-service

# Or rebuild:
docker-compose up -d --build --force-recreate user-service
```

---

### "Database connection failed"

**Check PostgreSQL:**
```bash
# Is postgres running?
docker ps | grep postgres

# Check logs
docker logs lg-infra-postgres --tail=20

# Test connection from service
docker exec lg-backend-user sh -c "nc -zv postgres 5432"
# Should output: Connection succeeded
```

**Check credentials:**
```bash
# Verify DATABASE_URL format
# postgres://username:password@host:port/database

# Test connection manually
docker exec lg-infra-postgres psql -U licenseguard -d licenseguard -c "SELECT 1;"
```

---

### "Redis connection refused"

**Check Redis:**
```bash
# Is redis running?
docker ps | grep redis

# Test connection
docker exec lg-infra-redis redis-cli -a changeme PING
# Should output: PONG

# Check from service
docker exec lg-backend-user sh -c "nc -zv redis 6379"
```

---

### "Hot-reload not working"

**Check builder status:**
```bash
make dev-sync-status

# Should show: Up (healthy)
```

**Check for errors:**
```bash
make dev-sync-check

# Should show: ✅ All checks passed
```

**View logs:**
```bash
make dev-sync-logs PACKAGE=menu-registry
```

**Rebuild:**
```bash
make dev-sync-rebuild
```

---

### "Tests failing in CI but passing locally"

**Common causes:**

1. **Different Node version:**
   ```bash
   # Check local version
   docker run --rm node:20-alpine node --version

   # Check CI version in .github/workflows/test.yml
   ```

2. **Missing .env variables:**
   - CI doesn't have your .env file
   - Add secrets to GitHub: Settings → Secrets → Actions

3. **Database state:**
   - Local DB has test data, CI starts fresh
   - Use migrations and seed data

4. **Time zones:**
   - Use UTC in tests: `process.env.TZ = 'UTC'`

---

### "npm package not found" (@wolfgangm81/*)

**Check .npmrc:**
```bash
cd repos/services/lg-user-service
cat .npmrc

# Should contain:
# @wolfgangm81:registry=https://npm.pkg.github.com
# //npm.pkg.github.com/:_authToken=${GITHUB_TOKEN}
```

**Check GitHub token:**
```bash
echo $GITHUB_TOKEN
# Should output: ghp_...
```

**Install package:**
```bash
docker run --rm -v $(pwd):/app -w /app \
  -e GITHUB_TOKEN=$GITHUB_TOKEN \
  node:20-alpine sh -c "
    echo '@wolfgangm81:registry=https://npm.pkg.github.com' > .npmrc
    echo '//npm.pkg.github.com/:_authToken=\${GITHUB_TOKEN}' >> .npmrc
    npm install
  "
```

---

## Resources & Links

### Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Platform architecture
- **[CLAUDE.md](./CLAUDE.md)** - AI development guidelines
- **[DOCKER.md](./DOCKER.md)** - Docker best practices
- **[RBAC.md](./RBAC.md)** - RBAC implementation guide
- **[TESTING.md](./TESTING.md)** - Testing strategy
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Common issues
- **[HOT_RELOAD_QUICK_REF.md](../HOT_RELOAD_QUICK_REF.md)** - Hot-reload reference

### Service Documentation

Each service has its own documentation:
- `repos/services/lg-user-service/ARCHITECTURE.md`
- `repos/services/lg-permissions-service/ARCHITECTURE.md`
- `repos/services/lg-api-keys-service/ARCHITECTURE.md`
- `repos/services/lg-menu-service/ARCHITECTURE.md`
- `repos/services/lg-secrets-service/ARCHITECTURE.md`

### External Resources

**Docker:**
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/)

**Node.js & TypeScript:**
- [Node.js Docs](https://nodejs.org/docs/)
- [TypeScript Handbook](https://www.typescriptlang.org/docs/)
- [Express.js Guide](https://expressjs.com/en/guide/routing.html)

**Database:**
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [Knex.js (Query Builder)](https://knexjs.org/)
- [Redis Commands](https://redis.io/commands)

**Testing:**
- [Vitest](https://vitest.dev/)
- [Supertest (HTTP testing)](https://github.com/ladjs/supertest)

**GitHub:**
- [GitHub Packages](https://docs.github.com/en/packages)
- [GitHub Actions](https://docs.github.com/en/actions)
- [Semantic Release](https://semantic-release.gitbook.io/)

---

## Next Steps

Now that you're set up, here are some great next tasks to get familiar with the codebase:

### Beginner Tasks

1. **Add a new field to the User model**
   - Add `phone_number` field to users table
   - Update User model and types
   - Update API responses
   - Write migration

2. **Add validation to existing endpoint**
   - Add email format validation to `/user/register`
   - Add password strength requirements
   - Write tests

3. **Improve error messages**
   - Find generic error messages
   - Make them more specific
   - Update tests

### Intermediate Tasks

1. **Add a new API endpoint**
   - `GET /user/search?email=...` to search users
   - Requires admin permission
   - Paginated results

2. **Create a new menu item**
   - Add "User Management" menu item
   - Set appropriate permissions
   - Test in admin UI

3. **Add caching to expensive query**
   - Find slow database query
   - Add Redis caching
   - Benchmark improvement

### Advanced Tasks

1. **Implement new RBAC feature**
   - Add "inherit permissions from parent OU"
   - Update DAG closure table
   - Write comprehensive tests

2. **Add new microservice**
   - Create lg-notification-service
   - Handle email/SMS notifications
   - Integrate with existing services

3. **Performance optimization**
   - Profile slow endpoints
   - Optimize database queries
   - Add database indexes

---

## Getting Help

### Stuck on something?

1. **Check documentation first** (this guide, CLAUDE.md, ARCHITECTURE.md)
2. **Search GitHub issues** for similar problems
3. **Check service logs** (`docker logs -f <service>`)
4. **Ask in team chat** (Slack, Discord, etc.)
5. **Create GitHub issue** with:
   - What you're trying to do
   - What you expected
   - What actually happened
   - Steps to reproduce
   - Logs/screenshots

### Common Questions

**Q: Can I use npm instead of pnpm in Docker commands?**
A: Yes! Just replace `pnpm` with `npm` in all Docker commands. However, services use pnpm by default for better disk usage.

**Q: Do I need Node.js installed on my host?**
A: No! All npm/node commands run in Docker containers. But it's convenient to have Node.js for IDE autocompletion.

**Q: Can I work on multiple services at once?**
A: Yes! Each service is in its own repo. Just open multiple terminal windows or use tmux/screen.

**Q: How do I know which service to modify?**
A: Check [ARCHITECTURE.md](./ARCHITECTURE.md) for service responsibilities. Generally:
- User-related → lg-user-service
- Permissions/RBAC → lg-permissions-service
- API keys → lg-api-keys-service
- Menus → lg-menu-service
- Secrets → lg-secrets-service

**Q: What if I break something?**
A: Don't worry! All changes are in git. You can always:
```bash
git reset --hard origin/main  # Reset to last commit
docker-compose down -v        # Reset database
./scripts/dev/start.sh        # Fresh start
```

---

**Welcome aboard! Happy coding! 🎉**

**Questions?** Check the docs or ask the team. We're here to help!

---

**Last Updated:** 2026-01-25
**Next Review:** 2026-02-25
**Maintainer:** Development Team
