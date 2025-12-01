

## hvfhv_precompute.R
## -------------------
## Heavy computation for HVFHV volume RF counterfactual
## Run this once on a machine with sufficient memory (>100GB).
## It will write intermediate results as .rds into hvfhv_volume/rds/.

## ---- 套件 ----
required_pkgs <- c(
  "arrow", "dplyr", "lubridate", "ggplot2", "tidyr",
  "randomForest", "irlba", "Matrix", "broom", "scales"
)

for (pkg in required_pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
  library(pkg, character.only = TRUE)
}

## ---- 路徑設定 ----
base_dir     <- "C:/Users/hp/Desktop/ECON5166-final_project"
analysis_dir <- file.path(base_dir, "hvfhv_volume")
data_dir     <- file.path(base_dir, "data")
rds_dir      <- file.path(analysis_dir, "rds")
out_dir      <- file.path(analysis_dir, "Volume/random_forest_hourly")

dir.create(analysis_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(rds_dir,      recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir,      recursive = TRUE, showWarnings = FALSE)

## ---- 讀取 treated LocationID 清單 ----
treated_file <- file.path(
  base_dir,
  "2025 Congestion Pricing – Affected TLC LocationID List.txt"
)
treated_ids  <- scan(treated_file, what = integer(), quiet = TRUE)

cat("Number of treated DOLocationID:", length(treated_ids), "\n")

## ---- 讀取 2024/01–2024/12 & 2025/01–2025/06 檔名 ----
months_2024 <- sprintf("2024-%02d", 1:12)
months_2025 <- sprintf("2025-%02d", 1:6)
months_all  <- c(months_2024, months_2025)

data_files  <- file.path(
  data_dir,
  paste0("fhvhv_tripdata_", months_all, ".parquet")
)

print(data_files)

## ---- 逐檔讀取並做 aggregate（避免保留 trip-level 全資料） ----
hourly_y_list    <- list()
time_info_list   <- list()
other_pair_list  <- list()

for (f in data_files) {
  cat("Reading and aggregating file:", f, "...\n")
  
  trips_f <- read_parquet(f, as_data_frame = TRUE) %>%
    dplyr::mutate(
      pickup_datetime = lubridate::ymd_hms(
        pickup_datetime,
        tz = "America/New_York"
      )
    ) %>%
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
  
  ## 1. 每小時 treated 流量（當檔案的期間）
  hourly_y_list[[f]] <- trips_f %>%
    dplyr::group_by(datetime_hour) %>%
    dplyr::summarise(
      y = sum(treated_loc),
      .groups = "drop"
    )
  
  ## 2. 每小時時間資訊（當檔案的期間）
  time_info_list[[f]] <- trips_f %>%
    dplyr::transmute(
      datetime_hour = datetime_hour,
      date          = date,
      hour_of_day   = hour,
      day_of_month  = day,
      month         = month,
      dow           = dow
    ) %>%
    dplyr::distinct(datetime_hour, .keep_all = TRUE)
  
  ## 3. non-treated flows 的 (PU, DO) feature（當檔案的期間）
  other_pair_list[[f]] <- trips_f %>%
    dplyr::filter(!treated_loc) %>%
    dplyr::mutate(
      feature = paste(PULocationID, DOLocationID, sep = "_")
    ) %>%
    dplyr::group_by(datetime_hour, feature) %>%
    dplyr::summarise(
      trips_cnt = dplyr::n(),
      .groups   = "drop"
    )
  
  rm(trips_f)
  gc()
}

## ---- 合併 aggregate 結果 ----
hourly_y <- dplyr::bind_rows(hourly_y_list) %>%
  dplyr::group_by(datetime_hour) %>%
  dplyr::summarise(y = sum(y), .groups = "drop")

time_info <- dplyr::bind_rows(time_info_list) %>%
  dplyr::distinct(datetime_hour, .keep_all = TRUE) %>%
  dplyr::arrange(datetime_hour) %>%
  dplyr::mutate(
    row_id   = dplyr::row_number(),
    is_train = (date >= as.Date("2024-04-01") & date <= as.Date("2024-12-31"))
  )

other_pair_all <- dplyr::bind_rows(other_pair_list)

rm(hourly_y_list, time_info_list, other_pair_list)
gc()

cat("hourly_y dim:", paste(dim(hourly_y), collapse = " x "), "\n")
cat("time_info dim:", paste(dim(time_info), collapse = " x "), "\n")
cat("other_pair_all dim:", paste(dim(other_pair_all), collapse = " x "), "\n")

## ---- 建立 feature set & sparse matrix ----
train_hours <- time_info %>%
  dplyr::filter(is_train) %>%
  dplyr::select(datetime_hour)

train_features <- other_pair_all %>%
  dplyr::inner_join(train_hours, by = "datetime_hour") %>%
  dplyr::distinct(feature) %>%
  dplyr::arrange(feature) %>%
  dplyr::mutate(col_id = dplyr::row_number())

cat("Number of train features (PU,DO pairs):", nrow(train_features), "\n")

other_all_idx <- other_pair_all %>%
  dplyr::inner_join(train_features, by = "feature") %>%
  dplyr::inner_join(
    time_info %>% dplyr::select(datetime_hour, row_id),
    by = "datetime_hour"
  )

n_hours <- nrow(time_info)
p_feats <- nrow(train_features)

X_all_sparse <- Matrix::sparseMatrix(
  i    = other_all_idx$row_id,
  j    = other_all_idx$col_id,
  x    = other_all_idx$trips_cnt,
  dims = c(n_hours, p_feats)
)

rm(other_pair_all, other_all_idx)
gc()

cat("X_all_sparse dim:", paste(dim(X_all_sparse), collapse = " x "), "\n")

## ---- PCA: 只用訓練期 ----
train_rows <- which(time_info$is_train)
X_train_sparse <- X_all_sparse[train_rows, ]

K <- 10
cat("Running fast PCA with irlba on training period (K =", K, ")...\n")
pca_res <- irlba::prcomp_irlba(
  X_train_sparse,
  n      = K,
  center = TRUE,
  scale. = TRUE
)
cat("Fast PCA finished.\n")

var_explained <- pca_res$sdev^2 / sum(pca_res$sdev^2)
cum_var_K     <- cumsum(var_explained[1:K])

pc_var_df <- data.frame(
  PC          = 1:K,
  VarExpl     = var_explained[1:K],
  CumVarExpl  = cum_var_K
)

## 原始維度 / 總變異解釋比例
p_feats_train <- ncol(X_train_sparse)
pc10_total_var <- sum(pca_res$sdev^2)
pc10_explained_ratio <- pc10_total_var / p_feats_train

pc_var_df$Original_dimension              <- p_feats_train
pc_var_df$Reduced_dimension               <- K
pc_var_df$total_variance_explained_up_to_K <- pc10_explained_ratio

cat("PC1~PC10 explain",
    round(pc10_explained_ratio * 100, 3),
    "% of total variance.\n")

## 繪製與輸出 PCA summary
p_pc <- ggplot(pc_var_df, aes(x = PC, y = CumVarExpl)) +
  geom_line() +
  geom_point() +
  scale_x_continuous(breaks = seq_len(K)) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(
    title = "Cumulative Variance Explained by Principal Components",
    x     = "Principal Component (PC)",
    y     = "Cumulative Variance Explained"
  ) +
  theme(
    plot.title = element_text(size = 10)
  )

pca_summary_file <- file.path(out_dir, "PCA_summary.txt")

cat(
  "Original_dimension:", p_feats_train, "\n",
  "Reduced_dimension:", K, "\n\n",
  file = pca_summary_file
)

write.table(
  pc_var_df,
  file      = pca_summary_file,
  sep       = "\t",
  row.names = FALSE,
  quote     = FALSE,
  append    = TRUE
)

ggsave(
  filename = file.path(out_dir, "PC1_K_cumulative_variance.png"),
  plot     = p_pc,
  width    = 5,
  height   = 5,
  dpi      = 300
)

## ---- 計算所有時間點 PC scores ----
cat("Computing PC scores for all periods with predict() on sparse matrix...\n")
scores_all  <- predict(pca_res, newdata = X_all_sparse)
scores_all  <- scores_all[, 1:K, drop = FALSE]

pc_df <- as.data.frame(scores_all)
colnames(pc_df) <- paste0("PC", 1:K)
pc_df$datetime_hour <- time_info$datetime_hour

cat("pc_df dim:", paste(dim(pc_df), collapse = " x "), "\n")

## ---- 建立 Random Forest 資料 ----
rf_data_hour <- pc_df %>%
  dplyr::left_join(hourly_y, by = "datetime_hour") %>%
  dplyr::left_join(time_info, by = "datetime_hour") %>%
  dplyr::arrange(datetime_hour)

rf_data_hour$y[is.na(rf_data_hour$y)] <- 0L

rf_data_hour <- rf_data_hour %>%
  dplyr::mutate(
    hour_factor  = factor(hour_of_day),
    day_factor   = factor(day_of_month),
    month_factor = factor(month),
    dow_factor   = factor(dow)
  )

cat("rf_data_hour dim:", paste(dim(rf_data_hour), collapse = " x "), "\n")

## ---- Random Forest 訓練 ----
y_all <- rf_data_hour$y
X_all <- rf_data_hour %>%
  dplyr::select(dplyr::starts_with("PC"),
                hour_factor, day_factor, month_factor, dow_factor)

X_train <- X_all[train_rows, , drop = FALSE]
y_train <- y_all[train_rows]

cat("X_train dim:", paste(dim(X_train), collapse = " x "), "\n")

set.seed(123)
rf_fit <- randomForest(
  x          = X_train,
  y          = y_train,
  ntree      = 500,
  importance = TRUE
)

print(rf_fit)

## ---- RF 評估 ----
y_hat_train <- predict(rf_fit, newdata = X_train)
y_hat_all   <- predict(rf_fit, newdata = X_all)

SSE_train <- sum((y_train - y_hat_train)^2)
SST_train <- sum((y_train - mean(y_train))^2)
R2_train  <- 1 - SSE_train / SST_train

SSE_all <- sum((y_all - y_hat_all)^2)
SST_all <- sum((y_all - mean(y_all))^2)
R2_all  <- 1 - SSE_all / SST_all

cat("Hourly training R^2 (2024/04–2024/12) =", R2_train, "\n")
cat("Hourly overall  R^2 (2024/01–2025/06) =", R2_all,  "\n")

## ---- RF 樹深度統計 ----
ntree <- rf_fit$ntree

get_tree_depth <- function(tree_df) {
  left  <- tree_df[, "left daughter"]
  right <- tree_df[, "right daughter"]
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
  file      = rf_summary_file,
  sep       = "\t",
  row.names = FALSE,
  quote     = FALSE
)

## ---- 變數重要度 ----
var_imp <- randomForest::importance(rf_fit)

## ---- 建立 pred_df & daily_avg ----
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
  file      = file.path(out_dir, "hourly_predictions.txt"),
  sep       = "\t",
  row.names = FALSE,
  quote     = FALSE
)

