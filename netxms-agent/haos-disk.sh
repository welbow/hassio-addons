#!/usr/bin/env sh
# Report Home Assistant OS host-disk stats from the Supervisor API, for use as
# NetXMS ExternalParameter / ExternalList / ExternalTable metric sources.
#
#   haos-disk total|used|free|usedperc|lifetime   -> single value
#   haos-disk volumes                             -> instance list (for discovery)
#   haos-disk table                               -> CSV (header row + one data row)
#
# total/used/free are returned in BYTES (the Supervisor reports GB, so we
# multiply); usedperc and lifetime are percentages (0-100).
set -e

# HA OS exposes a single managed data partition; give it a stable instance name
# so instance discovery and the table share one volume identifier.
VOLUME=data

# The instance list needs no API call.
if [ "$1" = "volumes" ]; then
    echo "$VOLUME"
    exit 0
fi

INFO="$(curl -sf -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" http://supervisor/host/info)" || exit 1

case "$1" in
    total)    echo "$INFO" | jq -r '.data.disk_total * 1073741824 | floor' ;;
    used)     echo "$INFO" | jq -r '.data.disk_used  * 1073741824 | floor' ;;
    free)     echo "$INFO" | jq -r '.data.disk_free  * 1073741824 | floor' ;;
    usedperc) echo "$INFO" | jq -r 'if .data.disk_total > 0 then (.data.disk_used / .data.disk_total * 100) else 0 end' ;;
    lifetime) echo "$INFO" | jq -r '.data.disk_life_time' ;;
    table)
        echo "Mount,Total,Used,Free,UsedPerc"
        echo "$INFO" | jq -r --arg v "$VOLUME" \
            '.data | "\($v),\(.disk_total*1073741824|floor),\(.disk_used*1073741824|floor),\(.disk_free*1073741824|floor),\(if .disk_total>0 then (.disk_used/.disk_total*100) else 0 end)"'
        ;;
    *) echo "usage: haos-disk {total|used|free|usedperc|lifetime|volumes|table}" >&2; exit 2 ;;
esac
