#!/usr/bin/env bash
# UI test: Swift Charts (HelloCharts sample, `import Charts`) — bar heights against the y domain, annotations,
# stacked series with a custom style scale and legend, a donut of sector marks, line/point/rule/area
# positions, horizontal bars, custom AxisMarks labels, a date axis and a rectangle heat map.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloCharts; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/charts; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/charts.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloCharts.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "chart renders"                              'grep -q "charts shown" <<<"$log" && [ -s $shots/charts.png ]'
ylabels() { for v in 0 10 20 30 40; do grep -q "text=$v$" <<<"$log" || return 1; done; }
check "y axis value labels (0 ... 40)"             'ylabels'
check "category axis labels"                       'grep -q "text=A$" <<<"$log" && grep -q "text=B$" <<<"$log" && grep -q "text=C$" <<<"$log" && grep -q "text=Mon$" <<<"$log" && grep -q "text=Tue$" <<<"$log"'
check "annotations on bars"                        'grep -q "text=v10" <<<"$log" && grep -q "text=v20" <<<"$log" && grep -q "text=v40" <<<"$log"'
check "legend for foregroundStyle(by:)"            'grep -q "text=Apples" <<<"$log" && grep -q "text=Pears" <<<"$log" && grep -q "text=Plums" <<<"$log"'
check "chartLegend(.hidden) hides a legend"     '[ "$(grep -c "text=Apples" <<<"$log")" = 2 ]'
check "custom AxisMarks values and labels"         'grep -q "text=0%" <<<"$log" && grep -q "text=50%" <<<"$log" && grep -q "text=100%" <<<"$log"'
check "several AxisMarks on one axis"              'grep -q "text=q25" <<<"$log" && grep -q "text=q75" <<<"$log"'
check "a chart in a ScrollView is 200 pt tall"      'grep -q "x 200) id=ideal" <<<"$log"'
check "date axis labels"                          'grep -q "text=Jan [0-9]" <<<"$log" && grep -q "text=5000" <<<"$log"'
python3 tests/ui/charts_check.py $shots/charts.png || fail=1
check "exits cleanly"                              '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
