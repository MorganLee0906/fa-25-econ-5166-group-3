

## Author: Tung-Yen Wu
## Date last edited: 2025/11/28
## Notes: This script utilizes the hvfhv data from 2024/01~2025/10 to evaluate the policy effect of congestion fee.
##        The main algorithm is to Random Forest to synthesize the counterfactual (control) group of tips data, then the treatment effect can be identified.
##        To see the concepts of the algorithm, please go to /findings/hvfhv/model
## To excute this code, please ensure you have download the  hvfhv data from 2024/01~2025/10, the code for download can be found in /data/code/Extract data.R,
##                      and the list of treated locations, the file is  /data/processed/2025 Congestion Pricing – Affected TLC LocationID List.txt
## The results is saved in /findings/hvfhv/fee

## ---- 套件 ----
if (!requireNamespace("arrow", quietly = TRUE)) install.packages("arrow")
if (!requireNamespace("dplyr", quietly = TRUE)) install.packages("dplyr")
if (!requireNamespace("lubridate", quietly = TRUE)) install.packages("lubridate")
if (!requireNamespace("ggplot2", quietly = TRUE)) install.packages("ggplot2")
if (!requireNamespace("tidyr", quietly = TRUE)) install.packages("tidyr")
if (!requireNamespace("randomForest", quietly = TRUE)) install.packages("randomForest")
if (!requireNamespace("irlba", quietly = TRUE)) install.packages("irlba")
if (!requireNamespace("Matrix", quietly = TRUE)) install.packages("Matrix")

library(arrow)
library(dplyr)
library(lubridate)
library(ggplot2)
library(tidyr)
library(randomForest)
library(irlba)
library(Matrix)

## ---- 1. 設定工作目錄 ----
setwd("C:/Users/hp/Desktop/ECON5166-final_project")

## ---- 2. 讀取 treated LocationID 清單 ----
treated_file <- "2025 Congestion Pricing – Affected TLC LocationID List.txt"
treated_ids  <- scan(treated_file, what = integer(), quiet = TRUE)

## ---- 3. 讀取 2024-01 ~ 2024-12 & 2025-01 ~ 2025-06 fhvhv 資料（方案 A：只讀必要欄位）----
months_2024 <- sprintf("2024-%02d", 1:12)
months_2025 <- sprintf("2025-%02d", 1:6)
months_all  <- c(months_2024, months_2025)

data_files  <- file.path("data",
                         paste0("fhvhv_tripdata_", months_all, ".parquet"))

# 只讀會用到的欄位，減少記憶體壓力
needed_cols <- c(
  "pickup_datetime",
  "PULocationID", "DOLocationID",
  "tips",
  "trip_miles", "trip_time",
  "base_passenger_fare", "tolls"
)

trips_raw <- lapply(
  data_files,
  function(f) read_parquet(f, col_select = needed_cols)
) |>
  bind_rows()

## ---- 3a. 確保 pickup_datetime 已是 POSIXct，不在 mutate 裡重轉 ----
if (!inherits(trips_raw$pickup_datetime, "POSIXct")) {
  trips_raw$pickup_datetime <- as.POSIXct(
    trips_raw$pickup_datetime,
    tz = "America/New_York"
  )
} else {
  # 若已是 POSIXct，只設定時區
  attr(trips_raw$pickup_datetime, "tzone") <- "America/New_York"
}

## ---- 4. 處理時間欄位、只保留平日 ----
trips <- trips_raw %>%
  dplyr::filter(!is.na(pickup_datetime)) %>%
  dplyr::mutate(
    datetime_hour = lubridate::floor_date(pickup_datetime, unit = "hour"),
    date         = as.Date(pickup_datetime),
    year         = lubridate::year(pickup_datetime),
    month        = lubridate::month(pickup_datetime),
    day          = lubridate::day(pickup_datetime),
    hour         = lubridate::hour(pickup_datetime),
    dow          = lubridate::wday(pickup_datetime, week_start = 1),  # 1 = Monday
    is_weekday   = dow <= 5,
    treated_loc  = DOLocationID %in% treated_ids
  ) %>%
  dplyr::filter(is_weekday)

