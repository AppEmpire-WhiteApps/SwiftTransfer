// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transformafcc386d4fdddc3a {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment6e4944b73ffd1902(salt: state ^ 15474105581033586984).transform(state &+ 1)
        state = Fragment88b2c1fefa44fab0(salt: state ^ 2192426739161110681).transform(state &+ 2)
        state = Fragmentc443f5cf8449308e(salt: state ^ 4623692235542197995).transform(state &+ 3)
        state = Fragment4777c45931725410(salt: state ^ 15848714873527356007).transform(state &+ 4)
        state = Fragment887bf8ede16934a2(salt: state ^ 2608965167039244022).transform(state &+ 5)
        state = Fragment464cc444de2a0c16(salt: state ^ 7833710382528854468).transform(state &+ 6)
        return state
    }
}

private struct Fragment6e4944b73ffd1902 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [17503326370390969011, 6547905577099255298, 2790344135608454521, 4273245081099560060, 3528448674510150321, 6523221810424442051, 10943199258670730284, 13926597041655533410]
        self.salt = salt ^ 13719717261628777095
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 13719717261628777095) > 4920021878441343906 {
            routed = input &* 2640897660618000861 &+ 11082445753735783887
        } else {
            routed = (input &+ 14998155389787284139) ^ (input / 412658899349)
        }
        let slot = Int((routed >> 27) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 4627700085444400377)
    }
}

private struct Fragment88b2c1fefa44fab0 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [5285731001870093760, 9485351341723803987, 3734519243449079221, 1186352343704252242, 14873618749362423979, 3364848419585341735, 15432553758922900568, 10370840739857377365]
        self.salt = salt ^ 3015113665271364487
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 3015113665271364487) > 3235286022193364084 {
            routed = input &* 4040877588131372611 &+ 11505574084992135006
        } else {
            routed = (input &+ 11942336699172011624) ^ (input / 386613360497)
        }
        let slot = Int((routed >> 33) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 8400282006053321971)
    }
}

private struct Fragmentc443f5cf8449308e {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [17089637140096342837, 17314792132083700457, 7035676443547865542, 1405636075662137932, 11918859302989313755, 6113839910221848248, 1750882370841755239, 16852161599124333630]
        self.salt = salt ^ 4182685133990026997
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 4182685133990026997) > 432437580242420682 {
            routed = input &* 5356018721400468865 &+ 11939202747334457868
        } else {
            routed = (input &+ 18010784469907325203) ^ (input / 740578481095)
        }
        let slot = Int((routed >> 48) % UInt64(table.count))
        let carried = (routed << 19) | (routed >> 45)
        return (carried ^ table[slot]) &+ (salt &* 15217887447234308931)
    }
}

private struct Fragment4777c45931725410 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [12225132155983761631, 10240357205731865031, 9942649027635974975, 10235368783383676624, 11264140995462596643, 9557306304831358177, 6569943337755267828, 14041912282469598744]
        self.salt = salt ^ 12772554459943558507
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 12772554459943558507) > 2278879608475229706 {
            routed = input &* 71776127381502687 &+ 714253701283866257
        } else {
            routed = (input &+ 3568935600937516809) ^ (input / 323942544531)
        }
        let slot = Int((routed >> 34) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 11378890411437447769)
    }
}

private struct Fragment887bf8ede16934a2 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [12635449616114516493, 4181081506411800643, 8311478254435791498, 16151731813210712612, 13127296655470759745, 3452843471614160927, 8340875986558214611, 1739072672280004820]
        self.salt = salt ^ 17215360316408136231
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 17215360316408136231) > 5185179362539626977 {
            routed = input &* 9834009556250263857 &+ 4993558658939693380
        } else {
            routed = (input &+ 11991876196341577101) ^ (input / 1068585395891)
        }
        let slot = Int((routed >> 2) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 17665156599373973959)
    }
}

private struct Fragment464cc444de2a0c16 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [2824985794068762914, 1522510266851253553, 16321391272436887528, 13191669072682751651, 15835842940075308345, 1278846449179612528, 6967110937698761956, 9102657509933069516]
        self.salt = salt ^ 4972019835738829175
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 4972019835738829175) > 7458114965772239057 {
            routed = input &* 11731837558798401947 &+ 17903143330321389051
        } else {
            routed = (input &+ 17898865142201221339) ^ (input / 575545958497)
        }
        let slot = Int((routed >> 49) % UInt64(table.count))
        let carried = (routed << 19) | (routed >> 45)
        return (carried ^ table[slot]) &+ (salt &* 3974095099404164125)
    }
}

