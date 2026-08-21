# Solarpark API Reference

Base URL: `https://portal.solarpark-online.com/ifms`

All requests require the header:
```
API-Key: <SCADA_API_KEY>
```

All dates use compact UTC format: `YYYYMMDDTHHMMSSz` (e.g. `20250901T000000Z`)

---

## Endpoints

### 1. GET /agents/:agent_id/sites

Returns all sites visible to the agent.

Agent ID used by this app: `4b5dc3b7-4ea5-4ed4-a32b-a78645085104`

**Response:** Array of site objects.

```json
[
  {
    "id": "25658d43-0ffd-42b4-a4e4-d3b808e85087",
    "name": "Danish Fields - T3",
    "state": "online",
    "siteTypeApcode": "Hybrid",
    "uri": "http://portal.solarpark-online.com/ifms/sites/25658d43-0ffd-42b4-a4e4-d3b808e85087",
    "properties": {
      "Timezone": "US/Central",
      "Latitude": "29.0194005",
      "Longitude": "-96.2358202",
      "City": "El Campo",
      "Country": "United States",
      "AddressStreet": "11000 Country Rd. 403",
      "AddressZIPCode": "77437",
      "TypeOfProject": "Production",
      "TypeOfPlant": "Grid-connected",
      "GridConnected": "Yes",
      "ACLoad": "Yes",
      "PlantDesigner": "Rosendin",
      "PlantInstaller": "Rosendin",
      "PlantOperator": "TOTAL ",
      "Portfolio": "TOTAL",
      "SubTypes": "PV,BESS,Hybrid",
      "NumOfTCPs": "74",
      "RecordingPeriod": "5m",
      "AvailableCalculationPeriods": "1s,1m,60m,1mo,Variant,1d,1y,5m",
      "Altitude": "1003",
      "TypicalUse": "Power station"
    },
    "enterprise": {
      "id": "fd054d7d-86c2-4c92-828f-747a68e68e0c",
      "name": "TotalEnergies Renewables USA, LLC",
      "uri": "http://portal.solarpark-online.com/ifms/enterprises/fd054d7d-86c2-4c92-828f-747a68e68e0c"
    }
  }
]
```

---

### 2. GET /sites/:site_id/segments?recursive=true

Returns all segments (inverter blocks, tracker groups, string groups, etc.) for a site.

**Response:** Array of segment objects.

```json
[
  {
    "id": "9e7df116-8854-11ee-a4ff-42010afa015a",
    "name": "Solar Inverter Block 023",
    "apcode": "ArrayGroup",
    "apcode_idx": 9,
    "uri": "http://portal.solarpark-online.com/ifms/segments/9e7df116-8854-11ee-a4ff-42010afa015a"
  },
  {
    "id": "b0aa659a-8854-11ee-a4ff-42010afa015a",
    "name": "Inverter module 023-1",
    "apcode": "InverterModule",
    "apcode_idx": 19,
    "uri": "http://portal.solarpark-online.com/ifms/segments/b0aa659a-8854-11ee-a4ff-42010afa015a"
  },
  {
    "id": "2f729116-9833-11ee-be18-42010afa015a",
    "name": "String DS-156.08",
    "apcode": "PanelGroup",
    "apcode_idx": 1088,
    "uri": "http://portal.solarpark-online.com/ifms/segments/2f729116-9833-11ee-be18-42010afa015a"
  }
]
```

---

### 3. GET /segments/:segment_id/mlocs

Returns all measurement locations (mlocs) for a segment.

**Response:** Array of mloc objects.

```json
[
  {
    "id": "d1f4e3ce-8854-11ee-a4ff-42010afa015a",
    "name": "Power Inverter Block AC",
    "apcode": "ArrayOutputPower",
    "sscode": null,
    "nameL1": null,
    "nameL2": null,
    "nameL3": null,
    "nameL4": null,
    "measurementTypeId": "3074ed0e-8264-11de-ad55-0090f586a869",
    "uri": "http://portal.solarpark-online.com/ifms/mlocs/d1f4e3ce-8854-11ee-a4ff-42010afa015a"
  },
  {
    "id": "5703af00-8855-11ee-a4ff-42010afa015a",
    "name": "Current roll",
    "apcode": "TrackerCurrentRoll",
    "sscode": null,
    "nameL1": null,
    "nameL2": null,
    "nameL3": null,
    "nameL4": null,
    "measurementTypeId": "3074ed1c-8264-11de-ad55-0090f586a869",
    "uri": "http://portal.solarpark-online.com/ifms/mlocs/5703af00-8855-11ee-a4ff-42010afa015a"
  }
]
```

---

### 4. GET /mlocs/:mloc_id

Returns a single mloc with its measurement sources embedded. Used to fetch measurement metadata.

