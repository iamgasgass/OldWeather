import SwiftUI

/// The two card palettes of OldOS (`weather_content_view_day` and
/// `weather_content_view_night_2`).
struct WeatherCardPalette {
    let header: LinearGradient
    let separator: Color
    let evenRow: LinearGradient
    let oddRow: LinearGradient
    let lastRow: LinearGradient
    let footer: LinearGradient
    let stroke: Color
    let lowTemperature: Color

    static let day = WeatherCardPalette(
        header: LinearGradient(oldOS: [.oldOS(51, 66, 94), .oldOS(52, 67, 95), .oldOS(54, 70, 98)]),
        separator: .oldOS(44, 56, 79),
        evenRow: LinearGradient(oldOS: [.oldOS(66, 85, 120), .oldOS(66, 86, 119)]),
        oddRow: LinearGradient(oldOS: [.oldOS(56, 72, 98), .oldOS(57, 72, 101)]),
        lastRow: LinearGradient(oldOS: [.oldOS(61, 77, 104), .oldOS(62, 78, 105)]),
        footer: LinearGradient(oldOS: [.oldOS(62, 78, 105), .oldOS(62, 77, 106)]),
        stroke: .oldOS(101, 113, 134),
        lowTemperature: .oldOS(124, 149, 189)
    )

    static let night = WeatherCardPalette(
        header: LinearGradient(oldOS: [.oldOS(52, 34, 50), .oldOS(52, 34, 50)]),
        separator: .oldOS(49, 32, 47),
        evenRow: LinearGradient(oldOS: [.oldOS(64, 41, 60), .oldOS(64, 41, 60)]),
        oddRow: LinearGradient(oldOS: [.oldOS(52, 34, 50), .oldOS(52, 34, 50)]),
        lastRow: LinearGradient(oldOS: [.oldOS(52, 34, 50), .oldOS(52, 34, 50)]),
        footer: LinearGradient(oldOS: [.oldOS(52, 34, 50), .oldOS(52, 34, 50)]),
        stroke: .oldOS(93, 78, 91),
        lowTemperature: .oldOS(83, 76, 84)
    )
}

/// One page: the card 80 pt below the top, with the big weather icon
/// overlapping its top edge (OldOS `WeatherPageView`).
struct WeatherPageView: View {
    @ObservedObject var city: WeatherCity
    let onInfo: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer().frame(height: 80)
                WeatherCardView(city: city, onInfo: onInfo)
            }
            // The big sun / moon / cloud, overlapping the top of the card. It
            // fades in when the data arrives and cross-fades when day turns to
            // night, instead of popping.
            WeatherBigIcon(code: city.currentIconCode)
        }
    }
}

/// The big weather icon of a page (OldOS drew it in `WeatherPageView`).
private struct WeatherBigIcon: View {
    let code: String

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            if !code.isEmpty {
                Image(WeatherIcons.image(code, mini: false))
                    .interpolation(.high)
                    .antialiased(true)
                    .padding(.top, 15 + WeatherIcons.offset(code))
                    .id(code)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.easeInOut(duration: 0.35), value: code)
        .allowsHitTesting(false)
    }
}

/// OldOS `weather_content_view_day` / `weather_content_view_night_2`.
struct WeatherCardView: View {
    @ObservedObject var city: WeatherCity
    let onInfo: () -> Void

