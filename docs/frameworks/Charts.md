# Charts

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 74.2% of Apple's iOS API (442 of 596, exact) · **Rows:** 17: 14 ✅ 2 🟡 1 ❌ · **iOS:** 16.0+
<!-- /generated:header -->

**Area:** [SwiftUI & Charts](../COVERAGE.md#swiftui) · **Apple:** [Charts](https://developer.apple.com/documentation/charts) · **Issues:** [`area:swiftui`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aswiftui)

## How isim implements it

- **Adapted:** built on isim's SwiftUI (`isim/swift/overlays/Charts`). Chart3D is projected and painted in a `Canvas`.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `Chart` view (`Chart { }`, `Chart(data) { }`, `ForEach` of marks, `if`/`else` content), `import Charts` | ✅ | ≤17 | isim's own implementation on its SwiftUI (`swift/overlays/Charts`; `if`/`else` content unverified); tested by HelloCharts (`tests/ui/test_charts.py`, measured in the screenshot) |
| `BarMark` (vertical, horizontal, ranges, date bins with `unit:`, `width`/`height`) | ✅ | ≤17 | |
| Bar stacking (`.standard`), grouping (`position(by:)`) | ✅ | ≤17 | `.normalized`/`.center` stacking unverified |
| `LineMark` (`series:`, `interpolationMethod`), `PointMark` | ✅ | ≤17 | linear and catmullRom drawn in the test; step/cardinal/monotone unverified |
| `symbol(_:)`, `symbol(by:)`, `symbolSize`, `symbolSize(by:)`, `chartSymbolScale`, `chartSymbolSizeScale` | ✅ | ≤17 | basic shapes (circle, square, triangle, diamond, pentagon, plus, cross, asterisk), custom `ChartSymbolShape`s, `symbol { view }` (centered on the point), `symbol(by:)` (default shape sequence or the symbol scale), sizes as areas in square points, `symbolSize(by:)` mapped onto the size scale's range (default 20...200). Tested: HelloChartsMore (test_charts_more) |
| `AreaMark` (stacked series, `yStart`/`yEnd`) | ✅ | ≤17 | stacking of several series unverified |
| `RuleMark`, `RectangleMark` | ✅ | ≤17 | |
| `SectorMark` (pie, donut `innerRadius`, `outerRadius`, `angularInset`) | ✅ | ≤17 | `angularInset` unverified; corner radius ignored |
| `PlottableValue.value(_:_:)`, `Plottable` (numbers, strings, dates, `RawRepresentable` enums) | ✅ | ≤17 | |
| `foregroundStyle(by:)` with the default palette and a legend, `chartForegroundStyleScale`, `chartLegend` | ✅ | ≤17 | `chartLegend(position: .top)` and custom legend content unverified |
| Axes: `chartXAxis`/`chartYAxis` (`.hidden`, `AxisMarks` position and values, `AxisGridLine`, `AxisTick`, `AxisValueLabel` with custom content), date axes, `AnyAxisContent` | ✅ | ≤17 | `AxisValueLabel`: Apple's initializers (text, `LocalizedStringKey` / `LocalizedStringResource`, content, `format:` with any `FormatStyle` of the value), `AxisValueLabelCollisionResolution` (adapted: `automatic` / `greedy` skip a label that would touch the last one placed, `minimumSpacing` apart; `truncate` shortens labels to the room before the next tick; `disabled` draws all; `priority` is accepted), `AxisValueLabelOrientation` (`vertical` / `verticalReversed`: turned a quarter, the axis makes room), `horizontalSpacing` / `verticalSpacing` (the gap to the plot); `multiLabelAlignment` and `offsetsMarks` are accepted. `AnyAxisContent(_:)` / `(erasing:)`. The pre-0.10 initializers stay (disfavored). Tested (HelloChartAxes); `AxisTick` unverified |
| Scales: `chartXScale`/`chartYScale` (`domain:` ranges, category lists, `.automatic(includesZero:reversed:)`; `range:`; `type:`), `ScaleType`, `PositionScaleRange` / `PlotDimensionScaleRange` | ✅ | ≤17 | `ScaleType`: `log` (base 10; an automatic domain covers whole decades, ticks at the powers of ten, also 2 and 5 within two decades), `squareRoot`, `power(exponent:)`, `symmetricLog` / `symmetricLog(slopeAtZero:)` (sign · log1p(slope · \|v\|)) transform positions; `category` makes the axis categorical; `date` and `linear` as before. `range:` (adapted): `.plotDimension(padding:)` / `(startPadding:endPadding:)` inset the domain's ends from the plot's, a `ClosedRange<CGFloat>` places them in points from the plot's leading edge (x) or bottom (y). All four overloads (`domain:range:type:`, `domain:type:`, `range:type:`, `type:`); the pre-0.10 `range: ClosedRange<CGFloat>` overload stays (disfavored). Tested (HelloChartAxes) |
| `annotation(position:alignment:spacing:)` | ✅ | ≤17 | |
| `chartXAxisLabel`, `chartYAxisLabel` (text or view content, `position`, `alignment`, `spacing`) | ✅ | ≤17 | x title below the plot (or `.top`), aligned along the axis; y title above the plot on the axis' side, or vertical beside it with `.leading` / `.trailing`. Tested: HelloChartsMore (bottom-trailing x, leading y) |
| `chartOverlay`/`chartBackground` (`ChartProxy`), selection (`chartXSelection`), scrolling (`chartScrollableAxes`) | ✅ | ≤17 | `ChartProxy`: `plotFrame` (an anchor for the overlay's `GeometryReader`), `plotSize`, `position(forX:/forY:/for:)`, `positionRange`, `value(atX:/atY:/at:)`, `xDomain`/`yDomain`, `selectXValue`/`selectXRange`/`selectAngleValue`; `chartGesture`. Selection: `chartXSelection` / `chartYSelection` (value: set while a finger is on the plot, cleared when it lifts; range: by dragging, kept), `chartAngleSelection` (pies). Scrolling: `chartScrollableAxes` with `chartX/YVisibleDomain(length:)` (numbers, dates, category counts), `chartScrollPosition(x:/y:/initialX:/initialY:)`, `chartScrollTargetBehavior(.valueAligned(unit:/matching:) / .paging)`; marks outside the window are clipped. Tested: HelloChartsMore (overlay + background placed with the proxy, value lookups, held selection, drag scroll snapped to 5); range, y and angle selection, date scrolling unverified |
| `chartPlotStyle`, vectorized plots (`BarPlot`, `LinePlot`, iOS 18), `Chart3D` | ✅ | 18.0 | `chartPlotStyle`: the plot area as a view (background, border, overlay; adapted: size modifiers do not resize the plot). iOS 18: `BarPlot`, `LinePlot` (data, series, y = f(x), parametric (x, y) = f(t)), `AreaPlot` (data, ranges, functions), `PointPlot`, `RulePlot`, `RectanglePlot`, `SectorPlot` with `PlottableProjection` key paths and the key-path modifiers (`foregroundStyle(by:)`, `symbol(by:)`, `symbolSize(by:)`, `opacity(by:)`); functions sampled over their domain or the x scale. iOS 26: `Chart3D` with `PointMark`/`RuleMark`/`RectangleMark(x:y:z:)` and `SurfacePlot` (`.heightBased`, `.normalBased`, shape styles), `chart3DPose` (a binding follows drags), `chart3DCameraProjection`, `chartZScale`; adapted: drawn in a Canvas (projected cube, painted back to front, simple shading, low/middle/high tick labels); `Angle2D` from isim's Spatial overlay. Tested: HelloChartsMore (plot style, BarPlot/PointPlot, sin LinePlot, band AreaPlot, SectorPlot; Chart3D on iOS 26) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `AnnotationContext`, `AnnotationOverflowResolution`, `AnyAxisMark`, `AnyChartSymbolShape`, `ChartAxisContent`, `ChartBinRange`, `ChartScrollTargetBehaviorContext`, `DateBins`, `NumberBins`, `Plot`, `PlotDimensionScaleRange`, `PositionScaleRange`, `ScaleRange` (14 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
154 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`AnnotationContext`](https://developer.apple.com/documentation/charts/annotationcontext)
- [`let targetSize: CGSize`](https://developer.apple.com/documentation/charts/annotationcontext/targetsize)
- [`AnnotationOverflowResolution`](https://developer.apple.com/documentation/charts/annotationoverflowresolution)
- [`static let automatic: AnnotationOverflowResolution`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/automatic)
- [`AnnotationOverflowResolution.Boundary`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/boundary)
- [`static let automatic: AnnotationOverflowResolution.Boundary`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/boundary/automatic)
- [`static let chart: AnnotationOverflowResolution.Boundary`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/boundary/chart)
- [`static let plot: AnnotationOverflowResolution.Boundary`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/boundary/plot)
- [`init(x: AnnotationOverflowResolution.Strategy, y: AnnotationOverflowResolution.Strategy)`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/init(x:y:))
- [`AnnotationOverflowResolution.Strategy`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/strategy)
- [`static let automatic: AnnotationOverflowResolution.Strategy`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/strategy/automatic)
- [`static let disabled: AnnotationOverflowResolution.Strategy`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/strategy/disabled)
- [`static let fit: AnnotationOverflowResolution.Strategy`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/strategy/fit)
- [`static func fit(to: AnnotationOverflowResolution.Boundary) -> AnnotationOverflowResolution.Strategy`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/strategy/fit(to:))
- [`static let padScale: AnnotationOverflowResolution.Strategy`](https://developer.apple.com/documentation/charts/annotationoverflowresolution/strategy/padscale)
- [`AnyAxisContent`](https://developer.apple.com/documentation/charts/anyaxiscontent)
- [`init(any AxisContent)`](https://developer.apple.com/documentation/charts/anyaxiscontent/init(_:))
- [`init(erasing: some AxisContent)`](https://developer.apple.com/documentation/charts/anyaxiscontent/init(erasing:))
- [`AnyAxisMark`](https://developer.apple.com/documentation/charts/anyaxismark)
- [`init(any AxisMark)`](https://developer.apple.com/documentation/charts/anyaxismark/init(_:))
- [`init(erasing: some AxisMark)`](https://developer.apple.com/documentation/charts/anyaxismark/init(erasing:))
- [`AnyChartSymbolShape`](https://developer.apple.com/documentation/charts/anychartsymbolshape)
- [`init(any ChartSymbolShape)`](https://developer.apple.com/documentation/charts/anychartsymbolshape/init(_:))
- [`func compositingLayer() -> some AxisContent`](https://developer.apple.com/documentation/charts/axiscontent/compositinglayer())
- [`func compositingLayer<V>(style: (PlaceholderContentView<Self>) -> V) -> some AxisContent`](https://developer.apple.com/documentation/charts/axiscontent/compositinglayer(style:))
- [`static func buildIf<T>(T?) -> T?`](https://developer.apple.com/documentation/charts/axiscontentbuilder/buildif(_:))
- [`static func buildLimitedAvailability<Content>(Content) -> AnyAxisContent`](https://developer.apple.com/documentation/charts/axiscontentbuilder/buildlimitedavailability(_:))
- [`func offset(CGSize) -> some AxisMark`](https://developer.apple.com/documentation/charts/axismark/offset(_:))
- [`func offset(x: CGFloat, y: CGFloat) -> some AxisMark`](https://developer.apple.com/documentation/charts/axismark/offset(x:y:))
- [`static func buildIf<T>(T?) -> T?`](https://developer.apple.com/documentation/charts/axismarkbuilder/buildif(_:))
- [`static func buildLimitedAvailability<Content>(Content) -> AnyAxisMark`](https://developer.apple.com/documentation/charts/axismarkbuilder/buildlimitedavailability(_:))
- [`AxisTick.Length`](https://developer.apple.com/documentation/charts/axistick/length)
- [`static var automatic: AxisTick.Length`](https://developer.apple.com/documentation/charts/axistick/length/automatic)
- [`static var label: AxisTick.Length`](https://developer.apple.com/documentation/charts/axistick/length/label)
- [`static func label(extendPastBy: CGFloat) -> AxisTick.Length`](https://developer.apple.com/documentation/charts/axistick/length/label(extendpastby:))
- [`static var longestLabel: AxisTick.Length`](https://developer.apple.com/documentation/charts/axistick/length/longestlabel)
- [`static func longestLabel(extendPastBy: CGFloat) -> AxisTick.Length`](https://developer.apple.com/documentation/charts/axistick/length/longestlabel(extendpastby:))
- [`AxisValueLabelCollisionResolution`](https://developer.apple.com/documentation/charts/axisvaluelabelcollisionresolution)
- [`static var automatic: AxisValueLabelCollisionResolution`](https://developer.apple.com/documentation/charts/axisvaluelabelcollisionresolution/automatic)
- [`static var disabled: AxisValueLabelCollisionResolution`](https://developer.apple.com/documentation/charts/axisvaluelabelcollisionresolution/disabled)
- [`static var greedy: AxisValueLabelCollisionResolution`](https://developer.apple.com/documentation/charts/axisvaluelabelcollisionresolution/greedy)
- [`static func greedy(priority: Double, minimumSpacing: CGFloat?) -> AxisValueLabelCollisionResolution`](https://developer.apple.com/documentation/charts/axisvaluelabelcollisionresolution/greedy(priority:minimumspacing:))
- [`static var truncate: AxisValueLabelCollisionResolution`](https://developer.apple.com/documentation/charts/axisvaluelabelcollisionresolution/truncate)
- [`AxisValueLabelOrientation`](https://developer.apple.com/documentation/charts/axisvaluelabelorientation)
- [`static var automatic: AxisValueLabelOrientation`](https://developer.apple.com/documentation/charts/axisvaluelabelorientation/automatic)
- [`static var horizontal: AxisValueLabelOrientation`](https://developer.apple.com/documentation/charts/axisvaluelabelorientation/horizontal)
- [`static var vertical: AxisValueLabelOrientation`](https://developer.apple.com/documentation/charts/axisvaluelabelorientation/vertical)
- [`static var verticalReversed: AxisValueLabelOrientation`](https://developer.apple.com/documentation/charts/axisvaluelabelorientation/verticalreversed)
- [`BasicChart3DSymbolShape`](https://developer.apple.com/documentation/charts/basicchart3dsymbolshape)
- [`func strokeBorder(lineWidth: CGFloat) -> some ChartSymbolShape`](https://developer.apple.com/documentation/charts/basicchartsymbolshape/strokeborder(linewidth:))
- [`BuilderConditional`](https://developer.apple.com/documentation/charts/builderconditional)
- [`func foregroundStyle(some Chart3DSurfaceStyle) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/foregroundstyle(_:)-1pjaq)
- [`func foregroundStyle(some ShapeStyle) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/foregroundstyle(_:)-7skde)
- [`func foregroundStyle<D>(by: PlottableValue<D>) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/foregroundstyle(by:))
- [`func metalness(Double) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/metalness(_:))
- [`func roughness(Double) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/roughness(_:))
- [`func symbol<S>(S) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/symbol(_:))
- [`func symbolRotation(Rotation3D) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/symbolrotation(_:))
- [`func symbolSize(CGFloat) -> some Chart3DContent`](https://developer.apple.com/documentation/charts/chart3dcontent/symbolsize(_:))
- [`Chart3DSymbolShape`](https://developer.apple.com/documentation/charts/chart3dsymbolshape)
- [`static var cone: BasicChart3DSymbolShape`](https://developer.apple.com/documentation/charts/chart3dsymbolshape/cone)
- [`static var cube: BasicChart3DSymbolShape`](https://developer.apple.com/documentation/charts/chart3dsymbolshape/cube)
- [`static var cylinder: BasicChart3DSymbolShape`](https://developer.apple.com/documentation/charts/chart3dsymbolshape/cylinder)
- [`static var sphere: BasicChart3DSymbolShape`](https://developer.apple.com/documentation/charts/chart3dsymbolshape/sphere)
- [`ChartAxisContent`](https://developer.apple.com/documentation/charts/chartaxiscontent)
- [`ChartBinRange`](https://developer.apple.com/documentation/charts/chartbinrange)
- [`let lowerBound: Bound`](https://developer.apple.com/documentation/charts/chartbinrange/lowerbound)
- [`let upperBound: Bound`](https://developer.apple.com/documentation/charts/chartbinrange/upperbound)
- [`func accessibilityIdentifier(String) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/accessibilityidentifier(_:))
- [`func alignsMarkStylesWithPlotArea(Bool) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/alignsmarkstyleswithplotarea(_:))
- [`func blur(radius: CGFloat) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/blur(radius:))
- [`func clipShape(some Shape, style: FillStyle) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/clipshape(_:style:))
- [`func compositingLayer() -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/compositinglayer())
- [`func compositingLayer<V>(style: (PlaceholderContentView<Self>) -> V) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/compositinglayer(style:))
- [`func mask<C>(content: () -> C) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/mask(content:))
- [`func offset(CGSize) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/offset(_:))
- [`func offset(x: CGFloat, y: CGFloat) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/offset(x:y:))
- [`func offset(x: CGFloat, yStart: CGFloat, yEnd: CGFloat) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/offset(x:ystart:yend:))
- [`func offset(xStart: CGFloat, xEnd: CGFloat, y: CGFloat) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/offset(xstart:xend:y:))
- [`func offset(xStart: CGFloat, xEnd: CGFloat, yStart: CGFloat, yEnd: CGFloat) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/offset(xstart:xend:ystart:yend:))
- [`func shadow(color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/shadow(color:radius:x:y:))
- [`func zIndex(Double) -> some ChartContent`](https://developer.apple.com/documentation/charts/chartcontent/zindex(_:))
- [`func angle(at: CGPoint) -> Angle`](https://developer.apple.com/documentation/charts/chartproxy/angle(at:))
- [`func foregroundStyle<P>(for: P) -> AnyShapeStyle?`](https://developer.apple.com/documentation/charts/chartproxy/foregroundstyle(for:))
- [`func foregroundStyleDomain<P>(dataType: P.Type) -> [P]`](https://developer.apple.com/documentation/charts/chartproxy/foregroundstyledomain(datatype:))
- [`func lineStyle<P>(for: P) -> StrokeStyle?`](https://developer.apple.com/documentation/charts/chartproxy/linestyle(for:))
- [`func lineStyleDomain<P>(dataType: P.Type) -> [P]`](https://developer.apple.com/documentation/charts/chartproxy/linestyledomain(datatype:))
- [`func symbol<P>(for: P) -> AnyChartSymbolShape?`](https://developer.apple.com/documentation/charts/chartproxy/symbol(for:))
- [`func symbolDomain<P>(dataType: P.Type) -> [P]`](https://developer.apple.com/documentation/charts/chartproxy/symboldomain(datatype:))
- [`func symbolSize<P>(for: P) -> CGFloat?`](https://developer.apple.com/documentation/charts/chartproxy/symbolsize(for:))
- [`func symbolSizeDomain<P>(dataType: P.Type) -> [P]`](https://developer.apple.com/documentation/charts/chartproxy/symbolsizedomain(datatype:))
- [`func updateTarget(inout ScrollTarget, context: ChartScrollTargetBehaviorContext)`](https://developer.apple.com/documentation/charts/chartscrolltargetbehavior/updatetarget(_:context:))
- [`func updateTarget(inout ScrollTarget, context: ScrollTargetBehaviorContext)`](https://developer.apple.com/documentation/charts/chartscrolltargetbehavior/updatetarget(_:context:)-8j5z4)
- [`func updateTarget(inout ScrollTarget, context: ScrollTargetBehaviorContext)`](https://developer.apple.com/documentation/charts/chartscrolltargetbehavior/updatetarget(_:context:)-8j5z4)
- [`ChartScrollTargetBehaviorContext`](https://developer.apple.com/documentation/charts/chartscrolltargetbehaviorcontext)
- [`var chartProxy: ChartProxy`](https://developer.apple.com/documentation/charts/chartscrolltargetbehaviorcontext/chartproxy)
- [`subscript<T>(dynamicMember _: KeyPath<ScrollTargetBehaviorContext, T>) -> T`](https://developer.apple.com/documentation/charts/chartscrolltargetbehaviorcontext/subscript(dynamicmember:))
- [`var perceptualUnitRect: CGRect`](https://developer.apple.com/documentation/charts/chartsymbolshape/perceptualunitrect)
- [`func strokeBorder(lineWidth: CGFloat) -> some ChartSymbolShape`](https://developer.apple.com/documentation/charts/chartsymbolshape/strokeborder(linewidth:))
- [`func strokeBorder(style: StrokeStyle) -> some ChartSymbolShape`](https://developer.apple.com/documentation/charts/chartsymbolshape/strokeborder(style:))
- [`DateBins`](https://developer.apple.com/documentation/charts/datebins)
- [`func index(for: Date) -> Int`](https://developer.apple.com/documentation/charts/datebins/index(for:))
- [`init(data: [Date], desiredCount: Int?, calendar: Calendar)`](https://developer.apple.com/documentation/charts/datebins/init(data:desiredcount:calendar:))
- [`init(range: ClosedRange<Date>, desiredCount: Int, calendar: Calendar)`](https://developer.apple.com/documentation/charts/datebins/init(range:desiredcount:calendar:))
- [`init(thresholds: [Date])`](https://developer.apple.com/documentation/charts/datebins/init(thresholds:))
- [`init(timeInterval: TimeInterval, range: ClosedRange<Date>)`](https://developer.apple.com/documentation/charts/datebins/init(timeinterval:range:))
- [`init(unit: Calendar.Component, by: Int, range: ClosedRange<Date>, calendar: Calendar)`](https://developer.apple.com/documentation/charts/datebins/init(unit:by:range:calendar:))
- [`var thresholds: [Date]`](https://developer.apple.com/documentation/charts/datebins/thresholds)
- [`MajorValueAlignment`](https://developer.apple.com/documentation/charts/majorvaluealignment)
- [`static func matching(DateComponents) -> MajorValueAlignment<Value>`](https://developer.apple.com/documentation/charts/majorvaluealignment/matching(_:))
- [`static var page: MajorValueAlignment<Value>`](https://developer.apple.com/documentation/charts/majorvaluealignment/page)
- [`static func unit(Value) -> MajorValueAlignment<Value>`](https://developer.apple.com/documentation/charts/majorvaluealignment/unit(_:))
- [`NumberBins`](https://developer.apple.com/documentation/charts/numberbins)
- [`func index(for: Value) -> Int`](https://developer.apple.com/documentation/charts/numberbins/index(for:))
- [`init(data: [Value], desiredCount: Int?, minimumStride: Value)`](https://developer.apple.com/documentation/charts/numberbins/init(data:desiredcount:minimumstride:)-3txi5)
- [`init(data: [Value], desiredCount: Int?, minimumStride: Value)`](https://developer.apple.com/documentation/charts/numberbins/init(data:desiredcount:minimumstride:)-8pvv7)
- [`init(range: ClosedRange<Value>, count: Int)`](https://developer.apple.com/documentation/charts/numberbins/init(range:count:)-6hip8)
- [`init(range: ClosedRange<Value>, count: Int)`](https://developer.apple.com/documentation/charts/numberbins/init(range:count:)-7975l)
- [`init(range: ClosedRange<Value>, desiredCount: Int, minimumStride: Value)`](https://developer.apple.com/documentation/charts/numberbins/init(range:desiredcount:minimumstride:)-32ok2)
- [`init(range: ClosedRange<Value>, desiredCount: Int, minimumStride: Value)`](https://developer.apple.com/documentation/charts/numberbins/init(range:desiredcount:minimumstride:)-4qxfa)
- [`init(size: Value, range: ClosedRange<Value>)`](https://developer.apple.com/documentation/charts/numberbins/init(size:range:)-3ach2)
- [`init(size: Value, range: ClosedRange<Value>)`](https://developer.apple.com/documentation/charts/numberbins/init(size:range:)-5me6y)
- [`init(thresholds: [Value])`](https://developer.apple.com/documentation/charts/numberbins/init(thresholds:))
- [`var thresholds: [Value]`](https://developer.apple.com/documentation/charts/numberbins/thresholds)
- [`Plot`](https://developer.apple.com/documentation/charts/plot)
- [`init(content: () -> Content)`](https://developer.apple.com/documentation/charts/plot/init(content:))
- [`PlotDimensionScaleRange`](https://developer.apple.com/documentation/charts/plotdimensionscalerange)
- [`PositionScaleRange`](https://developer.apple.com/documentation/charts/positionscalerange)
- [`static var plotDimension: PlotDimensionScaleRange`](https://developer.apple.com/documentation/charts/positionscalerange/plotdimension)
- [`static func plotDimension(padding: CGFloat) -> PlotDimensionScaleRange`](https://developer.apple.com/documentation/charts/positionscalerange/plotdimension(padding:))
- [`static func plotDimension(startPadding: CGFloat, endPadding: CGFloat) -> PlotDimensionScaleRange`](https://developer.apple.com/documentation/charts/positionscalerange/plotdimension(startpadding:endpadding:))
- [`PrimitivePlottableProtocol`](https://developer.apple.com/documentation/charts/primitiveplottableprotocol)
- [`ScaleRange`](https://developer.apple.com/documentation/charts/scalerange)
- [`VisualValue`](https://developer.apple.com/documentation/charts/scalerange/visualvalue)
- [`static var symmetricLog: ScaleType`](https://developer.apple.com/documentation/charts/scaletype/symmetriclog)
- [`static func symmetricLog(slopeAtZero: Double) -> ScaleType`](https://developer.apple.com/documentation/charts/scaletype/symmetriclog(slopeatzero:))
- [`init(matching: DateComponents, majorAlignment: MajorValueAlignment<Date>?, limitBehavior: ValueAlignedLimitBehavior)`](https://developer.apple.com/documentation/charts/valuealignedchartscrolltargetbehavior/init(matching:majoralignment:limitbehavior:))
- [`init<T>(unit: T, majorAlignment: MajorValueAlignment<T>?, limitBehavior: ValueAlignedLimitBehavior)`](https://developer.apple.com/documentation/charts/valuealignedchartscrolltargetbehavior/init(unit:majoralignment:limitbehavior:))
- [`init(xMatching: DateComponents, yMatching: DateComponents, xMajorAlignment: MajorValueAlignment<Date>?, yMajorAlignment: MajorValueAlignment<Date>?, limitBehavior: ValueAlignedLimitBehavior)`](https://developer.apple.com/documentation/charts/valuealignedchartscrolltargetbehavior/init(xmatching:ymatching:xmajoralignment:ymajoralignment:limitbehavior:))
- [`init<Y>(xMatching: DateComponents, yUnit: Y, xMajorAlignment: MajorValueAlignment<Date>?, yMajorAlignment: MajorValueAlignment<Y>?, limitBehavior: ValueAlignedLimitBehavior)`](https://developer.apple.com/documentation/charts/valuealignedchartscrolltargetbehavior/init(xmatching:yunit:xmajoralignment:ymajoralignment:limitbehavior:))
- [`init<X>(xUnit: X, yMatching: DateComponents, xMajorAlignment: MajorValueAlignment<X>?, yMajorAlignment: MajorValueAlignment<Date>?, limitBehavior: ValueAlignedLimitBehavior)`](https://developer.apple.com/documentation/charts/valuealignedchartscrolltargetbehavior/init(xunit:ymatching:xmajoralignment:ymajoralignment:limitbehavior:))
- [`init<X, Y>(xUnit: X, yUnit: Y, xMajorAlignment: MajorValueAlignment<X>?, yMajorAlignment: MajorValueAlignment<Y>?, limitBehavior: ValueAlignedLimitBehavior)`](https://developer.apple.com/documentation/charts/valuealignedchartscrolltargetbehavior/init(xunit:yunit:xmajoralignment:ymajoralignment:limitbehavior:))
- [`ValueAlignedLimitBehavior`](https://developer.apple.com/documentation/charts/valuealignedlimitbehavior)
- [`static var always: ValueAlignedLimitBehavior`](https://developer.apple.com/documentation/charts/valuealignedlimitbehavior/always)
- [`static var automatic: ValueAlignedLimitBehavior`](https://developer.apple.com/documentation/charts/valuealignedlimitbehavior/automatic)
- [`static var never: ValueAlignedLimitBehavior`](https://developer.apple.com/documentation/charts/valuealignedlimitbehavior/never)
- [`VectorizedAreaPlotContent`](https://developer.apple.com/documentation/charts/vectorizedareaplotcontent)
- [`VectorizedBarPlotContent`](https://developer.apple.com/documentation/charts/vectorizedbarplotcontent)
- [`func accessibilityIdentifier(KeyPath<Self.DataElement, String>) -> some VectorizedChartContent<Self.DataElement>
`](https://developer.apple.com/documentation/charts/vectorizedchartcontent/accessibilityidentifier(_:))
- [`VectorizedLinePlotContent`](https://developer.apple.com/documentation/charts/vectorizedlineplotcontent)
- [`VectorizedPointPlotContent`](https://developer.apple.com/documentation/charts/vectorizedpointplotcontent)
- [`VectorizedRectanglePlotContent`](https://developer.apple.com/documentation/charts/vectorizedrectangleplotcontent)
- [`VectorizedRulePlotContent`](https://developer.apple.com/documentation/charts/vectorizedruleplotcontent)
- [`VectorizedSectorPlotContent`](https://developer.apple.com/documentation/charts/vectorizedsectorplotcontent)

</details>
<!-- /generated:missing -->
