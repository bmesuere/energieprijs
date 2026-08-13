#!/usr/bin/env bash
set -euo pipefail

# Fetches Belgian EPEX price predictions from the hosted EpexPredictor API
# (https://epexpredictor.batzill.com, upstream: https://github.com/b3nn0/EpexPredictor)
# and applies the same Ecopower dynamic-tariff formulas as ecopower_dynamisch.sh.
#
# Output structure mirrors ecopower.json (raw_data / consumption_data /
# injection_data) with one extra field: known_until. Entries before that
# timestamp are actual day-ahead market prices; entries after it are model
# predictions.

# --- Constants ---------------------------------------------------------------

# Tax constants and taxes_cents are shared with ecopower_dynamisch.sh
source "$(dirname "$0")/ecopower_constants.sh"

# --- Fetch + transform -------------------------------------------------------

# The API returns 15-minute spot prices (ct/kWh) from now until ~7 days ahead.
# timezone=Europe/Brussels makes the timestamps local wall-clock time.
API_URL="https://epexpredictor.batzill.com/prices?region=BE&unit=CT_PER_KWH&timezone=Europe/Brussels"

curl --fail --silent "$API_URL" \
| jq --argjson taxes "$taxes_cents" '
  # "2026-08-13T21:30:00+02:00" -> "2026-08-13 21:30:00" (already local time)
  def to_local_str(ts): (ts | sub("T"; " ") | .[0:19]);

  # API prices are ct/kWh; the Ecopower formulas below are written for €/MWh
  # (like the Nord Pool feed in ecopower_dynamisch.sh), so convert back (x10).
  def ct_to_eurmwh(p): (p * 10.0);

  .prices as $prices
  | {
      known_until: to_local_str(.knownUntil),

      raw_data: ($prices | map({
        time:  to_local_str(.startsAt),
        price: .total
      })),

      consumption_data: ($prices | map({
        time:  to_local_str(.startsAt),
        price: (((( ct_to_eurmwh(.total) * 0.00102) + 0.004) * 1.06 * 100) + $taxes)
      })),

      injection_data: ($prices | map({
        time:  to_local_str(.startsAt),
        price: ((ct_to_eurmwh(.total) * 0.00098) - 0.015) * 100
      }))
    }
'
