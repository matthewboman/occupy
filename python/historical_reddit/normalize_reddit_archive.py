from pathlib import Path
from datetime import datetime, timezone
import argparse
import csv
import json


def strip_reddit_prefix(value):
    if not value:
        return None

    if value.startswith("t1_") or value.startswith("t3_"):
        return value[3:]

    return value


def iso_timestamp(value):
    if value is None:
        return None

    return datetime.fromtimestamp(
        value,
        tz=timezone.utc,
    ).isoformat()


def build_submission(record):
    permalink = record.get("permalink")

    return {
        "external_id": record["id"],
        "subreddit": record.get("subreddit"),
        "record_type": "submission",
        "submission_external_id": None,
        "parent_external_id": None,
        "author": record.get("author"),
        "body": "\n\n".join(
            part
            for part in [
                record.get("title"),
                record.get("selftext"),
            ]
            if part
        ),
        "posted_at": iso_timestamp(
            record.get("created_utc")
        ),
        "score": record.get("score"),
        "url": (
            f"https://www.reddit.com{permalink}"
            if permalink
            else record.get("url")
        ),
    }


def build_comment(record):
    permalink = record.get("permalink")

    return {
        "external_id": record["id"],
        "subreddit": record.get("subreddit"),
        "record_type": "comment",
        "submission_external_id": strip_reddit_prefix(
            record.get("link_id")
        ),
        "parent_external_id": strip_reddit_prefix(
            record.get("parent_id")
        ),
        "author": record.get("author"),
        "body": record.get("body"),
        "posted_at": iso_timestamp(
            record.get("created_utc")
        ),
        "score": record.get("score"),
        "url": (
            f"https://www.reddit.com{permalink}"
            if permalink
            else None
        ),
    }


def build_row(record, record_type):
    if record_type == "submission":
        return build_submission(record)

    if record_type == "comment":
        return build_comment(record)

    raise RuntimeError(
        f"Unsupported record type: {record_type}"
    )


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--input",
        required=True,
    )

    parser.add_argument(
        "--output",
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
        "--subreddit",
        required=True,
    )

    args = parser.parse_args()

    input_file = Path(args.input)
    output_file = Path(args.output)

    if not input_file.exists():
        raise RuntimeError(
            f"Input file not found: {input_file}"
        )

    output_file.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    fieldnames = [
        "external_id",
        "subreddit",
        "record_type",
        "submission_external_id",
        "parent_external_id",
        "author",
        "body",
        "posted_at",
        "score",
        "url",
    ]

    count = 0

    with input_file.open() as input_handle, output_file.open(
        "w",
        newline="",
    ) as output_handle:
        writer = csv.DictWriter(
            output_handle,
            fieldnames=fieldnames,
        )

        writer.writeheader()

        for line in input_handle:
            line = line.strip()

            if not line:
                continue

            record = json.loads(line)

            if (
                record.get("subreddit", "").lower()
                != args.subreddit.lower()
            ):
                continue

            row = build_row(
                record,
                args.type,
            )

            if not row["body"]:
                continue

            writer.writerow(row)

            count += 1

    print(
        f"Wrote {count} {args.type} records "
        f"for r/{args.subreddit}"
    )
    print(output_file)


if __name__ == "__main__":
    main()