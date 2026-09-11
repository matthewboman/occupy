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
        return {
            "completed": []
        }

    with STATE_FILE.open() as handle:
        state = json.load(handle)

    state["completed"] = state.get(
        "completed",
        [],
    )

    return state


def save_state(state):
    STATE_FILE.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    temporary_file = STATE_FILE.with_suffix(
        ".tmp"
    )

    with temporary_file.open("w") as handle:
        json.dump(
            state,
            handle,
            indent=2,
            sort_keys=True,
        )

    temporary_file.replace(
        STATE_FILE
    )


def checkpoint_key(
    input_file,
    record_type,
    subreddit,
):
    relative_path = input_file.relative_to(
        PROJECT_ROOT
    )

    return (
        f"{subreddit.lower()}:"
        f"{record_type}:"
        f"{relative_path}"
    )


def normalize_file(
    input_file,
    output_file,
    record_type,
    subreddit,
):
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
    relative_path = output_file.relative_to(
        PROJECT_ROOT
    )

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
        print(
            f"Skipping completed "
            f"r/{subreddit} "
            f"{record_type} "
            f"{input_file.name}"
        )

        if delete_raw and input_file.exists():
            input_file.unlink()

        return True

    output_file = (
        NORMALIZED_DIR
        / (
            f"{subreddit}_"
            f"{record_type}_"
            f"{input_file.stem}.csv"
        )
    )

    try:
        print(
            f"Processing "
            f"r/{subreddit} "
            f"{record_type} "
            f"{input_file.name}"
        )

        normalize_file(
            input_file,
            output_file,
            record_type,
            subreddit,
        )

        import_into_rails(
            output_file
        )

        state["completed"].append(
            key
        )

        save_state(
            state
        )

        if output_file.exists():
            output_file.unlink()

        if delete_raw and input_file.exists():
            input_file.unlink()

        print(
            f"Completed "
            f"r/{subreddit} "
            f"{record_type} "
            f"{input_file.name}"
        )

        return True

    except Exception as error:
        print(
            f"FAILED "
            f"r/{subreddit} "
            f"{record_type} "
            f"{input_file.name}: "
            f"{error}",
            file=sys.stderr,
        )

        if output_file.exists():
            output_file.unlink()

        return False


def load_manifest(path):
    with path.open() as handle:
        manifest = json.load(handle)

    if not isinstance(manifest, list):
        raise RuntimeError(
            "Manifest must contain a JSON array"
        )

    return manifest


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--manifest",
        required=True,
    )

    parser.add_argument(
        "--delete-raw",
        action="store_true",
    )

    args = parser.parse_args()

    manifest_file = Path(
        args.manifest
    ).resolve()

    if not manifest_file.exists():
        raise RuntimeError(
            f"Manifest not found: "
            f"{manifest_file}"
        )

    NORMALIZED_DIR.mkdir(
        parents=True,
        exist_ok=True,
    )

    manifest = load_manifest(
        manifest_file
    )

    state = load_state()

    succeeded = 0
    failed = 0

    for route in manifest:
        input_file = Path(
            route["input_file"]
        ).resolve()

        if not input_file.exists():
            print(
                f"FAILED missing raw file: "
                f"{input_file}",
                file=sys.stderr,
            )

            failed += 1

            continue

        if process_file(
            input_file=input_file,
            record_type=route["record_type"],
            subreddit=route["subreddit"],
            delete_raw=args.delete_raw,
            state=state,
        ):
            succeeded += 1
        else:
            failed += 1

    print()
    print(
        f"Completed/skipped files: "
        f"{succeeded}"
    )

    print(
        f"Failed files: {failed}"
    )

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()