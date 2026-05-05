# Bring shared scripts into the build context
FROM scratch AS ctx
COPY shared/ /shared

# Ubuntu 26.04 server image — derives from the minimal bootc base.
# Kernel, systemd-boot, dracut initramfs, bootc, and core userspace
# are all inherited. This layer adds server-specific packages only.
FROM ghcr.io/hanthor/ubuntu-26.04-bootc:latest AS system

ENV DEBIAN_FRONTEND=noninteractive

# Server packages: provisioning, networking, firewall, time sync, snaps.
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    apt-get update -y && \
    apt-get install -y \
        chrony \
        cloud-init \
        netplan.io \
        snapd \
        ubuntu-server-minimal \
        ufw && \
    # Enable server services
    systemctl enable --root / \
        chrony.service \
        cloud-init.service \
        cloud-init-local.service \
        cloud-config.service \
        cloud-final.service \
        ufw.service && \
    apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Re-run bootc-rootfs.sh to wipe /var (packages above wrote dpkg/apt state
# into /var; bootc requires /var to be empty in the image).
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/shared/bootc-rootfs.sh

# Clean up runtime directories left by post-install scripts.
RUN find /run -mindepth 1 -maxdepth 1 ! -name 'secrets' -exec rm -rf {} + ; \
    rm -rf /tmp/*

RUN bootc container lint
