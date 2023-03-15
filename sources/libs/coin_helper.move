/// The `CoinHelper` module contains helper funcs to work with `AptosFramework::Coin` module.
module hyperex::coin_helper {
    use std::string::{Self, String};

    use hyperex::curves::is_stable;
    use hyperex::math;
    use std::vector;
    use std::type_name;
    use sui::coin;
    use hyperex::comparator::Result;
    use hyperex::comparator;
    use sui::coin::{CoinMetadata, TreasuryCap};
    use sui::balance;
    use hyperex::pool_coin;

    // Errors codes.

    /// When both coins have same names and can't be ordered.
    const ERR_CANNOT_BE_THE_SAME_COIN: u64 = 3000;

    /// When provided CoinType is not a coin.
    const ERR_IS_NOT_COIN: u64 = 3001;

    // Constants.
    /// Length of symbol prefix to be used in LP coin symbol.
    const SYMBOL_PREFIX_LENGTH: u64 = 4;


    /// Compare two coins, `X` and `Y`, using names.
    /// Caller should call this function to determine the order of X, Y.
    public fun compare<X, Y>(): Result {
        let x = std::ascii::as_bytes(&type_name::into_string(type_name::get<X>()));
        let y = std::ascii::as_bytes(&type_name::into_string(type_name::get<X>()));
        comparator::compare(x, y)
    }

    /// Check that coins generics `X`, `Y` are sorted in correct ordering.
    /// X != Y && X.symbol < Y.symbol
    public fun is_sorted<X, Y>(): bool {
        let order = compare<X, Y>();
        assert!(!comparator::is_equal(&order), ERR_CANNOT_BE_THE_SAME_COIN);
        comparator::is_smaller_than(&order)
    }

    /// Get supply for `CoinType`.
    /// Would throw error if supply for `CoinType` doesn't exist.
    public fun supply<CoinType>(treasury: &mut TreasuryCap<CoinType>): u64 {
        balance::supply_value(coin::supply(treasury))
    }

    /// Get supply for `CoinType`. Coin is Poolcoin
    public fun supply_poolcoin<CoinType>(treasury: &mut pool_coin::TreasuryCap<CoinType>): u64 {
        balance::supply_value(pool_coin::supply(treasury))
    }
    /// Generate LP coin name and symbol for pair `X`/`Y` and curve `Curve`.
    /// ```
    ///
    /// (curve_name, curve_symbol) = when(curve) {
    ///     is Uncorrelated -> (""(no symbol), "-U")
    ///     is Stable -> ("*", "-S")
    /// }
    /// name = "LiquidLP-" + symbol<X>() + "-" + symbol<Y>() + curve_name;
    /// symbol = symbol<X>()[0:4] + "-" + symbol<Y>()[0:4] + curve_symbol;
    /// ```
    /// For example, for `LP<BTC, USDT, Uncorrelated>`,
    /// the result will be `(b"LiquidLP-BTC-USDT+", b"BTC-USDT+")`
    public fun generate_lp_name_and_symbol<X, Y, Curve>(metaX: &CoinMetadata<X>, metaY: &CoinMetadata<Y>): (String, String) {
        let lp_name = string::utf8(b"");
        string::append_utf8(&mut lp_name, b"LiquidLP-");
        string::append(&mut lp_name, string::from_ascii(coin::get_symbol(metaX)));
        string::append_utf8(&mut lp_name, b"-");
        string::append(&mut lp_name, string::from_ascii(coin::get_symbol(metaY)));

        let lp_symbol = string::utf8(b"");
        string::append(&mut lp_symbol, coin_symbol_prefix<X>(metaX));
        string::append_utf8(&mut lp_symbol, b"-");
        string::append(&mut lp_symbol, coin_symbol_prefix<Y>(metaY));

        let (curve_name, curve_symbol) = if (is_stable<Curve>()) (b"-S", b"*") else (b"-U", b"");
        string::append_utf8(&mut lp_name, curve_name);
        string::append_utf8(&mut lp_symbol, curve_symbol);

        (lp_name, lp_symbol)
    }

    fun coin_symbol_prefix<CoinType>(meta: &CoinMetadata<CoinType>): String {
        let symbol = string::from_ascii(coin::get_symbol(meta));
        let prefix_length = math::min_u64(string::length(&symbol), SYMBOL_PREFIX_LENGTH);
        string::sub_string(&symbol, 0, prefix_length)
    }

    ///@todo review performance ? gas
    public fun genPoolName<X, Y, Curve>(): vector<u8>{
        let x = std::ascii::as_bytes(&type_name::into_string(type_name::get<X>()));
        let y = std::ascii::as_bytes(&type_name::into_string(type_name::get<Y>()));
        let curve = std::ascii::as_bytes(&type_name::into_string(type_name::get<Curve>()));
        let name = vector::empty<u8>();
        vector::append(&mut name, *x);
        vector::append(&mut name, *y);
        vector::append(&mut name, *curve);
        name
    }

    #[test]
    fun testGenPoolName(){
        //@todo
    }
}
