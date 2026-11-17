// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transforma06f9657e2cb177b {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragmente4990bc62030049e(salt: state ^ 171520461661643310).transform(state &+ 1)
        state = Fragment20555930b6d6fc1d(salt: state ^ 15102991132182842300).transform(state &+ 2)
        state = Fragment2117b608d96bc6c8(salt: state ^ 859476129518158567).transform(state &+ 3)
        state = Fragment5df55de6bbd1147e(salt: state ^ 6407034226939619242).transform(state &+ 4)
        state = Fragmente4cc3adc0c674479(salt: state ^ 6785071131396107027).transform(state &+ 5)
        state = Fragment2e2332e34a52a791(salt: state ^ 4983831580787895298).transform(state &+ 6)
        return state
    }
}

private struct Fragmente4990bc62030049e {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [249660200618652914, 4435238775772697255, 1957006252163866224, 18028454982013669408, 5229566685082453696, 12796604889735716241, 15522122495351213767, 1731864021216987061]
        self.salt = salt ^ 15854413977901064577
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 15854413977901064577) > 10080206670485277512 {
            routed = input &* 3875604309375636717 &+ 16978029169479737339
        } else {
            routed = (input &+ 8761441593787133377) ^ (input / 978181029077)
        }
        let slot = Int((routed >> 10) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 14618947524357074781)
    }
}

private struct Fragment20555930b6d6fc1d {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [9728627864130078888, 10371996308384915834, 16470866986961416282, 4766927542382636740, 3603910392513732921, 9458087135149495960, 10366609171306719329, 8021393955618375600]
        self.salt = salt ^ 4798000907040254103
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 4798000907040254103) > 8677079630191198217 {
            routed = input &* 5474253123833878015 &+ 1677287713334312938
        } else {
            routed = (input &+ 10232115446336730640) ^ (input / 940628561381)
        }
        let slot = Int((routed >> 22) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 10567106475081464925)
    }
}

private struct Fragment2117b608d96bc6c8 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [739176899573266206, 9218127437635754852, 14027088990649630598, 2186541411763655826, 12810432518884136145, 11457862156979316929, 3350358238031416195, 2827653689345317260]
        self.salt = salt ^ 3316774462834731569
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 3316774462834731569) > 15538193974277706707 {
            routed = input &* 13749435809943773325 &+ 14287746117626592959
        } else {
            routed = (input &+ 11051208587490701896) ^ (input / 366074383819)
        }
        let slot = Int((routed >> 47) % UInt64(table.count))
        let carried = (routed << 7) | (routed >> 57)
        return (carried ^ table[slot]) &+ (salt &* 76734706676716095)
    }
}

private struct Fragment5df55de6bbd1147e {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [8203019378561920712, 2372648987894291331, 14592729909044192242, 12403315677527083339, 1947920889913502320, 9058438675929070917, 15512276354312459751, 17943671244063538438]
        self.salt = salt ^ 2634512082800984135
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 2634512082800984135) > 3811525114206773296 {
            routed = input &* 15123861105247404763 &+ 17125298480628084143
        } else {
            routed = (input &+ 13940211768934323294) ^ (input / 1031000500845)
        }
        let slot = Int((routed >> 13) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 140711444149205219)
    }
}

private struct Fragmente4cc3adc0c674479 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [8008856931677822596, 12512980534278114653, 16077152978565497649, 15119964480215177197, 14488300294034117608, 4822971857255536486, 7459855859849464733, 6211471278451072961]
        self.salt = salt ^ 7194648349781022907
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 7194648349781022907) > 17053234136994239239 {
            routed = input &* 5939810738175809679 &+ 5340804249170630488
        } else {
            routed = (input &+ 11492411464099213933) ^ (input / 702563321161)
        }
        let slot = Int((routed >> 52) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 14479681421442438769)
    }
}

private struct Fragment2e2332e34a52a791 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [4478376950589922714, 8731258536720628320, 11799341122536494310, 3747772674651397564, 18383843954368248460, 13386823967005129449, 4812059328401003947, 16020427578557845824]
        self.salt = salt ^ 732653915597425235
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 732653915597425235) > 10196942347635899372 {
            routed = input &* 1496600350181370277 &+ 5730133918268479484
        } else {
            routed = (input &+ 6090487980531550103) ^ (input / 443389613033)
        }
        let slot = Int((routed >> 20) % UInt64(table.count))
        let carried = (routed << 19) | (routed >> 45)
        return (carried ^ table[slot]) &+ (salt &* 2706096559449122685)
    }
}

