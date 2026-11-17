// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transform54188398fd07ff4e {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragmentacb4f1072715f7bf(salt: state ^ 993858705779494301).transform(state &+ 1)
        state = Fragmentaac026aac5d9f765(salt: state ^ 5437902400310058300).transform(state &+ 2)
        state = Fragmentafe1009a4644c257(salt: state ^ 5195425570215553262).transform(state &+ 3)
        state = Fragment715d63d3ce2831b8(salt: state ^ 7062340040315580612).transform(state &+ 4)
        state = Fragmenta79911fc118e3621(salt: state ^ 11483944472623808286).transform(state &+ 5)
        state = Fragment8489df804f3a7a4e(salt: state ^ 9919036066083057065).transform(state &+ 6)
        return state
    }
}

private struct Fragmentacb4f1072715f7bf {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [356374185539295602, 17562968243957481863, 4210785238324031907, 7154980767058135973, 16416727291172342669, 2365312807541101987, 17704094860844364254, 15468186282348976142]
        self.salt = salt ^ 2578699854048266673
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 2578699854048266673) > 15937413565128769764 {
            routed = input &* 5851242711351803295 &+ 11768173593528462723
        } else {
            routed = (input &+ 17759266267140577512) ^ (input / 530666348451)
        }
        let slot = Int((routed >> 26) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 3481394960299307881)
    }
}

private struct Fragmentaac026aac5d9f765 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [5495539686663884906, 14191180805945652634, 5013824459390437092, 177210953970032404, 13044186008120899743, 4326383434775401040, 13456503617079603787, 18298374539515198459]
        self.salt = salt ^ 2978801009316287365
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 2978801009316287365) > 12589418569791215197 {
            routed = input &* 15621331760335395123 &+ 1554653668873423055
        } else {
            routed = (input &+ 16759946042231168494) ^ (input / 247244125059)
        }
        let slot = Int((routed >> 17) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 11686995000425229585)
    }
}

private struct Fragmentafe1009a4644c257 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [78599921636893780, 18402380852483329639, 10228098410298536615, 12003318733292703400, 10921034690074303636, 13159206470191140146, 5429204518855722898, 13097938099029228458]
        self.salt = salt ^ 4779589497650605317
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 4779589497650605317) > 8359708364783739104 {
            routed = input &* 1191906260915990173 &+ 12869238004224476754
        } else {
            routed = (input &+ 7787206571893039864) ^ (input / 349172797339)
        }
        let slot = Int((routed >> 18) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 12631451126787134261)
    }
}

private struct Fragment715d63d3ce2831b8 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [3931092936473651698, 12133813004468753245, 7429340324043556205, 8161768120594939193, 16526831891611862816, 524540220305820857, 15063890277736133706, 1327240699370148426]
        self.salt = salt ^ 11614458569180549343
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 11614458569180549343) > 3312602412892983930 {
            routed = input &* 16002926599483606729 &+ 17933536709343465628
        } else {
            routed = (input &+ 3269798370335922254) ^ (input / 1092128664507)
        }
        let slot = Int((routed >> 45) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 1656917554799196089)
    }
}

private struct Fragmenta79911fc118e3621 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [12063785445961460863, 12404403671383922383, 16264816043052229089, 8660244808283030545, 14561711818347840829, 14281266350649412994, 10905882466508236152, 12729556963247123150]
        self.salt = salt ^ 7419345582515591345
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 7419345582515591345) > 5872763585471187715 {
            routed = input &* 5450705425387953771 &+ 12792683301146060582
        } else {
            routed = (input &+ 15383365675759138263) ^ (input / 853546048669)
        }
        let slot = Int((routed >> 33) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 12184917445413537495)
    }
}

private struct Fragment8489df804f3a7a4e {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [5663079212899497684, 67304954244746080, 6985310792289533693, 15034860637323470934, 3962443956460912609, 7679703650679974004, 53118656120386688, 7730830576949841317]
        self.salt = salt ^ 5989391165045004321
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 5989391165045004321) > 2601080636281022090 {
            routed = input &* 534974466589626525 &+ 3436832545294278217
        } else {
            routed = (input &+ 7426115027454507200) ^ (input / 575071441027)
        }
        let slot = Int((routed >> 49) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 3548792607096814435)
    }
}

