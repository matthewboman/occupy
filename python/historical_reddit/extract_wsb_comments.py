# not currently used

from pathlib import Path
import argparse
import shutil

import duckdb
from modelscope.hub.file_download import dataset_file_download


DATASET_ID = "open-index/arctic"

PROJECT_ROOT = Path(__file__).resolve().parents[2]

TEMP_DIR = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "temp"
    / "comments"
)

OUTPUT_DIR = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "normalized"
)


def download_shard(year, month, shard):
    file_path = (
        f"data/comments/{year}/{month:02d}/{shard:03d}.parquet"
    )

    return Path(
        dataset_file_download(
            dataset_id=DATASET_ID,
            file_path=file_path,
            local_dir=str(TEMP_DIR),
        )
    )


def extract_wsb(input_file, output_file):
    output_path = str(output_file).replace("'", "''")

    connection = duckdb.connect()

    connection.execute(
        f"""
        COPY (
          SELECT
            id,
            author,
            subreddit,
            body,
            score,
            created_utc,
            link_id,
            parent_id
          FROM read_parquet(?)
          WHERE lower(subreddit) = 'wallstreetbets'
        )
        TO '{output_path}'
        (FORMAT PARQUET)
        """,
        [str(input_file)],
    )

    return connection.execute(
        """
        SELECT COUNT(*)
        FROM read_parquet(?)
        """,
        [str(output_file)],
    ).fetchone()[0]


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--year",
        type=int,
        required=True,
    )

    parser.add_argument(
        "--month",
        type=int,
        required=True,
    )

    parser.add_argument(
        "--shard",
        type=int,
        default=0,
    )

    args = parser.parse_args()

    TEMP_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    input_file = download_shard(
        args.year,
        args.month,
        args.shard,
    )

    output_file = (
        OUTPUT_DIR
        / (
            f"wallstreetbets_comments_"
            f"{args.year}_{args.month:02d}_"
            f"{args.shard:03d}.parquet"
        )
    )

    count = extract_wsb(
        input_file,
        output_file,
    )

    print(f"Wrote {count} WallStreetBets comments")
    print(output_file)

    if TEMP_DIR.exists():
        shutil.rmtree(TEMP_DIR)


if __name__ == "__main__":
    main()