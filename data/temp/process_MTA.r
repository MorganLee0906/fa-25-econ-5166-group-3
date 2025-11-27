library(data.table)
library(dplyr)
library(arrow)
library(ggplot2)
library(lubridate)

# Read raw data
df_25 <- fread("~/Downloads/MTA_Subway_Origin-Destination_Ridership_Estimate__Beginning_2025.csv")


# We found that data only provide average ridership of every weekday in every month.

df_24 <- fread("~/Downloads/MTA_Subway_Origin-Destination_Ridership_Estimate__2024_20250928.csv")


# Bind 2 years
df <- rbindlist(list(df_24, df_25), use.names = TRUE, fill = TRUE)

# Save data
write_parquet(df, "~/Documents/DataScience/data.parquet", compression = "snappy")
rm(list = ls())

# Open data
ds_new <- open_dataset("~/Documents/DataScience/data.parquet", format = "parquet")
ds_new <- ds_new %>%
    collect()

# Overall Trend
overall_trend <- ds_new %>%
    select(c(Year, Month, `Estimated Average Ridership`)) %>%
    mutate(
        YearMonth = ym(sprintf("%d%02d", Year, Month))
    ) %>%
    group_by(YearMonth) %>%
    summarise(Monthly_Ridership = sum(`Estimated Average Ridership`, na.rm = TRUE))

overall_trend %>%
    ggplot(aes(x = YearMonth, y = Monthly_Ridership)) +
    geom_line(size = 1) +
    geom_point(size = 2) +
    labs(
        title = "Monthly Ridership Trend (Overall)",
        x = "Month",
        y = "Estimated Average Ridership",
    ) +
    scale_x_date(
        date_breaks = "1 month",
        date_labels = "%Y-%m"
    ) +
    theme_minimal(base_size = 14) +
    theme(
        axis.text.x = element_text(angle = 45, hjust = 1)
    )

# Top 5. Trend
top5_routes <- stationSet %>%
    slice_head(n = 5)

top5_data <- ds_new %>%
    inner_join(top5_routes,
        by = c("Origin Station Complex Name", "Destination Station Complex Name")
    )

top5_data <- top5_data %>%
    select(c(Year, Month, `Day of Week`, `Hour of Day`, `Origin Station Complex Name`, `Destination Station Complex Name`, `Estimated Average Ridership`)) %>%
    mutate(
        YearMonth = ym(sprintf("%d%02d", Year, Month))
    )

monthly_trend <- top5_data %>%
    group_by(YearMonth, `Origin Station Complex Name`, `Destination Station Complex Name`) %>%
    summarise(Monthly_Ridership = sum(`Estimated Average Ridership`, na.rm = TRUE))


monthly_trend %>%
    mutate(Route = paste(`Origin Station Complex Name`, "→", `Destination Station Complex Name`)) %>%
    ggplot(aes(x = YearMonth, y = Monthly_Ridership, color = Route, group = Route)) +
    geom_line(size = 1) +
    geom_point(size = 2) +
    labs(
        title = "Monthly Ridership Trend (Top Routes)",
        x = "Month",
        y = "Estimated Average Ridership",
        color = "Route"
    ) +
    scale_x_date(
        date_breaks = "1 month",
        date_labels = "%Y-%m"
    ) +
    theme_minimal(base_size = 14) +
    theme(
        legend.position = "bottom",
        legend.direction = "horizontal",
        legend.box = "horizontal",
        legend.title = element_text(size = 10),
        legend.text = element_text(size = 9),
        axis.text.x = element_text(angle = 45, hjust = 1)
    ) +
    guides(color = guide_legend(nrow = 5))
