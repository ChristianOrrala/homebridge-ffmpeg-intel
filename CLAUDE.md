# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo produces a single Docker image: the official `homebridge/homebridge:ubuntu` base with Jellyfin's hardware-accelerated FFmpeg build layered on top so Homebridge plugins (e.g. Unifi-Video) can use Intel Quick Sync transcoding. There is no application source code here — the entire deliverable is `Dockerfile`, the CI that publishes it, and the Unraid Community Apps template that points at the published image.

The image is published to **GHCR** as `ghcr.io/christianorrala/homebridge-ffmpeg-intel`. Note that `docker-compose.yml` still references the old `keithah/homebridge-ffmpeg-intel:latest` Docker Hub image — that is upstream/historical and unrelated to what this fork's CI publishes. The build is **AMD64-only** by design (Intel hardware acceleration); do not "fix" the README/Dockerfile claims of multi-arch support by adding ARM64 — the most recent commits (`f1c2270`, `fb2e710`) explicitly removed that.

## Architecture notes that aren't obvious from one file

- **FFmpeg path is intentionally non-default.** The Jellyfin `.deb` installs to `/usr/lib/jellyfin-ffmpeg/ffmpeg` and the stock `/usr/bin/ffmpeg` is left untouched. Plugins must be reconfigured to point at the Jellyfin path. A previous commit (`fb2e710`) removed a symlink that tried to paper over this — don't reintroduce it.
- **Jellyfin version is resolved at build time, not pinned.** The Dockerfile scrapes `repo.jellyfin.org/files/ffmpeg/ubuntu/latest-7.x/amd64/` for the newest `jellyfin-ffmpeg7_*.deb`. That's why CI runs daily — to pick up upstream FFmpeg releases without code changes. If you pin a version, you defeat the whole update mechanism.
- **`/var/lib/homebridge` → `/homebridge` symlink.** The base image expects state under `/var/lib/homebridge`; this Dockerfile replaces that with a symlink to `/homebridge` so the docker-compose volume mount (`./homebridge:/homebridge`) is the single source of truth. Touching the permissions block in the Dockerfile risks breaking first-boot on a fresh volume.
- **`docker-compose.yml` mounts host DRI/firmware paths.** `/usr/lib/x86_64-linux-gnu/dri`, `/lib/firmware`, and `/dev` are bind-mounted because Quick Sync needs the host's iHD/i965 drivers and kernel firmware blobs — installing them inside the image isn't sufficient. `group_add: "44"` is the host's `video` GID.
- **CI lives in `.github/workflows/build-and-push.yml`** and pushes to GHCR using the built-in `GITHUB_TOKEN` (no extra secrets required). It triggers on push to `main`, semver tags, daily cron at 02:00 UTC (to pick up Jellyfin FFmpeg releases), and `workflow_dispatch`. Tagging strategy is driven by `docker/metadata-action` — `latest` only on the default branch, plus sha/date/semver tags.
- **Unraid template lives at `unraid/homebridge-ffmpeg-intel.xml`.** Users add the raw GitHub URL of that file to Unraid Community Apps as a template repository. The template's `<TemplateURL>` self-references that raw URL — keep it in sync if the path or branch changes. The template uses `--device=/dev/dri` + `--group-add=44` rather than the heavier `/dev` + `/lib/firmware` bind mounts the docker-compose file uses; that's the idiomatic Unraid approach for Intel QSV and is intentional.

## Common commands

Build locally (AMD64 host required for the FFmpeg layer to install):

```
docker build -t homebridge-ffmpeg-intel .
```

Verify the Jellyfin FFmpeg inside a running container:

```
docker exec homebridge-ffmpeg-intel /usr/lib/jellyfin-ffmpeg/ffmpeg -version
```

Run via compose (uses the published image, not your local build — retag if testing locally):

```
docker compose up -d
```
