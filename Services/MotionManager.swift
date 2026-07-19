import CoreMotion

final class MotionManager {
    private let motion = CMMotionManager()
    private(set) var attitude: CMAttitude?
    private(set) var roll = 0.0, pitch = 0.0, yaw = 0.0

    func start() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let d = data else { return }
            self?.attitude = d.attitude
            self?.roll = d.attitude.roll
            self?.pitch = d.attitude.pitch
            self?.yaw = d.attitude.yaw
        }
    }

    func stop() { motion.stopDeviceMotionUpdates() }
}
