import AVFoundation
import CoreImage
import Darwin
import ImageIO
import SwiftUI

@MainActor
final class BridgeViewModel: ObservableObject {
    @Published var streaming = false
    @Published var ipAddress = ""

    private let camera = CameraManager()
    private let motion = MotionManager()
    private let server = StreamServer()
    private var frameCount = 0

    func setup() {
        ipAddress = getWiFiIP() ?? "无网络"
        server.start()
        camera.onFrame = { [weak self] buf in
            Task { @MainActor [weak self] in self?.process(buf) }
        }
    }

    func start() {
        camera.start()
        motion.start()
        streaming = true
    }

    func stop() {
        camera.stop()
        motion.stop()
        streaming = false
    }

    private func process(_ buf: CMSampleBuffer) {
        guard streaming else { return }
        frameCount += 1

        // 只每 3 帧发一次 (30fps → 10fps 发流，省带宽)
        guard frameCount % 3 == 0 else { return }

        guard let pixelBuf = CMSampleBufferGetImageBuffer(buf),
              let jpeg = pixelToJPEG(pixelBuf) else { return }

        let gyro = String(format: "%.4f,%.4f,%.4f,%lld",
                          motion.roll, motion.pitch, motion.yaw,
                          Int64(Date().timeIntervalSince1970 * 1000))
        server.send(jpeg: jpeg, gyro: gyro)
    }

    private func pixelToJPEG(_ buf: CVPixelBuffer) -> Data? {
        let ci = CIImage(cvPixelBuffer: buf)
        let ctx = CIContext()
        guard let cg = ctx.createCGImage(ci, from: ci.extent) else { return nil }
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, cg, [kCGImageDestinationLossyCompressionQuality: 0.6] as CFDictionary)
        CGImageDestinationFinalize(dest)
        return data as Data
    }

    private func getWiFiIP() -> String? {
        // 最简单：读 en0 接口 IP
        var addr: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }
            guard let ifa = ptr?.pointee else { continue }
            let family = ifa.ifa_addr.pointee.sa_family
            guard family == UInt8(AF_INET) else { continue }
            let name = String(cString: ifa.ifa_name)
            guard name == "en0" else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len),
                        &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            addr = String(cString: host)
        }
        freeifaddrs(ifaddr)
        return addr
    }
}
