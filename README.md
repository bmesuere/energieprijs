# Energieprijs

Deze repository bevat
- een script om de energieprijs van Ecopower te berekenen
- een script dat een voorspelling van de Belgische EPEX spotprijzen voor de komende dagen ophaalt en omrekent naar Ecopower-prijzen
- een github action om deze prijzen en voorspellingen te publiceren via github pages.

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

## Spotprijs voorspelling

Het script in `epex_forecast.sh` haalt een voorspelling van de Belgische EPEX spotprijzen op via de gratis gehoste API van [EpexPredictor](https://github.com/b3nn0/EpexPredictor) (https://epexpredictor.batzill.com/). Dat is een LightGBM-model dat op basis van weersvoorspellingen, het ENTSO-E load forecast en gasprijzen de spotprijs tot 7 dagen vooruit voorspelt in kwartierresolutie (MAE ~1.8 ct/kWh voor België). De eigen fork [bmesuere/EpexPredictor](https://github.com/bmesuere/EpexPredictor) is gearchiveerd nu upstream België ondersteunt.

Het script rekent de voorspelde spotprijzen om naar Ecopower verbruiks- en injectieprijzen met dezelfde formules als `ecopower_dynamisch.sh` (de gedeelde constanten staan in `ecopower_constants.sh`). De output wordt om de twee uur gepubliceerd op https://energie.bartm.be/forecast.json, bewust als apart bestand zodat duidelijk is dat dit voorspellingen zijn en geen vastgestelde prijzen.

Het formaat is hetzelfde als dat van `ecopower.json` (met `raw_data`, `consumption_data` en `injection_data`), aangevuld met een `known_until` veld: prijzen vóór dat tijdstip zijn effectieve day-ahead marktprijzen, prijzen erna zijn modelvoorspellingen.

```json
{
  known_until: "2026-08-14 23:45:00",
  raw_data: [...],
  consumption_data: [...],
  injection_data: [...]
}
```
