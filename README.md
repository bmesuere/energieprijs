# Energieprijs

Dit script berekent de energie- en injectieprijs van (mijn) Flow contract bij Engie van de lopende maand. Aangezien er een gemiddelde van dagprijzen gebruikt wordt, is deze prijs pas op het einde van de maand definitief.

Alle taksen en accijnzen worden in rekening gebracht (voor Oost-Vlaanderen).

Het script wordt elke nacht uitgevoerd en het resultaat wordt beschikbaar gesteld op https://energie.bartm.be/.

In Home Assistant kan je deze waarden eenvoudig toevoegen op volgende manier:

```yaml
rest:
  - resource: https://energie.bartm.be
    sensor:
      - name: "Injection Price"
        unit_of_measurement: "€/kWh"
        value_template: "{{ value_json.injection_price }}"
      - name: Electricity Price
        unit_of_measurement: "€/kWh"
        value_template: "{{ value_json.electricity_price }}"
```
