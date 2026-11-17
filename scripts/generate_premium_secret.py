#!/usr/bin/env python3
"""Append the local Apphud credential to the existing generated Swift source."""

import os
import secrets
from pathlib import Path


def main() -> None:
    value = os.environ.get("APPHUD_API_KEY", "").strip()
    if "REPLACE_WITH_KEY" in value:
        value = ""
    raw = value.encode("utf-8")
    salt = secrets.token_bytes(len(raw))
    masked = bytes(left ^ right for left, right in zip(raw, salt))
    output = Path(os.environ["DERIVED_FILE_DIR"]) / "LLMSecret.generated.swift"
    with output.open("a") as stream:
        stream.write("\nenum PremiumApphudCredential {\n")
        stream.write(f"    static let masked: [UInt8] = {list(masked)}\n")
        stream.write(f"    static let salt: [UInt8] = {list(salt)}\n")
        stream.write("}\n")


if __name__ == "__main__":
    main()
