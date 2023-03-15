/// Liquidswap LP coin.
module hyperex::lp_coin {
    /// LP coin type for Liquidswap.
    struct LP<phantom X, phantom Y, phantom Curve> has drop {}

    ///@fixme: how to make sure witness ?
    public fun createWitness<X, Y, Curve>(): LP<X, Y, Curve> {
        LP<X, Y, Curve>{}
    }
}
