import Network
import Observation

@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var isOffline = false
    private var monitor: NWPathMonitor?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status == .unsatisfied
            Task { @MainActor [weak self] in self?.isOffline = offline }
        }
        self.monitor = monitor
        monitor.start(queue: .global(qos: .utility))
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
    }
}
