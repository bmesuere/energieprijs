# Energieprijs

Deze repository bevat
- een script om de energieprijs van Ecopower te berekenen
- een submodule die een voorspelling doet van de Belgische EPEX spotprijzen voor de komende dagen
- een github action deze prijzen en voorspellingen te publiceren via github pages.

## Ecopower prijs - dynamisch tarief

Het script in `ecopower_dynamisch.sh` berekent de energieprijs voor een ecopower contract met dynamisch tarief in Oost-Vlaanderen. De output bevast zowel de ruwe spotprijs, als de prijs voor verbruik en injectie inclusief alle taksen en accijnzen. Het script wordt automatisch uitgevoerd via een github action en de output wordt gepubliceerd op https://energie.bartm.be/ecopower.json.

```json
{
  raw_data: [
    {
      time: "2025-10-17 00:00:00",
      price: 9.158
    },
    {
      time: "2025-10-17 00:15:00",
      price: 8.831
    },
    {
      time: "2025-10-17 00:30:00",
      price: 8.704
    },
    {
      time: "2025-10-17 00:45:00",
      price: 8.448
    },
    ...
  ],
  consumption_data: [
    {
      time: "2025-10-17 00:00:00",
      price: 23.387919600000004
    },
    {
      time: "2025-10-17 00:15:00",
      price: 23.034367200000002
    },
    {
      time: "2025-10-17 00:30:00",
      price: 22.897054800000003
    },
    {
      time: "2025-10-17 00:45:00",
      price: 22.620267600000005
    },
    ...
  ],
  injection_data: [
    ...
  ]
}
```

In Home Assistant kan je deze waarden eenvoudig toevoegen op volgende manier:

```yaml
rest:
  - resource: https://energie.bartm.be/ecopower.json
    scan_interval: 60
    headers:
      Accept: application/json
    sensor:
      - name: Ecopower Raw Price
        unique_id: ecopower_raw_price
        unit_of_measurement: "ct/kWh"
        state_class: measurement
        json_attributes:
          - raw_data
        value_template: >
          {% set ts = (now().replace(minute=(now().minute//15)*15, second=0, microsecond=0))
                        .strftime('%Y-%m-%d %H:%M:%S') %}
          {% set it = (value_json.raw_data | selectattr('time','eq', ts) | list | first) %}
          {{ it.price if it is not none else 'unknown' }}

      - name: Ecopower Consumption Price
        unique_id: ecopower_consumption_price
        unit_of_measurement: "ct/kWh"
        state_class: measurement
        json_attributes:
          - consumption_data
        value_template: >
          {% set ts = (now().replace(minute=(now().minute//15)*15, second=0, microsecond=0))
                        .strftime('%Y-%m-%d %H:%M:%S') %}
          {% set it = (value_json.consumption_data | selectattr('time','eq', ts) | list | first) %}
          {{ it.price if it is not none else 'unknown' }}

      - name: Ecopower Injection Price
        unique_id: ecopower_injection_price
        unit_of_measurement: "ct/kWh"
        state_class: measurement
        json_attributes:
          - injection_data
        value_template: >
          {% set ts = (now().replace(minute=(now().minute//15)*15, second=0, microsecond=0))
                        .strftime('%Y-%m-%d %H:%M:%S') %}
          {% set it = (value_json.injection_data | selectattr('time','eq', ts) | list | first) %}
          {{ it.price if it is not none else 'unknown' }}

template:
  - sensor:
      - name: "Ecopower Consumption Price €/kWh"
        unique_id: ecopower_consumption_price_eur_per_kwh
        unit_of_measurement: "€/kWh"
        state_class: measurement
        icon: mdi:currency-eur
        availability: "{{ is_number(states('sensor.ecopower_consumption_price')) }}"
        state: >
          {{ (states('sensor.ecopower_consumption_price') | float / 100) | round(5) }}

      - name: "Ecopower Injection Price €/kWh"
        unique_id: ecopower_injection_price_eur_per_kwh
        unit_of_measurement: "€/kWh"
        state_class: measurement
        icon: mdi:currency-eur
        availability: "{{ is_number(states('sensor.ecopower_injection_price')) }}"
        state: >
          {{ (states('sensor.ecopower_injection_price') | float / 100) | round(5) }}
```

## Spotprijs predictie

De submodule `EpexPredictor` bevat een machine learning model dat de EPEX spotprijzen voor België voorspelt op basis van weersvoorspellingen. Het model is getraind met historische weerdata en prijsdata van EPEX. Voor meer informatie over de werking van het model, zie de README in de submodule.

Deze voorspellingen worden automatisch om de twee uur gegenereerd via een github action en gepubliceerd op https://energie.bartm.be/forecast.json.

In EVCC, een open-source EV laadcontroller, kan je deze voorspellingen gebruiken om slim te laden op basis van de verwachte energieprijzen. Je kan hiervoor de volgende configuratie toevoegen aan je `evcc.yaml` bestand. Je past wel best de constanten in de formules aan om je lokale belastingen, heffingen en andere kosten weer te geven.

```yaml
tariffs:
  grid:
    type: custom
    forecast:
      source: http
      uri: https://energie.bartm.be/forecast.json
      jq: "map(.value = ((1.02 * (.value / 100) + 0.004 + 0.1232292) * 1.06)) | tostring"
  feedin:
    type: custom
    forecast:
      source: http
      uri: https://energie.bartm.be/forecast.json
      jq: "map(.value = (0.98 * (.value / 100) - 0.015)) | tostring"
```
