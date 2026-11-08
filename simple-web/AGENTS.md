# simple-web Agent Guide

`simple-web` is a simple Nginx web server serving static web pages from `public/`.

- Docker Compose runs the `nginx:latest` image and mounts `./public` read-only at `/usr/share/nginx/html`.
- Put or update static site files in `public/`; there is no application runtime or build step.
- Traefik routes `simple.michaelblack.xyz` to the Nginx service on port 80.
