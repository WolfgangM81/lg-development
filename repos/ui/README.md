# Frontend Applications

This directory contains frontend applications for the LicenseGuard platform.

---

## Applications Overview

| Application | Purpose | Technology | Port | Status |
|-------------|---------|------------|------|--------|
| [lg-admin](./lg-admin/) | Admin dashboard & management | Vite + React | 3000 | ✅ Active |

---

## Architecture

### lg-admin

**Technology Stack:**
- React 18
- Vite (build tool)
- TypeScript
- React Router
- lg-admin-ui (shared components)
- lg-types (type definitions)

**Features:**
- Single Page Application (SPA)
- JWT-based authentication
- Role-based UI rendering
- Real-time updates
- Responsive design

---

## Access URLs

### Development (Local)

| Application | URL | Proxy Domain |
|-------------|-----|--------------|
| Admin UI | `http://localhost:3000` | `http://admin.lg.local` |

**Note:** Proxy domain requires `/etc/hosts` configuration. See [PROXY_DOMAINS.md](../../PROXY_DOMAINS.md)

---

## Development Workflow

### Start Application

```bash
# From project root
cd /Users/wolfgang/Projects/lg-development
./scripts/dev/start.sh

# Or start admin UI only
docker-compose up -d admin
```

### Work on Application

```bash
# Navigate to app
cd repos/ui/lg-admin

# Make changes
vi src/pages/Dashboard.tsx

# Rebuild and restart (from project root)
cd /Users/wolfgang/Projects/lg-development
docker-compose up -d --build admin

# View logs
docker logs -f lg-frontend-admin

# Test changes
open http://admin.lg.local
```

### Run Tests

```bash
cd repos/ui/lg-admin
npm test
```

### Build for Production

```bash
cd repos/ui/lg-admin
npm run build

# Output in dist/
```

---

## Directory Structure

```
lg-admin/
├── src/
│   ├── App.tsx                # Main application component
│   ├── main.tsx               # Entry point
│   ├── pages/                 # Page components
│   │   ├── Dashboard.tsx
│   │   ├── Users.tsx
│   │   └── Settings.tsx
│   ├── components/            # Reusable components
│   │   ├── Header.tsx
│   │   ├── Sidebar.tsx
│   │   └── Footer.tsx
│   ├── hooks/                 # Custom React hooks
│   │   ├── useAuth.ts
│   │   └── useAPI.ts
│   ├── utils/                 # Utility functions
│   │   ├── api.ts            # API client
│   │   └── auth.ts           # Auth helpers
│   ├── styles/               # Global styles
│   └── types/                # Local type definitions
├── public/                   # Static assets
├── tests/                    # Unit & integration tests
├── Dockerfile               # Container build
├── vite.config.ts           # Vite configuration
├── package.json             # Dependencies
├── CLAUDE.md               # AI development guidelines
└── README.md               # Application documentation
```

---

## Routing

### Client-Side Routes

| Route | Component | Description |
|-------|-----------|-------------|
| `/` | Dashboard | Main dashboard |
| `/users` | Users | User management |
| `/roles` | Roles | Role management |
| `/permissions` | Permissions | Permission management |
| `/menu` | Menu | Menu configuration |
| `/api-keys` | API Keys | API key management |
| `/secrets` | Secrets | Secret management |
| `/tours` | Tours | Guided tours |
| `/settings` | Settings | Application settings |
| `/login` | Login | Authentication |

---

## State Management

### Authentication State

```typescript
// useAuth hook
const { user, isAuthenticated, login, logout } = useAuth();
```

### API State

```typescript
// useAPI hook
const { data, loading, error } = useAPI('/api/users');
```

---

## Shared Components

The admin UI uses shared components from `lg-admin-ui` package:

```typescript
import { Button, Input, Table, Modal } from '@wolfgangm81/lg-admin-ui';
```

---

## API Integration

### API Client

```typescript
// utils/api.ts
const apiClient = {
  get: (url: string) => fetch(`http://api.lg.local${url}`),
  post: (url: string, data: any) => fetch(`http://api.lg.local${url}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }),
  // ...
};
```

### Authentication

```typescript
// utils/auth.ts
const authToken = localStorage.getItem('authToken');

// Include in API requests
fetch('/api/users', {
  headers: {
    'Authorization': `Bearer ${authToken}`
  }
});
```

---

## Styling

### Theme System

Uses `lg-admin-ui` theme provider:

```typescript
import { ThemeProvider } from '@wolfgangm81/lg-admin-ui';

function App() {
  return (
    <ThemeProvider>
      {/* Application content */}
    </ThemeProvider>
  );
}
```

### Custom Styles

```typescript
// Tailwind CSS (if used)
import './styles/tailwind.css';

// Or custom CSS modules
import styles from './Dashboard.module.css';
```

---

## Environment Variables

### Development

```env
VITE_API_URL=http://api.lg.local
VITE_AUTH_DOMAIN=admin.lg.local
```

### Production

```env
VITE_API_URL=https://api.licenseguard.com
VITE_AUTH_DOMAIN=admin.licenseguard.com
```

---

## Testing

### Unit Tests

```bash
npm test
```

### E2E Tests

```bash
# Run Playwright tests (from project root)
cd repos/infrastructure/lg-e2e-tests
npm run test
```

---

## Build & Deployment

### Development Build

```bash
npm run dev
```

### Production Build

```bash
npm run build

# Output: dist/
```

### Docker Build

```bash
# From project root
docker-compose build admin
docker-compose up -d admin
```

---

## Performance

### Code Splitting

Vite automatically code-splits routes:

```typescript
const Dashboard = lazy(() => import('./pages/Dashboard'));
const Users = lazy(() => import('./pages/Users'));
```

### Bundle Size

```bash
npm run build

# View bundle size analysis
npm run build -- --mode analyze
```

---

## Troubleshooting

### "API request failed"

**Problem:** Cannot connect to backend services

**Solution:**
1. Check backend services are running:
   ```bash
   docker-compose ps
   ```

2. Verify API URL in `.env`:
   ```
   VITE_API_URL=http://api.lg.local
   ```

3. Check `/etc/hosts`:
   ```
   127.0.0.1 api.lg.local
   ```

---

### "Authentication failed"

**Problem:** Login not working

**Solution:**
1. Check user service is running:
   ```bash
   docker logs lg-backend-user
   ```

2. Verify JWT token is stored:
   ```javascript
   console.log(localStorage.getItem('authToken'));
   ```

3. Check token expiration

---

### "Hot reload not working"

**Problem:** Changes not reflected in browser

**Solution:**
```bash
# Restart Vite dev server
docker-compose restart admin

# Or rebuild
docker-compose up -d --build admin
```

---

## Documentation

Each application has:
- **README.md** - User-facing documentation
- **CLAUDE.md** - AI assistant guidelines

---

## Related Documentation

- [System Architecture](../../docs/ARCHITECTURE.md)
- [Package Dependencies](../../docs/DEPENDENCIES.md)
- [Docker Setup](../../docs/DOCKER.md)
- [Proxy Domains](../../PROXY_DOMAINS.md)

---

**Total Applications:** 1
**Technology Stack:** React, Vite, TypeScript
**Deployment:** Docker Compose (local), CDN + S3 (production - future)