## ---- 5. 每小時 target y = treated_loc 的「average tips」----
# 「該小時所有 DOLocationID ∈ treated_ids 的 trip 的平均 tips」
hourly_y <- trips %>%
  dplyr::group_by(datetime_hour) %>%
  dplyr::summarise(
    y = mean(tips[treated_loc], na.rm = TRUE),   # 平均 tips（只看 treated_loc）
    .groups = "drop"
  )

## ---- 6. 建立每小時時間資訊（for train/test split & dummy）----
time_info <- trips %>%
  dplyr::transmute(
    datetime_hour = datetime_hour,
    date          = date,
    hour_of_day   = hour,
    day_of_month  = day,
    month         = month,
    dow           = dow
  ) %>%
  dplyr::distinct(datetime_hour, .keep_all = TRUE) %>%
  dplyr::arrange(datetime_hour) %>%
  dplyr::mutate(
    row_id   = dplyr::row_number(),
    # 訓練期 = 2024/04/01 ~ 2024/12/31
    is_train = (date >= as.Date("2024-04-01") & date <= as.Date("2024-12-31"))
  )

## ---- 7. 建立 non-treated flow 的 long format（所有期間）----
other_pair_all <- trips %>%
  dplyr::filter(!treated_loc) %>%
  dplyr::mutate(
    feature = paste(PULocationID, DOLocationID, sep = "_")
  ) %>%
  dplyr::group_by(datetime_hour, feature) %>%
  dplyr::summarise(
    trips_cnt = dplyr::n(),
    .groups   = "drop"
  )

## ---- 8. 定義 training hours & feature set（只用 train period 來定義特徵）----
train_hours <- time_info %>%
  dplyr::filter(is_train) %>%
  dplyr::select(datetime_hour)

# 在訓練期出現過的 (PU, DO) feature
train_features <- other_pair_all %>%
  dplyr::inner_join(train_hours, by = "datetime_hour") %>%
  dplyr::distinct(feature) %>%
  dplyr::arrange(feature) %>%
  dplyr::mutate(col_id = dplyr::row_number())

## ---- 9. 把所有期間 non-treated flow 映射成 sparse matrix（row=hour, col=feature）----
other_all_idx <- other_pair_all %>%
  dplyr::inner_join(train_features, by = "feature") %>%
  dplyr::inner_join(time_info %>% dplyr::select(datetime_hour, row_id),
                    by = "datetime_hour")

n_hours <- nrow(time_info)
p_feats <- nrow(train_features)   # 原始維度（feature 數）

X_all_sparse <- Matrix::sparseMatrix(
  i    = other_all_idx$row_id,
  j    = other_all_idx$col_id,
  x    = other_all_idx$trips_cnt,
  dims = c(n_hours, p_feats)
)

## ---- 10. 只用 train rows 做 PCA（fast PCA via irlba）----
train_rows <- which(time_info$is_train)

X_train_sparse <- X_all_sparse[train_rows, ]

K <- 10  # 縮減後維度
cat("Running fast PCA with irlba on training period...\n")
pca_res <- irlba::prcomp_irlba(
  X_train_sparse,
  n      = K,
  center = TRUE,
  scale. = TRUE
)
cat("Fast PCA finished.\n")

# 解釋變異（訓練期）
var_explained <- pca_res$sdev^2 / sum(pca_res$sdev^2)
cum_var_K <- cumsum(var_explained[1:K])

pc_var_df <- data.frame(
  PC          = 1:K,
  VarExpl     = var_explained[1:K],
  CumVarExpl  = cum_var_K
)

out_dir <- "fee/random_forest_hourly"
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# PCA 累積解釋變異圖
p_pc <- ggplot(pc_var_df, aes(x = PC, y = CumVarExpl)) +
  geom_line() +
  geom_point() +
  scale_x_continuous(breaks = seq(1, K, by = 1)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Cumulative Variance Explained by Principal Components",
    x = "Principal Component (PC)",
    y = "Cumulative Variance Explained"
  ) +
  theme(
    plot.title = element_text(size = 8)
  )

