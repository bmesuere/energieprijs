# Shared Ecopower tariff constants, sourced by ecopower_dynamisch.sh and
# epex_forecast.sh. Update tax rates here so both outputs stay in sync.

# Individual taxes (EUR/kWh)
groenestroomcertificaten=0.0110
wkk=0.0039
distributie=0.0523
bijdrage_energie=0
accijns=0.046

# Sum taxes and add 6% VAT, then convert to cents/kWh
taxes_cents=$(
  echo "scale=6; (($groenestroomcertificaten + $wkk + $distributie + $bijdrage_energie + $accijns) * 1.06) * 100" | bc
)
