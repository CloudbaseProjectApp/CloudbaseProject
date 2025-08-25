import SwiftUI
import Combine
import Charts

// Data wrapper so all lines live in the same dataset for forecast/actual comparison chart
struct WindSeriesPoint: Identifiable {
    let id = UUID()
    let time: Date
    let value: Double?
    let series: String
}

struct WindArrow: View {
    let speed: Double
    let direction: Double   // degrees from north
    let color: Color

    var body: some View {
        Image(systemName: "arrow.up")
            .resizable()
            .frame(width: 10, height: 18)
            .rotationEffect(.degrees(direction+180))  // rotate arrow to wind dir
            .foregroundColor(color)
    }
}

struct SiteForecastActualCompareView: View {
    @ObservedObject var siteForecastViewModel: SiteForecastViewModel
    @ObservedObject var stationReadingsHistoryViewModel: StationReadingsHistoryViewModel
    
    var body: some View {
        VStack {
            if let chart = buildChart() {
                chart
            } else {
                Text("No data available")
                    .font(.subheadline)
                    .foregroundColor(infoFontColor)
                
            }
        }
/*        .onDisappear {
            // Clear old data when the view appears
            stationReadingsHistoryViewModel.pastReadingsData = PastReadingsData(
                timestamp: [],
                windSpeed: [],
                windGust: [],
                windDirection: []
            )
        }
 */
    }
    
    // Use to show actual reading arrows up to a limit of 3 arrows per hour
    func sampledActuals(times: [Date], speeds: [Double], dirs: [Double]) -> [(Date, Double, Double)] {
        guard times.count == speeds.count, times.count == dirs.count else { return [] }
        
        // Group by 20-minute intervals
        let grouped = Dictionary(grouping: zip(times, zip(speeds, dirs))) { t, _ in
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: t)
            let minute = (comps.minute ?? 0) / 20 * 20  // round down to nearest 15 min
            return Calendar.current.date(from: DateComponents(
                year: comps.year,
                month: comps.month,
                day: comps.day,
                hour: comps.hour,
                minute: minute
            )) ?? t
        }
        var result: [(Date, Double, Double)] = []
        
