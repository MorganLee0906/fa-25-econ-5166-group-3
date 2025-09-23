#!/usr/bin/env python3
# save as summary_stats_notebook.py

import sys
import pandas as pd
import nbformat as nbf
from pathlib import Path

def create_summary_notebook(data_path):
    data_path = Path(data_path).resolve()

    # Prepare notebook
    nb = nbf.v4.new_notebook()
    
    # Add imports cell
    nb.cells.append(nbf.v4.new_code_cell(
        "import pandas as pd\n"
        f"df = pd.read_csv(r'{data_path}')\n"
        "df.head()"
    ))

    # Add summary stats cell
    nb.cells.append(nbf.v4.new_code_cell(
        "df.describe(include='all')"
    ))

    # Add missing values cell
    nb.cells.append(nbf.v4.new_code_cell(
        "df.isnull().sum()"
    ))

    # Save notebook
    out_path = data_path.with_suffix(".summary.ipynb")
    with open(out_path, "w") as f:
        nbf.write(nb, f)

    print(f"Notebook created: {out_path}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python summary_stats_notebook.py <path-to-data>")
        sys.exit(1)

    create_summary_notebook(sys.argv[1])
