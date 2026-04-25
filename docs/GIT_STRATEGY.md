# Git Strategy — Barq Wadih

## Branching Model

We follow a simplified **Git Flow** model with two long-lived branches and short-lived feature branches.

### Long-Lived Branches

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Production-ready code. Deployed to production. | Requires PR + CI pass + 1 approval |
| `develop` | Integration branch. All feature branches merge here first. | Requires PR + CI pass |

### Short-Lived Branches

| Pattern | Example | Purpose |
|---------|---------|---------|
| `feature/sprint-XX-description` | `feature/sprint-02-user-auth` | New feature work |
| `fix/description` | `fix/ad-image-upload-crash` | Bug fixes |
| `hotfix/description` | `hotfix/payment-validation` | Urgent production fixes (branch from `main`) |
| `release/vX.Y.Z` | `release/v1.0.0` | Release preparation |
| `chore/description` | `chore/update-deps` | Maintenance, refactoring |

---

## Workflow

### Feature Development

```
1. git checkout develop
2. git pull origin develop
3. git checkout -b feature/sprint-XX-description
4. ... develop and commit ...
5. git push origin feature/sprint-XX-description
6. Open PR → develop (fill PR template checklist)
7. CI runs → code review → merge
```

### Hotfix (Production Bug)

```
1. git checkout main
2. git checkout -b hotfix/description
3. ... fix and commit ...
4. Open PR → main
5. After merge to main, also merge main → develop
```

### Release

```
1. git checkout develop
2. git checkout -b release/vX.Y.Z
3. Bump version numbers, final testing
4. Open PR → main
5. After merge, tag: git tag -a vX.Y.Z -m "Release vX.Y.Z"
6. Merge main → develop
```

---

## Commit Convention

We enforce **Conventional Commits** via commitlint.

### Format

```
<type>(<scope>): <subject>
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Code style (formatting, semicolons, no logic change) |
| `refactor` | Code restructuring (no feature/fix) |
| `perf` | Performance improvement |
| `test` | Adding/updating tests |
| `chore` | Build, CI, dependencies, tooling |
| `ci` | CI/CD changes |
| `revert` | Reverting a previous commit |

### Scopes

| Scope | Target |
|-------|--------|
| `backend` | Laravel backend |
| `frontend` | Next.js frontend |
| `mobile` | Flutter mobile app |
| `infra` | Docker, CI/CD, deployment |
| `docs` | Documentation |
| `deps` | Dependency updates |

### Examples

```
feat(backend): add user registration endpoint
fix(mobile): resolve dark mode shimmer colors
docs(frontend): update API client usage guide
chore(deps): upgrade Laravel to 12.1
ci(backend): add Larastan to CI pipeline
refactor(mobile): extract bootstrap.dart from main.dart
```

---

## Code Review Guidelines

1. **Every PR must be reviewed** before merging
2. **CI must pass** — no merging with red checks
3. **PR template checklist** must be completed
4. **Squash merge** preferred for feature branches (clean history)
5. **No force-pushing** to `main` or `develop`
6. **Delete branch** after merge

---

## Tags & Versioning

We follow **Semantic Versioning** (SemVer):

```
MAJOR.MINOR.PATCH
```

- **MAJOR**: Breaking API changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

Current: `v0.1.0` (Sprint 1 — Foundation)
