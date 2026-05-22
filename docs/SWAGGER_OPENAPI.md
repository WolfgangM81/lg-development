# OpenAPI/Swagger Documentation Guide

**Status:** ✅ Configured (Task #4 of Platform Roadmap)
**Date:** 2026-01-25
**Documentation Standard:** OpenAPI 3.0.0

---

## Overview

This guide explains how to add and maintain OpenAPI/Swagger documentation for all LicenseGuard services.

### Benefits

✅ **Self-documenting APIs** - Documentation stays in sync with code
✅ **Interactive testing** - Try endpoints directly in browser
✅ **Type safety** - OpenAPI spec can generate TypeScript types
✅ **Client generation** - Auto-generate API clients for frontend
✅ **Contract testing** - Validate requests/responses against spec

---

## Quick Start

### 1. Install Swagger for All Services

```bash
cd /Users/wolfgang/Projects/lg-development

# Run automated setup
./scripts/setup-swagger.sh

# This installs:
# - swagger-jsdoc (generates OpenAPI spec from JSDoc comments)
# - swagger-ui-express (serves interactive Swagger UI)
```

---

### 2. Add setupSwagger to server.ts

**Edit each service's `src/server.ts`:**

```typescript
import express from 'express';
import { setupSwagger } from './swagger';  // ADD THIS

const app = express();

// ... other middleware ...

// Add Swagger documentation
if (process.env.NODE_ENV !== 'production') {
  setupSwagger(app);  // ADD THIS
}

// ... routes ...

export default app;
```

**Why the production check?**
- Swagger UI can expose sensitive info
- Only enable in development/staging

---

### 3. Document Routes

**Use JSDoc comments with `@swagger` tag:**

```typescript
/**
 * @swagger
 * /user/login:
 *   post:
 *     summary: Login user
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - email
 *               - password
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 user:
 *                   $ref: '#/components/schemas/User'
 *                 token:
 *                   type: string
 *       401:
 *         description: Invalid credentials
 */
router.post('/login', async (req, res) => {
  // Implementation
});
```

---

### 4. Rebuild and Test

```bash
# Rebuild services
docker-compose up -d --build

# Access Swagger UI
open http://api.lg.local/user/api-docs          # User Service
open http://api.lg.local/permissions/api-docs   # Permissions Service
open http://api.lg.local/v1/api-docs            # API Keys Service
open http://api.lg.local/menu/api-docs          # Menu Service
open http://api.lg.local/secrets/api-docs       # Secrets Service
```

---

## OpenAPI Annotation Patterns

### Basic GET Endpoint

```typescript
/**
 * @swagger
 * /user/{id}:
 *   get:
 *     summary: Get user by ID
 *     description: Retrieve a user's profile by their unique identifier
 *     tags:
 *       - User
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *         description: User ID
 *       - in: query
 *         name: include
 *         schema:
 *           type: string
 *           enum: [permissions, roles, orgUnits]
 *         description: Additional data to include
 *     responses:
 *       200:
 *         description: User found
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/User'
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 */
```

---

### POST with Request Body

```typescript
/**
 * @swagger
 * /permissions/rbac/organizational-units:
 *   post:
 *     summary: Create organizational unit
 *     description: Create a new organizational unit in the hierarchy
 *     tags:
 *       - RBAC
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *                 minLength: 1
 *                 maxLength: 100
 *                 example: Engineering Department
 *               parent_id:
 *                 type: string
 *                 format: uuid
 *                 nullable: true
 *                 example: 550e8400-e29b-41d4-a716-446655440000
 *               description:
 *                 type: string
 *                 example: Software engineering teams
 *     responses:
 *       201:
 *         description: Organizational unit created
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/OrganizationalUnit'
 *       400:
 *         $ref: '#/components/responses/ValidationError'
 *       409:
 *         description: Organizational unit already exists
 */
```

---

### PUT/PATCH Update

```typescript
/**
 * @swagger
 * /menu/{id}:
 *   put:
 *     summary: Update menu item
 *     tags:
 *       - Menu
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               label:
 *                 type: string
 *               path:
 *                 type: string
 *               icon:
 *                 type: string
 *               parent_id:
 *                 type: string
 *                 format: uuid
 *                 nullable: true
 *     responses:
 *       200:
 *         description: Menu item updated
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/MenuItem'
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 */
```

---

### DELETE Endpoint

```typescript
/**
 * @swagger
 * /secrets/{id}:
 *   delete:
 *     summary: Delete secret
 *     description: Permanently delete an encrypted secret
 *     tags:
 *       - Secrets
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: path
 *         name: id
 *         required: true
 *         schema:
 *           type: string
 *           format: uuid
 *     responses:
 *       204:
 *         description: Secret deleted successfully
 *       404:
 *         $ref: '#/components/responses/NotFoundError'
 *       403:
 *         $ref: '#/components/responses/ForbiddenError'
 */
```

---

### Array Responses

```typescript
/**
 * @swagger
 * /permissions/rbac/roles:
 *   get:
 *     summary: List all roles
 *     tags:
 *       - RBAC
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - in: query
 *         name: page
 *         schema:
 *           type: integer
 *           minimum: 1
 *           default: 1
 *       - in: query
 *         name: limit
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 20
 *     responses:
 *       200:
 *         description: List of roles
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: array
 *                   items:
 *                     $ref: '#/components/schemas/Role'
 *                 pagination:
 *                   type: object
 *                   properties:
 *                     page:
 *                       type: integer
 *                     limit:
 *                       type: integer
 *                     total:
 *                       type: integer
 */
```

---

## Defining Reusable Schemas

**In route files or separate schema file:**

```typescript
/**
 * @swagger
 * components:
 *   schemas:
 *     User:
 *       type: object
 *       required:
 *         - id
 *         - email
 *         - firstName
 *         - lastName
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         email:
 *           type: string
 *           format: email
 *         firstName:
 *           type: string
 *         lastName:
 *           type: string
 *         createdAt:
 *           type: string
 *           format: date-time
 *         lastLogin:
 *           type: string
 *           format: date-time
 *           nullable: true
 *
 *     OrganizationalUnit:
 *       type: object
 *       required:
 *         - id
 *         - name
 *       properties:
 *         id:
 *           type: string
 *           format: uuid
 *         name:
 *           type: string
 *         parent_id:
 *           type: string
 *           format: uuid
 *           nullable: true
 *         created_by:
 *           type: string
 *           format: uuid
 *         created_at:
 *           type: string
 *           format: date-time
 */
```

---

## Authentication Documentation

### JWT Bearer Token

**Already configured in swagger-setup.ts:**

```yaml
securitySchemes:
  bearerAuth:
    type: http
    scheme: bearer
    bearerFormat: JWT
```

**Use in routes:**

```typescript
/**
 * @swagger
 * /user/me:
 *   get:
 *     security:
 *       - bearerAuth: []
 *     # ... rest of spec
 */
```

**To test in Swagger UI:**
1. Go to http://api.lg.local/user/api-docs
2. Click "Authorize" button (top-right)
3. Enter: `Bearer <your-jwt-token>`
4. Click "Authorize"
5. Now all requests include the token

---

### Internal API Key

```typescript
/**
 * @swagger
 * /internal/users:
 *   get:
 *     security:
 *       - internalApiKey: []
 *     # ... rest of spec
 */
```

---

## Common Response Schemas

**Already defined in swagger-setup.ts:**

```yaml
responses:
  UnauthorizedError:    # 401
  ForbiddenError:       # 403
  NotFoundError:        # 404
  ValidationError:      # 400
  InternalError:        # 500
```

**Usage:**

```typescript
/**
 * @swagger
 * /user/me:
 *   get:
 *     responses:
 *       200:
 *         # ... success response
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/InternalError'
 */
```

---

## Tags for Organization

**Group endpoints by feature:**

```typescript
/**
 * @swagger
 * tags:
 *   - name: Authentication
 *     description: User login and registration
 *   - name: User
 *     description: User profile management
 *   - name: RBAC
 *     description: Role-based access control
 *   - name: Health
 *     description: Service health checks
 */
```

**Then use in routes:**

```typescript
/**
 * @swagger
 * /user/login:
 *   post:
 *     tags:
 *       - Authentication
 */
```

---

## Examples and Descriptions

### Add Examples

```typescript
/**
 * @swagger
 * /user/register:
 *   post:
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *                 example: user@example.com
 *               password:
 *                 type: string
 *                 example: SecurePass123!
 *           examples:
 *             validUser:
 *               summary: Valid registration
 *               value:
 *                 email: john.doe@example.com
 *                 password: MySecurePassword123!
 *                 firstName: John
 *                 lastName: Doe
 *             invalidEmail:
 *               summary: Invalid email format
 *               value:
 *                 email: not-an-email
 *                 password: password123
 */
```

---

### Add Rich Descriptions

```typescript
/**
 * @swagger
 * /permissions/rbac/check-access:
 *   post:
 *     summary: Check user access
 *     description: |
 *       Verify if a user has permission to perform an action on a resource.
 *
 *       This endpoint checks:
 *       1. User's direct role permissions
 *       2. Inherited permissions from parent organizational units
 *       3. System-wide permissions
 *
 *       ### Permission Format
 *       Permissions are defined as `resource:action`, where:
 *       - **resource**: The object being accessed (e.g., `users`, `documents`)
 *       - **action**: The operation (e.g., `create`, `read`, `update`, `delete`)
 *
 *       ### Examples
 *       - `users:create` - Can create users
 *       - `documents:read` - Can read documents
 *       - `*:*` - Full admin access
 */
```

---

## Accessing Swagger UI

### Individual Services

| Service | Swagger UI URL | OpenAPI JSON |
|---------|---------------|--------------|
| User Service | http://api.lg.local/user/api-docs | http://api.lg.local/user/api-docs.json |
| Permissions | http://api.lg.local/permissions/api-docs | http://api.lg.local/permissions/api-docs.json |
| API Keys | http://api.lg.local/v1/api-docs | http://api.lg.local/v1/api-docs.json |
| Menu | http://api.lg.local/menu/api-docs | http://api.lg.local/menu/api-docs.json |
| Secrets | http://api.lg.local/secrets/api-docs | http://api.lg.local/secrets/api-docs.json |

---

### Direct Service Access (No Proxy)

```bash
# User Service
open http://localhost:3002/api-docs

# Permissions Service
open http://localhost:3003/api-docs

# API Keys Service
open http://localhost:3001/api-docs
```

---

## Swagger Aggregator (Optional)

**Create a unified dashboard showing all services:**

```bash
./scripts/create-swagger-aggregator.sh
```

**Access aggregator:**
```bash
open http://api.lg.local/docs
```

**Shows:**
- Links to all service Swagger UIs
- Combined OpenAPI spec
- Service health status

---

## Best Practices

### DO

✅ **Document all public endpoints** - Every route should have @swagger comments
✅ **Include examples** - Show valid request/response examples
✅ **Use $ref for reuse** - Define schemas once, reference everywhere
✅ **Add descriptions** - Explain what endpoints do and when to use them
✅ **Document errors** - Show all possible error responses
✅ **Version your API** - Include version in info.version
✅ **Test in Swagger UI** - Use "Try it out" to verify examples work
✅ **Keep it updated** - Update docs when code changes

### DON'T

❌ **Don't hardcode URLs** - Use server definitions
❌ **Don't expose internal endpoints** - Only document public APIs
❌ **Don't skip error responses** - Document all status codes
❌ **Don't use inline schemas everywhere** - Extract to components/schemas
❌ **Don't commit secrets** - No API keys or tokens in examples
❌ **Don't enable in production** - Use NODE_ENV check
❌ **Don't forget authentication** - Document security requirements

---

## Documentation Maintenance

### When to Update Swagger Docs

**Update documentation when:**
1. ✅ Adding a new endpoint
2. ✅ Changing request/response format
3. ✅ Adding/removing parameters
4. ✅ Changing authentication requirements
5. ✅ Adding new error responses
6. ✅ Deprecating endpoints

### Documentation Review Checklist

Before merging code:
- [ ] All new endpoints documented
- [ ] Request/response examples provided
- [ ] Error responses documented
- [ ] Authentication requirements specified
- [ ] Swagger UI tested ("Try it out" works)
- [ ] OpenAPI spec validates (no errors in console)

---

## Troubleshooting

### "Swagger UI shows no endpoints"

**Check:**
```bash
# View OpenAPI JSON
curl http://api.lg.local/user/api-docs.json | jq .

# Should show paths:
# {
#   "openapi": "3.0.0",
#   "paths": {
#     "/user/login": { ... },
#     "/user/register": { ... }
#   }
# }
```

**If empty paths:**
1. Check `apis` configuration in swagger.ts points to route files
2. Ensure @swagger comments are above routes
3. Rebuild service: `docker-compose up -d --build user-service`

---

### "Cannot find module 'swagger-jsdoc'"

```bash
# Reinstall dependencies
cd repos/services/lg-user-service
docker run --rm -v $(pwd):/app -w /app node:20-alpine sh -c "
  npm install swagger-jsdoc swagger-ui-express
"
```

---

### "Syntax error in OpenAPI spec"

**View errors in console:**
```bash
docker logs lg-backend-user | grep swagger
```

**Common issues:**
- Missing required fields (summary, responses)
- Invalid YAML in @swagger comments
- Incorrect indentation
- Missing closing quotes

**Validate OpenAPI spec:**
```bash
# Use online validator
curl http://api.lg.local/user/api-docs.json > openapi.json
# Upload to: https://editor.swagger.io/
```

---

### "Authentication not working in Swagger UI"

**Check security scheme:**
```typescript
// In swagger.ts
securitySchemes: {
  bearerAuth: {
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'JWT'
  }
}
```

**In route:**
```typescript
/**
 * @swagger
 * /user/me:
 *   get:
 *     security:
 *       - bearerAuth: []
 */
```

**To test:**
1. Login via Swagger UI (`/user/login`)
2. Copy token from response
3. Click "Authorize" → Enter `Bearer <token>`
4. Try protected endpoint

---

## Integration with CI/CD

### Validate OpenAPI Spec in CI

**Add to `.github/workflows/test.yml`:**

```yaml
- name: Validate OpenAPI spec
  run: |
    npm install -g @apidevtools/swagger-cli
    swagger-cli validate src/swagger.ts
```

---

### Generate TypeScript Types from OpenAPI

```bash
# Install openapi-typescript
npm install -D openapi-typescript

# Generate types
npx openapi-typescript http://api.lg.local/user/api-docs.json -o types/user-api.ts
```

**Use in frontend:**
```typescript
import type { paths } from './types/user-api';

type LoginRequest = paths['/user/login']['post']['requestBody']['content']['application/json'];
type LoginResponse = paths['/user/login']['post']['responses']['200']['content']['application/json'];
```

---

## Next Steps

After setting up Swagger:

1. **Document all endpoints** - Add @swagger comments to all routes
2. **Test interactively** - Use Swagger UI to test each endpoint
3. **Generate client** - Auto-generate frontend API client from spec
4. **Contract testing** - Validate API responses match OpenAPI spec
5. **API versioning** - Plan for API v2 when needed

**Related Tasks:**
- Task #5: CI/CD will validate OpenAPI specs
- Task #8: Test coverage should include Swagger examples

---

**Status:** ✅ Complete
**Reviewed:** 2026-01-25
**Next Task:** #5 - GitHub Actions CI/CD Pipeline
