//
//  LocationManager.swift
//  Axiomora
//
//  Created by Veer on 24/04/26.
//

import CoreLocation
import MapKit

class LocationManager: NSObject {

    static let shared = LocationManager()

    private let manager = CLLocationManager()

    // The last location the OS delivered. Nil until the first fix arrives.
    private(set) var lastLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // Call this once (e.g. in AppDelegate or the first time the camera opens)
    // so permission is already granted by the time a photo is taken.
    func requestPermissionIfNeeded() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        // Start updates so lastLocation stays fresh while the app is in use.
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // Reverse-geocodes `lastLocation` into a city/state/country string and
    // returns it via `completion` on the main queue. Returns nil if no
    // location is available or geocoding fails.
    func reverseGeocodeCurrentLocation(completion: @escaping (String?) -> Void) {
        guard let location = lastLocation else {
            completion(nil)
            return
        }

        // MKReverseGeocodingRequest's initializer returns nil for invalid coordinates,
        // so guard against that before making the network call.
        guard let request = MKReverseGeocodingRequest(location: location) else {
            completion(nil)
            return
        }

        // Using the completion-handler variant rather than `await request.mapItems`
        // because MKMapItem does not conform to Sendable, which causes a compiler
        // warning when crossing concurrency boundaries with the async property.
        request.getMapItems { mapItems, error in
            guard error == nil, let mapItem = mapItems?.first else {
                completion(nil)
                return
            }

            // cityWithContext gives "Mumbai" domestically and "Mumbai, India" when
            // the user's locale makes the country relevant — ideal for a signature.
            // Falls back to the full postal address string if city info is absent.
            let locationString = mapItem.addressRepresentations?.cityWithContext
                ?? mapItem.address?.fullAddress

            completion(locationString)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Keep only the freshest fix
        lastLocation = locations.last
    }
}
