import Foundation

enum WebReceiverMode: String, Sendable {
    /// iPhone -> Android: the browser downloads the selected data.
    case download
    /// Android -> iPhone: the browser uploads files.
    case upload
}

/// Address of a running web receiver session.
struct WebReceiverEndpoint: Sendable, Equatable {
    var host: String?
    var hostKind: NetworkInterfaces.Kind?
    var port: UInt16
    var token: String
    var code: String

    /// Link encoded in the QR code: http://<ip>:<port>/s/<token>
    var sessionURL: String? {
        host.map { "http://\($0):\(port)/s/\(token)" }
    }

    /// Short address for manual entry; the page asks for the code.
    var rootURL: String? {
        host.map { "http://\($0):\(port)" }
    }
}

enum WebReceiverStopReason: Sendable, Equatable {
    case finished
    case idle
    case background
    case cancelled
    case failed(String)
}

enum WebReceiverEvent: Sendable {
    /// A photo was refused before download headers or upload file bytes were written.
    case photoTransferRequiresPremium
    /// A new device opened the link; nothing is served until `approve(client:)`.
    case approvalRequested(client: String)
    case clientApproved(client: String)
    case uploadPlanned(count: Int, bytes: Int64)
    case fileReceived(ReceivedItem)
    /// The browser pressed "Send" and all files of this batch arrived.
    case uploadFinished([ReceivedItem])
    case stopped(WebReceiverStopReason)
}

enum WebReceiverError: Error, Equatable {
    case listenerFailed(String)
    case localNetworkDenied
    case missingContent
}

/// Progress by bytes actually sent (download) or received (upload).
struct WebTransferProgress: Sendable, Equatable {
    var bytesDone: Int64 = 0
    var bytesTotal: Int64 = 0
    var categoryBytesDone: [DataCategory: Int64] = [:]
    var categoryBytesTotal: [DataCategory: Int64] = [:]
    var categoryItemsDone: [DataCategory: Int] = [:]
    var categoryItemsTotal: [DataCategory: Int] = [:]
    var activeTransfers = 0
    var approvedClients = 0
    var receivedFiles = 0
    var failures: [ImportFailure] = []
    var lastActivity = Date()

    var fraction: Double {
        guard bytesTotal > 0 else { return 0 }
        return min(1, Double(bytesDone) / Double(bytesTotal))
    }
}
