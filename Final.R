# ================================================================
# INTERACTIVE RAPIDO INSIGHTS DASHBOARD FOR BANGALORE METRO
# ================================================================

library(shiny)
library(tidyverse)
library(lubridate)
library(plotly)
library(viridis)
library(tidyr)
library(dplyr)

# ---------------------------------------------------------
# Load data
# ---------------------------------------------------------
hourly <- read_delim("C:/Users/siddh/Downloads/DV Assignment/station-hourly.csv", delim = ";")

station_pair_hourly <- read_delim("C:/Users/siddh/Downloads/DV Assignment/stationpair-hourly.csv", delim = ";") %>%
  rename(
    From_Station = `Origin Station`,
    To_Station   = `Destination Station`
  ) %>%
  mutate(Date = as.Date(Date))

# ---------------------------------------------------------
# Add weekday/weekend feature
# ---------------------------------------------------------
add_temporal <- function(df) {
  df %>%
    mutate(
      wday = wday(Date, label = TRUE, week_start = 1),
      day_type = if_else(wday %in% c("Sat", "Sun"), "Weekend", "Weekday")
    )
}

hourly <- add_temporal(hourly)
station_pair_hourly <- add_temporal(station_pair_hourly)

# Keep only Aug–Sep period (2 months)
hourly <- hourly %>% filter(Date >= as.Date("2025-08-01"), Date <= as.Date("2025-09-30"))
station_pair_hourly <- station_pair_hourly %>% filter(Date >= as.Date("2025-08-01"), Date <= as.Date("2025-09-30"))

# ================================================================
# BUILD DATA FOR HEATMAP (unchanged from your earlier code)
# ================================================================
origin_avg <- station_pair_hourly %>%
  group_by(From_Station, day_type, Hour, Date) %>%
  summarise(total_r = sum(Ridership), .groups="drop") %>%
  rename(Station = From_Station)

destination_avg <- station_pair_hourly %>%
  group_by(To_Station, day_type, Hour, Date) %>%
  summarise(total_r = sum(Ridership), .groups="drop") %>%
  rename(Station = To_Station)

combined <- bind_rows(origin_avg, destination_avg) %>%
  group_by(Station, day_type, Hour, Date) %>%
  summarise(total_r = sum(total_r), .groups="drop")

median_r <- combined %>%
  group_by(Station, day_type, Hour) %>%
  summarise(median_r = median(total_r), .groups="drop")

daily_totals <- median_r %>%
  group_by(Station, day_type) %>%
  summarise(total = sum(median_r), .groups="drop")

heatmap_df <- median_r %>%
  left_join(daily_totals, by=c("Station", "day_type")) %>%
  mutate(ratio = ifelse(total == 0, 0, median_r / total)) %>%
  complete(Hour = 0:23, Station, day_type, fill = list(ratio = 0, median_r = 0))

station_order <- heatmap_df %>%
  filter(Hour %in% c(8:10, 17:19)) %>%
  group_by(Station) %>%
  summarise(pk = mean(median_r), .groups="drop") %>%
  arrange(desc(pk)) %>%
  pull(Station)


# ================================================================
# RAPIDO METRIC COMPUTATION
# ================================================================

# ----------------------------
# 1. RAPIDO PICKUP HOTSPOTS
# ----------------------------
pickup_hotspots <- combined %>%
  filter(Hour %in% c(8:10, 17:19)) %>%
  group_by(Station) %>%
  summarise(
    peak_load = mean(total_r),
    weekend_load = mean(total_r[day_type=="Weekend"]),
    .groups="drop"
  ) %>%
  replace_na(list(weekend_load=0)) %>%
  arrange(desc(peak_load))

# ----------------------------
# 2. DIRECTIONALITY (Residential vs Office)
# ----------------------------
directionality <- combined %>%
  group_by(Station) %>%
  summarise(
    morning_inbound  = sum(total_r[Hour %in% 8:10]),
    evening_outbound = sum(total_r[Hour %in% 17:19]),
    .groups="drop"
  ) %>%
  mutate(
    dir_ratio = (evening_outbound + 1)/(morning_inbound + 1),
    category = case_when(
      dir_ratio > 1.3 ~ "Residential Zone",
      dir_ratio < 0.8 ~ "Office Zone",
      TRUE ~ "Mixed"
    )
  ) %>%
  arrange(desc(dir_ratio))

