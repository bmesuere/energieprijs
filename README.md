# Energieprijs

Dit script berekent de energie- en injectieprijs van (mijn) ecopower contract van de lopende maand.

Alle taksen en accijnzen worden in rekening gebracht (voor Oost-Vlaanderen).

Het script wordt elke nacht uitgevoerd en het resultaat wordt beschikbaar gesteld op https://energie.bartm.be/.

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
