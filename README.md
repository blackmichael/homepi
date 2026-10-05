# HomePi

Managed infrastructure for running various applications on a Raspberry Pi home server.

## Setup

Each application can be run individually, but they all rely on the `proxy_external` network. Spin that up before spinning up anything else.
```zsh
docker network create proxy_external
```

Applications keep runtime configuration in `<app>/.env.template`.
- Non-secret values can live there directly.
- Secrets should be stored as `op://...` references.

`homepi.sh` is the supported way to start and stop services. When an app has a `.env.template`, the script runs Docker Compose through `op run --env-file` so 1Password references are resolved before Compose starts.

Your shell must be authenticated to use the 1Password CLI `op` before starting secret-backed apps.

The `infrastructure` app uses locally-managed `cloudflared`. `homepi.sh` materializes tunnel credentials JSON into `infrastructure/.runtime/tunnel-credentials.json`, mounts it read-only into container, and removes it on stop.

`cloudflared` forwards all tunnel traffic to `http://traefik:80`. Traefik then routes requests by Docker labels.

Configure these values in `infrastructure/.env.template`:
- `CLOUDFLARED_TUNNEL_ID`: tunnel UUID for locally-managed tunnel
- `CLOUDFLARED_TUNNEL_CREDENTIALS_JSON`: exact 1Password secret reference for full tunnel credentials JSON contents

If `cloudflared-tunnel-credentials` is stored as file attachment in 1Password, secret reference may need `?attr=content`.

## Usage

Start one or more apps:
```zsh
./homepi.sh --start --app infrastructure simple-web
./homepi.sh --start --app bluesky-api --pull
```

Stop apps:
```zsh
./homepi.sh --stop --app bluesky-api
./homepi.sh --stop --app all
```

For more usage:
```zsh
./homepi.sh --help
```

## Beszel Monitoring

Beszel is deployed as the `beszel` app. The hub listens on `127.0.0.1:8090` only and is not routed through Traefik; expose it privately with Tailscale Serve. The included agent monitors this Raspberry Pi and its Docker containers; host networking is used so the hub can reach the agent on port `45876`.

On first setup, start the hub without secrets, create the admin account, and add a system in the Beszel UI. Use the agent key and token shown by Beszel as the `BESZEL_AGENT_KEY` and `BESZEL_AGENT_TOKEN` references in `beszel/.env.template` (store both values in 1Password). Then start the app normally so `op run` resolves the values:

```zsh
./homepi.sh --start --app beszel --no-secrets
# Configure the agent credentials in beszel/.env.template after creating the system.
./homepi.sh --start --app beszel
```

The hub persists data in the `beszel_data` Docker volume. Keep the agent key and token private.

## Deploy Automation

GitHub Actions can deploy supported applications automatically after new `:latest` images are pushed to `ghcr.io`.

`homepi` expects repo-scoped self-hosted runner on Raspberry Pi with labels `self-hosted`, `linux`, `arm64`, and `homepi-deploy`. Deploy workflow runs only on that runner and executes:

```zsh
./homepi.sh --start --app <app-dir> --pull --no-secrets
```

Supported application mappings live in `.github/deploy-targets.txt`.

For automatic deploys, application repo workflow should send `repository_dispatch` event to this repo with:
- `event_type`: `deploy-homepi`
- `client_payload.source_repo`: publishing repo name, for example `blackmichael/bluesky-feeds`

Example step from image-publish workflow:

```yaml
- name: Trigger HomePi deploy
  run: |
    gh api repos/blackmichael/homepi/dispatches \
      -f event_type=deploy-homepi \
      -f 'client_payload[source_repo]=${{ github.repository }}'
  env:
    GH_TOKEN: ${{ secrets.HOMEPI_DISPATCH_TOKEN }}
```

Store `HOMEPI_DISPATCH_TOKEN` in application repo Actions secrets. Fine-grained PAT scoped to `blackmichael/homepi` with `Contents: Read and write` is sufficient.

Manual retries are also available through GitHub Actions `workflow_dispatch` in this repo. Enter `homepi.sh --app` value, such as `bluesky-api`.

To support new application:
1. Add app directory with `docker-compose.yml` or `docker-compose.yaml` so `homepi.sh --app <name>` works.
2. Add one line to `.github/deploy-targets.txt`.
3. In application repo, add deploy trigger step shown above after successful GHCR push.
4. Push both repos, then test manual deploy from `homepi` Actions before relying on automatic deploys.

To remove application support:
1. Remove app line from `.github/deploy-targets.txt`.
2. Remove or disable dispatch step in application repo workflow.
3. Remove app directory from this repo if service is retired.

## Harness
The Paseo + OMP service is the current remote agent harness. See [`harness/README.md`](harness/README.md) for one-time setup, 1Password, and Tailscale Serve instructions. Start it from the repository root with:
```bash
./harness/setup.sh
docker compose -f harness/docker-compose.yml build --pull
./homepi.sh --start --app harness
```

## Legacy OpenCode
The `opencode/` service is retained as the predecessor to `harness/`.

### Agent Skills
Manage agent skills via `scripts/agent-skills`, which runs `npx skills` commands in the opencode container for you.

Set up a symlink for easy access.
```bash
sudo ln -s /mnt/data/dev/homepi/scripts/agent-skills /usr/local/bin/agent-skills
```

Add new skills
```bash
agent-skills add vercel-labs/agent-skills
```

List global skills
```bash
agent-skills list -g
```

## Notes

We do not use Docker Compose `env_file` for `.env.template` files containing `op://...` references. Compose reads `env_file` values itself, so those references would not be resolved by `op run`.

For `cloudflared`, local routing config lives in `infrastructure/cloudflared/config.yaml`, while tunnel credentials stay in 1Password and are written to `infrastructure/.runtime/` only at runtime.

Repo also includes `.githooks/pre-commit`, which scans staged `.env.template` changes for likely plaintext secrets and requires manual confirmation before commit.

Git cannot auto-enable local hooks in fresh clones, so repo also enforces same `.env.template` secret scan in GitHub Actions on every push and pull request. New clones need no setup for remote enforcement. If you also want local pre-commit blocking in a fresh clone, point Git at tracked hooks with `git config core.hooksPath .githooks`.
