# NetXMS Agent

This add-on runs the official NetXMS agent (`ghcr.io/netxms/agent`) and lets your
NetXMS server poll the Home Assistant host over tcp/4700.

## Configuration

Options are set on the add-on's **Configuration** tab.

### `master_servers` (required)

Address(es) of the NetXMS server(s) allowed to poll this agent. Accepts a single
host, a CIDR range, or a comma-separated list. Maps directly to `MasterServers`
in `nxagentd.conf`.

```yaml
master_servers: "192.168.3.0/24"
```

### `hostname` (optional)

The name this node reports as. Leave blank to use the container hostname. Maps to
`Hostname`.

```yaml
hostname: "homeassistant"
```

### `extra_config` (optional)

A list of raw `nxagentd.conf` lines. Paste any additional agent configuration
here — one directive per list item. This is where `DebugLevel` lives (default
`DebugLevel = 2`), and where you can add things like `EnableSubagents`,
`SubAgent`, custom `Action`/`ExternalParameter` entries, etc.

```yaml
extra_config:
  - "DebugLevel = 2"
  - "EnableSubAgentAutoload = yes"
```

## How the config is assembled

On start, the add-on generates `/etc/nxagentd.conf` from your options:

```
LogFile = {stdout}
DataDirectory = /data
MasterServers = <master_servers>
Hostname = <hostname>          # only if set
<each extra_config line>
```

The effective config is printed to the add-on log at startup so you can confirm
what was applied. Agent state is persisted in the add-on's `/data` volume.

## What is monitored

- **CPU / memory / uptime / network interfaces** — via host networking.
- **Processes** (`Process.*`, `System.ProcessCount`) — via `host_pid` + the
  `SYS_PTRACE` capability. These require **Protection mode** to be turned off (see
  below); everything else works with it on.

### Disk / filesystem metrics

Unlike a plain Docker Compose setup, a Home Assistant add-on **cannot** bind-mount
the host root filesystem (`/ → /rootfs`) — it always has its own mount namespace,
and the Supervisor only allows mapping a fixed set of named HA folders. As a
result, the native `FileSystem.*` metrics report the add-on container's view, not
the host disk.

Instead, this add-on can report the **HA OS host data-disk** stats by querying the
Supervisor API (enabled via `hassio_api: true`). A bundled helper,
`/usr/local/bin/haos-disk`, reads `GET /host/info` using the add-on's
`SUPERVISOR_TOKEN` and exposes the values as agent metrics, a list (for instance
discovery), and a table.

#### Can this be a native "filesystem" DCI?

Not in the auto-discovered **File Systems** tab of the node — that table is
produced by the agent's built-in filesystem provider from real mounts in the
container's namespace, and built-in `FileSystem.*` metrics cannot be overridden by
an `ExternalParameter` (the built-in wins; the override is dropped). Even a custom
compiled subagent can't replace those core handlers.

What you *can* do is get a **near-native, instance-discovered** experience in a
custom `HAOS.FileSystem.*` namespace — DCIs that auto-create per volume plus a
table DCI — using only agent config (no compilation). Add these lines to
`extra_config`:

```yaml
extra_config:
  - "DebugLevel = 2"
  # Instance-discovery list (one line per volume).
  - "ExternalList = HAOS.FileSystem.Volumes:/usr/local/bin/haos-disk volumes"
  # Per-volume metrics (parameterized; the instance is supplied by discovery).
  - "ExternalParameter = HAOS.FileSystem.Total(*):/usr/local/bin/haos-disk total"
  - "ExternalParameter = HAOS.FileSystem.Used(*):/usr/local/bin/haos-disk used"
  - "ExternalParameter = HAOS.FileSystem.Free(*):/usr/local/bin/haos-disk free"
  - "ExternalParameter = HAOS.FileSystem.UsedPerc(*):/usr/local/bin/haos-disk usedperc"
  # One-grid table DCI (all volumes, all columns).
  - "ExternalTable = HAOS.FileSystem.Table:instanceColumns=Mount;separator=,:/usr/local/bin/haos-disk table"
  # Disk wear is host-wide, so keep it a single scalar metric.
  - "ExternalParameter = HAOS.Disk.LifeTime:/usr/local/bin/haos-disk lifetime"
```

On the NetXMS server, wire it up like native filesystem DCIs:

1. **Instance discovery** — on the HA node (or a template), create a DCI with
   *Instance discovery method* = **Agent List**, *List name* =
   `HAOS.FileSystem.Volumes`. Set the metric to
   `HAOS.FileSystem.Free({instance})` and repeat for `Total` / `Used` /
   `UsedPerc`. The `{instance}` macro expands to each volume (`data`), so the
   agent auto-creates one DCI per volume — exactly how native FS DCIs template.
   - `Total` / `Used` / `Free`: data type **Integer (64-bit)**, units **Bytes (IEC)**.
   - `UsedPerc`: data type **Float**, units **%** — threshold here (e.g. alert > 90),
     just like `FileSystem.UsedPerc(/)`.
2. **Table DCI** — add a *Table DCI* with metric `HAOS.FileSystem.Table` and
   instance column `Mount` for a single grid of Mount / Total / Used / Free /
   UsedPerc.
3. **Disk wear** — a normal DCI on `HAOS.Disk.LifeTime` (Float, %); threshold to
   catch aging eMMC/SSD (native FS DCIs can't give you this).

Put the whole set in a **template** applied to your HA nodes and every HA host
gets the same auto-discovered disk DCIs.

Notes and caveats:

- This reports the single HA OS **data partition** — the disk that actually fills
  up on HA OS — not an enumeration of every mount. That is the meaningful host
  disk for most HA installs. Discovery therefore returns one volume (`data`); the
  parameterized metrics ignore the instance argument and always report that disk.
- Each poll makes its own call to the internal `http://supervisor` endpoint, so
  keep the DCI polling interval reasonable (e.g. 5 min).
- The Supervisor reports whole GB; `haos-disk` multiplies to bytes so NetXMS can
  apply byte formatting.

## Protection mode

Home Assistant's **Protection mode** (on the add-on's **Info** tab) is enabled by
default. While it is on, the Supervisor ignores the most host-invasive add-on
options — including `host_pid` — even though this add-on requests them.

What that means here:

| Feature | Works with Protection mode ON? |
| --- | --- |
| CPU / memory / uptime / network | Yes |
| `HAOS.FileSystem.*` / `HAOS.Disk.*` host-disk metrics (Supervisor API) | Yes |
| Processes (`Process.*`, `System.ProcessCount`) | **No** — needs `host_pid` |

If you want host process metrics, turn **Protection mode off** for this add-on.
Home Assistant will warn that you are granting elevated system access — expected,
since process visibility requires the host PID namespace. If you don't need
per-process monitoring, leave Protection mode on; nothing else is affected.

## Networking

The agent uses host networking and listens on **tcp/4700**. Ensure your NetXMS
server can reach the Home Assistant host on that port, and that `master_servers`
covers the server's address.
