#! /usr/bin/bash

PDFJAM="/usr/bin/pdfjam --quiet --keepinfo --fitpaper true"

set_length() {
    if [[ $2 != +([[:digit:]]) ]]; then
        echo "Invalid length: $2"
        exit 1
    fi
    eval $1=\$2
}

if [[ $# -lt 4 ]]; then
    cat <<END
Usage: $(basename "$0") TOP BOTTOM OUTSIDE [INSIDE] PDFFILE

All units are PostScript points.
END
    exit 1
fi
for length in TOP BOTTOM OUTSIDE; do
    set_length "$length" "$1"
    shift
done
if [[ $# -gt 1 ]]; then
    set_length INSIDE "$1"
    shift
else
    INSIDE=$OUTSIDE
fi
if [[ $(pdfinfo "$1" | grep -e "Pages:" -e "Page size:") =~ ([[:digit:]]+)[^[:digit:]]+([[:digit:]]+)[^\ ]*\ x\ ([[:digit:]]+) ]]; then
    PAGES=${BASH_REMATCH[1]}
    WIDTH=${BASH_REMATCH[2]}
    HEIGHT=${BASH_REMATCH[3]}
else
    echo "Could not get PDF information"
    exit 1
fi

VSKIP=$((HEIGHT - TOP - BOTTOM - 3 * (WIDTH - OUTSIDE - INSIDE) / 4))
ODD=$(seq -s, 1 2 $PAGES)
EVEN=$(seq -s, 2 2 $PAGES)
NAME=$(basename "$1")
TMPDIR=".tmp_$NAME-noprint"
mkdir "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

$PDFJAM "$1" "$ODD" --trim "$INSIDE $((BOTTOM + VSKIP)) $OUTSIDE $TOP" --clip true --angle 90 --outfile "$TMPDIR/odd-top.pdf" &
$PDFJAM "$1" "$ODD" --trim "$INSIDE $BOTTOM $OUTSIDE $((TOP + VSKIP))" --clip true --angle 90 --outfile "$TMPDIR/odd-bottom.pdf" &
$PDFJAM "$1" "$EVEN" --trim "$OUTSIDE $((BOTTOM + VSKIP)) $INSIDE $TOP" --clip true --angle 90 --outfile "$TMPDIR/even-top.pdf" &
$PDFJAM "$1" "$EVEN" --trim "$OUTSIDE $BOTTOM $INSIDE $((TOP + VSKIP))" --clip true --angle 90 --outfile "$TMPDIR/even-bottom.pdf" &
wait

ORDER=$({
    seq 1 2 $PAGES  # odd, top
    seq 1 2 $PAGES  # odd, bottom
    seq 2 2 $PAGES  # even, top
    seq 2 2 $PAGES  # even, bottom
  } | nl -w1 | sort -s -k2 -n | cut -f1 | paste -s -d,)
$PDFJAM "$TMPDIR"/{odd-top,odd-bottom,even-top,even-bottom}.pdf --outfile /dev/stdout | \
    $PDFJAM /dev/stdin "$ORDER" --outfile "${NAME%.pdf}-noprint.pdf"

