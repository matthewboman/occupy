from pathlib import Path

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[2]

RAW_DIR = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "raw"
    / "submissions"
    / "2023"
    / "12"
)

files = sorted(RAW_DIR.glob("*.parquet"))

if not files:
    raise RuntimeError(f"No parquet files found in {RAW_DIR}")

file_path = files[0]

print(f"Inspecting: {file_path}")
print()

connection = duckdb.connect()

schema = connection.execute(
    """
    DESCRIBE
    SELECT *
    FROM read_parquet(?)
    """,
    [str(file_path)],
).fetchdf()

print("SCHEMA")
print(schema.to_string(index=False))

print()
print("SAMPLE")

rows = connection.execute(
    """
    SELECT *
    FROM read_parquet(?)
    LIMIT 3
    """,
    [str(file_path)],
).fetchdf()

print(rows.to_string())