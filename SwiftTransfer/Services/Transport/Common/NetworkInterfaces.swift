import Darwin
import Foundation

/// Local IPv4 address detection for the web receiver link.
enum NetworkInterfaces {
    enum Kind: Sendable, Equatable {
        /// Wi-Fi (en0).
        case wifi
        /// This iPhone shares a Personal Hotspot (bridge100).
        case hotspot
        /// Any other local interface (e.g. other en*, simulator host interfaces).
        case other
    }

    struct Address: Sendable, Equatable {
        var interface: String
        var ip: String
        var kind: Kind
    }

    /// All non-loopback IPv4 addresses of local (non-cellular) interfaces.
    static func localIPv4Addresses() -> [Address] {
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }
        var result: [Address] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let current = cursor {
            defer { cursor = current.pointee.ifa_next }
            let flags = Int32(current.pointee.ifa_flags)
            guard let address = current.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0
            else { continue }
            let name = String(cString: current.pointee.ifa_name)
            // Cellular (pdp_ip*), VPN tunnels (utun*, ipsec*) and AWDL are never advertised.
            if name.hasPrefix("pdp_ip") || name.hasPrefix("utun") || name.hasPrefix("ipsec")
                || name.hasPrefix("awdl") || name.hasPrefix("llw") {
                continue
            }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let length = socklen_t(address.pointee.sa_len)
            guard getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else {
                continue
            }
            let ip = String(cString: host)
            guard !ip.hasPrefix("169.254.") else { continue }
            let kind: Kind
            if name == "en0" {
                kind = .wifi
            } else if name.hasPrefix("bridge") {
                kind = .hotspot
            } else {
                kind = .other
            }
            result.append(Address(interface: name, ip: ip, kind: kind))
        }
        return result
    }

    /// Preferred address for the QR link: Wi-Fi, then hotspot bridge, then other local interfaces.
    static func preferredIPv4() -> Address? {
        let addresses = localIPv4Addresses()
        return addresses.first { $0.kind == .wifi }
            ?? addresses.first { $0.kind == .hotspot }
            ?? addresses.first { $0.interface.hasPrefix("en") }
            ?? addresses.first
    }

    /// True for loopback, private (RFC 1918), link-local and IPv6 local addresses.
    static func isLocalAddress(_ ip: String) -> Bool {
        let host = ip.split(separator: "%").first.map(String.init) ?? ip
        if host == "::1" || host.hasPrefix("127.") {
            return true
        }
        let lower = host.lowercased()
        if lower.hasPrefix("::ffff:") {
            return isLocalAddress(String(lower.dropFirst("::ffff:".count)))
        }
        if lower.hasPrefix("fe80:") || lower.hasPrefix("fc") || lower.hasPrefix("fd") {
            return true
        }
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }
        switch (octets[0], octets[1]) {
        case (10, _):
            return true
        case (172, 16...31):
            return true
        case (192, 168):
            return true
        case (169, 254):
            return true
        default:
            return false
        }
    }
}
