from pathlib import Path
from datetime import datetime, timedelta, timezone
import argparse
import json
import subprocess
import sys
import time

import requests


PROJECT_ROOT = Path(__file__).resolve().parents[2]

PROCESSOR = (
    PROJECT_ROOT
    / "python"
    / "historical_reddit"
    / "process_reddit_archive.py"
)

BASE_URL = "https://arctic-shift.photon-reddit.com"

REQUEST_DELAY = 2.0
REQUEST_TIMEOUT = 60

LIMIT = 100

MAX_RETRIES = 8
INITIAL_RETRY_DELAY = 5


def parse_date(value):
    return datetime.strptime(
        value,
        "%Y-%m-%d",
    ).replace(tzinfo=timezone.utc)


def endpoint(record_type):
    if record_type == "submission":
        return f"{BASE_URL}/api/posts/search"

    return f"{BASE_URL}/api/comments/search"


def raw_directory(subreddit, record_type, day):
    directory_name = (
        "submissions"
        if record_type == "submission"
        else "comments"
    )

    return (
        PROJECT_ROOT
        / "data"
        / "reddit"
        / "raw"
        / directory_name
        / subreddit
        / day.strftime("%Y")
        / day.strftime("%m")
    )


def raw_file(subreddit, record_type, day):
    directory = raw_directory(
        subreddit,
        record_type,
        day,
    )

    directory.mkdir(
        parents=True,
        exist_ok=True,
    )

    return directory / (
        f"{subreddit}_{record_type}_{day:%Y_%m_%d}.jsonl"
    )


def format_timestamp(timestamp):
    return datetime.fromtimestamp(
        timestamp,
        tz=timezone.utc,
    ).strftime(
        "%Y-%m-%d %H:%M:%S"
    )


def request_page(
    subreddit,
    record_type,
    after,
    before,
):
    params = {
        "subreddit": subreddit,
        "after": format_timestamp(after),
        "before": format_timestamp(before),
        "sort": "asc",
        "limit": LIMIT,
    }

    retry_delay = INITIAL_RETRY_DELAY

    for attempt in range(MAX_RETRIES + 1):
        response = requests.get(
            endpoint(record_type),
            params=params,
            timeout=REQUEST_TIMEOUT,
            headers={
                "User-Agent": "occupy-historical-reddit-importer/1.0"
            },
        )

        if response.ok:
            payload = response.json()

            return payload.get("data", [])

        timeout_error = (
            response.status_code == 422
            and "timeout" in response.text.lower()
        )

        rate_limited = (
            response.status_code == 429
        )

        if (
            timeout_error
            or rate_limited
        ) and attempt < MAX_RETRIES:
            print(
                f"Arctic Shift returned HTTP "
                f"{response.status_code}: "
                f"{response.text}"
            )

            print(
                f"Retrying in {retry_delay} seconds "
                f"(attempt {attempt + 1}/{MAX_RETRIES})",
                flush=True,
            )

            time.sleep(retry_delay)

            retry_delay *= 2

            continue

        print(
            f"Arctic Shift returned HTTP "
            f"{response.status_code}",
            file=sys.stderr,
        )

        print(
            f"URL: {response.url}",
            file=sys.stderr,
        )

        print(
            f"Response: {response.text}",
            file=sys.stderr,
        )

        response.raise_for_status()

    raise RuntimeError(
        "Arctic Shift request retries exhausted"
    )


def existing_download_state(output_file, start):
    if not output_file.exists():
        return (
            int(start.timestamp()),
            set(),
            0,
        )

    seen_ids = set()
    last_created_utc = None
    count = 0

    with output_file.open() as handle:
        for line in handle:
            line = line.strip()

            if not line:
                continue

            record = json.loads(line)

            external_id = record.get("id")

            if external_id:
                seen_ids.add(external_id)

            created_utc = record.get(
                "created_utc"
            )

            if created_utc is not None:
                last_created_utc = int(
                    created_utc
                )

            count += 1

    if last_created_utc is None:
        cursor = int(
            start.timestamp()
        )
    else:
        cursor = (
            last_created_utc
            + 1
        )

    return (
        cursor,
        seen_ids,
        count,
    )


def download_day(
    subreddit,
    record_type,
    day,
):
    output_file = raw_file(
        subreddit,
        record_type,
        day,
    )

    start = day
    finish = day + timedelta(days=1)

    (
        cursor,
        seen_ids,
        count,
    ) = existing_download_state(
        output_file,
        start,
    )

    before = int(
        finish.timestamp()
    )

    if count:
        print(
            f"Resuming r/{subreddit} "
            f"{record_type} "
            f"{day.date()} "
            f"after {count} existing records"
        )
    else:
        print(
            f"Downloading r/{subreddit} "
            f"{record_type} "
            f"{day.date()}"
        )

    with output_file.open("a") as handle:
        while cursor < before:
            records = request_page(
                subreddit=subreddit,
                record_type=record_type,
                after=cursor,
                before=before,
            )

            if not records:
                break

            for record in records:
                external_id = record.get(
                    "id"
                )

                if not external_id:
                    continue

                if external_id in seen_ids:
                    continue

                seen_ids.add(
                    external_id
                )

                handle.write(
                    json.dumps(record)
                    + "\n"
                )

                count += 1

            handle.flush()

            last_created_utc = records[-1].get(
                "created_utc"
            )

            if last_created_utc is None:
                raise RuntimeError(
                    "Last record has no created_utc"
                )

            next_cursor = (
                int(last_created_utc)
                + 1
            )

            if next_cursor <= cursor:
                raise RuntimeError(
                    "Pagination cursor did not advance"
                )

            cursor = next_cursor

            print(
                f"  downloaded {count} records",
                flush=True,
            )

            if len(records) < LIMIT:
                break

            time.sleep(
                REQUEST_DELAY
            )

    print(
        f"Downloaded {count} records to "
        f"{output_file}"
    )

    return output_file


def process_download(
    subreddit,
    record_type,
    input_file,
    delete_raw,
):
    command = [
        sys.executable,
        str(PROCESSOR),
        "--subreddit",
        subreddit,
        "--type",
        record_type,
        "--input-dir",
        str(input_file.parent),
    ]

    if delete_raw:
        command.append(
            "--delete-raw"
        )

    subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        check=True,
    )


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--subreddit",
        required=True,
    )

    parser.add_argument(
        "--start",
        required=True,
        help="YYYY-MM-DD",
    )

    parser.add_argument(
        "--end",
        required=True,
        help="YYYY-MM-DD, exclusive",
    )

    parser.add_argument(
        "--type",
        choices=[
            "submission",
            "comment",
            "both",
        ],
        default="both",
    )

    parser.add_argument(
        "--delete-raw",
        action="store_true",
    )

    args = parser.parse_args()

    start = parse_date(
        args.start
    )

    end = parse_date(
        args.end
    )

    if end <= start:
        raise RuntimeError(
            "--end must be after --start"
        )

    record_types = (
        [
            "submission",
            "comment",
        ]
        if args.type == "both"
        else [
            args.type
        ]
    )

    day = start

    while day < end:
        for record_type in record_types:
            input_file = download_day(
                subreddit=args.subreddit,
                record_type=record_type,
                day=day,
            )

            process_download(
                subreddit=args.subreddit,
                record_type=record_type,
                input_file=input_file,
                delete_raw=args.delete_raw,
            )

        day += timedelta(
            days=1
        )


if __name__ == "__main__":
    main()