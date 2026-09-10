from pathlib import Path
import argparse
import json
import subprocess

import duckdb
from huggingface_hub import HfApi, hf_hub_download


REPO_ID = "Dk587/arctic"
REPO_TYPE = "dataset"

PROJECT_ROOT = Path(__file__).resolve().parents[2]

TEMP_DIR = PROJECT_ROOT / "data" / "reddit" / "temp"
STATE_FILE = PROJECT_ROOT / "data" / "reddit" / "import_state.json"


def load_state():
    if not STATE_FILE.exists():
        return {
            "completed": [],
            "failed": [],
        }

    with STATE_FILE.open() as file:
        return json.load(file)


def save_state(state):
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)

    with STATE_FILE.open("w") as file:
        json.dump(state, file, indent=2)


def discover_shards(year, month):
    prefix = f"data/submissions/{year}/{month:02d}/"

    api = HfApi()

    files = api.list_repo_files(
        repo_id=REPO_ID,
        repo_type=REPO_TYPE,
    )

    return sorted(
        file
        for file in files
        if file.startswith(prefix)
        and file.endswith(".parquet")
    )


def download_shard(repo_path):
    TEMP_DIR.mkdir(parents=True, exist_ok=True)

    downloaded_path = hf_hub_download(
        repo_id=REPO_ID,
        repo_type=REPO_TYPE,
        filename=repo_path,
        local_dir=TEMP_DIR,
    )

    return Path(downloaded_path)


def process_shard(parquet_path, repo_path):
    stem = Path(repo_path).stem

    csv_path = TEMP_DIR / f"{stem}_wallstreetbets.csv"

    output_path = str(csv_path).replace("'", "''")

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
          WHERE lower(subreddit) = 'wallstreetbets'
        )
        TO '{output_path}'
        (
          HEADER,
          DELIMITER ','
        )
        """,
        [str(parquet_path)],
    )

    return csv_path


def import_into_rails(csv_path):
    relative_path = csv_path.relative_to(PROJECT_ROOT)

    subprocess.run(
        [
            str(PROJECT_ROOT / "bin" / "rails"),
            "historical_reddit:import",
            f"FILE={relative_path}",
        ],
        cwd=PROJECT_ROOT,
        check=True,
    )


def cleanup(parquet_path, csv_path):
    if csv_path.exists():
        csv_path.unlink()

    if parquet_path.exists():
        parquet_path.unlink()


def mark_completed(state, repo_path):
    if repo_path not in state["completed"]:
        state["completed"].append(repo_path)

    if repo_path in state["failed"]:
        state["failed"].remove(repo_path)

    save_state(state)


def mark_failed(state, repo_path):
    if repo_path not in state["failed"]:
        state["failed"].append(repo_path)

    save_state(state)


def import_month(year, month):
    state = load_state()

    shards = discover_shards(year, month)

    if not shards:
        print(f"No shards found for {year}-{month:02d}")
        return

    print(f"Found {len(shards)} shards")

    for repo_path in shards:
        if repo_path in state["completed"]:
            print(f"Skipping completed: {repo_path}")
            continue

        parquet_path = None
        csv_path = None

        try:
            print(f"Processing: {repo_path}")

            parquet_path = download_shard(repo_path)

            csv_path = process_shard(
                parquet_path,
                repo_path,
            )

            import_into_rails(csv_path)

            mark_completed(
                state,
                repo_path,
            )

            cleanup(
                parquet_path,
                csv_path,
            )

            print(f"Completed: {repo_path}")

        except Exception as error:
            mark_failed(
                state,
                repo_path,
            )

            print(f"FAILED: {repo_path}")
            print(error)

            if csv_path and csv_path.exists():
                csv_path.unlink()

            if parquet_path and parquet_path.exists():
                parquet_path.unlink()


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

    args = parser.parse_args()

    import_month(
        args.year,
        args.month,
    )


if __name__ == "__main__":
    main()