        // Take first reading in each 20-min interval
        for (_, vals) in grouped {
            if let (t, (s, d)) = vals.first {
                result.append((t, s, d))
            }
        }
        return result.sorted { $0.0 < $1.0 }
    }
    
    func xPosition(for time: Date, width: CGFloat, domainMin: Date, domainMax: Date) -> CGFloat {
        let totalSeconds = domainMax.timeIntervalSince(domainMin)
        let secondsFromStart = time.timeIntervalSince(domainMin)
        return CGFloat(secondsFromStart / totalSeconds) * width
    }
    
    private func buildChart() -> AnyView? {
        let actual = stationReadingsHistoryViewModel.pastReadingsData
        guard !actual.timestamp.isEmpty else { return nil }
        let forecast = siteForecastViewModel.forecastData?.pastHourly

        let actualMin = actual.timestamp.min() ?? Date()
        let actualMax = actual.timestamp.max() ?? Date()

        let yDomain: ClosedRange<Double>? = {
            var allValues = actual.windSpeed + actual.windGust
            if let f = forecast {
                allValues += f.windSpeed + f.windGust
            }
            guard let minV = allValues.min(), let maxV = allValues.max() else { return nil }
            let range = maxV - minV
            let padding = (range == 0) ? max(1, maxV) * 0.1 : range * 0.1
            return (minV - padding)...(maxV + padding)
        }()

        var points: [WindSeriesPoint] = []
        for (i, t) in actual.timestamp.enumerated() {
            if i < actual.windSpeed.count {
                points.append(WindSeriesPoint(time: t, value: actual.windSpeed[i], series: "Actual Wind"))
            }
            if i < actual.windGust.count {
                let gust = actual.windGust[i]
                points.append(WindSeriesPoint(time: t, value: gust == 0 ? nil : gust, series: "Actual Gust"))
            }
        }

        if let f = forecast {
            // Forecast wind points
            let windPoints: [WindSeriesPoint] = f.timestamp.enumerated().compactMap { i, t in
                guard i < f.windSpeed.count else { return nil }
                return WindSeriesPoint(time: t, value: f.windSpeed[i], series: "Forecast Wind")
            }

            // Forecast gust points
            let gustPoints: [WindSeriesPoint] = f.timestamp.enumerated().compactMap { i, t in
                guard i < f.windGust.count else { return nil }
                return WindSeriesPoint(time: t, value: f.windGust[i], series: "Forecast Gust")
            }

            points.append(contentsOf: extrapolateToDomainEdges(points: windPoints, domain: actualMin...actualMax))
            points.append(contentsOf: extrapolateToDomainEdges(points: gustPoints, domain: actualMin...actualMax))
        }
        
        let actualWindPoints = points.filter { $0.series == "Actual Wind" }
        let allLinePoints = points

        let actualArrows = sampledActuals(
            times: actual.timestamp,
            speeds: actual.windSpeed,
            dirs: actual.windDirection
        ).filter { $0.0 >= actualMin && $0.0 <= actualMax }

        let forecastArrows: [(Date, Double, Double)] = {
            guard let f = forecast else { return [] }
            return Array(zip(f.timestamp, zip(f.windSpeed, f.windDirection)))
                .map { ($0.0, $0.1.0, $0.1.1) }
                .filter { $0.0 >= actualMin && $0.0 <= actualMax }
        }()

        let _: DateFormatter = {
            let df = DateFormatter()
            df.dateFormat = "ha"
            return df
        }()

        let baseChart = Chart {
            if let domain = yDomain {
                areaMarks(points: actualWindPoints, domain: domain)
            }
            lineMarks(points: allLinePoints)
        }
        .chartForegroundStyleScale([
            "Actual Wind": Color.white,
            "Actual Gust": Color.gray,
            "Forecast Wind": Color.blue,
            "Forecast Gust": Color.blue.opacity(0.5)
        ])
        .chartLegend(.hidden)
        .chartXScale(domain: actualMin...actualMax)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(anchor: .top)
            }
        }
        .chartYAxis { AxisMarks(position: .leading) }
        .frame(height: 200)
        .ifLet(yDomain) { view, domain in
            view.chartYScale(domain: domain)
        }

        let container = VStack(alignment: .leading, spacing: 0) {
            ZStack {
                baseChart
                    .chartOverlay { proxy in
                        GeometryReader { geo in
                            if let plotFrame = proxy.plotFrame {
                                let plotRect = geo[plotFrame]

                                ZStack(alignment: .topLeading) {
                                    // Actual arrows row
                                    ForEach(actualArrows, id: \.0) { t, speed, dir in
                                        if let x = proxy.position(forX: t) {
                                            WindArrow(speed: speed, direction: dir, color: chartActualWindColor)
                                                .position(
                                                    x: x + plotRect.minX,   // align with data, not axis
                                                    y: plotRect.maxY + 35   // below X-axis labels
                                                )
                                        }
                                    }

                                    // Forecast arrows row (a bit lower)
                                    ForEach(forecastArrows, id: \.0) { t, speed, dir in
                                        if let x = proxy.position(forX: t) {
                                            WindArrow(speed: speed, direction: dir, color: chartForecastWindColor)
                                                .position(
                                                    x: x + plotRect.minX,
                                                    y: plotRect.maxY + 60
                                                )
                                        }
                                    }
                                }
                            }
                        }
                    }
            }
            .frame(height: 210) // chart + arrows
            Spacer()
            // Legend
            HStack(spacing: 20) {
                Spacer()
                VStack(spacing: 6) {
                    legendRow(color: chartActualGustColor, title: "Actual gust", imageScale: 10)
                    legendRow(color: chartActualWindColor, title: "Actual wind", imageScale: 10)
                }
                Spacer()
                VStack(spacing: 6) {
                    legendRow(color: chartForecastGustColor, title: "Forecast gust", imageScale: 10)
                    legendRow(color: chartForecastWindColor, title: "Forecast wind", imageScale: 10)
                }
                Spacer()
            }
            .padding(.top, 50)
            .font(.caption)
            Spacer()
        }

        return AnyView(container)
    }
    
    private func legendRow(color: Color, title: String, imageScale: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: imageScale, height: imageScale)
                .foregroundColor(color)
            Text(title)
                .foregroundColor(.white)
                .font(.caption2)
        }
    }
    
    private func areaMarks(points: [WindSeriesPoint], domain: ClosedRange<Double>) -> some ChartContent {
        ForEach(points, id: \.id) { p in
            if let v = p.value {
                AreaMark(
                    x: .value("Time", p.time),
                    yStart: .value("Baseline", domain.lowerBound),
                    yEnd: .value("Speed", v)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    .linearGradient(
                        colors: [Color.white.opacity(0.4), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
        }
    }
    
    private func lineMarks(points: [WindSeriesPoint]) -> some ChartContent {
        ForEach(points, id: \.id) { p in
            if let v = p.value {
                LineMark(
                    x: .value("Time", p.time),
                    y: .value("Speed", v)
                )
                .foregroundStyle(by: .value("Series", p.series))
                .interpolationMethod(.monotone)
            }
        }
    }
    
    func extrapolateToDomainEdges(points: [WindSeriesPoint], domain: ClosedRange<Date>) -> [WindSeriesPoint] {
        guard !points.isEmpty else { return [] }
        var result: [WindSeriesPoint] = []

        // Sort by time
        let sorted = points.sorted { $0.time < $1.time }

        // --- Left edge ---
        if let firstIn = sorted.first(where: { $0.time >= domain.lowerBound }),
           let idx = sorted.firstIndex(where: { $0.id == firstIn.id }), idx > 0 {
            let before = sorted[idx - 1]
            if let x0 = before.value, let x1 = firstIn.value {
                let t0 = before.time.timeIntervalSinceReferenceDate
                let t1 = firstIn.time.timeIntervalSinceReferenceDate
                let tEdge = domain.lowerBound.timeIntervalSinceReferenceDate
                let frac = (tEdge - t0) / (t1 - t0)
                let vEdge = x0 + (x1 - x0) * frac
                result.append(WindSeriesPoint(time: domain.lowerBound, value: vEdge, series: before.series))
            }
        }

        // All in-domain points
        result.append(contentsOf: sorted.filter { $0.time >= domain.lowerBound && $0.time <= domain.upperBound })

        // --- Right edge ---
        if let lastIn = sorted.last(where: { $0.time <= domain.upperBound }),
           let idx = sorted.firstIndex(where: { $0.id == lastIn.id }), idx < sorted.count - 1 {
            let after = sorted[idx + 1]
            if let x0 = lastIn.value, let x1 = after.value {
                let t0 = lastIn.time.timeIntervalSinceReferenceDate
                let t1 = after.time.timeIntervalSinceReferenceDate
                let tEdge = domain.upperBound.timeIntervalSinceReferenceDate
                let frac = (tEdge - t0) / (t1 - t0)
                let vEdge = x0 + (x1 - x0) * frac
                result.append(WindSeriesPoint(time: domain.upperBound, value: vEdge, series: lastIn.series))
            }
        }

        return result
    }
}

extension View {
    @ViewBuilder
    func ifLet<T, Content: View>(
        _ value: T?,
        transform: (Self, T) -> Content
    ) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

extension ChartProxy {
    static func valueToX(_ time: Date, in domain: ClosedRange<Date>, width: CGFloat) -> CGFloat? {
        guard domain.upperBound > domain.lowerBound else { return nil }
        let total = domain.upperBound.timeIntervalSince(domain.lowerBound)
        let offset = time.timeIntervalSince(domain.lowerBound)
        let fraction = offset / total
        return CGFloat(fraction) * width
    }
}
