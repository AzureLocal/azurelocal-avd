#!/usr/bin/env python3
"""Validate config/variables/*.yml against config/variables/schema/variables.schema.json."""

import json
import pathlib
import sys

import yaml
from jsonschema import ValidationError, validate


def validate_file(schema: dict, path: pathlib.Path) -> bool:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle)
    try:
        validate(instance=data, schema=schema)
        print(f"PASS: {path}")
        return True
    except ValidationError as exc:
        path_str = " > ".join(str(part) for part in exc.absolute_path)
        print(f"FAIL: {path}: {exc.message}")
        if path_str:
            print(f"PATH: {path_str}")
        return False


def main() -> int:
    root = pathlib.Path(__file__).resolve().parents[1]
    schema_path = root / "config" / "variables" / "schema" / "variables.schema.json"
    with schema_path.open("r", encoding="utf-8") as handle:
        schema = json.load(handle)

    targets = [root / "config" / "variables" / "variables.example.yml"]
    variables_file = root / "config" / "variables" / "variables.yml"
    if variables_file.exists():
        targets.append(variables_file)

    failed = False
    for target in targets:
        if not validate_file(schema, target):
            failed = True

    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
