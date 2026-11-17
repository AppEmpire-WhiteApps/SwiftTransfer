// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transform72f08a1901d8b6da {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment60dfa0c16c0237df(salt: state ^ 5756439464346942823).transform(state &+ 1)
        state = Fragment0f5c08f36ee3ee8a(salt: state ^ 3947953938312969458).transform(state &+ 2)
        state = Fragmente0cdbf11fc4f2ff9(salt: state ^ 15113421530212302218).transform(state &+ 3)
        state = Fragmentfdd7cd028c9774fe(salt: state ^ 853538062967045098).transform(state &+ 4)
        state = Fragment7e5f7ee24fb35869(salt: state ^ 2334953870456437129).transform(state &+ 5)
        state = Fragmentffedb5a7077fd705(salt: state ^ 15947121128159344954).transform(state &+ 6)
        return state
    }
}

private struct Fragment60dfa0c16c0237df {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [14864977705442524084, 14913870787045990362, 8051050002354850677, 2022162897578880288, 2301623288842854952, 251687272061936342, 16353966450958911901, 11313193471961598748]
        self.salt = salt ^ 6142032827483419997
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 6142032827483419997) > 10129467876573480056 {
            routed = input &* 11972784059528671045 &+ 16403993525713191612
        } else {
            routed = (input &+ 1168522174344953079) ^ (input / 501279973039)
        }
        let slot = Int((routed >> 1) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 11611865177971008133)
    }
}

private struct Fragment0f5c08f36ee3ee8a {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [16830334692824721390, 9060173415197756989, 5829523805298277101, 2125556117484287234, 1090306490353731036, 8359152879329840127, 18118772815035137159, 9500968167187991845]
        self.salt = salt ^ 8558769881959104821
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 8558769881959104821) > 12117781014369510123 {
            routed = input &* 10716630632168510725 &+ 14413602229286829721
        } else {
            routed = (input &+ 5890751238855300934) ^ (input / 345240952445)
        }
        let slot = Int((routed >> 27) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 17153249710626366991)
    }
}

private struct Fragmente0cdbf11fc4f2ff9 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [5713675216840611376, 12050415279602539877, 7796978098088493928, 2391870252438426839, 2117308065869933486, 7230101170885666872, 11446210298834029275, 4231879506365998839]
        self.salt = salt ^ 7727810529597409141
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 7727810529597409141) > 460871591205572018 {
            routed = input &* 15823564892231222769 &+ 5348648796113030913
        } else {
            routed = (input &+ 5795356692708722662) ^ (input / 643521853217)
        }
        let slot = Int((routed >> 20) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 8169854917843751533)
    }
}

private struct Fragmentfdd7cd028c9774fe {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [15361304855726354971, 13469046128056849210, 6797531947437310965, 15541683185733543326, 3386665964176561364, 8372800242265442835, 15605117108494167635, 17586722546980469300]
        self.salt = salt ^ 4129909570189609693
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 4129909570189609693) > 7623068189478564623 {
            routed = input &* 9120639035432625395 &+ 194012173911549508
        } else {
            routed = (input &+ 4358171488286109931) ^ (input / 211496860919)
        }
        let slot = Int((routed >> 54) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 15046781500642772323)
    }
}

private struct Fragment7e5f7ee24fb35869 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [1394650722436639820, 7984978402287869538, 1230436169257724960, 8974079141692273146, 564060648752193237, 18007885456876852398, 17064927563606715328, 8554494014053834741]
        self.salt = salt ^ 14340313487907187135
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 14340313487907187135) > 9795259045726286819 {
            routed = input &* 5225629534354366721 &+ 5801723209049211025
        } else {
            routed = (input &+ 3122249110810638304) ^ (input / 725477596253)
        }
        let slot = Int((routed >> 32) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 16037825067984258687)
    }
}

private struct Fragmentffedb5a7077fd705 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [15256396066107779001, 17163303520351570592, 7194283258439720278, 14310761109612055194, 3397138944177528998, 9724672997550812153, 12872273915573247281, 12822533537811099466]
        self.salt = salt ^ 18294045823128096657
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 18294045823128096657) > 2641553208255015181 {
            routed = input &* 15831690940201343803 &+ 8040210336772813844
        } else {
            routed = (input &+ 2858570247476563543) ^ (input / 269890377887)
        }
        let slot = Int((routed >> 6) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 17032924762065811667)
    }
}

