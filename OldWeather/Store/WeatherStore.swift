import SwiftUI
import Combine

/// The cities and the unit (OldOS `ObservableArray<WeatherObserver>` plus the
/// `weather_cities` / `weather_mode` user defaults).
final class WeatherStore: ObservableObject {
    static let shared = WeatherStore()

    /// iOS 6 allowed up to nine cities.
    static let maxCities = 9
    /// The first city iOS 6 showed.
    static let defaultCity = "Cupertino, United States"

    private enum Keys {
        static let cities = "weather_cities"
        static let coordinates = "weather_coordinates"
        static let mode = "weather_mode"
    }

    @Published private(set) var cities: [WeatherCity] = []
    @Published private(set) var mode: WeatherMode
    private var cancellables: [UUID: AnyCancellable] = [:]

    private init() {
        let defaults = UserDefaults.standard
        mode = WeatherMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .imperial

        let saved = (defaults.dictionary(forKey: Keys.cities) as? [String: String]) ?? [:]
        let coordinates = (defaults.dictionary(forKey: Keys.coordinates) as? [String: [Double]]) ?? [:]
        let ordered = saved
            .compactMap { key, value -> (Int, String, String)? in
                guard let index = Int(key), !value.isEmpty else { return nil }
                return (index, key, value)
            }
            .sorted { $0.0 < $1.0 }

        var loaded: [WeatherCity] = []
        for (_, key, name) in ordered {
            var pair: (Double, Double)?
            if let values = coordinates[key], values.count == 2 {
                pair = (values[0], values[1])
            }
            loaded.append(WeatherCity(location: name, mode: mode, coordinates: pair))
        }
        if loaded.isEmpty {
            loaded = [WeatherCity(location: Self.defaultCity, mode: mode, coordinates: (37.32300, -122.03218))]
        }
        cities = Array(loaded.prefix(Self.maxCities))
        cities.forEach(observe)
        save()
    }

    var canAddCity: Bool {
        cities.count < Self.maxCities
    }

    // MARK: Editing

    func add(_ result: OpenMeteoGeocodingResponse.Result) {
        guard canAddCity else { return }
        let city = WeatherCity(location: result.displayName, mode: mode, coordinates: (result.latitude, result.longitude))
        observe(city)
        cities.append(city)
        save()
    }

    func remove(_ city: WeatherCity) {
        guard cities.count > 1 else { return }
        cities.removeAll { $0.id == city.id }
        cancellables[city.id] = nil
        save()
    }

    func move(from source: Int, to destination: Int) {
        guard cities.indices.contains(source), cities.indices.contains(destination), source != destination else { return }
        let city = cities.remove(at: source)
        cities.insert(city, at: destination)
        save()
    }

    func setMode(_ newMode: WeatherMode) {
        guard newMode != mode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Keys.mode)
        cities.forEach { $0.updateMode(newMode) }
    }

    func refreshIfStale() {
        cities.forEach { $0.refreshIfStale() }
    }

    // MARK: Persistence

    /// Same layout as OldOS: `["0": "City, Country", "1": ...]`.
    private func save() {
        var names: [String: String] = [:]
        var coordinates: [String: [Double]] = [:]
        for (index, city) in cities.enumerated() {
            names["\(index)"] = city.fullLocation
            if let pair = city.coordinates {
                coordinates["\(index)"] = [pair.0, pair.1]
            }
        }
        let defaults = UserDefaults.standard
        defaults.set(names, forKey: Keys.cities)
        defaults.set(coordinates, forKey: Keys.coordinates)
    }

    /// Re-publish when a city finishes loading, and store the coordinates it
    /// resolved so the next launch skips the geocoding.
    private func observe(_ city: WeatherCity) {
        cancellables[city.id] = city.objectWillChange
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.save()
            }
    }
}
