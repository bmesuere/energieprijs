#!/bin/bash

# Define individual taxes (in euro/kWh)
groenestroomcertificaten=0.011
wkk=0.00392
distributie=0.0589031
bijdrage_energie=0.0019261
accijns=0.04748

# Sum taxes and add 6% VAT, then convert to cents
taxes_cents=$(echo "scale=4; (($groenestroomcertificaten + $wkk + $distributie + $bijdrage_energie + $accijns) * 1.06) * 100" | bc)

# Fetch market data and calculate derived prices in one command
curl --silent "https://my.yuso.io/api/market-data/daPrices?agg=h&from=$(date +%Y-%m-%d)%2000:00:00&to=$(date -v+1d +%Y-%m-%d)%2023:59:59" | \
jq --argjson taxes "$taxes_cents" '
  map({
    time: .dtlt,
    raw_price: (.price / 10),
    consumption_price: ((((.price * 0.00102) + 0.004) * 1.06 * 100) + $taxes),
    injection_price: ((.price * 0.00098) - 0.015) * 100
  })
'
