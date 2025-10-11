import os
import pandas as pd

# === 1. Setup directory ===
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# List all borough CSVs you want to include
input_files = [
    "Manhaton_speed.csv",
    "Staten_Island_speed.csv",
    "Brooklyn_speed.csv",
    "Bronx_speed.csv",
    "Queens_speed.csv"

]

# === 2. Process each file and store daily averages ===
all_daily_avgs = []

for file in input_files:
    print(f"Processing {file}...")

    # Read CSV
    df = pd.read_csv(file, encoding_errors="ignore")

    # Parse datetime
    df['DATA_AS_OF'] = pd.to_datetime(df['DATA_AS_OF'], errors='coerce')
    df['DATE'] = df['DATA_AS_OF'].dt.date

    # Identify borough name (from column or filename)
    if 'BOROUGH' in df.columns:
        borough = df['BOROUGH'].iloc[0]
    else:
        borough = os.path.splitext(file)[0].replace('_speed', '')

    # Compute daily average for that borough
    daily_avg = df.groupby('DATE', as_index=False)['SPEED'].mean()
    daily_avg.rename(columns={'SPEED': borough}, inplace=True)

    all_daily_avgs.append(daily_avg)

# === 3. Merge all boroughs on DATE ===
combined_df = all_daily_avgs[0]
for other_df in all_daily_avgs[1:]:
    combined_df = pd.merge(combined_df, other_df, on='DATE', how='outer')

# Sort by date (optional)
combined_df = combined_df.sort_values('DATE')

# === 4. Export final pivot-style table ===
output_file = "NYC_daily_avg_by_borough.csv"
combined_df.to_csv(output_file, index=False)

print(f"✅ Daily averages by borough saved to {output_file}")
