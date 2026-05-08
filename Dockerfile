FROM homebridge/homebridge:ubuntu

USER root

# Install dependencies
RUN apt-get update && \
    apt-get install -y wget curl && \
    rm -rf /var/lib/apt/lists/*

# Download and install the latest Jellyfin FFmpeg (AMD64 only)
RUN set -e; \
    echo "Downloading Jellyfin FFmpeg for AMD64..." && \
    UBUNTU_CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")" && \
    REPO_BASE="https://repo.jellyfin.org/files/ffmpeg/ubuntu" && \
    SUFFIXES="${UBUNTU_CODENAME:+${UBUNTU_CODENAME}-7.x }latest-7.x"; \
    for SUFFIX in $SUFFIXES; do \
        BASE_URL="${REPO_BASE}/${SUFFIX}/amd64/"; \
        LISTING="$(curl -fsSL "$BASE_URL" || true)"; \
        if echo "$LISTING" | grep -q 'jellyfin-ffmpeg7_'; then \
            break; \
        fi; \
    done; \
    if ! echo "$LISTING" | grep -q 'jellyfin-ffmpeg7_'; then \
        echo "No Jellyfin FFmpeg packages found for ${UBUNTU_CODENAME:-unknown}." >&2; \
        exit 1; \
    fi; \
    echo "Using Jellyfin FFmpeg repo: $BASE_URL" && \
    LATEST_DEB=$(echo "$LISTING" | grep -oP "jellyfin-ffmpeg7_[^\"<>]*\\.deb" | sort -V | tail -1) && \
    if [ -z "$LATEST_DEB" ]; then \
        echo "Failed to determine latest Jellyfin FFmpeg package from $BASE_URL" >&2; \
        exit 1; \
    fi; \
    echo "Found package: $LATEST_DEB" && \
    wget -O /tmp/jellyfin-ffmpeg.deb "${BASE_URL}${LATEST_DEB}" && \
    echo "Downloaded package, installing..." && \
    dpkg -i /tmp/jellyfin-ffmpeg.deb 2>&1 || (echo "Installation failed, installing dependencies..." && apt-get update && apt-get install -f -y && dpkg -i /tmp/jellyfin-ffmpeg.deb) && \
    echo "Package installed successfully" && \
    rm /tmp/jellyfin-ffmpeg.deb

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
