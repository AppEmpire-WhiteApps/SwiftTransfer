// Generated source diversification entry point. Regenerate from a clean clone.
internal struct PremiumKitNoise1478e59a42e4b865 {
    private let seed: UInt64

    init(seed: UInt64) {
        self.seed = seed
    }

    @inline(never)
    func digest() -> UInt64 {
        var state = seed
        state = Transformabff0e7fb97aab12.mix(state ^ 2577962524039381100)
        state = Transforma8a7297e34799a15.mix(state ^ 7739281563430335111)
        state = Transformce729bb012148d05.mix(state ^ 16443320647890197172)
        state = Transform54188398fd07ff4e.mix(state ^ 3525487910570675692)
        state = Transforma06f9657e2cb177b.mix(state ^ 11000217757792881906)
        state = Transform091e4e0fac2b4b6f.mix(state ^ 13857968453241570885)
        state = Transformbc33abc5e54bbd1c.mix(state ^ 2653590165953031762)
        state = Transform92755304f457d54a.mix(state ^ 1920971240056331836)
        state = Transformafcc386d4fdddc3a.mix(state ^ 17953622988160916535)
        state = Transform3e138775f57a23a4.mix(state ^ 6774411057680040481)
        state = Transform72f08a1901d8b6da.mix(state ^ 13562665950627628002)
        state = Transform05bb52bfa85c9aae.mix(state ^ 6253956025390357997)
        return state
    }
}
