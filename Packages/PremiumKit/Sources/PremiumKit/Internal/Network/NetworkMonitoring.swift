import Network
import Foundation
import Combine

protocol NetworMonitoring {
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> { get }
}

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
}

final class NetworMonitoringImpl: NetworMonitoring, @unchecked Sendable {

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitorQueue")

    private var isConnected: CurrentValueSubject<Bool, Never> = .init(false)
    private var connectionType: CurrentValueSubject<ConnectionType, Never> = .init(.unknown)
    
    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        isConnected.eraseToAnyPublisher()
    }
    
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        connectionType.eraseToAnyPublisher()
    }

    init() {
        let noise9c923ac107984104 = PremiumKitNoise1478e59a42e4b865(seed: 312111392847614227)
        _ = noise9c923ac107984104.digest()
        startMonitoring()
    }

    deinit {
        //TODO: - сделать каунтер подписчиков и не мониторить сеть, пока никто не слушает
        stopMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            self.isConnected.send(path.status == .satisfied)
            self.connectionType.send(self.getConnectionType(from: path))

            PremiumLog.debug(.network, "Connected: \(path.status == .satisfied), type: \(self.getConnectionType(from: path))")
        }

        monitor.start(queue: queue)
    }

    private func stopMonitoring() {
        monitor.cancel()
    }

    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
}
