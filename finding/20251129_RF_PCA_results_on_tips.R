



## Author: Tung-Yen Wu
## Date last edited: 2025/11/28
## Notes: Visualize the synthesize tips data from /finding/20251129_RF_PCA_on_tips
## The results is saved in /findings/hvfhv/fee

## ---- 0. 套件 & 工作目錄 ----
library(dplyr)
library(lubridate)
library(ggplot2)
library(tidyr)

setwd("C:/Users/hp/Desktop/ECON5166-final_project")

## ---- 0-1. 讀取 hourly_predictions_tips.csv ----
tips_file <- "fee/random_forest_hourly/hourly_predictions_tips.csv"
pred_df <- read.csv(tips_file)

str(pred_df)  # 看一下有哪些欄位，確認名字

## ---- 1. 三個期間的 R^2 計算 ----
# 這裡只建立一個 r2_data，不去改 pred_df 本身（避免影響後面 weekly 圖）
library(dplyr)
library(lubridate)

pred_df <- pred_df %>%
  mutate(
    date = as.Date(date)   # 如果原本 date 長得像 "2024-07-01"
  )
r2_data <- pred_df %>%
  mutate(
    period_group = case_when(
      # ⭐ In-sample：2024-04-01 ~ 2024-12-31（和你 RF 訓練區間一致）
      date >= as.Date("2024-04-01") & date <= as.Date("2024-12-31") ~ "in_sample_2024_04_12",
      # ⭐ Out-of-sample：2024-01-01 ~ 2024-03-31（訓練前 3 個月）
      date >= as.Date("2024-01-01") & date <  as.Date("2024-04-01") ~ "out_sample_2024_01_03",
      # ⭐ Treated-sample：2025-01-01 ~ 2025-03-31（你說要重點看的 2025/01~03）
      date >= as.Date("2025-01-01") & date <  as.Date("2025-04-01") ~ "treated_sample_2025_01_03",
      TRUE ~ NA_character_
    )
  ) %>%
  filter(!is.na(period_group))

# 算各期間 R^2
r2_df <- r2_data %>%
  group_by(period_group) %>%
  summarise(
    SSE = sum((y - y_hat)^2),
    SST = sum((y - mean(y))^2),
    R2  = 1 - SSE / SST,
    .groups = "drop"
  ) %>%
  mutate(
    label = case_when(
      period_group == "in_sample_2024_04_12"      ~ "In-sample (2024-04 to 2024-12)",
      period_group == "out_sample_2024_01_03"     ~ "Out-of-sample (2024-01 to 2024-03)",
      period_group == "treated_sample_2025_01_03" ~ "Treated-sample (2025-01 to 2025-03)",
      TRUE ~ period_group
    )
  )

# 存成 .txt
out_dir <- "fee/random_forest_hourly"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

