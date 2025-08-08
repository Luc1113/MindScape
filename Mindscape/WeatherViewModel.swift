//
//  WeatherViewModel.swift
//  Mindscape
//
//  Created by Luca DiGrigoli on 8/7/25.
//

import Foundation
import Combine
import CoreLocation
import SwiftUI

final class WeatherViewModel: NSObject, ObservableObject {
    // MARK: - Config
    /// Return Fahrenheit from the API. Set false to get Celsius instead.
    private let useFahrenheit: Bool = true

    // MARK: - Published state (used by DashboardView)
    @Published var temperature: Int? = nil          // e.g. 72
    @Published var symbolName: String? = nil        // e.g. "cloud.sun.fill"
    @Published var fetchFailed: Bool = false

    // MARK: - Extras for a richer mini-report
    @Published var conditionText: String = ""       // e.g. "Partly Cloudy"
    @Published var windMph: Int? = nil              // e.g. 8

    // MARK: - Private
    private let locationManager = CLLocationManager()
    private var hasRequestedAuth = false

    override init() {
        super.init()
        locationManager.delegate = self
    }

    // MARK: - Entry
    func fetchWeather() {
        // Reset UI state
        fetchFailed = false
        temperature = nil
        symbolName = nil
        conditionText = ""
        windMph = nil

        guard CLLocationManager.locationServicesEnabled() else {
            // Services off → fallback
            fetchFor(lat: 40.7128, lon: -74.0060)
            return
        }

        // Ask for permission; handle next steps in the delegate callback.
        // Analyzer is happy because we don't synchronously branch on status here.
        DispatchQueue.main.async {
            self.locationManager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Networking
    private func fetchFor(lat: Double, lon: Double) {
        guard var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else {
            DispatchQueue.main.async { self.fetchFailed = true }
            return
        }

        var items: [URLQueryItem] = [
            .init(name: "latitude", value: "\(lat)"),
            .init(name: "longitude", value: "\(lon)"),
            .init(name: "current_weather", value: "true"),
            .init(name: "timezone", value: "auto")
        ]
        // Ask the API for the unit we want so there's no local conversion mismatch
        if useFahrenheit {
            items.append(.init(name: "temperature_unit", value: "fahrenheit"))
            items.append(.init(name: "windspeed_unit", value: "mph"))
        } else {
            items.append(.init(name: "temperature_unit", value: "celsius"))
            items.append(.init(name: "windspeed_unit", value: "kmh"))
        }
        comps.queryItems = items

        guard let url = comps.url else {
            DispatchQueue.main.async { self.fetchFailed = true }
            return
        }

        URLSession.shared.dataTask(with: url) { data, resp, err in
            if let err = err {
                print("Weather error:", err)
                DispatchQueue.main.async { self.fetchFailed = true }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { self.fetchFailed = true }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

                // Temperature (already in desired unit per query)
                let temp = Int(round(decoded.current_weather.temperature))
                let code = decoded.current_weather.weathercode
                let wind = decoded.current_weather.windspeed ?? 0

                // Map weather code → SF Symbol + description
                let isNight = Self.isNight(localTimeISO: decoded.current_weather_timeISO)
                let symbol = Self.sfSymbol(for: code, isNight: isNight)
                let description = Self.description(for: code)

                DispatchQueue.main.async {
                    self.temperature = temp
                    self.symbolName = symbol
                    self.conditionText = description
                    // wind already mph if useFahrenheit == true; else km/h (we'll still show mph if you prefer)
                    self.windMph = self.useFahrenheit ? Int(round(wind)) : Int(round(wind * 0.621371))
                    self.fetchFailed = false
                }
            } catch {
                print("Decode error:", error)
                DispatchQueue.main.async { self.fetchFailed = true }
            }
        }.resume()
    }

    // MARK: - Helpers
    private static func isNight(localTimeISO: String?) -> Bool {
        guard let iso = localTimeISO,
              let date = ISO8601DateFormatter().date(from: iso) else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        return hour < 6 || hour >= 20
    }

    // WMO code → human text
    private static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1, 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunder + Hail"
        default: return "Weather"
        }
    }

    // WMO code → SF Symbol (night-aware)
    private static func sfSymbol(for code: Int, isNight: Bool) -> String {
        switch code {
        case 0:
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        case 1, 2:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 61, 63, 65:
            return "cloud.rain.fill"
        case 66, 67:
            return "cloud.hail.fill"
        case 71, 73, 75:
            return "cloud.snow.fill"
        case 77:
            return "cloud.sleet.fill"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95:
            return "cloud.bolt.fill"
        case 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension WeatherViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Now it’s safe to request a one-shot fix
            manager.requestLocation()
            timeoutFallback()
        case .restricted, .denied:
            // No permission → fallback immediately
            fetchFor(lat: 40.7128, lon: -74.0060)
        case .notDetermined:
            // Still waiting on the system prompt
            break
        @unknown default:
            fetchFor(lat: 40.7128, lon: -74.0060)
        }
    }

    func timeoutFallback() {
        // Fallback to NYC coordinates after 10 seconds if no location update
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.temperature == nil {
                self.fetchFor(lat: 40.7128, lon: -74.0060)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
        // Fall back so UI completes
        fetchFor(lat: 40.7128, lon: -74.0060)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let loc = locations.last {
            fetchFor(lat: loc.coordinate.latitude, lon: loc.coordinate.longitude)
        } else {
            fetchFor(lat: 40.7128, lon: -74.0060)
        }
    }
}

// MARK: - Models
private struct OpenMeteoResponse: Decodable {
    struct CurrentWeather: Decodable {
        let temperature: Double            // in F or C per query
        let windspeed: Double?             // in mph or km/h per query
        let weathercode: Int
    }

    let current_weather: CurrentWeather

    // Some variants include a current time; if present, we can night-check
    var current_weather_timeISO: String? = nil

    private enum CodingKeys: String, CodingKey {
        case current_weather
        case time                        // optional top-level ISO8601 string
        case current_weather_timeISO = "current_weather_time"
    }
}

extension OpenMeteoResponse {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        current_weather = try container.decode(CurrentWeather.self, forKey: .current_weather)
        // Try to read any provided ISO time field
        let t1 = try? container.decode(String.self, forKey: .current_weather_timeISO)
        let t2 = try? container.decode(String.self, forKey: .time)
        self.current_weather_timeISO = t1 ?? t2
    }
}
