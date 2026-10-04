# Paseo + OMP Harness

Runs Paseo's web UI and daemon in Docker with the Oh My Pi (`omp`) CLI installed and enabled as an agent provider. Repositories are mounted read/write from `/mnt/data/dev/projects`; Paseo and OMP state persist under `/mnt/data/dev/paseo/home`.

## One-time setup

From the repository root, run:

```bash
./harness/setup.sh
```

The script prepares persistent directories, installs `config.json` into Paseo's state directory (without overwriting an existing config), copies your SSH `known_hosts`, and sets ownership for Paseo's container user (`1000:1000`). It expects the shared GitHub key at `/mnt/data/dev/ssh/id_ed25519`; ensure that key is authorized with GitHub. To use a different source for `known_hosts`, set `KNOWN_HOSTS_SOURCE` when running the script.

`harness/.env.template` references Paseo settings in 1Password. Build the image, then start from the repository root using 1Password Secure's `ops` wrapper to resolve the template:

```bash
docker compose -f harness/docker-compose.yml build --pull
sudo ops -- ./homepi.sh --start --app harness
```

Rebuild after Dockerfile changes; use the `ops` command again whenever starting the service. The Compose port is bound to host loopback only. For a direct local check, open `http://127.0.0.1:6767`.

## Remote access over Tailscale

In the Tailscale console, create service `svc:harness`, allow TCP port `443`, and add the appropriate tags. Set the 1Password field referenced by `PASEO_HOSTNAMES` to the host's MagicDNS name, then recreate the service. On the host, forward the TCP service to the loopback-bound Paseo port:

```bash
sudo tailscale serve --service=svc:harness --tcp=443 127.0.0.1:6767
tailscale serve status
```

Use the MagicDNS hostname and port `443` as a TCP endpoint in Paseo clients; this is not an HTTPS URL. Disable the serve rule with `tailscale serve off`.

## OMP setup and maintenance

The image installs Bun (required by OMP's CLI) and the `omp` package. Paseo's config at `/mnt/data/dev/paseo/home/.paseo/config.json` enables the OMP provider bridge. Log in to each model provider from inside the container as `paseo`, so credentials are saved in the persistent home:

```bash
# ChatGPT subscription / Codex OAuth (headless device flow):
docker compose -f harness/docker-compose.yml exec -it --user paseo paseo omp login openai-codex-device

# Other OAuth-capable providers, for example:
docker compose -f harness/docker-compose.yml exec -it --user paseo paseo omp login anthropic
docker compose -f harness/docker-compose.yml exec -it --user paseo paseo omp login github-copilot
```

For the ChatGPT device flow, open the printed URL and enter the displayed code. `openai-codex-device` saves credentials for OMP's `openai-codex` provider. This is separate from OpenAI API billing: the standard `openai` provider reads `OPENAI_API_KEY` from the container environment rather than using this OAuth flow. Add API keys to a secret source, not the repository. Do not run `omp` as root; credentials are stored in `/home/paseo/.omp/agent/agent.db` and persist across rebuilds.

View logs and stop the service with:

```bash
docker compose -f harness/docker-compose.yml logs -f paseo
./homepi.sh --stop --app harness
```

Paseo state, OMP configuration, and credentials are kept in the separate persistent home directory.
