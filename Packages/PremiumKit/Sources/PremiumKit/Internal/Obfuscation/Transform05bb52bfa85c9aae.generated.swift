// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transform05bb52bfa85c9aae {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment59fed645cd30bc6a(salt: state ^ 13522138186570548972).transform(state &+ 1)
        state = Fragmentad0d8628b0609415(salt: state ^ 17920622392263141425).transform(state &+ 2)
        state = Fragmentf0e154a6384c5efb(salt: state ^ 2002746579476931184).transform(state &+ 3)
        state = Fragmentdde90c03250a5b23(salt: state ^ 15161083130363192619).transform(state &+ 4)
        state = Fragmente6e05f25342fa9b8(salt: state ^ 16426148057836879642).transform(state &+ 5)
        state = Fragmente14117c075d03ed4(salt: state ^ 17048762722652529137).transform(state &+ 6)
        return state
    }
}

private struct Fragment59fed645cd30bc6a {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [18071988933210903725, 11938952729582772119, 6128642954174124058, 16436791141187027395, 18169473237046146412, 9147680696624674369, 521029271746544655, 15329368536829065129]
        self.salt = salt ^ 16291508002498178111
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 16291508002498178111) > 1545368832199951944 {
            routed = input &* 8592255532626600017 &+ 17685640945335915748
        } else {
            routed = (input &+ 15792676890785141434) ^ (input / 1047575488081)
        }
        let slot = Int((routed >> 11) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 2290949774565595497)
    }
}

private struct Fragmentad0d8628b0609415 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [17266917702586405385, 2612933271758473877, 3370995416955110430, 16288480608707695889, 245513367938164528, 11003335089795411806, 7391887121385752191, 808444501072035205]
        self.salt = salt ^ 11702683800957070269
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 11702683800957070269) > 5063541900980216735 {
            routed = input &* 9554661626936051867 &+ 9130938728137295300
        } else {
            routed = (input &+ 9907763555675519492) ^ (input / 52426594815)
        }
        let slot = Int((routed >> 3) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 15959128052929473155)
    }
}

private struct Fragmentf0e154a6384c5efb {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [267474185496846356, 17698292256388974841, 4231267239200143973, 9236185028276455282, 7013015450280747728, 17460890175269539755, 12084107011059013536, 10783901607278051077]
        self.salt = salt ^ 9918621533708668081
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 9918621533708668081) > 9903732114115760071 {
            routed = input &* 7954728177971496219 &+ 726921142377590035
        } else {
            routed = (input &+ 10591554120725912099) ^ (input / 327633464747)
        }
        let slot = Int((routed >> 33) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 17042091030077177513)
    }
}

private struct Fragmentdde90c03250a5b23 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [12661353949196915900, 14059588508635936230, 1829384228040368648, 4882158266100914890, 8929406288598590519, 6396724106478863627, 1087381009068614464, 18440030407837226349]
        self.salt = salt ^ 10841295838066668895
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 10841295838066668895) > 14356261741944426818 {
            routed = input &* 2880183174463298029 &+ 18162120450686334486
        } else {
            routed = (input &+ 14347857273750831943) ^ (input / 1008589584111)
        }
        let slot = Int((routed >> 31) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 2305069532037701537)
    }
}

private struct Fragmente6e05f25342fa9b8 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [4831929424463956562, 1775114136869398545, 6219084294924623299, 17860804276344925913, 6128368180088412297, 14545169440127142797, 15736277198440449538, 1099323657162465128]
        self.salt = salt ^ 7894009546045003419
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 7894009546045003419) > 14003210541138906242 {
            routed = input &* 17507146137734680623 &+ 9761619981545677388
        } else {
            routed = (input &+ 16293637014000455923) ^ (input / 260011730311)
        }
        let slot = Int((routed >> 5) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 676420619135807693)
    }
}

private struct Fragmente14117c075d03ed4 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [13806680355725790807, 5368048561077887789, 14887438039283832317, 5649090949998770075, 3008351635297954932, 9761688901990520476, 14190693430251226089, 4135990653292057213]
        self.salt = salt ^ 108868032857673069
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 108868032857673069) > 18398895820890052741 {
            routed = input &* 15256925536789429641 &+ 17723098910669783955
        } else {
            routed = (input &+ 5974414909782320426) ^ (input / 566953445115)
        }
        let slot = Int((routed >> 12) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 16406629156705996379)
    }
}

