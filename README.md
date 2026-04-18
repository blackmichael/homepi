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

Skip 1Password resolution when desired:
```zsh
./homepi.sh --start --app infrastructure --no-secrets
```

## Notes

We do not use Docker Compose `env_file` for `.env.template` files containing `op://...` references. Compose reads `env_file` values itself, so those references would not be resolved by `op run`.

For `cloudflared`, local routing config lives in `infrastructure/cloudflared/config.yaml`, while tunnel credentials stay in 1Password and are written to `infrastructure/.runtime/` only at runtime.

Repo also includes `.githooks/pre-commit`, which scans staged `.env.template` changes for likely plaintext secrets and requires manual confirmation before commit.

Git cannot auto-enable local hooks in fresh clones, so repo also enforces same `.env.template` secret scan in GitHub Actions on every push and pull request. New clones need no setup for remote enforcement. If you also want local pre-commit blocking in a fresh clone, point Git at tracked hooks with `git config core.hooksPath .githooks`.
