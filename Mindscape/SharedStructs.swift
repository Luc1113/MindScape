//
//  SharedStructs.swift
//  Mindscape
//
//  Created by Luca DiGrigoli on 8/6/25.
//

import Foundation
import WeatherKit
import CoreLocation

let userNameKey = "userName"

/// Wraps a `Date` so it can drive `.sheet(item:)`
struct IdentifiableDate: Identifiable, Equatable {
    let id = UUID()
    let date: Date
}

/// Weather Enabler

@MainActor
class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: Int?
    @Published var symbolName: String?
    @Published var fetchFailed: Bool = false

    private let weatherService = WeatherService()
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func fetchWeather() {
        fetchFailed = false
        temperature = nil
        symbolName = nil

        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()

        // Fallback timeout after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if temperature == nil && symbolName == nil {
                fetchFailed = true
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            fetchFailed = true
            return
        }

        Task {
            do {
                let weather = try await weatherService.weather(for: location)
                self.temperature = Int(weather.currentWeather.temperature.value)
                self.symbolName = weather.currentWeather.symbolName
            } catch {
                print("Weather fetch error:", error)
                self.fetchFailed = true
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error:", error.localizedDescription)
        fetchFailed = true
    }
}