write.csv(
  pred_df,
  file      = file.path(out_dir, "hourly_predictions.csv"),
  row.names = FALSE
)

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

cat("Daily (05:00–21:00) mean overall R^2 (2024/01–2025/06) =", R2_day, "\n")

plot_daily <- daily_avg %>%
  tidyr::pivot_longer(
    cols      = c(y_mean, yhat_mean),
    names_to  = "series",
    values_to = "value"
  )

p_daily <- ggplot(plot_daily, aes(x = date, y = value, color = series)) +
  geom_line() +
  labs(
    title = paste0(
      "Daily Mean Trips (05:00–21:00): Actual vs RF Predicted (2024/01–2025/06)\n",
      "Hourly train R^2 = ", round(R2_train, 3),
      " ; Hourly overall R^2 = ", round(R2_all, 3),
      " ; Daily-mean overall R^2 = ", round(R2_day, 3)
    ),
    x = "Date",
    y = "Mean hourly trips (05:00–21:00)",
    color = ""
  ) +
  theme_minimal()

ggsave(
  filename = file.path(out_dir, "daily_avg_05_21_y_vs_yhat_2024_2025.png"),
  plot     = p_daily,
  width    = 10,
  height   = 5,
  dpi      = 300
)

## ---- 存成 .rds，給 Rmd 使用 ----
rf_R2 <- data.frame(
  R2_train = R2_train,
  R2_all   = R2_all,
  R2_day   = R2_day
)

saveRDS(hourly_y,  file.path(rds_dir, "hourly_y.rds"))
saveRDS(time_info, file.path(rds_dir, "time_info.rds"))
saveRDS(pc_var_df, file.path(rds_dir, "pc_var_df.rds"))
saveRDS(rf_summary, file.path(rds_dir, "rf_summary.rds"))
saveRDS(var_imp,    file.path(rds_dir, "var_imp.rds"))
saveRDS(pred_df,    file.path(rds_dir, "pred_df.rds"))
saveRDS(daily_avg,  file.path(rds_dir, "daily_avg.rds"))
saveRDS(rf_R2,      file.path(rds_dir, "rf_R2.rds"))

cat("\n[done] Heavy preprocessing finished. .rds files saved to:\n  ",
    rds_dir, "\n")