# ----------------------------
# 3. PICKUP FAILURE RISK
# ----------------------------
pickup_risk <- combined %>%
  group_by(Station) %>%
  summarise(
    peak = mean(total_r[Hour %in% c(8:10,17:19)]),
    offpeak = mean(total_r[Hour %in% 11:16]),
    .groups="drop"
  ) %>%
  mutate(
    peakness = peak/(offpeak+1),
    risk = case_when(
      peakness>3 ~ "High",
      peakness>1.5 ~ "Medium",
      TRUE ~ "Low"
    )
  ) %>%
  arrange(desc(peakness))

# ----------------------------
# 4. WEEKEND INTENSITY (WPS/WDR/WIS)
# ----------------------------
weekend_metrics <- combined %>%
  group_by(Station, day_type) %>%
  summarise(peak = max(total_r), total=sum(total_r), .groups="drop") %>%
  pivot_wider(names_from = day_type, values_from = c(peak,total), values_fill=0) %>%
  mutate(
    WDR = peak_Weekend/(peak_Weekday+1),
    WPS = peak_Weekend,
    WIS = 0.5*scales::rescale(WPS) + 0.5*scales::rescale(WDR)
  ) %>%
  arrange(desc(WIS))

# ----------------------------
# 5. REVENUE OPPORTUNITY (Ridership × Trip-Length Proxy × WIS)
# ----------------------------
trip_len_proxy <- station_pair_hourly %>%
  group_by(From_Station) %>%
  summarise(avg_len = mean(Ridership),
            .groups="drop")

revenue_score <- hourly %>%
  group_by(Station) %>%
  summarise(base = sum(Ridership), .groups="drop") %>%
  left_join(trip_len_proxy, by=c("Station"="From_Station")) %>%
  left_join(weekend_metrics %>% select(Station, WIS), by="Station") %>%
  mutate(
    avg_len = replace_na(avg_len,0),
    WIS = replace_na(WIS,0),
    score = base*(avg_len+1)*(WIS+0.1)
  ) %>%
  arrange(desc(score))


# ================================================================
# UI
# ================================================================
ui <- fluidPage(
  
  titlePanel("Interactive Bangalore Metro – Rapido Insights"),
  
  tabsetPanel(
    
    # -------------------------
    # 1. HEATMAP
    # -------------------------
    tabPanel("Station Heatmap",
             sidebarLayout(
               sidebarPanel(
                 selectInput("day_sel", "Select Day Type:",
                             choices=c("Weekday","Weekend"))
               ),
               mainPanel(plotlyOutput("heatmap", height="900px"))
             )
    ),
    
    # -------------------------
    # 2. TREEMAP
    # -------------------------
    tabPanel("Treemap",
             sidebarLayout(
               sidebarPanel(
                 selectInput("station_sel","Choose a Station:",
                             choices=sort(unique(c(station_pair_hourly$From_Station,
                                                   station_pair_hourly$To_Station)))))
               ,
               mainPanel(plotlyOutput("treemap",height="800px"))
             )
    ),
    
    # -------------------------
    # RAPIDO INSIGHTS SECTION
    # -------------------------
    
    tabPanel("Rapido Pickup Hotspots", plotlyOutput("r_hotspots",height="900px")),
    tabPanel("Directionality (Office vs Residential)", plotlyOutput("r_direction",height="900px")),
    tabPanel("Pickup Failure Risk", plotlyOutput("r_risk",height="900px")),
    tabPanel("Weekend Intensity (WPS/WDR/WIS)", plotlyOutput("r_weekend",height="900px")),
    tabPanel("Revenue Opportunity Score", plotlyOutput("r_revenue",height="900px")),
    
    # -------------------------
    # 6. OD CORRIDORS
    # -------------------------
    tabPanel("OD Corridors", plotlyOutput("corridors",height="900px")),
    
    # -------------------------
    # 7. TRENDS
    # -------------------------
    tabPanel("Trends",
             sidebarLayout(
               sidebarPanel(selectInput("trend_station","Station:",
                                        choices=sort(unique(hourly$Station)))),
               mainPanel(plotlyOutput("station_trends",height="600px"))
             )
    )
  )
)


