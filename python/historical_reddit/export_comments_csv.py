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

    args = parser.parse_args()

    input_file = Path(args.input)
    output_file = Path(args.output)

    if not input_file.exists():
        raise RuntimeError(f"Input file not found: {input_file}")

    output_file.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    count = 0

    with input_file.open() as input_handle, output_file.open(
        "w",
        newline="",
    ) as output_handle:
        writer = csv.DictWriter(
            output_handle,
            fieldnames=[
                "external_id",
                "record_type",
                "submission_external_id",
                "parent_external_id",
                "author",
                "body",
                "posted_at",
                "score",
                "url",
            ],
        )

        writer.writeheader()

        for line in input_handle:
            line = line.strip()

            if not line:
                continue

            record = json.loads(line)

            permalink = record.get("permalink")

            if permalink:
                url = f"https://www.reddit.com{permalink}"
            else:
                url = None

            writer.writerow(
                {
                    "external_id": record["id"],
                    "record_type": "comment",
                    "submission_external_id": strip_reddit_prefix(
                        record.get("link_id")
                    ),
                    "parent_external_id": strip_reddit_prefix(
                        record.get("parent_id")
                    ),
                    "author": record.get("author"),
                    "body": record.get("body"),
                    "posted_at": datetime.fromtimestamp(
                        record["created_utc"],
                        tz=timezone.utc,
                    ).isoformat(),
                    "score": record.get("score"),
                    "url": url,
                }
            )

            count += 1

    print(f"Wrote {count} comments")
    print(output_file)


if __name__ == "__main__":
    main()