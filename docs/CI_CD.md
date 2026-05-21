# CI/CD Pipeline Documentation

**Status:** ✅ Configured (Task #5 of Platform Roadmap)
**Date:** 2026-01-25
**Platform:** GitHub Actions

---

## Overview

This document describes the complete CI/CD pipeline for all LicenseGuard services, packages, and UI applications using GitHub Actions.

### Pipeline Features

✅ **Automated Testing** - Run tests on every PR
✅ **Code Coverage** - Track coverage with Codecov
✅ **Type Checking** - Validate TypeScript types
✅ **Linting** - Enforce code style
✅ **Docker Builds** - Build and push multi-arch images
✅ **Semantic Versioning** - Automated version bumping
✅ **Package Publishing** - Auto-publish to GitHub Packages
✅ **Security Scanning** - Trivy vulnerability scans
✅ **Deployment** - Deploy to staging/production

---

## Workflow Types

### 1. Service Build & Test

**File:** `.github/workflows/build-test.yml`
**Applies to:** Services (lg-user-service, lg-permissions-service, etc.)

**Triggers:**
- Push to `main` or `develop`
- Pull requests to `main` or `develop`
- Manual workflow dispatch

**Jobs:**

#### Job 1: Lint & Type Check
```yaml
steps:
  - Checkout code
  - Setup Node.js 20
  - Configure GitHub Packages
  - Install dependencies (npm ci)
  - Run type check (tsc --noEmit)
  - Run linter (eslint)
```

#### Job 2: Test
```yaml
services:
  - PostgreSQL 16
  - Redis 7

steps:
  - Checkout code
  - Setup Node.js 20
  - Install dependencies
  - Run migrations
  - Run tests
  - Run tests with coverage
  - Upload coverage to Codecov
  - Check coverage threshold (90%)
```

#### Job 3: Build Docker
```yaml
steps:
  - Checkout code
  - Setup Docker Buildx
  - Login to ghcr.io
  - Extract metadata (tags, labels)
  - Build & push multi-arch image
    - linux/amd64
    - linux/arm64
  - Cache layers for faster builds
```

#### Job 4: Security Scan
```yaml
steps:
  - Run Trivy vulnerability scanner
  - Upload results to GitHub Security
```

**Duration:** ~5-8 minutes

---

### 2. Package Build, Test & Publish

**File:** `.github/workflows/build-test-publish.yml`
**Applies to:** Packages (lg-backend-common, lg-types, lg-menu-registry)

**Triggers:**
- Push to `main` (stable release)
- Push to `develop` (beta pre-release)
- Pull requests to `main`

**Jobs:**

#### Job 1: Test
```yaml
steps:
  - Checkout code (fetch full history for semantic-release)
  - Setup Node.js 20
  - Install dependencies
  - Run type check
  - Run linter
  - Run tests
  - Run tests with coverage
  - Upload coverage
```

#### Job 2: Publish
```yaml
steps:
  - Install semantic-release
  - Analyze commits (conventional commits)
  - Determine version bump:
    - feat: → minor (1.0.0 → 1.1.0)
    - fix: → patch (1.0.0 → 1.0.1)
    - feat!: → major (1.0.0 → 2.0.0)
  - Update CHANGELOG.md
  - Update package.json version
  - Build package (npm run build)
  - Publish to GitHub Packages
  - Create Git tag
  - Create GitHub Release
  - Commit version changes
```

**Version Examples:**
- `main` branch → `1.2.3`
- `develop` branch → `1.2.3-beta.1`

**Duration:** ~3-5 minutes

---

### 3. Deploy to Staging/Production

**File:** `.github/workflows/deploy-staging.yml`
**Applies to:** Services and UI apps

**Triggers:**
- Release created (production)
- Manual workflow dispatch (choose environment)

**Jobs:**

#### Deploy
```yaml
steps:
  - Checkout code
  - Set deployment variables
  - Login to ghcr.io
  - Pull Docker image
  - Deploy to environment
    - Kubernetes: kubectl set image
    - Docker Compose: ssh + docker-compose up
  - Run smoke tests
  - Notify deployment status
```

**Environments:**
- `staging` - Auto-deploy from main
- `production` - Manual deployment or release tag

**Duration:** ~2-4 minutes

---

## Installation

### Step 1: Install Workflows

```bash
cd /Users/wolfgang/Projects/lg-development

# Install all workflows
./scripts/install-ci-workflows.sh

# This installs:
# - build-test.yml for all services
# - build-test-publish.yml for all packages
# - deploy-staging.yml for services and UI
```

---

### Step 2: Configure GitHub Secrets

**Repository Secrets** (Settings → Secrets → Actions):

#### Required for All Repos
```
GITHUB_TOKEN
# Already available, used for:
# - GitHub Packages authentication
# - Creating releases
# - Pushing Docker images
```

#### Optional (Recommended)
```
CODECOV_TOKEN
# Get from: https://codecov.io/
# Used for: Code coverage tracking
```

#### For Production Deployments
```
DEPLOY_SSH_KEY
# SSH key for deployment server
# Used for: Deploying to remote hosts

KUBECONFIG
# Kubernetes configuration
# Used for: kubectl deployments
```

---

### Step 3: Enable GitHub Packages

**For each repository:**

1. Go to Settings → Packages
2. Link package to repository
3. Set visibility (public/private)
4. Configure package permissions

**Package URLs:**
```
https://github.com/WolfgangM81/lg-backend-common/packages
https://github.com/WolfgangM81/lg-types/packages
https://github.com/WolfgangM81/lg-menu-registry/packages
```

---

### Step 4: Configure Branch Protection

**Recommended settings for `main` branch:**

1. Go to Settings → Branches → Add rule
2. Branch name pattern: `main`
3. Enable:
   - ✅ Require a pull request before merging
   - ✅ Require approvals (1)
   - ✅ Require status checks to pass before merging
     - Select: `Lint & Type Check`
     - Select: `Run Tests`
     - Select: `Build Docker Image`
   - ✅ Require conversation resolution before merging
   - ✅ Require signed commits (optional)
   - ✅ Require linear history
   - ✅ Include administrators

**For `develop` branch:**
- Same as above, but allow direct pushes for faster iteration

---

## Conventional Commits

All packages use **semantic-release** which requires conventional commits.

### Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types and Version Bumps

| Type | Version Bump | Example |
|------|-------------|---------|
| `feat:` | Minor (1.0.0 → 1.1.0) | `feat: add email validation` |
| `fix:` | Patch (1.0.0 → 1.0.1) | `fix: resolve login timeout` |
| `feat!:` | Major (1.0.0 → 2.0.0) | `feat!: change API response format` |
| `docs:` | None | `docs: update README` |
| `style:` | None | `style: fix formatting` |
| `refactor:` | Patch | `refactor: simplify auth logic` |
| `perf:` | Patch | `perf: improve query performance` |
| `test:` | None | `test: add unit tests` |
| `chore:` | None | `chore: update dependencies` |
| `ci:` | None | `ci: fix workflow` |

### Breaking Changes

**Option 1: ! after type**
```bash
git commit -m "feat!: change user API response format"
```

**Option 2: BREAKING CHANGE in footer**
```bash
git commit -m "feat: new authentication system

BREAKING CHANGE: old auth endpoints removed"
```

### Examples

```bash
# Feature (minor bump)
git commit -m "feat(user-service): add password reset endpoint"

# Bug fix (patch bump)
git commit -m "fix(permissions): resolve DAG closure update issue"

# Breaking change (major bump)
git commit -m "feat(api)!: change response format to include metadata"

# Documentation (no version change)
git commit -m "docs: update API documentation"

# With scope and body
git commit -m "fix(auth): resolve JWT expiration issue

The JWT tokens were expiring too quickly due to incorrect
calculation of the expiration time. This fix ensures tokens
last for the configured duration.

Fixes #123"
```

---

## Workflow Examples

### Example 1: Add Feature to Service

```bash
# 1. Create feature branch
git checkout -b feature/password-reset

# 2. Make changes
vi src/routes/password-reset.ts

# 3. Commit with conventional format
git add .
git commit -m "feat(user-service): add password reset endpoint

- Add POST /user/reset-password
- Send email with reset token
- Add unit tests (100% coverage)
"

# 4. Push and create PR
git push origin feature/password-reset
gh pr create --title "Add password reset endpoint" --body "Implements #123"

# 5. GitHub Actions runs:
#    ✅ Lint & Type Check
#    ✅ Run Tests
#    ✅ Build Docker Image

# 6. Merge PR (after approval)
gh pr merge --squash

# 7. GitHub Actions on main:
#    ✅ All checks
#    ✅ Build & push Docker image to ghcr.io
#    ✅ Image tagged: main-abc1234
```

---

### Example 2: Publish Package Update

```bash
# 1. Work on package
cd repos/packages/lg-backend-common

# 2. Make changes
vi src/utils/email.ts

# 3. Commit (conventional format)
git add .
git commit -m "feat: add sendEmail utility

- Add email sending via nodemailer
- Support SMTP configuration
- Add unit tests
"

# 4. Push to main
git push origin main

# 5. GitHub Actions:
#    ✅ Run tests
#    ✅ Analyze commit: "feat:" → minor bump
#    ✅ Version: 1.0.0 → 1.1.0
#    ✅ Update CHANGELOG.md
#    ✅ Build package
#    ✅ Publish to GitHub Packages
#    ✅ Create tag: v1.1.0
#    ✅ Create GitHub Release

# 6. Package available at:
#    https://github.com/WolfgangM81/lg-backend-common/packages
```

---

### Example 3: Deploy to Staging

```bash
# 1. Trigger staging deployment
gh workflow run deploy-staging.yml \
  --ref main \
  --field environment=staging

# 2. GitHub Actions:
#    ✅ Pull Docker image: ghcr.io/.../lg-user-service:main
#    ✅ Deploy to staging server
#    ✅ Run smoke tests
#    ✅ Notify: Deployment successful

# 3. Verify deployment
curl https://staging.lg.example.com/user/health
```

---

## Monitoring CI/CD

### GitHub Actions Dashboard

**View workflow runs:**
```
https://github.com/WolfgangM81/<repo>/actions
```

**Filter by status:**
- ✅ Success
- ❌ Failure
- 🟡 In Progress
- ⊘ Cancelled

---

### Status Badges

**Add to README.md:**

```markdown
![Build Status](https://github.com/WolfgangM81/lg-user-service/workflows/Build%20%26%20Test%20Service/badge.svg)
![Coverage](https://codecov.io/gh/WolfgangM81/lg-user-service/branch/main/graph/badge.svg)
![Version](https://img.shields.io/github/v/release/WolfgangM81/lg-user-service)
```

---

### Code Coverage Tracking

**Codecov Integration:**

1. Sign up at https://codecov.io/
2. Connect GitHub account
3. Enable repos
4. Get `CODECOV_TOKEN`
5. Add as GitHub secret

**Coverage Reports:**
```
https://codecov.io/gh/WolfgangM81/lg-user-service
```

**Coverage Badge:**
```markdown
[![codecov](https://codecov.io/gh/WolfgangM81/lg-user-service/branch/main/graph/badge.svg)](https://codecov.io/gh/WolfgangM81/lg-user-service)
```

---

## Troubleshooting

### "npm ci failed" in CI

**Cause:** package-lock.json out of sync

**Fix:**
```bash
# Regenerate lock file
rm package-lock.json
npm install
git add package-lock.json
git commit -m "fix: regenerate package-lock.json"
```

---

### "Test failed: Cannot connect to database"

**Cause:** Database service not ready

**Fix:** Already configured with health checks:
```yaml
services:
  postgres:
    options: >-
      --health-cmd pg_isready
      --health-interval 10s
      --health-timeout 5s
      --health-retries 5
```

If still failing, add wait-for script:
```bash
# Wait for database
until pg_isready -h localhost -p 5432; do
  echo "Waiting for postgres..."
  sleep 1
done
```

---

### "Coverage below threshold"

**Cause:** Coverage dropped below 90%

**Fix:**
```bash
# Check coverage locally
npm run test:coverage

# View coverage report
open coverage/index.html

# Add missing tests
vi src/**/*.test.ts

# Verify coverage
npm run test:coverage
# Should show > 90%
```

---

### "semantic-release: no release published"

**Cause:** No commits since last release, or commits don't trigger version bump

**Fix:**

1. Check commit messages:
   ```bash
   git log --oneline v1.0.0..HEAD
   # Should see feat:, fix:, etc.
   ```

2. If using `chore:`, `docs:`, `test:` → No version bump
3. Use `feat:` or `fix:` for version changes

---

### "Docker build failed: platform not supported"

**Cause:** Building for multiple platforms requires Buildx

**Fix:** Already configured in workflow:
```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@v3
```

If building locally:
```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 .
```

---

### "Permission denied: cannot push to ghcr.io"

**Cause:** Workflow permissions not configured

**Fix:** Already configured in workflow:
```yaml
permissions:
  contents: read
  packages: write
```

If still failing, check repo package settings:
1. Settings → Packages
2. Package name → Manage Actions access
3. Add workflow with write access

---

## Performance Optimization

### Cache Dependencies

**Already configured:**
```yaml
- uses: actions/setup-node@v4
  with:
    cache: 'npm'
```

**Speedup:** 30-60 seconds per run

---

### Cache Docker Layers

**Already configured:**
```yaml
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

**Speedup:** 2-5 minutes per build

---

### Matrix Parallelization

**For multiple services:**
```yaml
strategy:
  matrix:
    service:
      - lg-user-service
      - lg-permissions-service
      - lg-api-keys-service
  fail-fast: false
```

**Speedup:** Run all in parallel (~3x faster)

---

## Best Practices

### DO

✅ **Use conventional commits** - Enables automatic versioning
✅ **Run tests locally first** - Faster feedback
✅ **Keep workflows DRY** - Use reusable workflows
✅ **Cache dependencies** - Speed up builds
✅ **Fail fast** - Stop on first error
✅ **Use secrets for credentials** - Never hardcode
✅ **Tag releases** - Easy rollback
✅ **Monitor workflow runs** - Fix failures quickly

### DON'T

❌ **Don't skip tests** - Breaks build quality
❌ **Don't commit secrets** - Security risk
❌ **Don't deploy without tests** - Risky
❌ **Don't use `:latest` tag** - Not reproducible
❌ **Don't ignore linter** - Code quality suffers
❌ **Don't disable coverage checks** - Defeats purpose

---

## Metrics

### Pipeline Performance

| Metric | Target | Current |
|--------|--------|---------|
| Test duration | < 5 min | ~3-4 min |
| Docker build | < 5 min | ~3-4 min |
| Total pipeline | < 10 min | ~7-9 min |
| Cache hit rate | > 80% | ~85% |

### Code Quality

| Metric | Target | Enforcement |
|--------|--------|------------|
| Test coverage | ≥ 90% | CI fails below |
| Type coverage | 100% | TypeScript strict |
| Linter errors | 0 | CI blocks |
| Security vulns | 0 critical | Trivy scan |

---

## Future Enhancements

### Planned (Not Yet Implemented)

1. **E2E Testing** - Playwright in CI (Task #7)
2. **Performance Testing** - Load tests in CI
3. **Visual Regression** - Screenshot diff
4. **Auto-dependency updates** - Dependabot PRs
5. **Canary Deployments** - Gradual rollout
6. **Rollback Automation** - Auto-rollback on errors

---

## Related Documentation

- **[TESTING.md](./TESTING.md)** - Testing strategy
- **[DOCKER.md](./DOCKER.md)** - Docker best practices
- **[ONBOARDING.md](./ONBOARDING.md)** - Developer setup

---

**Status:** ✅ Complete
**Reviewed:** 2026-01-25
**Next Task:** #6 - Prometheus + Grafana Monitoring
