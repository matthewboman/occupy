from pathlib import Path
import json
import sys


if len(sys.argv) != 2:
    raise RuntimeError(
        "Usage: python inspect_comment_file.py /path/to/comment-file"
    )

file_path = Path(sys.argv[1])

if not file_path.exists():
    raise RuntimeError(f"File not found: {file_path}")

print(f"Inspecting: {file_path}")
print()

suffix = file_path.suffix.lower()

if suffix in [".jsonl", ".ndjson"]:
    with file_path.open() as file:
        for index, line in enumerate(file):
            record = json.loads(line)

            print("FIELDS")
            print(sorted(record.keys()))
            print()
            print("SAMPLE")
            print(json.dumps(record, indent=2))

            break

elif suffix == ".json":
    with file_path.open() as file:
        data = json.load(file)

    if isinstance(data, list):
        record = data[0]
    else:
        record = data

    print("FIELDS")
    print(sorted(record.keys()))
    print()
    print("SAMPLE")
    print(json.dumps(record, indent=2))

else:
    raise RuntimeError(
        f"Unsupported file type: {suffix}"
    )