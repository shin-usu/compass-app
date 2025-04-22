import SwiftUI
import CoreLocation
import Foundation

@MainActor
final class NavigationViewModel: ObservableObject {
    // --- 入力と出力 ---
    @Published var destinationLatitude:  String = ""
    @Published var destinationLongitude: String = ""

    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var distance:        Double?
    @Published private(set) var bearing:         Double?
    @Published private(set) var arrowRotation:   Double?   // ← UI に渡す最終回転角
    @Published private(set) var arrowRotationDisplay: Double?      // UI 表示用
    @Published private(set) var arrowRotationVisual:  Double?      // Image 回転用

    // --- 依存サービス ---
    private let locationService = LocationService.shared

    // --- 内部タスク ---
    private var locationTask: Task<Void, Never>?
    private var recalcTask:   Task<Void, Never>?
    private var headingTask:  Task<Void, Never>?

    private var currentHeading: Double?
    private var lastArrowAngle: Double?      // 累積角度（360 を超えても保持）
    private var lastVisualAngle: Double?
    
    init() {
        // ① 現在位置
        locationTask = Task {
            for await location in locationService.locationStream() {
                currentLocation = location
                recalculate()   // 距離・bearing 更新
            }
        }

        // ② 目的地入力
        recalcTask = Task {
            for await _ in destinationChangeStream() {
                recalculate()
            }
        }

        // ★ ③ コンパス方位
        headingTask = Task {
            for await heading in locationService.headingStream() {
                currentHeading = heading.trueHeading
                updateArrowRotation()
            }
        }
    }
    
    deinit {
        locationTask?.cancel()
        recalcTask?.cancel()
    }

    // MARK: - Private helpers

    /// TextField の 2 つのバインディングを AsyncStream に束ねる
    private func destinationChangeStream() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let latitudeCancellable = $destinationLatitude
                .sink { _ in continuation.yield(()) }

            let longitudeCancellable = $destinationLongitude
                .sink { _ in continuation.yield(()) }

            continuation.onTermination = { _ in
                latitudeCancellable.cancel()
                longitudeCancellable.cancel()
            }
        }
    }
    // 距離・bearing の計算後に呼ぶ
    private func recalculate() {
        guard
            let lat = Double(destinationLatitude),
            let lon = Double(destinationLongitude),
            let current = currentLocation
        else {
            distance = nil
            bearing  = nil
            return
        }

        let destination = CLLocation(latitude: lat, longitude: lon)
        distance = current.distance(from: destination)
        bearing  = GeoUtil.bearing(from: current.coordinate, to: destination.coordinate)
        updateArrowRotation()
    }

    private func updateArrowRotation() {
        guard let bearing, let heading = currentHeading else {
            arrowRotationVisual  = nil
            arrowRotationDisplay = nil
            lastVisualAngle      = nil
            return
        }

        // --- ① 真北基準の理想角 (0‒360) ---
        var ideal = bearing - heading
        if ideal < 0 { ideal += 360 }

        // --- ② 連続性を保つ ---
        if var last = lastVisualAngle {
            last.formTruncatingRemainder(dividingBy: 360)          // 0‒360 比較用
            var delta = ideal - last                               // 差分
            if delta > 180 { delta -= 360 }                        // 最短経路へ折りたたみ
            if delta < -180 { delta += 360 }
            ideal = (lastVisualAngle ?? 0) + delta                 // 累積角
        }

        // --- ③ 公開値をセット ---
        arrowRotationVisual  = ideal                               // 連続角 (アニメ用)
        let mod = ideal.truncatingRemainder(dividingBy: 360)
        arrowRotationDisplay = mod >= 0 ? mod : mod + 360          // 0‒359
        lastVisualAngle      = ideal
    }
}

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NavigationViewModel()

    var body: some View {
        VStack(spacing: 24) {

            // --- 目的地入力 ---
            HStack {
                TextField("緯度 (例: 35.6586)", text: $viewModel.destinationLatitude)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)

                TextField("経度 (例: 139.7454)", text: $viewModel.destinationLongitude)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
            }

            // --- 距離 ---
            if let d = viewModel.distance {
                Text(String(format: "直線距離: %.1f m", d))
                    .font(.title2).bold()
            }

            // --- 矢印コンパス ---
            if
                let rot = viewModel.arrowRotationVisual
            {
                Image(systemName: "location.north.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rot))                    // 連続角で回す
                    .animation(.easeInOut(duration: 0.2), value: rot)

                // 表示は 0‒359° に正規化
                if let disp = viewModel.arrowRotationDisplay {
                    Text(String(format: "方角: %.0f°", disp))
                        .monospacedDigit()
                }
            } else {
                Text("方角計算中…")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}



#Preview {
    ContentView()
}
