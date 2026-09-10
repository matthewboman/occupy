# Not currenly used

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

OUTPUT_DIR = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "normalized"
)

OUTPUT_FILE = OUTPUT_DIR / "wallstreetbets_submissions_2023_12.parquet"


files = sorted(RAW_DIR.glob("*.parquet"))

if not files:
    raise RuntimeError(f"No parquet files found in {RAW_DIR}")

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

connection = duckdb.connect()

file_paths = [str(path) for path in files]

output_path = str(OUTPUT_FILE).replace("'", "''")

connection.execute(
    f"""
    COPY (
      SELECT
        id,
        author,
        subreddit,
        title,
        selftext,
        score,
        created_utc,
        url
      FROM read_parquet(?)
      WHERE lower(subreddit) = 'wallstreetbets'
    )
    TO '{output_path}'
    (FORMAT PARQUET)
    """,
    [file_paths],
)

count = connection.execute(
    """
    SELECT COUNT(*)
    FROM read_parquet(?)
    """,
    [str(OUTPUT_FILE)],
).fetchone()[0]

print(f"Wrote {count} WallStreetBets submissions")
print(OUTPUT_FILE)