// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transform091e4e0fac2b4b6f {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragmentefb9262872699d9b(salt: state ^ 4700269218782250988).transform(state &+ 1)
        state = Fragment344adde71a33e05b(salt: state ^ 16782911267497623300).transform(state &+ 2)
        state = Fragmentce20cf730b4d7f87(salt: state ^ 5632126972984490965).transform(state &+ 3)
        state = Fragmentd4107b180b89d909(salt: state ^ 2782656108582820813).transform(state &+ 4)
        state = Fragment7ba16253d3357c58(salt: state ^ 6983587195022650088).transform(state &+ 5)
        state = Fragment7ecf23c2cc9bca2d(salt: state ^ 9945359579008186164).transform(state &+ 6)
        return state
    }
}

private struct Fragmentefb9262872699d9b {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [17493899193165063203, 10016844128818418113, 11492241311934505789, 10093102011651152194, 3010477028720490220, 15338190957668411153, 329740515674036202, 15705007697828824396]
        self.salt = salt ^ 16425295902865478563
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 16425295902865478563) > 12841003165189057454 {
            routed = input &* 12168513052872516847 &+ 13947339914903916400
        } else {
            routed = (input &+ 10593359604688189905) ^ (input / 481460383711)
        }
        let slot = Int((routed >> 44) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 11490400098990839151)
    }
}

private struct Fragment344adde71a33e05b {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [17737984338950269138, 6307688116402187113, 7855807320713884153, 8005909527864955307, 16367384856169287554, 1162987052480575707, 17087309378195906601, 12448743489521751864]
        self.salt = salt ^ 14650185454378699583
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 14650185454378699583) > 1324779903533527387 {
            routed = input &* 7368531400807402721 &+ 8346861567823823759
        } else {
            routed = (input &+ 873677715122105901) ^ (input / 114255974817)
        }
        let slot = Int((routed >> 38) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 9609343235041256235)
    }
}

private struct Fragmentce20cf730b4d7f87 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [13203797617571866383, 17494574484099666698, 4802972919130972137, 5347978877256498922, 8035847422464538598, 5806818598198552785, 8706957059187127352, 10869627717360433789]
        self.salt = salt ^ 992081397348859771
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 992081397348859771) > 10714395353622648533 {
            routed = input &* 7292831437772614557 &+ 13243322533778136975
        } else {
            routed = (input &+ 7594982482865983472) ^ (input / 289309832401)
        }
        let slot = Int((routed >> 32) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 206275850923088397)
    }
}

private struct Fragmentd4107b180b89d909 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [11720179656076489092, 6225832701636971352, 11328207884774790742, 3124764405852489702, 9973066576185338920, 10192381161726884898, 18343211360050415398, 15318515028902894902]
        self.salt = salt ^ 7700598496508968431
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 7700598496508968431) > 9330059792895968476 {
            routed = input &* 627859247262995823 &+ 13192902593586580862
        } else {
            routed = (input &+ 3375205080313783888) ^ (input / 1087707595155)
        }
        let slot = Int((routed >> 15) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 12054028922161002445)
    }
}

private struct Fragment7ba16253d3357c58 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [7178462165190256629, 9725747669148381446, 7454118554111518486, 15468011968137809388, 6389529292180636563, 11617819357560067229, 9332220349322163737, 10518408035890409716]
        self.salt = salt ^ 12032547029670021533
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 12032547029670021533) > 4646262079243159312 {
            routed = input &* 15126532304351113849 &+ 10758201818530343994
        } else {
            routed = (input &+ 11742647477781391922) ^ (input / 136995030689)
        }
        let slot = Int((routed >> 49) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 7233932163292647697)
    }
}

private struct Fragment7ecf23c2cc9bca2d {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [12360150849174835531, 12720308599625384657, 1277567079739843473, 9907521012522296279, 5999743861015619848, 7793240709512607688, 14052235274593892211, 8495792610140556061]
        self.salt = salt ^ 3243134702510611903
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 3243134702510611903) > 12955756032450448343 {
            routed = input &* 11286929377175886937 &+ 11798644086707010181
        } else {
            routed = (input &+ 5249003207135338401) ^ (input / 733003393901)
        }
        let slot = Int((routed >> 39) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 5557774106250920645)
    }
}

