// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transformbc33abc5e54bbd1c {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment7b0943f3c2e1b601(salt: state ^ 15009599064208965229).transform(state &+ 1)
        state = Fragment5a002b9964db2cd9(salt: state ^ 7088522296196434068).transform(state &+ 2)
        state = Fragment223b522ee61cffde(salt: state ^ 16742012525446070632).transform(state &+ 3)
        state = Fragmentf965ec7f5b623564(salt: state ^ 5345071127531171807).transform(state &+ 4)
        state = Fragment0fe2ae86e74cce4b(salt: state ^ 836737945166139384).transform(state &+ 5)
        state = Fragmentb4d73009d1f29495(salt: state ^ 7996592075136663898).transform(state &+ 6)
        return state
    }
}

private struct Fragment7b0943f3c2e1b601 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [3523063125338735738, 14383514344757200333, 11421804775269094066, 17139595933107746499, 5200103382599220889, 16561916396135910590, 9135360717811324373, 12873772293659314236]
        self.salt = salt ^ 5459014100963873437
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 5459014100963873437) > 18025507586920801261 {
            routed = input &* 16930237705218785633 &+ 10355133016372759811
        } else {
            routed = (input &+ 6064947080983949682) ^ (input / 554846353387)
        }
        let slot = Int((routed >> 11) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 13974051480170101927)
    }
}

private struct Fragment5a002b9964db2cd9 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [9055603467704761661, 467269738608630007, 3282357156773447297, 5397359579350985671, 11247819735904747089, 11416275753791242300, 8415570085241034285, 9286031385365525369]
        self.salt = salt ^ 10166788541488866333
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 10166788541488866333) > 2112923925737527467 {
            routed = input &* 8006868939267423367 &+ 5884525413167497770
        } else {
            routed = (input &+ 31990977288357555) ^ (input / 942398977223)
        }
        let slot = Int((routed >> 12) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 17998774492884638021)
    }
}

private struct Fragment223b522ee61cffde {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [2161375859211217553, 8760505838655239084, 7000714402336666119, 5346692816598396186, 3499449759863857891, 16294415545548577363, 6736745046207004708, 1530441257197817760]
        self.salt = salt ^ 6399386036464028445
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 6399386036464028445) > 6953995893221644740 {
            routed = input &* 15165206986330595581 &+ 12758751344465110207
        } else {
            routed = (input &+ 13485260634104617385) ^ (input / 562110855823)
        }
        let slot = Int((routed >> 5) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 2901022091071169929)
    }
}

private struct Fragmentf965ec7f5b623564 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [17833270453559648701, 582953392349107215, 17757804647555752673, 2576778318384996634, 4498660064727888005, 11909832927284276347, 18392067727546333949, 11002798533050124491]
        self.salt = salt ^ 14312548416165564349
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 14312548416165564349) > 5623586575692380088 {
            routed = input &* 1703546221059266143 &+ 16016103078821862527
        } else {
            routed = (input &+ 10707838807090913040) ^ (input / 190912637265)
        }
        let slot = Int((routed >> 43) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 15130225779746995509)
    }
}

private struct Fragment0fe2ae86e74cce4b {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [8086398374046879690, 12404307241812475068, 11799405395862175628, 8904105232263881648, 14857901155649264752, 5287679390999058178, 2051202333517292179, 5346056427131318044]
        self.salt = salt ^ 2572948752317815691
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 2572948752317815691) > 6367897645147684346 {
            routed = input &* 3939434927099385219 &+ 1720634278770849992
        } else {
            routed = (input &+ 15789566426892745079) ^ (input / 717175476655)
        }
        let slot = Int((routed >> 40) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 12612485945668369093)
    }
}

private struct Fragmentb4d73009d1f29495 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [13456077410290885831, 7647025977806981820, 10068422709103850489, 8405699696966040196, 15567681015679503691, 2094105410913120396, 6790628551075548276, 12139654083818631642]
        self.salt = salt ^ 3813492967563790733
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 3813492967563790733) > 15679278111877108124 {
            routed = input &* 4392861565468922179 &+ 12575232992797029033
        } else {
            routed = (input &+ 9815764373648361077) ^ (input / 965125347979)
        }
        let slot = Int((routed >> 37) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 8018417816258134057)
    }
}

