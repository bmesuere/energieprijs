#!/bin/bash
epex_dam=$(curl --silent  "https://my.yuso.io/api/market-data/daPrices?agg=d&from=$(date +%Y-%m)-01%2000:00:00&to=$(date +%Y-%m-%d)%2023:59:59" | jq '.[].price' | awk 'BEGIN{print "a=(0 \\"} {print "+"$0" \\" } END{print ") / "NR".0; scale=2; (a+0.005)/1"}' | bc -l)

# EnergyVision
# btw * (1.5 + 0.105 * EPEXDAM) + distributie + groene stroom + WKK + bijdrage + accijns
distributie=6.24373
groen=1.166
wkk=0.41552
bijdrage=0.20417
accijns=5.03288
price=$(echo "scale=4; (1.06 * (1.5 + ( 0.105 * $epex_dam)) + $distributie + $groen + $wkk + $bijdrage + $accijns) / 100" | bc -l)

# -1.5 + 0.06 * EPEXDAM
injection=$(echo "scale=4; (-1.5 + ( 0.06 * $epex_dam)) / 100" | bc -l)

echo "{"
echo "\"electricity_price\": 0$price,"
echo "\"injection_price\": 0$injection"
echo "}"