write.table(
  r2_df,
  file = file.path(out_dir, "R2_by_period.txt"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

## ---- 2. R^2 柱狀圖 ----
r2_df$label <- factor(
  r2_df$label,
  levels = c(
    "Out-of-sample (2024-01 to 2024-03)",
    "In-sample (2024-04 to 2024-12)",
    "Treated-sample (2025-01 to 2025-03)"
  )
)

p_r2 <- ggplot(r2_df, aes(x = label, y = R2)) +
  geom_col() +
  geom_text(aes(label = round(R2, 3)), vjust = -0.3, size = 3) +
  ylim(0, 1) +
  labs(
    title = "R-squared by Period",
    x = "",
    y = "R-squared"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1, size =6))

ggsave(
  filename = file.path(out_dir, "R2_by_period_bar.png"),
  plot = p_r2,
  width = 4,
  height = 4,
  dpi = 300
)


## ---- 3. Weekly mean y & y_hat with 95% CI (2024-07 ~ 2025-06) ----
weekly_df <- pred_df %>%
  filter(date >= as.Date("2024-07-01"),
         date <= as.Date("2025-06-30")) %>%
  mutate(
    week_start = floor_date(date, unit = "week", week_start = 1)
  ) %>%
  group_by(week_start) %>%
  summarise(
    n         = n(),
    y_mean    = mean(y),
    y_sd      = sd(y),
    yhat_mean = mean(y_hat),
    yhat_sd   = sd(y_hat),
    .groups   = "drop"
  ) %>%
  mutate(
    y_se       = y_sd / sqrt(n),
    yhat_se    = yhat_sd / sqrt(n),
    y_lower    = y_mean - 1.96 * y_se,
    y_upper    = y_mean + 1.96 * y_se,
    yhat_lower = yhat_mean - 1.96 * yhat_se,
    yhat_upper = yhat_mean + 1.96 * yhat_se
  )

weekly_long <- weekly_df %>%
  transmute(
    week_start,
    actual_mean     = y_mean,
    actual_lower    = y_lower,
    actual_upper    = y_upper,
    predicted_mean  = yhat_mean,
    predicted_lower = yhat_lower,
    predicted_upper = yhat_upper
  ) %>%
  pivot_longer(
    cols = -week_start,
    names_to = c("series", "stat"),
    names_sep = "_",
    values_to = "value"
  ) %>%
  pivot_wider(
    names_from = stat,
    values_from = value
  ) %>%
  mutate(
    series = factor(series,
                    levels = c("actual", "predicted"),
                    labels = c("Actual", "Predicted"))
  )

cutoff_date <- as.Date("2025-01-05")  # 你要的 cutoff（1 月第一週的某一天）

p_week_ci <- ggplot(weekly_long,
                    aes(x = week_start, y = mean,
                        color = series, fill = series)) +
  geom_line() +
  geom_ribbon(aes(ymin = lower, ymax = upper),
              alpha = 0.15, color = NA) +
  geom_vline(xintercept = cutoff_date,
             color = "blue", linetype = "dashed", linewidth = 0.6) +
  scale_x_date(
    date_breaks = "1 month",
    date_labels = "%Y-%m"
  ) +
  labs(
    title = "Weekly Mean Actual vs Predicted with 95% CI (2024-07 to 2025-06)",
    subtitle = "Vertical blue line indicates the first week of January 2025 (cutoff)",
    x = "Week start date",
    y = "Hourly trips (weekly mean)",
    color = "Series",
    fill  = "Series"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  filename = file.path(out_dir, "weekly_mean_y_vs_yhat_95CI_2024-07_to_2025-06.png"),
  plot = p_week_ci,
  width = 10,
  height = 5,
  dpi = 300
)

## ---- 3. Weekly mean y & y_hat with 95% CI (2024-07 ~ 2025-06) ----
weekly_df <- pred_df %>%
  filter(date >= as.Date("2024-07-01"),
         date <= as.Date("2025-06-30")) %>%
  mutate(
    week_start = floor_date(date, unit = "week", week_start = 1)
  ) %>%
  group_by(week_start) %>%
  summarise(
    n         = n(),
    y_mean    = mean(y),
    y_sd      = sd(y),
    yhat_mean = mean(y_hat),
    yhat_sd   = sd(y_hat),
    .groups   = "drop"
  ) %>%
  mutate(
    y_se       = y_sd / sqrt(n),
    yhat_se    = yhat_sd / sqrt(n),
    y_lower    = y_mean - 1.96 * y_se,
    y_upper    = y_mean + 1.96 * y_se,
    yhat_lower = yhat_mean - 1.96 * yhat_se,
    yhat_upper = yhat_mean + 1.96 * yhat_se
  )

weekly_long <- weekly_df %>%
  transmute(
    week_start,
    actual_mean     = y_mean,
    actual_lower    = y_lower,
    actual_upper    = y_upper,
    predicted_mean  = yhat_mean,
    predicted_lower = yhat_lower,
    predicted_upper = yhat_upper
  ) %>%
  pivot_longer(
    cols = -week_start,
    names_to = c("series", "stat"),
    names_sep = "_",
    values_to = "value"
  ) %>%
  pivot_wider(
    names_from = stat,
    values_from = value
  ) %>%
  mutate(
    series = factor(series,
                    levels = c("actual", "predicted"),
                    labels = c("Actual", "Predicted"))
  )

cutoff_date <- as.Date("2025-01-05")  # 你要的 cutoff（1 月第一週的某一天）

p_week_ci <- ggplot(weekly_long,
                    aes(x = week_start, y = mean,
                        color = series, fill = series)) +
  geom_line() +
  geom_ribbon(aes(ymin = lower, ymax = upper),
              alpha = 0.15, color = NA) +
  geom_vline(xintercept = cutoff_date,
             color = "blue", linetype = "dashed", linewidth = 0.6) +
  scale_x_date(
    date_breaks = "1 month",
    date_labels = "%Y-%m"
  ) +
  labs(
    title = "Weekly Mean Actual vs Predicted with 95% CI (2024-07 to 2025-06)",
    subtitle = "Vertical blue line indicates the first week of January 2025 (cutoff)",
    x = "Week start date",
    y = "Hourly trips (weekly mean)",
    color = "Series",
    fill  = "Series"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

ggsave(
  filename = file.path(out_dir, "weekly_mean_y_vs_yhat_95CI_2024-07_to_2025-06.png"),
  plot = p_week_ci,
  width = 10,
  height = 5,
  dpi = 300
)