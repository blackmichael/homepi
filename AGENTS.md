# HomePi Agent Guide

## Repository Shape

- This repository manages Raspberry Pi services with Docker Compose; there is no package manager, application build, or automated test suite.
- Each top-level directory containing `docker-compose.yml` or `docker-compose.yaml` is an app discovered by `homepi.sh`; currently this includes `infrastructure`, `simple-web`, `bluesky-api`, `f1pickem-web`, and `at-me`.
- `infrastructure` provides the external `proxy_external` Docker network, Traefik, and the locally managed Cloudflare tunnel. Other apps use Traefik labels for routing on that network.

## Running Services

- Use `./homepi.sh --start --app <app>...` and `./homepi.sh --stop --app <app>...`; use `--app all` to operate on every discovered app.
- Starting automatically creates `proxy_external`; stopping `--app all` removes it, so do not manually remove the network while services are running.
- Add `--pull` to start commands when testing or deploying the latest image.
- Apps with `.env.template` require an authenticated 1Password CLI (`op`) for normal starts. `--no-secrets` passes the template directly and is intended only where secret resolution is not needed.
- Run from the repository root because `homepi.sh` resolves app paths relative to its own location and discovers apps from top-level directories.

## Configuration And Secrets

- Keep secret values in `.env.template` as `op://...` references, not plaintext. Do not use Compose `env_file` for these templates because Compose would bypass `op run` resolution.
- `infrastructure/.env.template` contains the Cloudflare tunnel ID and a 1Password reference for the full credentials JSON; `infrastructure/cloudflared/config.yaml` routes tunnel traffic to `traefik:80`.
- `.runtime/` is ignored and must not be committed. It is reserved for runtime infrastructure files.
- Validate tracked templates with `./scripts/check-env-templates.sh --worktree`; the pre-commit hook scans staged templates with `--staged` and may require `HOMEPI_ENV_TEMPLATE_ACK=1` in non-interactive reviewed commits.

## Deployment

- GitHub Actions deployment runs only on a self-hosted `linux`/`arm64` runner labeled `homepi-deploy` and invokes `./homepi.sh --start --app <app> --pull`. Apps with `.env.template` use `op run`, so the runner must have authenticated 1Password CLI access for secret-backed apps.
- Automatic deployment supports only mappings in `.github/deploy-targets.txt`; update that file when adding a source-repository-triggered app.
- Resolve and validate mappings with `bash ./scripts/resolve-deploy-target.sh --app <app>` or `bash ./scripts/resolve-deploy-target.sh --source-repo <owner/repo>` before changing deployment wiring.