ggsave(
  filename = file.path(out_dir, "PC1_K_cumulative_variance.png"),
  plot = p_pc,
  width = 5,
  height = 5,
  dpi = 300
)

## ---- 10b. 輸出 PCA summary 到 .txt ----
pca_summary_file <- file.path(out_dir, "PCA_summary.txt")

cat(
  "Original_dimension:", p_feats, "\n",
  "Reduced_dimension:", K, "\n\n",
  file = pca_summary_file
)

write.table(
  pc_var_df,
  file = pca_summary_file,
  sep = "\t",
  row.names = FALSE,
  quote = FALSE,
  append = TRUE
)

## ---- 11. 用 PCA 模型算「所有期間」的 PC scores（dense; 若記憶體足夠）----
cat("Computing PC scores for all periods with predict()...\n")
X_all_dense <- as.matrix(X_all_sparse)
scores_all  <- predict(pca_res, newdata = X_all_dense)
scores_all  <- scores_all[, 1:K, drop = FALSE]

pc_df <- as.data.frame(scores_all)
colnames(pc_df) <- paste0("PC", 1:K)
pc_df$datetime_hour <- time_info$datetime_hour

## ---- 12. 合併 PC scores + y + 時間 dummy ----
rf_data_hour <- pc_df %>%
  dplyr::left_join(hourly_y, by = "datetime_hour") %>%
  dplyr::left_join(time_info, by = "datetime_hour") %>%
  dplyr::arrange(datetime_hour)

# 若某些小時沒有 treated_loc 的 trip，y 會是 NaN，改成 0
rf_data_hour$y[is.na(rf_data_hour$y)] <- 0

# 建立 factor dummy
rf_data_hour <- rf_data_hour %>%
  dplyr::mutate(
    hour_factor  = factor(hour_of_day),
    day_factor   = factor(day_of_month),
    month_factor = factor(month),
    dow_factor   = factor(dow)
  )

## ---- 13. 準備 Random Forest 的 X & y（train / all）----
y_all <- rf_data_hour$y

X_all <- rf_data_hour %>%
  dplyr::select(dplyr::starts_with("PC"),
                hour_factor, day_factor, month_factor, dow_factor)
# ⚠️ 如果你之後要把 trip_miles, trip_time, base_passenger_fare, tolls
# 當作額外 covariates，可以把它們 aggregate 成 hourly features 再加進 X_all
# 目前只是把它們讀進來，還沒進入模型。

X_train <- X_all[train_rows, , drop = FALSE]
y_train <- y_all[train_rows]

## ---- 14. Random Forest：用 2024/04–2024/12 訓練 ----
set.seed(123)
rf_fit <- randomForest(
  x        = X_train,
  y        = y_train,
  ntree    = 500,
  importance = TRUE
)

# 訓練期預測
y_hat_train <- predict(rf_fit, newdata = X_train)

# 全期間預測（2024/01–2025/06，每個小時）
y_hat_all <- predict(rf_fit, newdata = X_all)

## ---- 14b. Random Forest 結構 summary：樹的數量 & 深度 ----
ntree <- rf_fit$ntree

get_tree_depth <- function(tree_df) {
  left  <- tree_df[,"left daughter"]
  right <- tree_df[,"right daughter"]
  nnode <- nrow(tree_df)
  depth <- integer(nnode)
  depth[1] <- 1
  for (i in seq_len(nnode)) {
    if (left[i]  != 0) depth[left[i]]  <- depth[i] + 1
    if (right[i] != 0) depth[right[i]] <- depth[i] + 1
  }
  max(depth)
}

cat("Computing tree depths for random forest...\n")
tree_depths <- vapply(
  1:ntree,
  function(i) {
    tree_i <- randomForest::getTree(rf_fit, k = i, labelVar = FALSE)
    get_tree_depth(tree_i)
  },
  numeric(1)
)

