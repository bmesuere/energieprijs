#!/usr/bin/env bash
set -euo pipefail

# --- Constants ---------------------------------------------------------------

# Individual taxes (EUR/kWh)
groenestroomcertificaten=0.011
wkk=0.00392
distributie=0.0589031
bijdrage_energie=0.0019261
accijns=0.04748

# Sum taxes and add 6% VAT, then convert to cents/kWh
taxes_cents=$(
  echo "scale=6; (($groenestroomcertificaten + $wkk + $distributie + $bijdrage_energie + $accijns) * 1.06) * 100" | bc
)

# We fetch the full Brussels local day [00:00, 23:59:59.999] but in UTC for the API.
BRUSSELS_TZ="Europe/Brussels"

# --- Date range (UTC ISO-8601 with Z) ---------------------------------------
# Start/end are midnight..23:59:59.999 of "today" in Brussels local time, expressed in UTC.

if date -v +1d >/dev/null 2>&1; then
  # BSD/macOS
  today_local=$(TZ="$BRUSSELS_TZ" date +%Y-%m-%d)
  tomorrow_local=$(TZ="$BRUSSELS_TZ" date -v+1d +%Y-%m-%d)

  start_epoch=$(TZ="$BRUSSELS_TZ" date -j -f "%Y-%m-%d %H:%M:%S" "$today_local 00:00:00" +%s)
  end_epoch=$(TZ="$BRUSSELS_TZ" date -j -f "%Y-%m-%d %H:%M:%S" "$tomorrow_local 23:59:59" +%s)

  START=$(date -u -r "$start_epoch" +%Y-%m-%dT%H:%M:%S.000Z)
  END=$(date -u -r "$end_epoch"   +%Y-%m-%dT%H:%M:%S.999Z)
else
  # GNU/Linux
  start_epoch=$(TZ="$BRUSSELS_TZ" date -d 'today 00:00:00' +%s)
  end_epoch=$(TZ="$BRUSSELS_TZ"   date -d 'tomorrow 23:59:59' +%s)

  START=$(date -u -d "@$start_epoch" +%Y-%m-%dT%H:%M:%S.000Z)
  END=$(date -u -d "@$end_epoch"    +%Y-%m-%dT%H:%M:%S.999Z)
fi

# --- Fetch + transform -------------------------------------------------------
# New API provides 15-minute "day_ahead" values:
#   https://yuso.com/api/market-prices?type=day_ahead&start=...&end=...
# Field mapping:
#   timestamp_utc (ISO-8601, UTC), amount (€/MWh)
# We output time in Brussels local ("YYYY-MM-DD HH:MM:SS") and prices in ct/kWh.
# Note: €/MWh -> ct/kWh is a division by 10 ( *100 / 1000 = /10 ).

export TZ="Europe/Brussels"
curl --silent "https://yuso.com/api/market-prices?type=day_ahead&start=${START}&end=${END}" \
| jq --argjson taxes "$taxes_cents" '
  # "2025-09-29T22:00:00.000000Z" -> "2025-09-29T22:00:00Z"
  def norm_ts(ts): ts | sub("\\.\\d+Z$"; "Z");

  # Convert UTC ISO → Brussels local wall time "YYYY-MM-DD HH:MM:SS"
  def to_local(ts):
    norm_ts(ts) | fromdateiso8601 | localtime | strftime("%Y-%m-%d %H:%M:%S");

  def eurmwh_to_ctkwh(p): (p / 10.0);

  map(select(.type == "day_ahead")) as $rows
  |
  {
    raw_data: ($rows
      | map({
          time:  to_local(.timestamp_utc),
          price: (eurmwh_to_ctkwh(.amount))
        })
    ),
    consumption_data: ($rows
      | map({
          time:  to_local(.timestamp_utc),
          price: ((((.amount * 0.00102) + 0.004) * 1.06 * 100) + $taxes)
        })
    ),
    injection_data: ($rows
      | map({
          time:  to_local(.timestamp_utc),
          price: (((.amount * 0.00098) - 0.015) * 100)
        })
    )
  }
'
