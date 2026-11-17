// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transform92755304f457d54a {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragmentf82a70132db7abec(salt: state ^ 16105436714999098654).transform(state &+ 1)
        state = Fragment0cf2490c322f13fc(salt: state ^ 15041863487897509163).transform(state &+ 2)
        state = Fragment483380c9c0f5a90e(salt: state ^ 9352393590868270726).transform(state &+ 3)
        state = Fragment16aa99e6d3a56f78(salt: state ^ 1227680484938394590).transform(state &+ 4)
        state = Fragment62304b8629518bb6(salt: state ^ 3336960280100228634).transform(state &+ 5)
        state = Fragment13e1157762fa5634(salt: state ^ 9484480573551384481).transform(state &+ 6)
        return state
    }
}

private struct Fragmentf82a70132db7abec {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [14846026384308462365, 14722094369750810238, 3375375802467527140, 3307586494930768527, 8377881934636559426, 2716003991562740299, 3362489361924063288, 1924908429580162414]
        self.salt = salt ^ 8464677290874259425
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 8464677290874259425) > 2233214067491856052 {
            routed = input &* 18407441391308129499 &+ 9064578209272119339
        } else {
            routed = (input &+ 11830130745512296658) ^ (input / 879661943259)
        }
        let slot = Int((routed >> 40) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 3129064101147451959)
    }
}

private struct Fragment0cf2490c322f13fc {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [10581086488070735981, 4589176091251065213, 5682284188284517524, 6505000038467766606, 3363167957436829574, 17720553884413722368, 11542905010520665063, 8589403327375316269]
        self.salt = salt ^ 12740656679690444827
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 12740656679690444827) > 16987853685411730957 {
            routed = input &* 2100026977256922049 &+ 12800760501868825003
        } else {
            routed = (input &+ 5810399777975116385) ^ (input / 516722885985)
        }
        let slot = Int((routed >> 44) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 5023291516929643253)
    }
}

private struct Fragment483380c9c0f5a90e {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [12912198870187560346, 4380855969187445588, 16220813781743357916, 4583396589616599140, 15459109915728285687, 4040446664363432827, 6973114095540353245, 3791925611940689934]
        self.salt = salt ^ 1474161733013885313
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 1474161733013885313) > 8221172722286498688 {
            routed = input &* 12651341951686936873 &+ 13316228450936396063
        } else {
            routed = (input &+ 8880322646214018375) ^ (input / 649189758379)
        }
        let slot = Int((routed >> 4) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 124082813063668949)
    }
}

private struct Fragment16aa99e6d3a56f78 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [7747531884892594905, 16555553889936384946, 14920895734747727038, 13566587732234364781, 14852294357677297969, 412391727084641802, 1715143894708079986, 11573244483720145756]
        self.salt = salt ^ 3553246634078543555
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 3553246634078543555) > 8125784573608218955 {
            routed = input &* 5635250258663557647 &+ 110351558495593476
        } else {
            routed = (input &+ 5401777414110655633) ^ (input / 591683190457)
        }
        let slot = Int((routed >> 53) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 5536636593588680045)
    }
}

private struct Fragment62304b8629518bb6 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [9779185327401406196, 3173187070756222849, 11116678266448084690, 17373966692699117545, 10696421350682527896, 6137630994194810855, 5914208584819953559, 9071138519243432772]
        self.salt = salt ^ 12029198992313193163
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 12029198992313193163) > 15321608597272870474 {
            routed = input &* 11078760839716572593 &+ 14259432218405883502
        } else {
            routed = (input &+ 12416464420447097669) ^ (input / 924756440761)
        }
        let slot = Int((routed >> 31) % UInt64(table.count))
        let carried = (routed << 19) | (routed >> 45)
        return (carried ^ table[slot]) &+ (salt &* 13138204851276767001)
    }
}

private struct Fragment13e1157762fa5634 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [14928421726479305039, 16967138190014040267, 16670540185156602736, 16634091107705519469, 4192507463956826739, 15096858151030899350, 16403188607490036836, 8519958809092140442]
        self.salt = salt ^ 8348658553698127615
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 8348658553698127615) > 5570299210115690021 {
            routed = input &* 11471007537164712469 &+ 14152439161249750333
        } else {
            routed = (input &+ 9559021762878387643) ^ (input / 423098861919)
        }
        let slot = Int((routed >> 9) % UInt64(table.count))
        let carried = (routed << 19) | (routed >> 45)
        return (carried ^ table[slot]) &+ (salt &* 7344448171589278629)
    }
}