rf_summary <- data.frame(
  ntree      = ntree,
  min_depth  = min(tree_depths),
  mean_depth = mean(tree_depths),
  max_depth  = max(tree_depths)
)

rf_summary_file <- file.path(out_dir, "RandomForest_summary.txt")
write.table(
  rf_summary,
  file = rf_summary_file,
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

## ---- 15. 計算 R^2（訓練期 & 全期間）----
SSE_train <- sum((y_train - y_hat_train)^2)
SST_train <- sum((y_train - mean(y_train))^2)
R2_train  <- 1 - SSE_train / SST_train

SSE_all <- sum((y_all - y_hat_all)^2)
SST_all <- sum((y_all - mean(y_all))^2)
R2_all  <- 1 - SSE_all / SST_all

cat("Hourly training R^2 (2024/04–2024/12) =", R2_train, "\n")
cat("Hourly overall R^2 (2024/01–2025/06)  =", R2_all,  "\n")

## ---- 16. 把預測結果存成 .txt 和 .csv（所有期間每小時）----
pred_df <- rf_data_hour %>%
  dplyr::mutate(
    y_hat   = y_hat_all,
    period  = dplyr::case_when(
      date >= as.Date("2024-04-01") & date <= as.Date("2024-12-31") ~ "train_2024_04_12",
      date >= as.Date("2024-01-01") & date <  as.Date("2024-04-01") ~ "test_2024_01_03",
      date >= as.Date("2025-01-01") & date <  as.Date("2025-04-01") ~ "test_2025_01_03",
      TRUE ~ "other"
    )
  ) %>%
  dplyr::select(datetime_hour, date, hour_of_day,
                y, y_hat, period)

write.table(
  pred_df,
  file = file.path(out_dir, "hourly_predictions_tips.txt"),
  sep = "\t",
  row.names = FALSE,
  quote = FALSE
)

write.csv(
  pred_df,
  file = file.path(out_dir, "hourly_predictions_tips.csv"),
  row.names = FALSE
)

## ---- 17. 聚合成每天 05:00–21:00 的「平均 hourly tips」----
daily_avg <- pred_df %>%
  dplyr::filter(hour_of_day >= 5 & hour_of_day < 21) %>%
  dplyr::group_by(date) %>%
  dplyr::summarise(
    y_mean    = mean(y),
    yhat_mean = mean(y_hat),
    .groups   = "drop"
  )

SSE_day <- sum((daily_avg$y_mean - daily_avg$yhat_mean)^2)
SST_day <- sum((daily_avg$y_mean - mean(daily_avg$y_mean))^2)
R2_day  <- 1 - SSE_day / SST_day
cat("Daily (05:00–21:00) mean tips R^2 (2024/01–2025/06) =", R2_day, "\n")

## ---- 18. 畫圖：2024/01–2025/06 每天 05:00–21:00 的 average tips：實際 vs 預測 ----
plot_daily <- daily_avg %>%
  tidyr::pivot_longer(cols = c(y_mean, yhat_mean),
                      names_to = "series",
                      values_to = "value")

p_daily <- ggplot(plot_daily, aes(x = date, y = value, color = series)) +
  geom_line() +
  labs(
    title = paste0(
      "Daily Mean Hourly Tips (05:00–21:00): Actual vs RF Predicted (2024/01–2025/06)\n",
      "Hourly train R^2 = ", round(R2_train, 3),
      " ; Hourly overall R^2 = ", round(R2_all, 3),
      " ; Daily-mean tips R^2 = ", round(R2_day, 3)
    ),
    x = "Date",
    y = "Mean hourly tips (USD)",
    color = ""
  ) +
  theme_minimal()

ggsave(
  filename = file.path(out_dir, "daily_avg_05_21_tips_y_vs_yhat_2024_2025.png"),
  plot = p_daily,
  width = 10,
  height = 5,
  dpi = 300
)