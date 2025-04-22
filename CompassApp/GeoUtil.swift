import CoreLocation
import Foundation

enum GeoUtil {

    /// **真北**基準の方位（0–360°、時計回り）
    static func bearing(from start: CLLocationCoordinate2D,
                        to   end:   CLLocationCoordinate2D) -> Double {

        let φ1 = start.latitude .toRadians
        let λ1 = start.longitude.toRadians
        let φ2 = end.latitude   .toRadians
        let λ2 = end.longitude  .toRadians

        let Δλ = λ2 - λ1
        let y   = sin(Δλ) * cos(φ2)
        let x   = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ   = atan2(y, x)             // -π–+π
        let deg = θ.toDegrees             // -180–+180
        return fmod(deg + 360, 360)       // 0–360
    }
}

// MARK: - Double helpers

private extension Double {
    var toRadians: Double { self * .pi / 180 }
    var toDegrees: Double { self * 180 / .pi }
}
