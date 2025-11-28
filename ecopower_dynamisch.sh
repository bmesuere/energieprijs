#!/usr/bin/env bash
set -euo pipefail

# --- Constants ---------------------------------------------------------------

# Individual taxes (EUR/kWh)
groenestroomcertificaten=0.0110
wkk=0.0039
distributie=0.0589
bijdrage_energie=0.0019
accijns=0.0475

# Sum taxes and add 6% VAT, then convert to cents/kWh
taxes_cents=$(
  echo "scale=6; (($groenestroomcertificaten + $wkk + $distributie + $bijdrage_energie + $accijns) * 1.06) * 100" | bc
)

BRUSSELS_TZ="Europe/Brussels"


# --- Date strings for the nord pool API (Brussels local) --------------------------
# Nord Pool endpoint wants a date=YYYY-MM-DD in local market convention.
# We query "today" and "tomorrow" then filter strictly to today's local wall-clock.

if date -v +1d >/dev/null 2>&1; then
  # BSD/macOS
  today_local=$(TZ="$BRUSSELS_TZ" date +%Y-%m-%d)
  tomorrow_local=$(TZ="$BRUSSELS_TZ" date -v+1d +%Y-%m-%d)
else
  # GNU/Linux
  today_local=$(TZ="$BRUSSELS_TZ" date +%Y-%m-%d)
  tomorrow_local=$(TZ="$BRUSSELS_TZ" date -d 'tomorrow' +%Y-%m-%d)
fi

# --- Fetch + transform -------------------------------------------------------

export TZ="$BRUSSELS_TZ"

API_BASE="https://dataportal-api.nordpoolgroup.com/api/DayAheadPrices"
Q_PARAMS="market=DayAhead&deliveryArea=BE&currency=EUR"

# Fetch today & tomorrow (quietly fail with non-zero if HTTP error)
json_today=$(
  curl --fail --silent "${API_BASE}?date=${today_local}&${Q_PARAMS}"
)
json_tomorrow=$(
  curl --fail --silent "${API_BASE}?date=${tomorrow_local}&${Q_PARAMS}"
)

# Merge, normalize, filter to *today in Brussels*, and emit 3 payloads
printf '%s\n%s\n' "$json_today" "$json_tomorrow" \
| jq --slurp --argjson taxes "$taxes_cents" '
  # Helpers ------------------------------------------------------------
  def to_local_str(ts):
    (ts | fromdateiso8601 | localtime | strftime("%Y-%m-%d %H:%M:%S"));
  def local_date(ts):
    (ts | fromdateiso8601 | localtime | strftime("%Y-%m-%d"));
  def eurmwh_to_ctkwh(p): (p / 10.0);

  # Slurp both docs, concatenate all quarter-hours
  map(select(. != null and . != ""))
  | map(.multiAreaEntries) | add
  # Keep only entries that have a BE price (defensive)
  | map(select(.entryPerArea and (.entryPerArea | has("BE"))))
  # Build the three views using your formulas
  | {
      raw_data: (map({
        time:  to_local_str(.deliveryStart),
        price: eurmwh_to_ctkwh(.entryPerArea.BE)
      })),

      consumption_data: (map({
        time:  to_local_str(.deliveryStart),
        # Your original: (((amount * 0.00102) + 0.004) * 1.06 * 100) + taxes
        # Here, .entryPerArea.BE is €/MWh
        price: ((((.entryPerArea.BE * 0.00102) + 0.004) * 1.06 * 100) + $taxes)
      })),

      injection_data: (map({
        time:  to_local_str(.deliveryStart),
        # Your original: (((amount * 0.00098) - 0.015) * 100)
        price: (((.entryPerArea.BE * 0.00098) - 0.015) * 100)
      }))
    }
'
