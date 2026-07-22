# welbow's Home Assistant Add-ons

A collection of [Home Assistant](https://www.home-assistant.io/) add-ons.

## Installation

Add this repository to Home Assistant once, and every add-on below becomes
available in your store:

1. Go to **Settings → Add-ons → Add-on Store**.
2. Open the **⋮** menu (top-right) → **Repositories**.
3. Add this URL:

   ```
   https://github.com/welbow/hassio-addons
   ```

4. Close the dialog and refresh — the add-ons appear in the store.

## Add-ons

| Add-on | Description |
| --- | --- |
| [NetXMS Agent](netxms-agent) | Runs the NetXMS monitoring agent so your NetXMS server can poll this host for CPU, memory, network, process and disk metrics. amd64 only. |

See each add-on's own `DOCS.md` for configuration details.

## License

The add-on wrappers in this repository are MIT-licensed. The upstream software
each add-on packages (e.g. NetXMS) is licensed separately by its own project.
