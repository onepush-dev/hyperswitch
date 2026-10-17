# Hyperswitch router v1.128.0 for Railway.
# Official upstream image (digest-pinned) + the v1.128.0 config, DB migrations and diesel CLI,
# so a fresh deploy migrates Postgres and boots with zero inputs.
# Build context is prepared by .github/workflows/router-image.yml (it adds upstream/ from the v1.128.0 tag).
FROM docker.io/juspaydotin/hyperswitch-router:v1.128.0-standalone@sha256:2fc7df76116074426685caed60e212839bc0b21fa708461b9f53978cf27151e4

USER root

# diesel CLI 2.3.5 (same version upstream's migration_runner uses), libpq bundled; checksum-verified.
ARG DIESEL_VERSION=2.3.5
ARG DIESEL_SHA256=264d6f71426d9cf25ce389d1669ef9a18df0bc8f1807736be76a757843ee1645
RUN apt-get update \
 && apt-get install -y --no-install-recommends xz-utils libstdc++6 \
 && curl -fsSL -o /tmp/diesel.tar.xz "https://github.com/diesel-rs/diesel/releases/download/v${DIESEL_VERSION}/diesel_cli-x86_64-unknown-linux-gnu.tar.xz" \
 && echo "${DIESEL_SHA256}  /tmp/diesel.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/diesel.tar.xz -C /tmp \
 && install -m 0755 /tmp/diesel_cli-x86_64-unknown-linux-gnu/diesel /usr/local/bin/diesel \
 && rm -rf /tmp/diesel* /var/lib/apt/lists/* \
 && diesel --version && setpriv --version

# Upstream v1.128.0 files: router config, Superposition fallback seed, v1 migrations.
COPY upstream/config/docker_compose.toml /local/config/hyperswitch.toml
COPY upstream/config/superposition_seed.toml /local/config/superposition_seed.toml
COPY upstream/migrations /local/migrations
COPY diesel.toml /local/diesel.toml
COPY railway-entrypoint.sh /local/railway-entrypoint.sh

RUN chmod 0755 /local/railway-entrypoint.sh \
 && mkdir -p /local/bin/files /local/bin/config \
 && ln -s /local/config/superposition_seed.toml /local/bin/config/superposition_seed.toml \
 && chown -R app:app /local/bin/files

# Starts as root only to fix ownership of the mounted volume, then drops to the image's `app` user.
WORKDIR /local/bin
EXPOSE 8080
ENTRYPOINT ["/local/railway-entrypoint.sh"]
CMD ["/local/bin/router", "-f", "/local/config/hyperswitch.toml"]
