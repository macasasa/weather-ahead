import Charts
import SwiftUI

/// Hourly temperature curve, styled after the native Weather "Conditions"
/// chart: a smooth catmullRom line over a soft vertical gradient, with the
/// day's high and low points annotated.
struct TemperatureChart: View {
    enum Mode { case actual, feelsLike }

    let hours: [HourSummary]
    let mode: Mode
    let accent: Color

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    private var points: [Point] {
        hours.map { hour in
            let celsius = mode == .actual ? hour.temperatureCelsius : hour.apparentTemperatureCelsius
            return Point(date: hour.date, value: TemperatureText.localeValue(celsius: celsius))
        }
    }

    private var highPoint: Point? { points.max { $0.value < $1.value } }
    private var lowPoint: Point? { points.min { $0.value < $1.value } }

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Temperature", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(colors: [accent.opacity(0.35), accent.opacity(0.02)],
                                   startPoint: .top, endPoint: .bottom)
                )

                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Temperature", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .foregroundStyle(accent)
            }

            if let highPoint {
                PointMark(x: .value("Time", highPoint.date), y: .value("Temperature", highPoint.value))
                    .foregroundStyle(accent)
                    .annotation(position: .top, spacing: 2) {
                        Text(highPoint.value.formatted(.number.precision(.fractionLength(0))) + "°")
                            .font(.caption2.weight(.semibold))
                    }
            }
            if let lowPoint {
                PointMark(x: .value("Time", lowPoint.date), y: .value("Temperature", lowPoint.value))
                    .foregroundStyle(accent.opacity(0.7))
                    .annotation(position: .bottom, spacing: 2) {
                        Text(lowPoint.value.formatted(.number.precision(.fractionLength(0))) + "°")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.number.precision(.fractionLength(0))) + "°")
                    }
                }
            }
        }
        .frame(height: 200)
    }
}

/// Hourly chance-of-precipitation bars, styled after the native "Chance of
/// Precipitation" chart.
struct PrecipitationChart: View {
    let hours: [HourSummary]

    var body: some View {
        Chart(hours) { hour in
            BarMark(
                x: .value("Time", hour.date, unit: .hour),
                y: .value("Chance", hour.precipitationChance)
            )
            .foregroundStyle(Color.blue.gradient)
            .cornerRadius(3)
        }
        .chartYScale(domain: 0...1)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 0.5, 1.0]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.formatted(.percent.precision(.fractionLength(0))))
                    }
                }
            }
        }
        .frame(height: 130)
    }
}
