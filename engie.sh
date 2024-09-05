#!/bin/bash
epex_dam=$(curl --silent  "https://my.yuso.io/api/market-data/daPrices?agg=d&from=$(date +%Y-%m)-01%2000:00:00&to=$(date +%Y-%m-%d)%2023:59:59" | jq '.[].price' | awk 'BEGIN{print "a=(0 \\"} {print "+"$0" \\" } END{print ") / "NR".0; scale=2; (a+0.005)/1"}' | bc -l)

# Engie Flow
# btw * (3.3563 + 0.1140 * EPEXDAM) + distributie + groene stroom + WKK + bijdrage + accijns
afname=4.72
groen=1.21
wkk=0.42
bijdrage=0.2042
accijns=5.0329
price=$(echo "(1.06 * (3.3563 + ( 0.1140 * $epex_dam)) + $afname + $groen + $wkk + $bijdrage + $accijns) / 100" | bc -l --scale=4)

# 0.0300 + 0.0612 * EPEXDAM
injection=$(echo "(0.03 + ( 0.0612 * $epex_dam)) / 100" | bc -l --scale=4)

echo "{"
echo "\"electricity_price\": 0$price,"
echo "\"injection_price\": 0$injection"
echo "}"

