import SwiftUI
import Foundation

// MARK: - Open-Meteo responses (OldOS `OpenMeteoGeocodingResponse` / `OpenMeteoResponse`)

struct OpenMeteoGeocodingResponse: Codable {
    struct Result: Codable, Identifiable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let admin1: String?
        let timezone: String?

        var displayName: String {
            if let country, !country.isEmpty { return "\(name), \(country)" }
            return name
        }

        /// The search list also shows the state / region, so two cities
        /// with the same name can be told apart.
        var searchName: String {
            var parts = [name]
            if let admin1, !admin1.isEmpty, admin1 != name { parts.append(admin1) }
            if let country, !country.isEmpty { parts.append(country) }
            return parts.joined(separator: ", ")
        }
    }

    let results: [Result]?
}

struct OpenMeteoResponse: Codable {
    struct Current: Codable {
        let time: String?
        let temperature_2m: Double?
        let weather_code: Int?
        let is_day: Int?
    }

    struct Daily: Codable {
        let time: [String]?
        let temperature_2m_max: [Double]?
        let temperature_2m_min: [Double]?
        let weather_code: [Int]?
    }

    let timezone: String?
    let current: Current?
    let daily: Daily?
}

// MARK: - Units

enum WeatherMode: String {
    case imperial
    case metric
}

// MARK: - Iconography (OldOS `json_iconography_to_image` / `_offset`)

enum WeatherIcons {
    /// WMO weather code → OldOS icon code ("01d", "10n", ...).
    static func code(for weatherCode: Int?, isDay: Bool) -> String {
        guard let weatherCode else { return "" }
        let suffix = isDay ? "d" : "n"
        switch weatherCode {
        case 0:
            return "01" + suffix
        case 1, 2:
            return "02" + suffix
        case 3:
            return "03" + suffix
        case 45, 48:
            return "50" + suffix
        case 51, 53, 55, 56, 57,
             61, 63, 65, 66, 67,
             80, 81, 82:
            return "10" + suffix
        case 71, 73, 75, 77, 85, 86:
            return "13" + suffix
        case 95, 96, 99:
            return "11" + suffix
        default:
            return "50" + suffix
        }
    }

    /// The big icon over the card, or the small one of a forecast row.
    static func image(_ code: String, mini: Bool) -> String {
        if code.contains("n") {
            return "WeatherMoon"
        }
        guard code.contains("d") else { return "" }
        let base: String
        switch code {
        case "01d": base = "Sun"
        case "02d", "04d": base = "PartlyCloudy"
        case "03d": base = "Cloudy"
        case "09d": base = mini ? "Rain" : "RainClouds"
        case "10d": base = "Rain"
        case "11d": base = "Lightning"
        case "13d": base = "Snow"
        default: base = "Fog"
        }
        return (mini ? "Mini" : "Weather") + base
    }

    /// How far down the big icon sits so it overlaps the card like iOS 6.
    static func offset(_ code: String) -> CGFloat {
        if code.contains("n") {
            return 40
        }
        guard code.contains("d") else { return 0 }
        switch code {
        case "01d", "02d", "04d": return 0
        case "03d": return 20
        case "09d": return 15
        case "10d": return 22.5
        case "11d": return 25
        case "13d": return 10
        default: return 15
        }
    }
}

// MARK: - A city (OldOS `WeatherObserver`)

final class WeatherCity: ObservableObject, Identifiable, Equatable {
    static func == (lhs: WeatherCity, rhs: WeatherCity) -> Bool {
        lhs.id == rhs.id
    }

    struct DailyForecastEntry {
        let date: Date
        let maxTemp: Double
        let minTemp: Double
        let weatherCode: Int
    }

    let id = UUID()

    @Published var lastUpdatedText = ""
    @Published var locationString = ""
    @Published var fullLocation = ""

    @Published var currentTemp: Double?
    @Published var currentHigh: Double?
    @Published var currentLow: Double?
    @Published var currentWeatherCode: Int?
    @Published var isDay = true
    @Published var dailyForecast: [DailyForecastEntry] = []
    @Published private(set) var mode: WeatherMode

    let originalQuery: String
    private var latitude: Double?
    private var longitude: Double?
    private(set) var lastUpdate: Date?

    var coordinates: (Double, Double)? {
        guard let latitude, let longitude else { return nil }
        return (latitude, longitude)
    }
    private var loading = false

    /// - Parameters:
    ///   - location: "City, Country" as saved in the list.
    ///   - coordinates: known when the city comes from the search list, so
    ///     the right "Springfield" is shown instead of the first match.
    init(location: String, mode: WeatherMode, coordinates: (Double, Double)? = nil) {
        originalQuery = location
        self.mode = mode
        fullLocation = location
        locationString = location
        if let index = location.range(of: ",")?.lowerBound {
            locationString = String(location[..<index])
        }
        if let coordinates {
            latitude = coordinates.0
            longitude = coordinates.1
        }
        refresh()
    }