    var body: some View {
        let palette = city.isNight ? WeatherCardPalette.night : WeatherCardPalette.day
        GeometryReader { geometry in
            let height = geometry.size.height
            ZStack {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(palette.header)
                        .frame(height: height * 200 / 750)
                    ForEach(0..<6, id: \.self) { i in
                        row(i, palette: palette, width: geometry.size.width)
                    }
                    Rectangle()
                        .fill(palette.footer)
                        .frame(height: height * 34 / 750)
                }
                .cornerRadius(12)
                // Rasterised once: the cards slide without re-rendering
                // every gradient row.
                .drawingGroup()
                .oldOSStrokeRoundedRectangle(12, palette.stroke, lineWidth: 4)
                .padding([.leading, .trailing], 18)
                .padding([.top, .bottom], 4)
                .overlay(
                    // The glass gloss over the top of the card.
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(LinearGradient(oldOS: [OldOSStop(.white, 0.2), OldOSStop(.oldOS(80, 84, 89), 1)]))
                            .frame(height: height * 230 / (750 * 4))
                            .opacity(0.20)
                        Spacer()
                    }
                    .cornerRadius(12 * 18 / 16)
                    .padding([.leading, .trailing], 16)
                    .padding(.top, 2)
                    .allowsHitTesting(false)
                )

                VStack(spacing: 0) {
                    WeatherHeader(city: city)
                        .frame(height: height * 200 / 750)
                    Spacer()
                    footer
                        .padding(.bottom, 8)
                }
                .cornerRadius(12)
                .padding([.leading, .trailing], 18)
                .padding([.top, .bottom], 4)
            }
        }
    }

    // MARK: Forecast rows

    private func row(_ i: Int, palette: WeatherCardPalette, width: CGFloat) -> some View {
        let symbols = Self.weekdayFormatter.weekdaySymbols ?? []
        let weekday = symbols.isEmpty ? "" : symbols[wrapping: Calendar.current.component(.weekday, from: Date()) - 1 + i]
        let entry = city.dailyForecast[optional: i]
        return VStack(spacing: 0) {
            if i == 0 {
                Rectangle().fill(palette.separator).frame(height: 2)
            }
            Rectangle().fill(i == 5 ? palette.lastRow : (i % 2 == 0 ? palette.evenRow : palette.oddRow))
            if i != 5 {
                Rectangle().fill(palette.separator).frame(height: 2)
            }
        }
        .overlay(
            HStack {
                HStack(spacing: 0) {
                    Text(weekday)
                        .font(OldOSFont.bold(18))
                        .textCase(.uppercase)
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                        .lineLimit(1)
                    Spacer()
                }
                .frame(width: width / 2.5)
                .padding(.leading, 8)
                if let entry {
                    Image(WeatherIcons.image(WeatherIcons.code(for: entry.weatherCode, isDay: true), mini: true))
                }
                Spacer()
                if let entry {
                    Text("\(Int(entry.maxTemp.rounded()))°")
                        .font(OldOSFont.bold(20))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                    Text("\(Int(entry.minTemp.rounded()))°")
                        .font(OldOSFont.bold(20))
                        .foregroundColor(palette.lowTemperature)
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                        .padding(.trailing, 8)
                }
            }
            .padding(.leading, 0)
        )
    }

    static let weekdayFormatter = DateFormatter()

    // MARK: Footer

    private var footer: some View {
        HStack {
            // OldOS showed Yahoo!'s button; the data now comes from
            // Open-Meteo, whose page it opens (attribution).
            Link(destination: URL(string: "https://open-meteo.com/")!) {
                Image("YahooButton")
            }
            .padding(.leading, 8)
            Spacer()
            Text(city.lastUpdatedText)
                .font(OldOSFont.bold(13))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            Button {
                WeatherHaptics.tap()
                onInfo()
            } label: {
                Image("InfoButton")
                    .padding(.trailing, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// OldOS `weather_header`: city, H / L, and the big temperature.
struct WeatherHeader: View {
    @ObservedObject var city: WeatherCity

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                VStack(alignment: .leading) {
                    Text(city.locationString)
                        .font(OldOSFont.bold(20))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("H: \(Self.value(city.currentHigh))° L: \(Self.value(city.currentLow))°")
                        .font(OldOSFont.bold(18))
                        .foregroundColor(Color.white.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                        .lineLimit(1)
                }
                .padding(.leading, 8)
                .padding(.top, 40)
                Spacer()
                Group {
                    Text(Self.value(city.currentTemp))
                        .font(OldOSFont.regular(80))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                        .lineLimit(1)
                        .fixedSize()
                    Text("°")
                        .font(OldOSFont.regular(40))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.9), radius: 0, x: 0, y: 1.5)
                        .offset(x: -10, y: -14)
                }
                .padding(.leading, 4)
            }
        }
    }

    /// OldOS printed `Int(value ?? 0)`; "--" is shown until the data loads.
    static func value(_ temperature: Double?) -> String {
        guard let temperature else { return "--" }
        return "\(Int(temperature.rounded()))"
    }
}
