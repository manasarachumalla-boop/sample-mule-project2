# hello-world-api

A **MuleSoft 4** REST API application exposing a `GET /hello` endpoint, with a complete **GitHub Actions CI/CD pipeline** for automated deployment to **CloudHub 2.0 Sandbox**.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Project Structure](#project-structure)
3. [API Endpoint](#api-endpoint)
4. [Local Run Steps](#local-run-steps)
5. [Configuration](#configuration)
6. [MUnit Tests](#munit-tests)
7. [CloudHub 2.0 Deployment](#cloudhub-20-deployment)
8. [GitHub Actions Setup](#github-actions-setup)
9. [GitHub Secrets Setup](#github-secrets-setup)
10. [Deployment Flow](#deployment-flow)
11. [Feature Branch Deployment Behavior](#feature-branch-deployment-behavior)

---

## Project Overview

| Property      | Value                               |
|---------------|-------------------------------------|
| Artifact ID   | `hello-world-api`                   |
| Group ID      | `com.mycompany`                     |
| Version       | `1.0.0`                             |
| Mule Runtime  | `4.6.0`                             |
| Java          | `17`                                |
| Packaging     | `mule-application`                  |
| Deploy Target | CloudHub 2.0 — Sandbox — us-east-1  |

---

## Project Structure

```
hello-world-api/
├── .github/
│   └── workflows/
│       └── deploy-feature.yml              # CI/CD pipeline (feature branches)
├── src/
│   ├── main/
│   │   ├── mule/
│   │   │   ├── global.xml                  # HTTP config, global error handler
│   │   │   └── hello-world-api.xml         # GET /hello flow
│   │   └── resources/
│   │       ├── config-local.yaml           # Local dev properties
│   │       ├── config-sandbox.yaml         # CloudHub Sandbox properties
│   │       └── log4j2.xml                  # Runtime logging config
│   └── test/
│       ├── munit/
│       │   └── hello-world-api-test-suite.xml   # MUnit 3.x test suite
│       └── resources/
│           └── log4j2-test.xml             # Test logging config
├── mule-artifact.json                      # Mule runtime descriptor
├── pom.xml                                 # Maven build + CloudHub 2.0 deploy
├── settings.xml                            # Maven repository credentials
└── README.md
```

---

## API Endpoint

| Method | Path     | Status  | Response Body                               |
|--------|----------|---------|---------------------------------------------|
| `GET`  | `/hello` | `200`   | `{"message": "Hello World from MuleSoft"}`  |

### Sample request

```bash
curl -i http://localhost:8081/hello
```

### Sample response

```
HTTP/1.1 200 OK
Content-Type: application/json

{
  "message": "Hello World from MuleSoft"
}
```

---

## Local Run Steps

### Prerequisites

| Tool             | Minimum Version | Notes                        |
|------------------|-----------------|------------------------------|
| Java JDK         | 17              | Temurin recommended          |
| Apache Maven     | 3.9+            |                              |
| Anypoint Studio  | 7.x             | Optional – visual IDE        |

### 1. Clone the repository

```bash
git clone https://github.com/manasarachumalla-boop/sample-mule-project2.git
cd sample-mule-project2
```

### 2. Build (skip tests)

```bash
mvn clean package -DskipTests -s settings.xml
```

### 3. Run MUnit tests

```bash
mvn test -s settings.xml
```

Coverage reports are written to `target/site/munit/coverage/`.

### 4. Run in Anypoint Studio

Open the project in **Anypoint Studio → File → Import → Anypoint Studio Project**.
Then: **Run As → Mule Application**.

Application will start on `http://localhost:8081`.

### 5. Test the endpoint

```bash
curl http://localhost:8081/hello
# {"message":"Hello World from MuleSoft"}
```

### 6. Change the active environment

```bash
# Default (local)
mvn clean package -Dmule.env=local -s settings.xml

# Sandbox profile
mvn clean package -Dmule.env=sandbox -s settings.xml
```

---

## Configuration

Environment properties are externalised into YAML files and loaded at runtime based on the `mule.env` system property.

| File                   | Environment | Activated when        |
|------------------------|-------------|-----------------------|
| `config-local.yaml`    | Local dev   | `mule.env=local` (default) |
| `config-sandbox.yaml`  | Sandbox     | `mule.env=sandbox`    |

### Key properties

```yaml
http:
  port: "8081"        # HTTP listener port
  basePath: "/api"    # Base path prefix (informational)

app:
  name: "hello-world-api"
  env: "local"        # local | sandbox
  version: "1.0.0"

log:
  level: "DEBUG"      # DEBUG locally, INFO in sandbox

api:
  greeting: "Hello World from MuleSoft"
```

> **Never commit secrets to YAML files.** Sensitive values (API keys, client secrets) must be passed via Anypoint Secure Properties or environment variables.

---

## MUnit Tests

The test suite at `src/test/munit/hello-world-api-test-suite.xml` contains:

| Test Name                              | Validates                                          |
|----------------------------------------|----------------------------------------------------|
| `hello-world-get-flow-success-test`    | Flow returns non-null payload with greeting text   |
| `hello-world-get-flow-valid-json-test` | Payload is a valid JSON object `{...}`             |

### Run tests

```bash
mvn test -s settings.xml
```

### View coverage

Open `target/site/munit/coverage/index.html` in a browser.

---

## CloudHub 2.0 Deployment

The Mule Maven Plugin (`mule-maven-plugin`) is configured in `pom.xml` for CloudHub 2.0 deployment.

### Deployment parameters

| Property                  | Default value            | Override flag                     |
|---------------------------|--------------------------|-----------------------------------|
| `app.name`                | `hello-world-api`        | `-Dapp.name=my-app`               |
| `deploy.environment`      | `Sandbox`                | `-Ddeploy.environment=Production` |
| `deploy.target`           | `Cloudhub-US-East-1`     | `-Ddeploy.target=...`             |
| `deploy.replica.size`     | `0.1`                    | `-Ddeploy.replica.size=0.2`       |
| `deploy.replicas`         | `1`                      | `-Ddeploy.replicas=2`             |
| `deploy.runtime.version`  | `4.6.0:1e`               | `-Ddeploy.runtime.version=4.6.1`  |

### Manual deploy from CLI

```bash
mvn deploy -DskipTests -s settings.xml \
  -Dapp.name=hello-world-api \
  -Danypoint.client.id=<YOUR_CLIENT_ID> \
  -Danypoint.client.secret=<YOUR_CLIENT_SECRET>
```

> Authentication uses **Anypoint Connected App** (client_credentials grant). No username/password required.

---

## GitHub Actions Setup

The pipeline is defined in `.github/workflows/deploy-feature.yml`.

### What it does (on every push to `feature/**`)

```
push to feature/xxx
       │
       ▼
┌──────────────────────────────────────┐
│  1. Checkout code (actions/checkout) │
│  2. Set up Java 17 (Temurin)         │
│  3. Cache Maven repository           │
│  4. mvn clean package -DskipTests    │
│  5. mvn test  (MUnit + coverage)     │
│  6. Upload coverage artifact         │
│  7. Sanitize branch → app name       │
│  8. mvn deploy (CloudHub 2.0 SBX)    │
│  9. Print deployment summary         │
└──────────────────────────────────────┘
```

### Enable the workflow

1. Push `.github/workflows/deploy-feature.yml` to your repository.
2. Add [GitHub Secrets](#github-secrets-setup).
3. Push to a `feature/` branch — the pipeline starts automatically.

---

## GitHub Secrets Setup

The pipeline requires two **GitHub Actions Secrets** for Anypoint Platform authentication.

### Create a Connected App in Anypoint Platform

1. Log in to [Anypoint Platform](https://anypoint.mulesoft.com)
2. Navigate to **Access Management → Connected Apps**
3. Click **Create App**
4. Grant the following scopes:
   - `Runtime Manager - Read Applications`
   - `Runtime Manager - Create Applications`
   - `Runtime Manager - Delete Applications`
   - `Runtime Manager - Deploy Applications`
   - `Exchange - Read`
5. Copy the generated **Client ID** and **Client Secret**

### Add secrets to your GitHub repository

1. Go to your repository on GitHub
2. Navigate to **Settings → Secrets and variables → Actions**
3. Click **New repository secret** for each:

| Secret Name              | Value                              |
|--------------------------|------------------------------------|
| `ANYPOINT_CLIENT_ID`     | Your Connected App Client ID       |
| `ANYPOINT_CLIENT_SECRET` | Your Connected App Client Secret   |

---

## Deployment Flow

```
Developer pushes to feature/my-feature
             │
             ▼
   GitHub Actions triggered
             │
    ┌────────┴─────────┐
    │                  │
    ▼                  ▼
Build + Test      Compute app name
(mvn package)     feature/my-feature
(mvn test)        → hello-world-api-feature-my-feature
    │                  │
    └────────┬─────────┘
             │
             ▼
    Deploy to CloudHub 2.0
    Environment: Sandbox
    Target: Cloudhub-US-East-1
    App: hello-world-api-feature-my-feature
             │
             ▼
    ✅ App running at:
    https://hello-world-api-feature-my-feature.us-e2.cloudhub.io/hello
```

---

## Feature Branch Deployment Behavior

### Branch name sanitization rules

CloudHub 2.0 application names must:
- Be **lowercase**
- Contain only **alphanumeric characters and hyphens**
- Be **maximum 42 characters** long

The pipeline automatically sanitizes the branch name:

| Branch Name                  | CloudHub App Name                             |
|------------------------------|-----------------------------------------------|
| `feature/login`              | `hello-world-api-feature-login`               |
| `feature/my-feature`         | `hello-world-api-feature-my-feature`          |
| `feature/my-feature/v2`      | `hello-world-api-feature-my-feature-v2`       |
| `feature/UPPERCASE`          | `hello-world-api-feature-uppercase`           |
| `feature/under_score`        | `hello-world-api-feature-under-score`         |

### Deployment behavior by event type

| GitHub Event                    | Build | Test | Deploy |
|---------------------------------|-------|------|--------|
| Push to `feature/**`            | ✅    | ✅   | ✅     |
| Pull Request (any branch)       | ✅    | ✅   | ❌     |
| Manual trigger (skip_deploy=false) | ✅ | ✅   | ✅     |
| Manual trigger (skip_deploy=true)  | ✅ | ✅   | ❌     |

### Rollback / Redeployment

Re-deploying the same branch simply re-runs the pipeline.
The Mule Maven Plugin will **update** an existing CloudHub 2.0 application in-place (rolling update).

To force a full redeployment:

```bash
# Trigger by pushing an empty commit
git commit --allow-empty -m "chore: trigger redeploy"
git push origin feature/my-feature
```

---

## References

- [MuleSoft Documentation](https://docs.mulesoft.com/general/)
- [Mule Maven Plugin – CloudHub 2.0](https://docs.mulesoft.com/mule-runtime/latest/deploy-to-cloudhub-2)
- [MUnit Framework](https://docs.mulesoft.com/munit/latest/)
- [Anypoint Connected Apps](https://docs.mulesoft.com/access-management/connected-apps-overview)
- [GitHub Actions – actions/setup-java](https://github.com/actions/setup-java)
