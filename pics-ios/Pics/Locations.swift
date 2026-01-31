import CoreLocation

class Locations {
  let log = LoggerFactory.shared.system(Locations.self)

  var manager: CLLocationManager?
  private var delegate: LocationsDelegate?
  private var updates: AsyncThrowingStream<[CLLocation], Error>?
  var locations: AsyncThrowingStream<[CLLocation], Error> {
    updates
      ?? AsyncThrowingStream(unfolding: {
        []
      })
  }

  func start() {
    self.manager = CLLocationManager()
    self.updates = AsyncThrowingStream(bufferingPolicy: .bufferingNewest(1)) { cont in
      self.delegate = LocationsDelegate(cont: cont)
      manager?.delegate = self.delegate
      cont.onTermination = { @Sendable _ in
        self.manager?.stopUpdatingLocation()
      }
    }
  }

  func stop() {
    manager?.stopUpdatingLocation()
  }
}

class LocationsDelegate: NSObject, CLLocationManagerDelegate {
  let log = LoggerFactory.shared.system(LocationsDelegate.self)
  private let cont: AsyncThrowingStream<[CLLocation], Error>.Continuation

  init(cont: AsyncThrowingStream<[CLLocation], Error>.Continuation) {
    self.cont = cont
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    // "the most recent location update is at the end of the array"
    cont.yield(locations)
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
    log.error("Locations error \(error)")
    cont.yield(with: .failure(error))
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    switch manager.authorizationStatus {
    case .authorizedWhenInUse, .authorizedAlways:
      log.info("Location services available.")
      manager.startUpdatingLocation()
      break
    case .restricted, .denied:
      log.info("Location services unavailable.")
      manager.stopUpdatingLocation()
      break
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
      break
    default:
      break
    }
  }
}
