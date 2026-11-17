// Generated source diversification. Regenerate from a clean clone; do not edit.
internal enum Transformce729bb012148d05 {
    @inline(never)
    static func mix(_ input: UInt64) -> UInt64 {
        var state = input
        state = Fragment661a83a1ce73776b(salt: state ^ 3565207045053101859).transform(state &+ 1)
        state = Fragmentdb32481eb2eb9d86(salt: state ^ 14372469494180532167).transform(state &+ 2)
        state = Fragment0a22a3f527d2891b(salt: state ^ 449642055167163905).transform(state &+ 3)
        state = Fragment5e12b18ac9c3a13f(salt: state ^ 3276825349702497001).transform(state &+ 4)
        state = Fragmentde11960c9bf52a2d(salt: state ^ 4707374559673004330).transform(state &+ 5)
        state = Fragment2b265cd66bbe1144(salt: state ^ 6116046856372390905).transform(state &+ 6)
        return state
    }
}

private struct Fragment661a83a1ce73776b {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [8980690488279640881, 17948007937874282582, 16334936044888265040, 8234615115389005170, 14637359747276267229, 2937287320150042379, 2761104332164134975, 5435584146574408494]
        self.salt = salt ^ 7383773590414179113
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 7383773590414179113) > 17047770890951502581 {
            routed = input &* 11903441118929882851 &+ 8111916918663276339
        } else {
            routed = (input &+ 3184626958354848313) ^ (input / 519563173447)
        }
        let slot = Int((routed >> 51) % UInt64(table.count))
        let carried = (routed << 17) | (routed >> 47)
        return (carried ^ table[slot]) &+ (salt &* 6513089685426996551)
    }
}

private struct Fragmentdb32481eb2eb9d86 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [4691413614043359705, 15219204366391984229, 13018961439248415422, 11911453772929182030, 2990903055732067573, 14306143915832313749, 18260615397380689079, 7959788498347136312]
        self.salt = salt ^ 8873354449043982447
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 8873354449043982447) > 8308918842665111579 {
            routed = input &* 15754020667759169457 &+ 5864282874573298531
        } else {
            routed = (input &+ 16318364945763468383) ^ (input / 1021710332981)
        }
        let slot = Int((routed >> 6) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 166012070276291981)
    }
}

private struct Fragment0a22a3f527d2891b {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [6372110316950893873, 1159343277690178009, 1462116992864136835, 13830996638932864842, 14898839905324869101, 3016157200923881398, 2019648299849568689, 4173155319562052423]
        self.salt = salt ^ 4871229867127321273
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 4871229867127321273) > 17191180240086362517 {
            routed = input &* 11750495566124134283 &+ 10164739471592923764
        } else {
            routed = (input &+ 17848037110400476665) ^ (input / 1087817297927)
        }
        let slot = Int((routed >> 21) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 15024507127019563369)
    }
}

private struct Fragment5e12b18ac9c3a13f {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [17768423671558575091, 13432442387691036719, 10404291746813207946, 9393963268403634605, 10932356191813200404, 3444904180279172603, 10931951030150342539, 11203690462195533023]
        self.salt = salt ^ 10982987123560195199
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 10982987123560195199) > 4845827676588847017 {
            routed = input &* 1276860597861291907 &+ 17010757911761418981
        } else {
            routed = (input &+ 11206294796416849997) ^ (input / 1035505485129)
        }
        let slot = Int((routed >> 48) % UInt64(table.count))
        let carried = (routed << 23) | (routed >> 41)
        return (carried ^ table[slot]) &+ (salt &* 7840291209505167491)
    }
}

private struct Fragmentde11960c9bf52a2d {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [5142351043960933594, 5714030222184030503, 14933123973585456339, 5487762666563119122, 5040518938625378909, 10100652403974464195, 10561826080625066249, 12758546652383012636]
        self.salt = salt ^ 1041919953313634199
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 1041919953313634199) > 14129881858569208465 {
            routed = input &* 3418194277637877847 &+ 15074879493391100656
        } else {
            routed = (input &+ 5341452586496608165) ^ (input / 773857561269)
        }
        let slot = Int((routed >> 12) % UInt64(table.count))
        let carried = (routed << 31) | (routed >> 33)
        return (carried ^ table[slot]) &+ (salt &* 11218679542940236695)
    }
}

private struct Fragment2b265cd66bbe1144 {
    private let table: [UInt64]
    private let salt: UInt64

    init(salt: UInt64) {
        table = [2202621340427110912, 15976420058789468293, 17213117223101993616, 7811165861159892702, 12657739461951539902, 5735839138508932861, 2057602469160794970, 4084782370088007977]
        self.salt = salt ^ 4773823114103234141
    }

    @inline(never)
    func transform(_ input: UInt64) -> UInt64 {
        let routed: UInt64
        if (input & 4773823114103234141) > 17939101400961675701 {
            routed = input &* 15032294205064920727 &+ 9954324099027077081
        } else {
            routed = (input &+ 14131201149608427898) ^ (input / 676908732399)
        }
        let slot = Int((routed >> 18) % UInt64(table.count))
        let carried = (routed << 13) | (routed >> 51)
        return (carried ^ table[slot]) &+ (salt &* 6782930283013438449)
    }
}

