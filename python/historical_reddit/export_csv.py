# not currently used

from pathlib import Path

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[2]

INPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "normalized"
    / "wallstreetbets_submissions_2023_12.parquet"
)

OUTPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "normalized"
    / "wallstreetbets_submissions_2023_12.csv"
)


if not INPUT_FILE.exists():
    raise RuntimeError(f"Missing input file: {INPUT_FILE}")

output_path = str(OUTPUT_FILE).replace("'", "''")

connection = duckdb.connect()

connection.execute(
    f"""
    COPY (
      SELECT
        id AS external_id,
        author,
        concat_ws(
          '\n\n',
          nullif(title, ''),
          nullif(selftext, '')
        ) AS body,
        to_timestamp(created_utc) AS posted_at,
        score,
        url
      FROM read_parquet(?)
    )
    TO '{output_path}'
    (
      HEADER,
      DELIMITER ','
    )
    """,
    [str(INPUT_FILE)],
)

count = connection.execute(
    """
    SELECT COUNT(*)
    FROM read_csv_auto(?)
    """,
    [str(OUTPUT_FILE)],
).fetchone()[0]

print(f"Wrote {count} rows")
print(OUTPUT_FILE)