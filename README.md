# Ministack WAF Testing

A local AWS WAF testing environment using [Ministack](https://ministack.dev) — a lightweight AWS emulator.  
The project runs entirely in Docker (using dev containers) and requires no real AWS account.

## Architecture

WAF v2 (WebACL) is associated with the API Gateway stage. Every incoming HTTP request is evaluated by WAF first — blocked requests receive a `403 Forbidden` response, allowed requests are forwarded to the Lambda integration.

```
Client (dev container) → API Gateway [WAF v2] → Lambda → S3
```

See [architecture.md](architecture.md) for the full diagram

## Infrastructure Choice

Infrastructure is defined using **AWS CloudFormation** and deployed with a single `aws cloudformation deploy` command from inside the `dev` container.

**AWS CloudFormation** is choosen based on the following comparison with AWS CLI scripts and Terraform:

| | AWS CLI scripts | CloudFormation | Terraform |
|---|---|---|---|
| Extra tools required | ✅ no | ✅ no | ❌ yes (binary) |
| Manages resource dependencies | ❌ manual (ARNs...) | ✅ automatic | ✅ automatic |
| Single command deploy | ❌ no | ✅ yes | ✅ yes |
| Rollback on failure | ❌ no | ✅ yes | ✅ yes |
| Ministack support | ✅ yes | ✅ yes | ✅ yes (via provider) |
| Clean for GitHub | ❌ no | ✅ yes (single YAML) | ✅ yes |

## Dev Environment

| Container | Image | Purpose |
|---|---|---|
| `ministack` | `ministackorg/ministack:latest` | ministack container with AWS services (on port 4566) |
| `dev` | custom Ubuntu 26.04 | dev container with tools to interact with AWS services. Preinstalled tools: AWS CLI v2, Python 3, test scripts |

### Prerequisites

- Docker
- VS Code with Dev Containers extension

### Start

Open this folder in VS Code and select **Reopen in Container**.

## Project Roadmap

### Infrastructure
- [ ] S3 bucket
- [ ] Lambda function (Python) — receives file from API GW, stores in S3
- [ ] API Gateway (REST API) with Lambda integration
- [ ] WAF v2 WebACL associated to API Gateway stage
- [ ] Basic WAF rule: block requests with specific file types (e.g. `.exe`)

### Tests
- [ ] Test: allowed request passes through WAF → Lambda → S3
- [ ] Test: blocked request returns 403
- [ ] Test: file size limit rule
- [ ] Test: custom WAF rule (regex pattern match)

### Logging (optional)
- [ ] CloudWatch Logs for Lambda
- [ ] WAF logging to S3

## Deployment

```bash
# inside dev container
aws cloudformation deploy \
  --template-file infra/template.yaml \
  --stack-name ministack-waf \
  --endpoint-url http://ministack:4566
```

## Teardown

```bash
aws cloudformation delete-stack \
  --stack-name ministack-waf \
  --endpoint-url http://ministack:4566
```