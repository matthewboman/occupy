from pathlib import Path
import argparse
import json
import subprocess
import sys


PROJECT_ROOT = Path(__file__).resolve().parents[2]

NORMALIZER = (
    PROJECT_ROOT
    / "python"
    / "historical_reddit"
    / "normalize_reddit_archive.py"
)

NORMALIZED_DIR = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "normalized"
)

STATE_FILE = (
    PROJECT_ROOT
    / "data"
    / "reddit"
    / "archive_import_state.json"
)


def load_state():
    if not STATE_FILE.exists():
        return {"completed": []}

    with STATE_FILE.open() as handle:
        return json.load(handle)


def save_state(state):
    STATE_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with STATE_FILE.open("w") as handle:
        json.dump(
            state,
            handle,
            indent=2,
            sort_keys=True,
        )


def checkpoint_key(input_file, record_type, subreddit):
    relative_path = input_file.relative_to(PROJECT_ROOT)

    return (
        f"{subreddit}:"
        f"{record_type}:"
        f"{relative_path}"
    )


def normalize_file(input_file, output_file, record_type, subreddit):
    subprocess.run(
        [
            sys.executable,
            str(NORMALIZER),
            "--input",
            str(input_file),
            "--output",
            str(output_file),
            "--type",
            record_type,
            "--subreddit",
            subreddit,
        ],
        check=True,
    )


def import_into_rails(output_file):
    relative_path = output_file.relative_to(PROJECT_ROOT)

    subprocess.run(
        [
            str(PROJECT_ROOT / "bin" / "rails"),
            "historical_reddit:import",
            f"FILE={relative_path}",
        ],
        cwd=PROJECT_ROOT,
        check=True,
    )


def process_file(
    input_file,
    record_type,
    subreddit,
    delete_raw,
    state,
):
    key = checkpoint_key(
        input_file,
        record_type,
        subreddit,
    )

    if key in state["completed"]:
        print(f"Skipping completed {input_file}")
        return True

    output_file = (
        NORMALIZED_DIR
        / f"{input_file.stem}_{record_type}_{subreddit}.csv"
    )

    try:
        print(f"Processing {input_file}")

        normalize_file(
            input_file,
            output_file,
            record_type,
            subreddit,
        )

        import_into_rails(output_file)

        state["completed"].append(key)
        save_state(state)

        if output_file.exists():
            output_file.unlink()

        if delete_raw and input_file.exists():
            input_file.unlink()

        print(f"Completed {input_file}")

        return True

    except Exception as error:
        print(
            f"FAILED {input_file}: {error}",
            file=sys.stderr,
        )

        return False


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--subreddit",
        required=True,
    )

    parser.add_argument(
        "--type",
        choices=[
            "submission",
            "comment",
        ],
        required=True,
    )

    parser.add_argument(
        "--input-dir",
        required=True,
    )

    parser.add_argument(
        "--delete-raw",
        action="store_true",
    )

    args = parser.parse_args()

    input_dir = Path(args.input_dir).resolve()

    if not input_dir.exists():
        raise RuntimeError(
            f"Input directory not found: {input_dir}"
        )

    NORMALIZED_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    files = sorted(
        path
        for path in input_dir.iterdir()
        if path.is_file()
        and path.suffix.lower() in [
            ".json",
            ".jsonl",
            ".ndjson",
        ]
    )

    if not files:
        raise RuntimeError(
            f"No supported archive files found in {input_dir}"
        )

    state = load_state()

    succeeded = 0
    failed = 0

    for input_file in files:
        if process_file(
            input_file,
            args.type,
            args.subreddit,
            args.delete_raw,
            state,
        ):
            succeeded += 1
        else:
            failed += 1

    print()
    print(f"Completed/skipped files: {succeeded}")
    print(f"Failed files: {failed}")

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()