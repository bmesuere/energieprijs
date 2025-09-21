#!/usr/bin/env bash
set -euo pipefail

# Define individual taxes (in euro/kWh)
groenestroomcertificaten=0.011
wkk=0.00392
distributie=0.0589031
bijdrage_energie=0.0019261
accijns=0.04748

# Sum taxes and add 6% VAT, then convert to cents
taxes_cents=$(echo "scale=6; (($groenestroomcertificaten + $wkk + $distributie + $bijdrage_energie + $accijns) * 1.06) * 100" | bc)

# Cross-platform dates:
if date -v +1d >/dev/null 2>&1; then
  # BSD (macOS)
  FROM="$(date +%Y-%m-%d)%2000:00:00"
  TO="$(date -v+1d +%Y-%m-%d)%2023:59:59"
else
  # GNU (Linux/CI)
  FROM="$(date -d 'today' +%Y-%m-%d)%2000:00:00"
  TO="$(date -d 'tomorrow' +%Y-%m-%d)%2023:59:59"
fi

curl --silent "https://my.yuso.io/api/market-data/daPrices?agg=h&from=${FROM}&to=${TO}" \
| jq --argjson taxes "$taxes_cents" '
  {
    raw_data: [
      .[] | { time: .dtlt, price: (.price / 10) }
    ],
    consumption_data: [
      .[] | { time: .dtlt, price: ((((.price * 0.00102) + 0.004) * 1.06 * 100) + $taxes) }
    ],
    injection_data: [
      .[] | { time: .dtlt, price: (((.price * 0.00098) - 0.015) * 100) }
    ]
  }
'
