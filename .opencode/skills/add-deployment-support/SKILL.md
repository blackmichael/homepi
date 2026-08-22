---
name: add-deployment-support
description: Use when adding a new HomePi service or deployment target; tracks the required HomePi Compose and deploy mapping changes and communicates the source-repository GitHub Actions changes.
---

# Add Deployment Support

Use this workflow when a service publishes a Docker image and should be deployable by HomePi.

## Gather First

Identify these values before editing:

- HomePi app directory name, which must be a top-level directory containing `docker-compose.yml` or `docker-compose.yaml`.
- Source repository in `owner/name` form.
- Published image name and tag, normally `ghcr.io/<owner>/<image>:latest`.
- Container port, host port if needed, public hostname, and required environment variables.
- Whether the service needs secrets at runtime. The deploy workflow uses `--no-secrets`, so do not silently add `op://...` values that deployment cannot resolve.

If the user has not supplied these values, inspect the source repository when available; ask only for values that cannot be verified.

## HomePi Changes

Make the smallest complete set of changes:

1. Add `<app>/docker-compose.yml` with the published image, restart policy, required ports, the external `proxy_external` network, and Traefik labels when the service is public.
2. Add `<app>/.env.template` only when Compose needs variable substitution. Keep secret-looking values empty, placeholder-based, or as `op://...` references; never add plaintext secrets.
3. Add exactly one `<app>|<owner/name>` line to `.github/deploy-targets.txt`.
4. Do not change `.github/workflows/deploy.yml` for a normal app. It already resolves mappings and runs `./homepi.sh --start --app <app> --pull --no-secrets`.

Use the existing Compose files and `README.md` as the style reference. Do not use Compose `env_file` for `.env.template`; `homepi.sh` must invoke `op run` for secret-backed local starts.

## External Repository Handoff

The source repository must trigger HomePi after its image has been pushed successfully. Communicate these required changes explicitly, even if that repository is not mounted:

```yaml
- name: Trigger HomePi deploy
  run: |
    gh api repos/blackmichael/homepi/dispatches \
      -f event_type=deploy-homepi \
      -f 'client_payload[source_repo]=${{ github.repository }}'
  env:
    GH_TOKEN: ${{ secrets.HOMEPI_DISPATCH_TOKEN }}
```

Tell the user to:

- Add the step after the successful GHCR image push in the source repository workflow.
- Add `HOMEPI_DISPATCH_TOKEN` to that repository's Actions secrets. It needs access to dispatch events in `blackmichael/homepi`.
- Keep the source repository string exactly identical to the mapping in `.github/deploy-targets.txt`.
- Test the source workflow and then use HomePi Actions `workflow_dispatch` with the app directory for a manual deployment check.

If the source repository is available and the user explicitly authorizes edits outside HomePi, inspect its existing image-publish workflow and make the smallest equivalent change. Otherwise, do not edit outside this repository; return the handoff above with the exact target repository and workflow location to update.

## Verify

Run from the HomePi repository root:

```bash
bash -n homepi.sh scripts/check-env-templates.sh scripts/resolve-deploy-target.sh
./scripts/check-env-templates.sh --worktree
bash ./scripts/resolve-deploy-target.sh --app <app>
bash ./scripts/resolve-deploy-target.sh --source-repo <owner/name>
git diff --check
```

If Docker is available, also run `docker compose -f <app>/docker-compose.yml config` with the required non-secret environment values. Report any unavailable Docker or external-repository verification rather than claiming deployment succeeded.

## Final Report

Separate the result into:

- HomePi files changed and verification results.
- External repository changes required or made.
- Required secret/configuration setup.
- Manual deployment test still needed.