    static let longFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy h:mm a"
        return formatter
    }()

    var currentIconCode: String {
        WeatherIcons.code(for: currentWeatherCode, isDay: isDay)
    }

    var isNight: Bool {
        currentIconCode.contains("n")
    }

    func refresh() {
        guard !loading else { return }
        if latitude != nil, longitude != nil {
            fetchForecast()
        } else {
            geocodeAndLoad()
        }
    }

    /// Re-download when the data is older than 15 minutes (on launch and
    /// when the app comes back to the foreground).
    func refreshIfStale() {
        guard let lastUpdate else {
            refresh()
            return
        }
        if Date().timeIntervalSince(lastUpdate) > 15 * 60 {
            refresh()
        }
    }

    func updateMode(_ newMode: WeatherMode) {
        guard newMode != mode else { return }
        mode = newMode
        loading = false
        refresh()
    }

    private func geocodeAndLoad() {
        guard !originalQuery.isEmpty,
              let encoded = originalQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json")
        else {
            lastUpdatedText = "Invalid location"
            return
        }

        loading = true
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard error == nil, let data else {
                DispatchQueue.main.async {
                    self.loading = false
                    self.lastUpdatedText = "Geocoding failed"
                }
                return
            }
            do {
                let decoded = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: data)
                // "City, Country": retry with the city name alone when the
                // full string matches nothing.
                guard let result = decoded.results?.first(where: { self.matchesCountry($0) }) ?? decoded.results?.first else {
                    DispatchQueue.main.async {
                        self.loading = false
                        if self.originalQuery != self.locationString {
                            self.geocodeCityOnly()
                        } else {
                            self.lastUpdatedText = "Location not found"
                        }
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.apply(result)
                }
            } catch {
                DispatchQueue.main.async {
                    self.loading = false
                    self.lastUpdatedText = "Geocoding failed"
                }
            }
        }.resume()
    }

    private func geocodeCityOnly() {
        guard let encoded = locationString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=10&language=en&format=json")
        else { return }
        loading = true
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self else { return }
            let decoded = data.flatMap { try? JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: $0) }
            DispatchQueue.main.async {
                guard let result = decoded?.results?.first(where: { self.matchesCountry($0) }) ?? decoded?.results?.first else {
                    self.loading = false
                    self.lastUpdatedText = "Location not found"
                    return
                }
                self.apply(result)
            }
        }.resume()
    }

    private func matchesCountry(_ result: OpenMeteoGeocodingResponse.Result) -> Bool {
        guard let comma = originalQuery.range(of: ",") else { return false }
        let country = originalQuery[comma.upperBound...].trimmingCharacters(in: .whitespaces)
        return !country.isEmpty && result.country == country
    }

    private func apply(_ result: OpenMeteoGeocodingResponse.Result) {
        latitude = result.latitude
        longitude = result.longitude
        locationString = result.name
        loading = false
        fetchForecast()
    }

    private func fetchForecast() {
        guard let latitude, let longitude,
              var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        else { return }

        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "6"),
            URLQueryItem(name: "temperature_unit", value: mode == .imperial ? "fahrenheit" : "celsius")
        ]
        guard let url = components.url else { return }

        loading = true
        let requestedMode = mode
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard error == nil, let data,
                  let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            else {
                DispatchQueue.main.async {
                    self.loading = false
                    self.lastUpdatedText = "Update failed"
                }
                return
            }
            DispatchQueue.main.async {
                self.loading = false
                // The unit was switched while this was loading.
                guard requestedMode == self.mode else { return }
                self.apply(decoded)
            }
        }.resume()
    }

    private func apply(_ decoded: OpenMeteoResponse) {
        if let current = decoded.current {
            currentTemp = current.temperature_2m
            currentWeatherCode = current.weather_code
            isDay = (current.is_day ?? 1) == 1
        }

        if let daily = decoded.daily,
           let times = daily.time,
           let maxs = daily.temperature_2m_max,
           let mins = daily.temperature_2m_min,
           let codes = daily.weather_code {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            let count = min(times.count, maxs.count, mins.count, codes.count, 6)
            dailyForecast = (0..<count).map { i in
                DailyForecastEntry(
                    date: formatter.date(from: times[i]) ?? Date(),
                    maxTemp: maxs[i],
                    minTemp: mins[i],
                    weatherCode: codes[i]
                )
            }
            if let first = dailyForecast.first {
                currentHigh = first.maxTemp
                currentLow = first.minTemp
            }
        }

        let now = Date()
        lastUpdate = now
        lastUpdatedText = "Updated \(Self.longFormat.string(from: now))"
    }
}
