# **Bangalore Metro Mobility Insights Dashboard (R Shiny)**

An interactive dashboard built in **R Shiny** that turns Bangalore Metro (Namma Metro) ridership data into actionable mobility insights for last-mile operators such as **Rapido**.
The project uses two months of hourly station-level and OD-pair data to compute **proxy metrics** for pickup hotspots, directionality, peak load risk, weekend intensity, and OD corridor strength.

This work was completed as part of **MBA Data Visualisation coursework at MDI Gurgaon**.

---

## **Overview**

This project analyses commuter patterns in the Bangalore Metro system using hourly ridership and station-pair flow data.
The aim is to translate raw transit patterns into **business-ready insights** for mobility operators who rely on high-frequency, predictable movement patterns around metro stations.

The dashboard is fully interactive, allowing users to explore:

* Heatmaps of station activity
* Treemaps of strongest station linkages
* Directional flow patterns
* OD corridor matrices
* Daily station trends
* Profitability proxies

---

## **Project Objectives**

The dashboard answers practical mobility questions such as:

* Where should Rapido position captains for maximum pickups?
* Which stations behave like business hubs vs residential zones?
* Where is the highest risk of ride cancellation due to supply shortages?
* Which areas require weekend fleet ramp-up?
* What are the strongest travel corridors across the city?

---

## **Data Sources**

The project uses two datasets provided as CSV files:

1. **station-hourly.csv**
   Hourly ridership at each metro station.

2. **stationpair-hourly.csv**
   Hourly OD flows between every station pair (origin → destination).

Date coverage: **1 Aug 2025 to 30 Sep 2025**
Hours covered: **0–23**
Fields include ridership, day type, station names, and temporal information.

---

## **Business Context: Why Rapido?**

Rapido operates bike taxis and autos, making its business sensitive to:

* Metro-linked demand surges
* Last-mile connectivity gaps
* Location-specific directional flows
* Weekend leisure hotspots
* High-density commuter corridors

This dataset allows Rapido (or any mobility platform) to:

* Predict demand
* Place supply efficiently
* Reduce cancellations
* Improve ETAs
* Build multimodal products (Metro → Rapido auto/bike)

---

## **Proxy Metrics Explained**

Several **derived metrics (proxies)** were designed to interpret mobility demand.

---

### **1. Pickup Hotspots**

**What it measures:**
Stations with high median ridership during peak hours (8–10 AM, 5–7 PM).

**Logic:**
High footfall at specific hours means riders are exiting the metro simultaneously, creating dense clusters of pickup demand.

**Formula:**

```
Hotspot Score = Median(Peak-Hour Ridership)
```

---

### **2. Directionality Score**

**What it measures:**
Whether a station behaves like:

* A **residential origin** (AM outbound, PM inbound), or
* A **commercial/office destination** (AM inbound, PM outbound).

**Logic:**
If AM entries > AM exits, the station likely represents a residential zone.
If PM exits > PM entries, it behaves like a commercial hub.

**Formula:**

```
Directionality = (AM Inbound - AM Outbound) – (PM Inbound - PM Outbound)
```

---

### **3. Pickup Failure Risk (Peakiness)**

**What it measures:**
How sharply ridership spikes during peak hours compared to off-peak hours.

**Logic:**
A station with extreme peak surges but weak off-peak demand is more likely to face driver shortages → cancellations.

**Formula:**

```
Peakiness = Peak Ridership / Off-Peak Ridership
```

---

### **4. Weekend Intensity Score**

**What it measures:**
How much a station transforms into a leisure/shopping hotspot on weekends.

**Logic:**
Office stations collapse on weekends; leisure stations stay active.

**Formula:**

```
Weekend Intensity = Weekend Avg / Weekday Avg
```

---

### **5. OD Corridor Strength**

**What it measures:**
Station-pair routes with the highest interstation movement.

**Logic:**
High corridor flows indicate reliable commuter funnels, ideal for:

* Shuttle integrations
* Pooling
* Priority pricing
* Fleet staging

**Formula:**

```
Corridor Strength = Sum(Ridership from A → B)
```

---

## **Dashboard Features**

* **Interactive Heatmap**
  Hourly station activity by ridership share.

* **Treemap (Top Linked Stations)**
  Shows strongest OD connections for any chosen station.

* **Peak Pressure Chart**
  Identifies most congested stations during AM/PM rush hours.

* **Directionality Visualization**
  Residential vs commercial station behaviours.

* **Weekend Intensity View**
  Leisure-driven stations highlighted.

* **OD Corridor Matrix**
  Full interactive OD heatmap.

* **Station Trends**
  Daily ridership evolution.

* **Profitability Proxy**
  Ridership × Trip-length estimation to find high-value stations.

---

## **Installation**

Install required packages:

```r
install.packages(c(
  "shiny", "tidyverse", "plotly", "lubridate",
  "viridis", "tidyr", "dplyr"
))
```

---

## **How to Run**

Run the app locally:

```r
shiny::runApp("app.R")
```

Or open from RStudio by pressing **Run App**.

Ensure CSVs are placed correctly and file paths updated in the script.

---

## **Limitations**

* Only **2 months** of data; limited seasonal/event insight.
* No GPS-level locality data; proxies are used for mobility inference.
* Metro geography is assumed to approximate residential/work clusters.

---

## **License**

This project is open-sourced under the **MIT License**.
