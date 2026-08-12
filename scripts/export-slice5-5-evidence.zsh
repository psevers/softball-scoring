#!/bin/zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
    print -u2 "usage: $0 <result-bundle.xcresult> <new-output-directory>"
    exit 64
fi

result_bundle=$1
output_directory=$2

if [[ ! -d $result_bundle ]]; then
    print -u2 "result bundle does not exist: $result_bundle"
    exit 66
fi

if [[ -e $output_directory ]]; then
    print -u2 "refusing to overwrite existing output: $output_directory"
    exit 73
fi

output_parent=${output_directory:h}
if [[ ! -d $output_parent ]]; then
    print -u2 "output parent does not exist: $output_parent"
    exit 73
fi

staging_directory=$(mktemp -d "$output_parent/.softball-scoring-evidence.XXXXXX")
trap 'rm -rf -- "$staging_directory"' EXIT
export_directory="$staging_directory/exported"
prepared_directory="$staging_directory/prepared"
mkdir -p "$export_directory" "$prepared_directory"
xcrun xcresulttool export attachments \
    --path "$result_bundle" \
    --output-path "$export_directory"
cp "$export_directory/manifest.json" "$prepared_directory/xcresult-attachments.json"

mapping_file="$staging_directory/attachment-map.tsv"
/usr/bin/python3 - "$export_directory/manifest.json" > "$mapping_file" <<'PY'
import json
import os
import re
import sys

with open(sys.argv[1], encoding="utf-8") as manifest_file:
    manifest = json.load(manifest_file)

suffix = re.compile(r"_[0-9]+_[0-9A-F-]{36}\.png$")
safe_evidence_name = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\.png")
for test in manifest:
    for attachment in test["attachments"]:
        exported_name = attachment["exportedFileName"]
        suggested_name = attachment["suggestedHumanReadableName"]
        evidence_name = suffix.sub(".png", suggested_name)
        if os.path.basename(exported_name) != exported_name or exported_name in {".", ".."}:
            raise SystemExit(f"unsafe exported attachment name: {exported_name}")
        if evidence_name == suggested_name:
            raise SystemExit(f"unexpected attachment name: {suggested_name}")
        if safe_evidence_name.fullmatch(evidence_name) is None:
            raise SystemExit(f"unsafe evidence attachment name: {evidence_name}")
        print(f"{exported_name}\t{evidence_name}")
PY

attachment_count=0
while IFS=$'\t' read -r exported_name evidence_name; do
    if [[ -e "$prepared_directory/$evidence_name" ]]; then
        print -u2 "refusing to overwrite duplicate attachment: $evidence_name"
        exit 73
    fi
    cp "$export_directory/$exported_name" "$prepared_directory/$evidence_name"
    (( attachment_count += 1 ))
done < "$mapping_file"

if [[ $attachment_count -eq 0 ]]; then
    print -u2 "result bundle contained no screenshot attachments"
    exit 65
fi

mv "$prepared_directory" "$output_directory"
print "Exported $attachment_count evidence images to $output_directory"
