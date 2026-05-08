FROM homebridge/homebridge:ubuntu

USER root

# Install Jellyfin FFmpeg from the official Jellyfin APT repo. The repo serves
# per-codename builds, so APT picks one compiled against the base image's libc6.
# Directory-listing scraping of repo.jellyfin.org/files/ffmpeg/ no longer works
# (the host returns 403 to non-browser clients); the APT path is the documented
# install method and lets APT resolve dependencies on its own.
RUN set -e; \
    apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates curl gnupg && \
    . /etc/os-release && \
    install -d -m 0755 /etc/apt/keyrings && \
    curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg && \
    chmod 0644 /etc/apt/keyrings/jellyfin.gpg && \
    printf 'Types: deb\nURIs: https://repo.jellyfin.org/%s\nSuites: %s\nComponents: main\nArchitectures: amd64\nSigned-By: /etc/apt/keyrings/jellyfin.gpg\n' \
        "$ID" "$VERSION_CODENAME" > /etc/apt/sources.list.d/jellyfin.sources && \
    apt-get update && \
    apt-get install -y --no-install-recommends jellyfin-ffmpeg7 && \
    rm -rf /var/lib/apt/lists/*

# Verify installation
RUN echo "Verifying FFmpeg installation..." && \
    dpkg -l | grep jellyfin && \
    ls -la /usr/lib/jellyfin-ffmpeg/ffmpeg && \
    /usr/lib/jellyfin-ffmpeg/ffmpeg -version

# Fix homebridge directory permissions
RUN chown -R homebridge:homebridge /homebridge && \
    chmod -R 755 /homebridge && \
    chown homebridge:homebridge /var/lib && \
    chmod 755 /var/lib && \
    rm -rf /var/lib/homebridge && \
    ln -sf /homebridge /var/lib/homebridge && \
    chown -h homebridge:homebridge /var/lib/homebridge

EXPOSE 8581
