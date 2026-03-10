#!/usr/bin/env bash

# Usage: ./parse_fastqc_report.sh fastqc_data.txt
fastqc_report="$1"

# Check file existence and readability
if [[ -z "$fastqc_report" ]]; then
    echo "Error: No input file provided. Usage: $0 fastqc_data.txt"
    exit 1
fi
if [[ ! -f "$fastqc_report" ]]; then
    echo "Error: File '$fastqc_report' does not exist."
    exit 1
fi
if [[ ! -r "$fastqc_report" ]]; then
    echo "Error: File '$fastqc_report' is not readable."
    exit 1
fi

# Check for FastQC report marker
if ! grep -q '##FastQC' "$fastqc_report"; then
    echo "Error: File '$fastqc_report' does not appear to be a FastQC report (missing ##FastQC marker)."
    exit 1
fi
# Check for required modules
if ! grep -q '>>Sequence Length Distribution' "$fastqc_report"; then
    echo "Error: Sequence Length Distribution section not found in FastQC report."
    exit 1
fi
if ! grep -q '>>Per sequence quality scores' "$fastqc_report"; then
    echo "Error: Per sequence quality scores section not found in FastQC report."
    exit 1
fi

# Get average quality per read from "Per sequence quality scores"
avg_quality=$(awk '/>>Per sequence quality scores/,/>>END_MODULE/ { if ($1 ~ /^[0-9]+$/) { sum += $1 * $2; count += $2 } } END { if (count > 0) print sum/count; else print "NA" }' "$fastqc_report")

# Get average read length from "Sequence Length Distribution"
avg_length=$(awk '/>>Sequence Length Distribution/,/>>END_MODULE/ { if ($1 ~ /^[0-9]+-[0-9]+$/) { split($1, range, "-"); mid = (range[1]+range[2])/2; sum += mid * $2; count += $2 } } END { if (count > 0) print sum/count; else print "NA" }' "$fastqc_report")

# Output results
if [[ "$avg_quality" == "NA" ]]; then
    echo "Average Quality: NA (data not found)"
    exit 1
fi

if [[ "$avg_length" == "NA" ]]; then
    echo "Average Read Length: NA (data not found)"
    exit 1
fi

if (( $(echo "$avg_length > 1000" | bc -l) )); then
    if (( $(echo "$avg_quality > 30" | bc -l) )); then
        echo "map-hifi"
    else
        echo "map-ont"
    fi
else
    echo "sr"
fi