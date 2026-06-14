# Infrastructure

Ore's only backend component is a **thin proxy for the Claude API** used by the
practice planner (Phase 4). The API key lives here, never in the app. See
`docs/decisions/0002-ai-proxy-backend.md`.

## Footprint (deliberately tiny)

V1 does **not** stand up the parked AWS collaboration layer (DynamoDB/S3 for
shared setlists). Prod is one Lambda behind API Gateway, plus optionally a
static privacy-policy page (S3 + CloudFront).

```
infrastructure/
  prod/        Terraform for the AWS prod proxy (Lambda + API Gateway)  [Phase 4]
  README.md
```

## Environments

| Env | Where | How the app reaches it |
|---|---|---|
| Local dev | A local server, or a non-AWS host (Cloudflare Worker / Vercel) | Debug build → `ORE_API_BASE_URL = http://localhost:8787` |
| Prod | AWS (Lambda + API Gateway), Terraform-managed | Release build → prod base URL |

Running the proxy locally / off-AWS for dev is intentional: it keeps the
interface accessible and fast to iterate, without prod's lockdown. The app
selects the base URL by build configuration (`project.yml`), so no code change
is needed to switch environments.

## State & safety (Docket lessons)

- Keep Terraform state in a single remote backend (S3 + DynamoDB lock) once prod
  lands.
- Apply one change at a time — concurrent applies race the state lock.
- The proxy authenticates callers with the Sign-in-with-Apple identity token and
  rate-limits per user; it never returns the API key to the client.

> Terraform is added in Phase 4. This directory is a placeholder until then.