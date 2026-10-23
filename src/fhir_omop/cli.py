import argparse
import json
import logging
import os
from pathlib import Path

from .ingest import load_directory
from .quality import profile


def main() -> None:
    parser = argparse.ArgumentParser(prog="fhir-omop")
    sub = parser.add_subparsers(dest="command", required=True)
    ingest = sub.add_parser("ingest", help="validate and load FHIR bundle JSON files")
    ingest.add_argument("directory", type=Path)
    ingest.add_argument("--database-url", default=os.getenv("DATABASE_URL"))
    check = sub.add_parser("profile", help="write a local ingestion quality report")
    check.add_argument("directory", type=Path)
    check.add_argument("--output", type=Path, default=Path("quality-report.json"))
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s %(message)s")
    if args.command == "ingest":
        if not args.database_url:
            parser.error("DATABASE_URL or --database-url is required")
        print(json.dumps(load_directory(args.directory, args.database_url), indent=2))
    else:
        report = profile(args.directory)
        args.output.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()

