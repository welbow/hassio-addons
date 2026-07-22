ARG BUILD_FROM=ghcr.io/netxms/agent:latest
FROM ${BUILD_FROM}

# jq parses the add-on options (/data/options.json); curl + jq back the
# optional HAOS.Disk.* metrics that query the Supervisor API.
RUN apt-get update \
    && apt-get install -y --no-install-recommends jq curl \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /run.sh
COPY haos-disk.sh /usr/local/bin/haos-disk
RUN chmod a+x /run.sh /usr/local/bin/haos-disk

# Clear any inherited entrypoint so our start script runs directly.
ENTRYPOINT []
CMD [ "/run.sh" ]
