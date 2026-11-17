// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transform3e138775f57a23a4 {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment85538fca8e997d45(salt: state ^ 6372431802276863964).transform(state &+ 1)
        state = Fragment97430f8d987d7b23(salt: state ^ 2616328636201462968).transform(state &+ 2)
        state = Fragment8ad879f2a5aff9a5(salt: state ^ 17381763809965804255).transform(state &+ 3)
        state = Fragment9bf374aa4d423812(salt: state ^ 4310688902460941551).transform(state &+ 4)
        state = Fragmentfcca686db4a73f60(salt: state ^ 14425454704775006731).transform(state &+ 5)
        state = Fragment9be8e6b73f91df18(salt: state ^ 9633421624685060463).transform(state &+ 6)
        return state
    }
}

private struct Fragment85538fca8e997d45 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [1744030019717204707, 142028485780427339, 16599943640791785940, 3448034603711872610, 16669991638764227780, 5909876790725352563, 3861011919600099437, 4314947320024934753]
        self.salt = salt ^ 16540408333462639477
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 16540408333462639477) > 2921389843373711740 {
            routed = input &* 2404738079481889943 &+ 16153794061905574835
        } else {
            routed = (input &+ 16125995553161581477) ^ (input / 957826849605)
        }
        let slot = Int((routed >> 8) % UInt64(table.count))
        let carried = (routed << 29) | (routed >> 35)
        return (carried ^ table[slot]) &+ (salt &* 1458677943539576627)
    }
}

private struct Fragment97430f8d987d7b23 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [6842619277013318515, 17037608470113853562, 17009490159780006577, 2688652883576964435, 4983732853645983911, 4223618130599725879, 3169082415000861530, 5506766243121128746]
        self.salt = salt ^ 1577830006250054957
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 1577830006250054957) > 4093071012734070175 {
            routed = input &* 17226469506093848391 &+ 3592527629996097941
        } else {
            routed = (input &+ 6484311992699523754) ^ (input / 570223178943)
        }
        let slot = Int((routed >> 42) % UInt64(table.count))
        let carried = (routed << 11) | (routed >> 53)
        return (carried ^ table[slot]) &+ (salt &* 4914181069168353823)
    }
}

private struct Fragment8ad879f2a5aff9a5 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [18438498801872572105, 14625235580283845704, 5445626717487034398, 10067789926063237993, 13498893198195678680, 8814536806601452667, 9676400307140466091, 15546491793189144567]
        self.salt = salt ^ 3130037979704936709
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 3130037979704936709) > 3293773527130654164 {
            routed = input &* 12146538973001724013 &+ 7176815148046573030
        } else {
            routed = (input &+ 5424528890536295550) ^ (input / 267318132471)
        }
        let slot = Int((routed >> 15) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 7796860075986813669)
    }
}

private struct Fragment9bf374aa4d423812 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [16998614767640709245, 4822248326205439372, 16181140074410169958, 13355118850415583770, 16261563703093014235, 6643819498454264184, 8385662407160997227, 3845532797465207510]
        self.salt = salt ^ 8454850081155564611
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 8454850081155564611) > 13213614663181145973 {
            routed = input &* 5326445718682301955 &+ 1917223451273064501
        } else {
            routed = (input &+ 11119827813467018055) ^ (input / 505876443147)
        }
        let slot = Int((routed >> 41) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 2773272126979958537)
    }
}

private struct Fragmentfcca686db4a73f60 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [6091995070590883092, 4570865500529689326, 11918534456646797334, 9388118635191870629, 4409809736439444288, 608903955448627779, 5181383093192907129, 11665677391795507631]
        self.salt = salt ^ 2643622489735712417
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 2643622489735712417) > 18291721220100050551 {
            routed = input &* 8534580855177607801 &+ 16367792352902768856
        } else {
            routed = (input &+ 8443328412876775047) ^ (input / 875489520641)
        }
        let slot = Int((routed >> 9) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 2917178077265464715)
    }
}

private struct Fragment9be8e6b73f91df18 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [11212060152646698645, 357889577648350691, 8822385244459127538, 11554488733160348830, 8118083995452893222, 5652539263926031091, 14598765602638266911, 1333676293725129746]
        self.salt = salt ^ 3741607278674779687
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 3741607278674779687) > 9470874498647809223 {
            routed = input &* 5679765246532556393 &+ 5256724866877650061
        } else {
            routed = (input &+ 4903527330240158838) ^ (input / 7187988001)
        }
        let slot = Int((routed >> 46) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 984915579711646797)
    }
}