**Response:** Single mloc object with `sources` array and parent `segment` info.

```json
{
  "id": "d1f4e3ce-8854-11ee-a4ff-42010afa015a",
  "name": "Power Inverter Block AC",
  "apcode": "ArrayOutputPower",
  "nameL1": null,
  "nameL2": null,
  "nameL3": null,
  "nameL4": null,
  "description": null,
  "rcv": false,
  "siteId": "25658d43-0ffd-42b4-a4e4-d3b808e85087",
  "measureType": {
    "id": "3074ed0e-8264-11de-ad55-0090f586a869",
    "apcode": "Power",
    "name": "Power",
    "dataType": "Float",
    "uri": "http://portal.solarpark-online.com/ifms/measureTypes/3074ed0e-8264-11de-ad55-0090f586a869"
  },
  "segment": {
    "id": "9e7df116-8854-11ee-a4ff-42010afa015a",
    "name": "Solar Inverter Block 023",
    "apcode": "ArrayGroup",
    "apcode_idx": 9,
    "uri": "http://portal.solarpark-online.com/ifms/segments/9e7df116-8854-11ee-a4ff-42010afa015a"
  },
  "monitor": null,
  "sources": [
    {
      "id": "d1f4e5b8-8854-11ee-a4ff-42010afa015a",
      "calcPeriod": "5m",
      "calcTimeSpanCount": 1,
      "calcTimeSpanMode": "fixed-time-span",
      "calcTypeApcode": "SumOfScalars",
      "engUnit": "kW",
      "manualIngest": false,
      "quality": null,
      "range": null,
      "date": "20250418T215300Z",
      "val": "2284.79834",
      "uri": "http://portal.solarpark-online.com/ifms/sources/d1f4e5b8-8854-11ee-a4ff-42010afa015a"
    }
  ]
}
```

---

### 5. POST /sites/sources/events

Bulk event fetch across one or more sites by measurement location apcode. Used by `Pf::EventDataService`.

**Request body:**
```json
{
  "siteIds": ["25658d43-0ffd-42b4-a4e4-d3b808e85087"],
  "startDate": "20250301T010000Z",
  "endDate": "20250301T010500Z",
  "measurementLocationApcodes": ["PPCActivePowerTr2"]
}
```

**Response:** Array of event objects.

```json
[
  {
    "siteId": "25658d43-0ffd-42b4-a4e4-d3b808e85087",
    "date": "20250301T010000Z",
    "measurementSourceId": "b8bcd7ae-8854-11ee-a4ff-42010afa015a",
    "val": "-618.5966186523438",
    "cpName": "1m",
    "measurementApcode": "PPCActivePowerTr2"
  },
  {
    "siteId": "25658d43-0ffd-42b4-a4e4-d3b808e85087",
    "date": "20250301T010100Z",
    "measurementSourceId": "b8bcd7ae-8854-11ee-a4ff-42010afa015a",
    "val": "-623.2684936523438",
    "cpName": "1m",
    "measurementApcode": "PPCActivePowerTr2"
  },
  {
    "siteId": "25658d43-0ffd-42b4-a4e4-d3b808e85087",
    "date": "20250301T010200Z",
    "measurementSourceId": "b8bcd7ae-8854-11ee-a4ff-42010afa015a",
    "val": "-620.5447998046875",
    "cpName": "1m",
    "measurementApcode": "PPCActivePowerTr2"
  }
]
```

---

### 6. GET /sources/:source_uuid/events?start_date=:start&end_date=:end

Per-source event fetch by UUID. Used by `Pf::EventDataService2` (called from `DataImportService`).

**Query params:**
- `start_date` — compact UTC date, e.g. `20250901T000000Z`
- `end_date` — compact UTC date, e.g. `20250902T000000Z`

**Response:** Array of event objects (same shape as endpoint 5).

```json
[
  {
    "siteId": "25658d43-0ffd-42b4-a4e4-d3b808e85087",
    "date": "20250901T000000Z",
    "measurementSourceId": "d1f4e5b8-8854-11ee-a4ff-42010afa015a",
    "val": "1842.3199462890625",
    "cpName": "5m",
    "measurementApcode": "ArrayOutputPower"
  },
  {
    "siteId": "25658d43-0ffd-42b4-a4e4-d3b808e85087",
    "date": "20250901T000500Z",
    "measurementSourceId": "d1f4e5b8-8854-11ee-a4ff-42010afa015a",
    "val": "1901.7744140625",
    "cpName": "5m",
    "measurementApcode": "ArrayOutputPower"
  }
]
```

---

## Error responses

| Status | Meaning |
|--------|---------|
| 401    | Invalid or missing API key |
| 404    | Resource not found |
| 200    | Success (even bulk endpoints return 200 with empty array `[]` if no data) |
