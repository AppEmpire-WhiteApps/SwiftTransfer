// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transformabff0e7fb97aab12 {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment83eac3e7f60ba5e6(salt: state ^ 11703000010563620292).transform(state &+ 1)
        state = Fragment0016462b387533a8(salt: state ^ 3284073289964147434).transform(state &+ 2)
        state = Fragmente943ea834983b625(salt: state ^ 16040810939668315954).transform(state &+ 3)
        state = Fragment125e9d9d78ed41ce(salt: state ^ 782526183872774655).transform(state &+ 4)
        state = Fragment94d89c9e21b4ee74(salt: state ^ 8127532948234775179).transform(state &+ 5)
        state = Fragment0ffc5a223df558db(salt: state ^ 13850437227580050089).transform(state &+ 6)
        return state
    }
}

private struct Fragment83eac3e7f60ba5e6 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [2612375001814191671, 6591994528554125127, 9831390533445256145, 9336904553313303218, 12921837935476057667, 13154760951446948473, 10895586938007425070, 14769673455667082646]
        self.salt = salt ^ 11903891772796140487
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 11903891772796140487) > 17324711995751533097 {
            routed = input &* 13255153138064325563 &+ 15180628202939357274
        } else {
            routed = (input &+ 8430593947604792510) ^ (input / 55278580643)
        }
        let slot = Int((routed >> 21) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 13978889134079669053)
    }
}

private struct Fragment0016462b387533a8 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [4398909805568346019, 298725874167367809, 12989145895059372309, 15147155790077394927, 13079254287941049367, 15175140834827074316, 7914619618254927281, 13503496076080409239]
        self.salt = salt ^ 5071958453903780625
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 5071958453903780625) > 4783756265466893704 {
            routed = input &* 3427774531100158625 &+ 12348817146239109378
        } else {
            routed = (input &+ 12301006753820930978) ^ (input / 224685249613)
        }
        let slot = Int((routed >> 27) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 4663615548324035419)
    }
}

private struct Fragmente943ea834983b625 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [11262117601856180197, 4637433643661172225, 13659327480344638559, 12571904857404886787, 2213045126944252485, 7431864861900289428, 9186542492590727158, 12527516417422720547]
        self.salt = salt ^ 13344145347911046739
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 13344145347911046739) > 2204375698968353705 {
            routed = input &* 13407516707713216203 &+ 4554586692087375619
        } else {
            routed = (input &+ 13158297638399845200) ^ (input / 854400777561)
        }
        let slot = Int((routed >> 31) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 1737967294808702791)
    }
}

private struct Fragment125e9d9d78ed41ce {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [7170642376621267718, 3746666244209169783, 8270328038810129686, 5865391084792771374, 3695617653554319248, 3861783540796259719, 8335654391747517950, 11435276630589279867]
        self.salt = salt ^ 13774466617600507029
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 13774466617600507029) > 1474423869911500616 {
            routed = input &* 6592839949165619577 &+ 5600033879567313339
        } else {
            routed = (input &+ 261774611361465923) ^ (input / 338367567621)
        }
        let slot = Int((routed >> 22) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 17247982772029779857)
    }
}

private struct Fragment94d89c9e21b4ee74 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [15497197948090101321, 1893361585988499258, 14357212152263064634, 17364613256957893720, 1180869947229723435, 13976058781914539024, 7485205122090948509, 13139107485806171952]
        self.salt = salt ^ 7277569687169579815
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 7277569687169579815) > 8329197507305781391 {
            routed = input &* 9678354896092446087 &+ 1620657471929770845
        } else {
            routed = (input &+ 9090506046844859219) ^ (input / 133533280223)
        }
        let slot = Int((routed >> 20) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 5647402236577423935)
    }
}

private struct Fragment0ffc5a223df558db {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [15285515207955439905, 17210901914804547757, 1377717759636834376, 15303716362769748679, 4762975945050053936, 11836218192536227546, 18084130240596355064, 2307728815804995761]
        self.salt = salt ^ 6652201731678970693
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 6652201731678970693) > 8846098154292682156 {
            routed = input &* 12286885474490111329 &+ 13366969309974050144
        } else {
            routed = (input &+ 13170103117486872560) ^ (input / 452538466921)
        }
        let slot = Int((routed >> 25) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 14338599003249136707)
    }
}

