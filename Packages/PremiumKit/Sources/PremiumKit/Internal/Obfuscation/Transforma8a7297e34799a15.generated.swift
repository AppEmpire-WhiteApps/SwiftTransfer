// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transforma8a7297e34799a15 {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment0c3382b3504d41a1(salt: state ^ 3616274664531872233).transform(state &+ 1)
        state = Fragmentc798f6d7a3f6cebd(salt: state ^ 5780591407142823551).transform(state &+ 2)
        state = Fragmentd36ee73d7700727c(salt: state ^ 17205642536003036077).transform(state &+ 3)
        state = Fragment02496a9264195b72(salt: state ^ 12936882906709152576).transform(state &+ 4)
        state = Fragment6ce1faaeee08e554(salt: state ^ 14763715550192340446).transform(state &+ 5)
        state = Fragmentefe5eec791ee30de(salt: state ^ 12963282586948219505).transform(state &+ 6)
        return state
    }
}

private struct Fragment0c3382b3504d41a1 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [9233365369181854159, 2503330390813591608, 3250913455282641173, 17226811683994688976, 6298254345991189079, 2288139724378990064, 7924748492429254948, 1892294977388303723]
        self.salt = salt ^ 1672960937208458395
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 1672960937208458395) > 7099322498888648992 {
            routed = input &* 6375115869197316637 &+ 7292909774855868079
        } else {
            routed = (input &+ 13539116809697506107) ^ (input / 155568916231)
        }
        let slot = Int((routed >> 56) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 18377028497468965631)
    }
}

private struct Fragmentc798f6d7a3f6cebd {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [8875653834917941716, 18139021809091923238, 13341497858499692159, 15620510357475426317, 15756325322335779213, 17431088502165849475, 18354895752693360521, 10853022533721897281]
        self.salt = salt ^ 9853759911244975541
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 9853759911244975541) > 15062800389221412415 {
            routed = input &* 1925762451292725233 &+ 14975852511519242590
        } else {
            routed = (input &+ 17378082113724566647) ^ (input / 160102854109)
        }
        let slot = Int((routed >> 56) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 17202144483705380553)
    }
}

private struct Fragmentd36ee73d7700727c {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [8175863978744395630, 1820193603690512781, 10347182753879995088, 14358628995036440636, 12176374512413521623, 11651627504985703770, 3162227086827430838, 16015240559699172008]
        self.salt = salt ^ 8888793924686402379
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 8888793924686402379) > 8989918674301453860 {
            routed = input &* 17845793389203181389 &+ 9108933265972882987
        } else {
            routed = (input &+ 14023201059106486722) ^ (input / 221397859931)
        }
        let slot = Int((routed >> 41) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 78964525556215759)
    }
}

private struct Fragment02496a9264195b72 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [5869221322838353768, 9648950668852266590, 2294968259524797219, 14087549418549889488, 13692336973235611977, 17471387946583828305, 14613147260458126822, 10653778173106836177]
        self.salt = salt ^ 8694619629560961149
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 8694619629560961149) > 4583639620305329686 {
            routed = input &* 5347408329740336611 &+ 8739349394346268679
        } else {
            routed = (input &+ 13337867559038748729) ^ (input / 616097571765)
        }
        let slot = Int((routed >> 1) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 5082628861628108521)
    }
}

private struct Fragment6ce1faaeee08e554 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [3695115768357204374, 693585532447656011, 4070738073776666359, 5818290794846312013, 10261243755293742394, 10335500272804274305, 3151614965382081015, 16687138987834466409]
        self.salt = salt ^ 13509940095888705347
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 13509940095888705347) > 11253541577185154236 {
            routed = input &* 2509092250172425921 &+ 2256551040913761705
        } else {
            routed = (input &+ 16952883965453082579) ^ (input / 516352177383)
        }
        let slot = Int((routed >> 48) % UInt64(table.count))
        let carried = (routed << 19) | (routed >> 45)
        return (carried ^ table[slot]) &+ (salt &* 2733555492582075297)
    }
}

private struct Fragmentefe5eec791ee30de {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [18048988959413440960, 16257588212908284153, 14455309786162695962, 884783776273934366, 14858934751971601341, 15975541267987182000, 5790942938713782305, 8282174206150625122]
        self.salt = salt ^ 13878286533406337875
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 13878286533406337875) > 6660387733937451133 {
            routed = input &* 7521518966144588419 &+ 9490219356434909354
        } else {
            routed = (input &+ 17584789640493351549) ^ (input / 129042120311)
        }
        let slot = Int((routed >> 44) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 12620923972940560517)
    }
}