# ================================================================
# SERVER
# ================================================================
server <- function(input, output, session) {
  
  # ---------------------------------------------------------
  # HEATMAP (unchanged)
  # ---------------------------------------------------------
  output$heatmap <- renderPlotly({
    df <- heatmap_df %>% filter(day_type == input$day_sel)
    p <- ggplot(df,
                aes(x=Hour, y=factor(Station,levels=rev(station_order)),
                    fill=ratio,
                    text=paste0(
                      "<b>Station:</b> ",Station,"<br>",
                      "<b>Hour:</b> ",Hour,":00<br>",
                      "<b>Ridership Share:</b> ", scales::percent(ratio)
                    ))) +
      geom_tile() +
      scale_fill_viridis(option="plasma") +
      theme_minimal()
    ggplotly(p, tooltip="text")
  })
  
  # ---------------------------------------------------------
  # TREEMAP (unchanged)
  # ---------------------------------------------------------
  output$treemap <- renderPlotly({
    df <- station_pair_hourly %>%
      filter(From_Station==input$station_sel | To_Station==input$station_sel) %>%
      mutate(other_station = if_else(From_Station==input$station_sel,To_Station,From_Station)) %>%
      group_by(other_station) %>%
      summarise(total=sum(Ridership), .groups="drop")
    
    plot_ly(
      df,
      type="treemap",
      labels=~other_station,
      parents=NA,
      values=~total,
      marker=list(colors=~total, colorscale="Inferno")
    )
  })
  
  
  # =============================================================
  # RAPIDO INSIGHT VISUALS
  # =============================================================
  
  # ----------------------------
  # 1. RAPIDO PICKUP HOTSPOTS
  # ----------------------------
  output$r_hotspots <- renderPlotly({
    df <- pickup_hotspots
    plot_ly(df,
            x=~peak_load,
            y=~reorder(Station,peak_load),
            type="bar",
            orientation="h",
            marker=list(color=~peak_load, colorscale="Viridis")) %>%
      layout(title="Rapido Pickup Hotspots (Peak-Hour Activity)")
  })
  
  # ----------------------------
  # 2. DIRECTIONALITY
  # ----------------------------
  output$r_direction <- renderPlotly({
    df <- directionality
    plot_ly(df,
            x=~dir_ratio,
            y=~reorder(Station,dir_ratio),
            type="bar",
            orientation="h",
            marker=list(color=~dir_ratio, colorscale="RdBu")) %>%
      layout(title="Directionality: Residential (>1.3) vs Office (<0.8)")
  })
  
  # ----------------------------
  # 3. PICKUP FAILURE RISK
  # ----------------------------
  output$r_risk <- renderPlotly({
    df <- pickup_risk
    plot_ly(df,
            x=~peakness,
            y=~reorder(Station,peakness),
            type="bar",
            orientation="h",
            marker=list(color=~peakness, colorscale="Inferno")) %>%
      layout(title="Pickup Failure Risk (Peakiness = Peak/Offpeak)")
  })
  
  # ----------------------------
  # 4. WEEKEND INTENSITY SCATTER
  # ----------------------------
  output$r_weekend <- renderPlotly({
    df <- weekend_metrics
    plot_ly(df,
            x=~WPS,
            y=~WDR,
            text=~Station,
            mode="markers",
            type="scatter",
            marker=list(size=12, color=~WIS, colorscale="Plasma")) %>%
      layout(title="Weekend Intensity (WPS vs WDR, color=WIS)",
             xaxis=list(title="Weekend Peak Strength (WPS)"),
             yaxis=list(title="Weekend Demand Ratio (WDR)"))
  })
  
  # ----------------------------
  # 5. REVENUE OPPORTUNITY SCORE
  # ----------------------------
  output$r_revenue <- renderPlotly({
    df <- revenue_score
    plot_ly(df,
            x=~score,
            y=~reorder(Station,score),
            type="bar",
            orientation="h",
            marker=list(color=~score, colorscale="Viridis")) %>%
      layout(title="Revenue Opportunity Score (Evening × Trip Length × WIS)")
  })
  
  # ---------------------------------------------------------
  # 6. OD CORRIDOR MATRIX (same as earlier)
  # ---------------------------------------------------------
  output$corridors <- renderPlotly({
    od_matrix <- station_pair_hourly %>%
      group_by(From_Station, To_Station) %>%
      summarise(total = sum(Ridership), .groups="drop") %>%
      pivot_wider(names_from=To_Station, values_from=total, values_fill = 0)
    
    plot_ly(
      x=colnames(od_matrix)[-1],
      y=od_matrix$From_Station,
      z=as.matrix(od_matrix[,-1]),
      type="heatmap",
      colorscale="Inferno"
    )
  })
  
  # ---------------------------------------------------------
  # 7. TRENDS (unchanged)
  # ---------------------------------------------------------
  output$station_trends <- renderPlotly({
    df <- hourly %>%
      filter(Station==input$trend_station) %>%
      group_by(Date) %>%
      summarise(total=sum(Ridership))
    plot_ly(df, x=~Date,y=~total,type="scatter",mode="lines+markers")
  })
  
}

shinyApp(ui, server)
