#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <min_depth> <input.sam|input.bam|input.cram>" >&2
  exit 1
fi

MIN_DEPTH="$1"
INPUT="$2"
MIN_GAP=10        # max gap to merge intervals
MIN_LEN=50        # minimum interval length to keep

if [[ ! -f "$INPUT" ]]; then
  echo "Error: file not found: $INPUT" >&2
  exit 1
fi

BASENAME="$(basename "$INPUT")"
OUTBED="${BASENAME%.*}.bed"

# Check dependencies
for cmd in megadepth bedtools; do
  command -v $cmd >/dev/null 2>&1 || { echo "Error: $cmd not found in PATH" >&2; exit 1; }
done

# Generate BED of intervals with coverage > MIN_DEPTH, merge gaps, remove tiny intervals
megadepth "$INPUT" --coverage --no-annotation-stdout \
  | awk -v d="$MIN_DEPTH" '$4 > d {print $1, $2, $3}' OFS='\t' \
  | sort -k1,1V -k2,2n \
  | bedtools merge -d "$MIN_GAP" -i - \
  | awk -v minlen="$MIN_LEN" '$3 - $2 >= minlen' \
  > "$OUTBED"

echo "Covered regions (depth > $MIN_DEPTH, gap ≤ $MIN_GAP bp, length ≥ $MIN_LEN bp) written to: $OUTBED"
