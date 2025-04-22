import CoreLocation
import Foundation

/// 現在位置を更新のたびに AsyncStream で流すシングルトン
final class LocationService: NSObject, CLLocationManagerDelegate {

    static let shared = LocationService()

    private let manager = CLLocationManager()
    private var continuation: AsyncStream<CLLocation>.Continuation?
    private var headingContinuation: AsyncStream<CLHeading>.Continuation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter  = kCLDistanceFilterNone
        manager.headingFilter   = 1
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func locationStream() -> AsyncStream<CLLocation> {
        AsyncStream { continuation in
            // 過去に作ったストリームがあれば破棄
            self.continuation?.finish()
            self.continuation = continuation

            // 即時に最新値を 1 発流す（あれば）
            if let loc = manager.location {
                continuation.yield(loc)
            }

            continuation.onTermination = { _ in
                // Streaming 停止時に特別な処理があればここで
            }
        }
    }

    func headingStream() -> AsyncStream<CLHeading> {
        AsyncStream { continuation in
            // 既存のストリームがあれば破棄
            self.headingContinuation?.finish()
            self.headingContinuation = continuation

            // 直近値があれば即時流す
            if let heading = manager.heading {
                continuation.yield(heading)
            }
        }
    }

    // MARK: CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        continuation?.yield(loc)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        // 0–360°、負値なら取得失敗
        guard newHeading.trueHeading >= 0 else { return }
        headingContinuation?.yield(newHeading)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 必要に応じて error を流す／ロギングする
        print("Location error: \(error.localizedDescription)")
    }
}
