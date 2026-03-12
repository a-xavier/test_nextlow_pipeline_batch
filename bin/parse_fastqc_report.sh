#!/usr/bin/env bash
set -euo pipefail

# Usage: ./parse_fastqc_report.sh fastqc_data.txt
fastqc_report="${1:-}"

# ---- checks ----
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

if ! grep -q '##FastQC' "$fastqc_report"; then
    echo "Error: File '$fastqc_report' does not appear to be a FastQC report."
    exit 1
fi

if ! grep -q '>>Sequence Length Distribution' "$fastqc_report"; then
    echo "Error: Sequence Length Distribution section not found."
    exit 1
fi

if ! grep -q '>>Per sequence quality scores' "$fastqc_report"; then
    echo "Error: Per sequence quality scores section not found."
    exit 1
fi

# ---- compute averages ----
read avg_quality avg_length <<< "$(awk '

BEGIN{
    in_len=0
    in_qual=0
    len_sum=0
    len_count=0
    qual_sum=0
    qual_count=0
}

# detect modules
/^>>Sequence Length Distribution/ {in_len=1; in_qual=0; next}
/^>>Per sequence quality scores/ {in_qual=1; in_len=0; next}
/^>>END_MODULE/ {in_len=0; in_qual=0; next}

# length distribution
in_len && $1 !~ /^#/ {

    count=$2+0
    len=$1

    if (len ~ /^[0-9]+-[0-9]+$/) {
        split(len,a,"-")
        mid=(a[1]+a[2])/2
    } else if (len ~ /^[0-9]+$/) {
        mid=len
    } else {
        next
    }

    len_sum += mid * count
    len_count += count
}

# quality distribution
in_qual && $1 !~ /^#/ {
    q=$1+0
    count=$2+0
    qual_sum += q * count
    qual_count += count
}

END{
    if(len_count>0){avg_len=len_sum/len_count}else{avg_len="NA"}
    if(qual_count>0){avg_qual=qual_sum/qual_count}else{avg_qual="NA"}

    printf "%s %s\n", avg_qual, avg_len
}
' "$fastqc_report")"

# ---- validate results ----
if [[ "$avg_quality" == "NA" ]]; then
    echo "Average Quality: NA (data not found)"
    exit 1
fi

if [[ "$avg_length" == "NA" ]]; then
    echo "Average Read Length: NA (data not found)"
    exit 1
fi

# ---- choose minimap2 preset (no bc needed) ----
awk -v len="$avg_length" -v qual="$avg_quality" '
BEGIN{
    if(len > 1000){
        if(qual > 30){
            print "map-hifi"
        } else {
            print "map-ont"
        }
    } else {
        print "sr"
    }
}'