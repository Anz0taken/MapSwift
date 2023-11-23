import SwiftUI
import MapKit
import CoreLocation

struct MapView: UIViewRepresentable {
    @State private var locationManager = CLLocationManager()
    @State private var userCoordinate = CLLocationCoordinate2D()
    @State private var initialRegionSet = false
    
    @Binding public var locations: [PostMapInfo]
    var locationSelectedHandler: ((PostMapInfo) -> Void)?
    
    @Binding var searchText: String
    @Binding public var selectedLocation: PostMapInfo?
    @Binding public var shouldUpdateRegion: Bool
    
    var didTapOnMap: ((PostMapInfo) -> Void)?  // Callback for map tap
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator

        // Request When in Use authorization
        locationManager.requestWhenInUseAuthorization()

        // Start updating location
        locationManager.delegate = context.coordinator
        locationManager.startUpdatingLocation()

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Check if the current visible region is close to the user's location only if shouldUpdateRegion is true
        if shouldUpdateRegion {
            // Set the initial region only when the view first appears
            if !initialRegionSet {
                enableInitialLocationFeatures(uiView)
            }

            // Update the flag to prevent continuous region updates
            shouldUpdateRegion = false
        }

        // Remove existing annotations
        uiView.removeAnnotations(uiView.annotations)

        // Filter locations based on search text
        let filteredLocations: [PostMapInfo]
        if searchText.isEmpty {
            filteredLocations = locations
        } else {
            filteredLocations = locations.filter { $0.postName.lowercased().contains(searchText.lowercased()) }
        }

        // Add new annotations for each filtered location point
        for location in filteredLocations {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            annotation.title = location.postName
            uiView.addAnnotation(annotation)
        }

        if let selectedLocation = selectedLocation {
            let region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: selectedLocation.latitude, longitude: selectedLocation.longitude), latitudinalMeters: 500, longitudinalMeters: 500)
            uiView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func enableInitialLocationFeatures(_ uiView: MKMapView) {
        // Code to enable location-dependent features when the view first appears
        if let location = locationManager.location?.coordinate {
            let region = MKCoordinateRegion(center: location, latitudinalMeters: 500, longitudinalMeters: 500)
            uiView.setRegion(region, animated: true)
        }
    }

    class Coordinator: NSObject, CLLocationManagerDelegate, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        // Handle location authorization changes
        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse:
                // Location services are available. Enable location features.
                DispatchQueue.main.async { [self] in
                    self.parent.enableLocationFeatures()
                }

            case .restricted, .denied:
                // Location services currently unavailable. Disable location features.
                DispatchQueue.main.async { [self] in
                    self.parent.disableLocationFeatures()
                }

            case .notDetermined:
                // Authorization not determined yet. Request When in Use authorization.
                manager.requestWhenInUseAuthorization()

            default:
                break
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let selectedLocation = parent.locations.first(where: { $0.postName == view.annotation?.title }) {
                parent.selectedLocation = selectedLocation
                parent.locationSelectedHandler?(selectedLocation)
                parent.didTapOnMap?(selectedLocation)
            }
        }

        // Update userCoordinate when the location is updated
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            if let location = locations.last?.coordinate {
                parent.userCoordinate = location
            }
        }
    }

    func enableLocationFeatures() {
        // Code to enable location-dependent features
        print("Location features enabled!")
    }

    func disableLocationFeatures() {
        // Code to disable location-dependent features
        print("Location features disabled!")
    }
}
