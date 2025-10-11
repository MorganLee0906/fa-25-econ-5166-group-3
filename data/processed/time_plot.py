import os
import pandas as pd
import matplotlib.pyplot as plt

# === 1. Setup directory ===
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# === 2. Read the combined daily average file ===
file = "NYC_daily_avg_by_borough.csv"
df = pd.read_csv(file, encoding_errors="ignore")

# Convert DATE to datetime for proper time plotting
df['DATE'] = pd.to_datetime(df['DATE'], errors='coerce')

# === 3. Define boroughs (ensure columns exist) ===
boroughs = ["Manhattan", "Staten Island", "Brooklyn", "Bronx", "Queens"]

# Filter only existing boroughs (in case some CSVs missing)
boroughs = [b for b in boroughs if b in df.columns]

# === 4. Plot ===
plt.figure(figsize=(12, 6))

for b in boroughs:
    plt.plot(df['DATE'], df[b], label=b, linewidth=2)

# === 5. Format plot ===
plt.title("Daily Average Speed by Borough", fontsize=16)
plt.xlabel("Date", fontsize=12)
plt.ylabel("Average Speed (mph)", fontsize=12)
plt.legend(title="Borough", fontsize=10)
plt.grid(True, linestyle="--", alpha=0.6)
plt.tight_layout()

# === 6. Save and/or show ===
plt.savefig("NYC_borough_speed_trends.png", dpi=300)
plt.show()

print("✅ Plot saved as 'NYC_borough_speed_trends.png' and displayed.")