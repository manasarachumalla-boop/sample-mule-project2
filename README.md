# hello-world-api

A sample MuleSoft 4 Hello World REST API with a complete CI/CD pipeline for automated deployment to **CloudHub 2.0 Sandbox** via GitHub Actions.

---

## Table of Contents

- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Local Run Steps](#local-run-steps)
- [Running MUnit Tests](#running-munit-tests)
- [GitHub Actions Setup](#github-actions-setup)
- [GitHub Secrets Setup](#github-secrets-setup)
- [Deployment Flow](#deployment-flow)
- [Feature Branch Deployment Behaviour](#feature-branch-deployment-behaviour)
- [API Reference](#api-reference)
- [Configuration Properties](#configuration-properties)

---

## Project Structure

```
hello-world-api/
├── .github/
│   └── workflows/
│       └── deploy-feature.yml        # GitHub Actions CI/CD pipeline
├── src/
│   ├── main/
│   │   ├── mule/
│   │   │   ├── global.xml            # Shared config: HTTP listener, error handler, property placeholder
│   │   │   └── hello-world-api.xml   # Main flow: GET /hello
│   │   └── resources/
│   │       ├── config-local.yaml     # Local development configuration
│   │       ├── config-sandbox.yaml   # CloudHub 2.0 Sandbox configuration
│   │       └── log4j2.xml            # Logging configuration
│   └── test/
│       ├── munit/
│       │   └── hello-world-api-test-suite.xml  # MUnit tests
│       └── resources/
│           └── log4j2-test.xml       # Logging config for MUnit runs
├── mule-artifact.json                # Mule runtime metadata
├── pom.xml                           # Maven build descriptor with Mule Maven Plugin
└── README.md
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Java (JDK) | 17 |
| Maven | 3.9+ |
| Anypoint Studio *(optional)* | 7.x |
| Mule Runtime | 4.6.0 |

Ensure Maven is configured with access to MuleSoft repositories. See [Maven settings](#github-actions-setup) for details.

---

## Local Run Steps

### 1. Clone the repository

```bash
git clone https://github.com/<your-org>/hello-world-api.git
cd hello-world-api
```

### 2. Configure Maven settings

Add the following server entries to `~/.m2/settings.xml` (or use the included `settings.xml`):

```xml
<servers>
  <server>
    <id>anypoint-exchange-v3</id>
    <username>~~~Client~~~</username>
    <password>YOUR_CLIENT_ID~?~YOUR_CLIENT_SECRET</password>
  </server>
  <server>
    <id>mulesoft-releases</id>
    <username>~~~Client~~~</username>
    <password>YOUR_CLIENT_ID~?~YOUR_CLIENT_SECRET</password>
  </server>
</servers>
```

Replace `YOUR_CLIENT_ID` and `YOUR_CLIENT_SECRET` with credentials from an **Anypoint Connected App** (Platform > Access Management > Connected Apps).

### 3. Build the application

```bash
mvn clean package -DskipTests -Dmule.env=local
```

### 4. Run locally with the Mule Maven Plugin

```bash
mvn mule:run -Dmule.env=local
```

The API will start on `http://localhost:8081`.

### 5. Test the endpoint

```bash
curl -i http://localhost:8081/hello
```

Expected response:

```json
{
  "message": "Hello World from MuleSoft"
}
```

---

## Running MUnit Tests

```bash
mvn clean test -Dmule.env=local
```

Coverage reports are generated at:

```
target/site/munit/coverage/
```

To skip coverage reporting:

```bash
mvn clean test -Dmule.env=local -Dmunit.coverage.runCoverage=false
```

---

## GitHub Actions Setup

The workflow file is located at `.github/workflows/deploy-feature.yml`.

### Pipeline Jobs

| Job | Trigger | What it does |
|-----|---------|--------------|
| `build-and-test` | Every push to `feature/**` | Compiles the app and runs all MUnit tests |
| `deploy` | After `build-and-test` passes, direct push only | Packages and deploys to CloudHub 2.0 Sandbox |

### Pipeline Steps (deploy job)

1. Checkout code
2. Set up Java 17 (Temurin)
3. Restore Maven dependency cache
4. Configure Maven `settings.xml` with Anypoint credentials from GitHub Secrets
5. Derive a CloudHub-safe application name from the branch name
6. Run `mvn deploy` with the Mule Maven Plugin CloudHub 2.0 goal
7. Write a deployment summary to the GitHub Actions job summary

---

## GitHub Secrets Setup

Navigate to your repository on GitHub: **Settings → Secrets and variables → Actions → New repository secret**

| Secret name | Description |
|-------------|-------------|
| `ANYPOINT_CLIENT_ID` | Client ID of an Anypoint Connected App with CloudHub deployment permissions |
| `ANYPOINT_CLIENT_SECRET` | Client Secret of the same Connected App |

### Creating an Anypoint Connected App

1. Log in to [Anypoint Platform](https://anypoint.mulesoft.com)
2. Go to **Access Management → Connected Apps → Create app**
3. Select **App acts on its own behalf (client credentials)**
4. Assign scopes:
   - `CloudHub Network Administrator` (or `Viewer`) on the target business group
   - `Exchange Contributor` (to pull assets during build)
5. Copy the generated **Client ID** and **Client Secret** into GitHub Secrets

---

## Deployment Flow

```
Developer pushes to feature/* branch
          │
          ▼
GitHub Actions triggered (push event)
          │
          ▼
┌─────────────────────────────────┐
│  Job: build-and-test            │
│  1. mvn clean test              │
│  2. Upload coverage report      │
└──────────────┬──────────────────┘
               │ (passes)
               ▼
┌─────────────────────────────────┐
│  Job: deploy                    │
│  1. Sanitise branch → app name  │
│  2. mvn deploy (skip tests)     │
│  3. Write deployment summary    │
└─────────────────────────────────┘
          │
          ▼
Application running in CloudHub 2.0 Sandbox
```

### Rollback / Redeployment

- **Redeploy**: Re-push to the same feature branch. The Mule Maven Plugin will redeploy the existing CloudHub application with the latest artefact.
- **Rollback**: Check out a previous commit and push to the branch, or re-tag and push. The pipeline will redeploy that revision.
- **Manual redeployment**: From Anypoint Runtime Manager, select the application and click **Redeploy**.

---

## Feature Branch Deployment Behaviour

Each feature branch deploys as a **separate named application** in CloudHub 2.0 Sandbox. This allows multiple feature branches to coexist simultaneously without overwriting each other.

### Naming convention

| Branch name | CloudHub app name |
|-------------|-------------------|
| `feature/login` | `hello-world-api-feature-login` |
| `feature/user-profile` | `hello-world-api-feature-user-profile` |
| `feature/MY_FEATURE` | `hello-world-api-feature-my-feature` |

### Sanitisation rules applied

1. Convert to lowercase
2. Replace any character that is not `a-z`, `0-9`, or `-` with `-`
3. Collapse consecutive hyphens into a single `-`
4. Strip leading/trailing hyphens
5. Truncate to **42 characters** (CloudHub limit)

### Pull Request behaviour

Pull request events **do not trigger the deploy job**. The workflow only triggers on direct `push` events to `feature/**` branches.

---

## API Reference

### GET /hello

Returns a Hello World JSON message.

**Request**

```
GET http://<host>:8081/hello
```

**Response – 200 OK**

```json
{
  "message": "Hello World from MuleSoft"
}
```

**Response headers**

| Header | Value |
|--------|-------|
| `Content-Type` | `application/json` |
| `X-Correlation-Id` | Mule correlation ID for request tracing |

**Error response – 500 Internal Server Error**

```json
{
  "status": "error",
  "httpStatus": 500,
  "message": "An unexpected error occurred. Please contact support.",
  "correlationId": "<correlation-id>"
}
```

---

## Configuration Properties

Environment-specific properties are externalised in YAML files under `src/main/resources/`. The active file is selected at startup via the `-Dmule.env` system property.

| File | Environment | `mule.env` value |
|------|-------------|-----------------|
| `config-local.yaml` | Local development | `local` (default) |
| `config-sandbox.yaml` | CloudHub 2.0 Sandbox | `sandbox` |

### Key properties

| Property | Description | Default (local) |
|----------|-------------|-----------------|
| `http.listener.host` | HTTP listener bind address | `0.0.0.0` |
| `http.listener.port` | HTTP listener port | `8081` |
| `api.name` | API name used in logging | `hello-world-api` |
| `logging.level` | Application log level | `DEBUG` (local), `INFO` (sandbox) |

> **Security note**: Never commit credentials or secrets to source control. Inject all sensitive values as CloudHub 2.0 application properties or Anypoint Secure Properties at deploy time.