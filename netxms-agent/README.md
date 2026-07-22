# NetXMS Agent

Run the [NetXMS](https://www.netxms.org/) monitoring agent as a Home Assistant
add-on so your NetXMS server can poll the Home Assistant host for CPU, memory,
network, process, uptime and (via the Supervisor API) host-disk metrics.

## Install

This add-on ships in the [welbow/hassio-addons](https://github.com/welbow/hassio-addons)
repository. Add that repository to Home Assistant
(**Settings → Add-ons → Add-on Store → ⋮ → Repositories**), then install
**NetXMS Agent** from the store. Set `master_servers` on the **Configuration**
tab and **Start**.

Full configuration and the optional host-disk DCIs are documented in
[DOCS.md](DOCS.md).

## Requirements / notes

- The upstream image `ghcr.io/netxms/agent` is currently published for
  **amd64 only**, so this add-on installs on amd64 Home Assistant hosts only
  (e.g. Intel/AMD NUC, generic x86-64, HA OS in a VM). ARM boards (Raspberry Pi)
  are not supported until NetXMS publishes ARM images.
- The agent uses **host networking** and listens on **tcp/4700** — make sure
  that port is reachable from your NetXMS server.
