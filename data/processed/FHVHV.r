library(arrow)
library(dplyr)

df <- open_dataset("~/Downloads/DS/FHVHV", format = "parquet")
df <- df %>%
  collect()

head(df)

head_df <- df[1:5,]
head_df.to_csv()