import Foundation
import Network
import os

/// TCP 推流 — 接受一个 PC 连接，发送帧 + 陀螺仪数据
final class StreamServer {
    private var listener: NWListener?
    private var connection: NWConnection?
    private var connected = false
    private let queue = DispatchQueue(label: "stream")
    private let logger = Logger(subsystem: "bridge", category: "stream")

    func start(port: UInt16 = 8888) {
        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
            listener?.newConnectionHandler = { [weak self] conn in
                self?.accept(conn)
            }
            listener?.start(queue: queue)
            logger.info("Listening on port \(port)")
        } catch {
            logger.error("Listen failed: \(error.localizedDescription)")
        }
    }

    private func accept(_ conn: NWConnection) {
        connection?.cancel()
        connection = conn
        conn.start(queue: queue)
        connected = true
        logger.info("Client connected")
    }

    /// 发送单帧 + 陀螺仪
    func send(jpeg: Data, gyro: String) {
        guard connected, let conn = connection else { return }
        // 协议: GYRO_JSON\n<length>\nJPEG_DATA
        let header = "\(gyro)\n\(jpeg.count)\n"
        guard let headerData = header.data(using: .utf8) else { return }
        let packet = headerData + jpeg
        conn.send(content: packet, completion: .idempotent)
    }

    func stop() {
        connection?.cancel()
        listener?.cancel()
        connected = false
    }
}
