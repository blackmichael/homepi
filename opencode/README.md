# OpenCode on Raspberry Pi

Runs the OpenCode web server in Docker with bounded CPU/memory usage while giving it direct access to development repositories stored on the Pi.

## Why Docker?

The container provides a few useful boundaries:

* Prevents OpenCode and child processes from consuming all host resources.
* Keeps OpenCode's runtime environment separate from the Pi.
* Limits filesystem access to explicitly mounted directories.
* Makes the OpenCode installation disposable while keeping projects, configuration, skills, and state persistent.

Projects remain normal files on the Pi. Docker bind-mounts them into the container, so changes made by OpenCode are immediately visible on the host.

## Directory layout

Persistent data lives under:

```text
/mnt/data/dev/
├── projects/     # Git repositories
└── opencode/
    ├── config/   # OpenCode configuration
    ├── agents/   # Global agent skills
    ├── data/     # OpenCode application/session data
    └── npm/      # npm/npx cache
```

Inside the container, `/mnt/data/dev/projects` is available as:

```text
/workspace
```

## Usage

Build and start:

```bash
docker compose up -d --build
```

Open OpenCode at:

```text
http://<pi-hostname>:3333
```

View logs:

```bash
docker compose logs -f opencode
```

Stop:

```bash
docker compose down
```

Rebuild after changing the Dockerfile:

```bash
docker compose up -d --build
```

## Managing OpenCode

Edit the host configuration directly:

```text
/mnt/data/dev/opencode/config/
```

Changes persist across container rebuilds.

To run commands inside the container:

```bash
docker compose exec opencode bash
```

For example, manage global skills with:

```bash
npx skills@latest list
npx skills@latest check
npx skills@latest update
```

## Important behavior

### Repository access

OpenCode has read/write access to everything under:

```text
/mnt/data/dev/projects
```

Changes made inside `/workspace` modify the actual host files. Docker does not create a separate copy.

### Resource limits

The container has explicit memory, swap, CPU, and process limits. If OpenCode or a tool it launches exceeds those limits, the offending process or container may be killed rather than exhausting resources across the entire Pi.

`restart: unless-stopped` allows the OpenCode server to restart automatically after a crash or reboot.

### Filesystem isolation

OpenCode can access mounted project/configuration directories but does not have general access to the Pi filesystem or Docker daemon.

Avoid adding broad mounts such as:

```text
/
```

or:

```text
/var/run/docker.sock
```

unless that additional access is explicitly required.

### File ownership

Ensure that the opencode user owns the opencode directories.
```bash
sudo mkdir -p \
  /mnt/data/dev/opencode/{data,config,agents,npm}

sudo chown -R 1000:1000 /mnt/data/dev/opencode
```

### Port

Only TCP port `3333` is published from the container. It is used for the OpenCode web server.

Development servers started inside the container are not externally reachable unless additional ports or another proxying mechanism are configured.

## Updating OpenCode

The Docker image contains the OpenCode runtime and development tooling. Persistent files remain under `/mnt/data/dev`, so the image can safely be rebuilt or replaced:

```bash
docker compose build --pull
docker compose up -d
```

