/// The current module contains pre-deplopyed scripts v2 for LiquidSwap.
module hyperex::scripts {
    use hyperex::router;
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Coin, CoinMetadata};
    use sui::transfer::transfer;
    use hyperex::global_config::GlobalConfig;
    use hyperex::liquidity_pool::{Pools, LiquidityPool};
    use hyperex::dao_storage::{Storages, Storage};
    use hyperex::lp_coin::LP;
    use hyperex::lp_coin;
    use hyperex::pool_coin;

    /// Register a new liquidity pool for `X`/`Y` pair.
    ///
    /// Note: X, Y generic coin parameters must be sorted.
    public entry fun register_pool<X, Y, Curve>(config: &GlobalConfig,
                                                pools: &mut Pools,
                                                daos: &mut Storages,
                                                metaX: &CoinMetadata<X>,
                                                metaY: &CoinMetadata<Y>,
                                                ctx: &mut TxContext) {
        let witness =  lp_coin::createWitness<X, Y, Curve>();
        router::register_pool<X, Y, Curve>(witness, config, pools, daos, metaX, metaY, ctx);
    }

    /// Register a new liquidity pool `X`/`Y` and immediately add liquidity.
    /// * `coin_x_val` - amount of coin `X` to add as liquidity.
    /// * `coin_x_val_min` - minimum amount of coin `X` to add as liquidity (slippage).
    /// * `coin_y_val` - minimum amount of coin `Y` to add as liquidity.
    /// * `coin_y_val_min` - minimum amount of coin `Y` to add as liquidity (slippage).
    ///
    /// Note: X, Y generic coin parameters must be sorted.
    public entry fun register_pool_and_add_liquidity<X, Y, Curve>(
        coin_x: Coin<X>,
        coin_x_val_min: u64,
        coin_y: Coin<Y>,
        coin_y_val_min: u64,

        config: &GlobalConfig,
        pools: &mut Pools,
        daos: &mut Storages,
        metaX: &CoinMetadata<X>,
        metaY: &CoinMetadata<Y>,
        timestamp_ms: u64,
        ctx: &mut TxContext
    ) {
        let witness = lp_coin::createWitness<X, Y, Curve>();
        router::register_pool<X, Y, Curve>(witness, config, pools, daos, metaX, metaY, ctx);
        add_liquidity<X, Y, Curve>(
            coin_x,
            coin_x_val_min,
            coin_y,
            coin_y_val_min,
            timestamp_ms,
            config,
            pools,
            ctx
        );
    }

    /// Add new liquidity into pool `X`/`Y` and get liquidity coin `LP`.
    /// * `coin_x_val` - amount of coin `X` to add as liquidity.
    /// * `coin_x_val_min` - minimum amount of coin `X` to add as liquidity (slippage).
    /// * `coin_y_val` - minimum amount of coin `Y` to add as liquidity.
    /// * `coin_y_val_min` - minimum amount of coin `Y` to add as liquidity (slippage).
    ///
    /// Note: X, Y generic coin parameters must be sorted.
    /// @fixme because clock is not available, use timestamp!
    public entry fun add_liquidity<X, Y, Curve>(
        coin_x: Coin<X>,
        coin_x_val_min: u64,
        coin_y: Coin<Y>,
        coin_y_val_min: u64,
        timestamp_ms: u64,
        config: &GlobalConfig,
        pools: &mut Pools,
        ctx: &mut TxContext
    ) {

        let (coin_x_remainder, coin_y_remainder, lp_coins) = router::add_liquidity<X, Y, Curve>(
                coin_x,
                coin_x_val_min,
                coin_y,
                coin_y_val_min,
                timestamp_ms,
                config,
                pools,
                ctx
            );

        let account_addr = sender(ctx);

        transfer(coin_x_remainder, account_addr);
        transfer(coin_y_remainder, account_addr);
        transfer(lp_coins, account_addr);
    }

    /// Remove (burn) liquidity coins `LP` from account, get `X` and`Y` coins back.
    /// * `lp_coins` - amount of `LP` coins to burn.
    /// * `min_x_out_val` - minimum amount of X coins to get.
    /// * `min_y_out_val` - minimum amount of Y coins to get.
    ///
    /// Note: X, Y generic coin parameters must be sorted.
    public entry fun remove_liquidity<X, Y, Curve>(
        lp_coins: pool_coin::Coin<LP<X, Y, Curve>>,
        min_x_out_val: u64,
        min_y_out_val: u64,

        pools: &mut Pools,
        timestamp_ms: u64,
        ctx: &mut TxContext
    ) {
        let (coin_x, coin_y) = router::remove_liquidity<X, Y, Curve>(
            lp_coins,
            min_x_out_val,
            min_y_out_val,
            pools,
            timestamp_ms,
            ctx
        );

        let account_addr = sender(ctx);
        transfer(coin_x, account_addr);
        transfer(coin_y, account_addr);
    }

    /// Swap exact coin `X` for at least minimum coin `Y`.
    /// * `coin_x` - amount of coins `X` to swap.
    /// * `coin_out_min_val` - minimum expected amount of coins `Y` to get.
    /// @fixme timestamp due to clock is unavailable
    public entry fun swap<X, Y, Curve>(
        coin_x: Coin<X>,
        coin_out_min_val: u64,
        timestamp_ms: u64,
        config: &GlobalConfig,
        pools: &mut Pools,
        daos: &mut Storages,
        ctx: &mut TxContext
    ) {
        let coin_y = router::swap_exact_coin_for_coin<X, Y, Curve>(
            coin_x,
            coin_out_min_val,
            timestamp_ms,
            config,
            pools,
            daos,
            ctx
        );

        let account_addr = sender(ctx);
        transfer(coin_y, account_addr);
    }

    /// Swap maximum coin `X` for exact coin `Y`.
    /// * `coin_x_max` - how much of coins `X` can be used to get `Y` coin.
    /// * `coin_out` - how much of coins `Y` should be returned.
    public entry fun swap_into<X, Y, Curve>(
        coin_x_max: Coin<X>,
        coin_out: u64,
        timestamp_ms: u64,
        config: &GlobalConfig,
        pools: &mut Pools,
        daos: &mut Storages,
        ctx: &mut TxContext
    ) {
        let (coin_x, coin_y) = router::swap_coin_for_exact_coin<X, Y, Curve>(
            coin_x_max,
            coin_out,
            timestamp_ms,
            config,
            pools,
            daos,
            ctx
        );

        let account_addr = sender(ctx);
        transfer(coin_x, account_addr);
        transfer(coin_y, account_addr);
    }

    /// Swap `coin_in` of X for a `coin_out` of Y.
    /// Does not check optimality of the swap, and fails if the `X` to `Y` price ratio cannot be satisfied.
    /// * `coin_in` - how much of coins `X` to swap.
    /// * `coin_out` - how much of coins `Y` should be returned.
    public entry fun swap_unchecked<X, Y, Curve>(
        coin_in: Coin<X>,
        coin_out: u64,
        timestamp_ms: u64,
        config: &GlobalConfig,
        pools: &mut Pools,
        daos: &mut Storages,
        ctx: &mut TxContext
    ) {
        let coin_y = router::swap_coin_for_coin_unchecked<X, Y, Curve>(coin_in,
            coin_out,
            timestamp_ms,
            config,
            pools,
            daos,
            ctx);
        let account_addr = sender(ctx);
        transfer(coin_y, account_addr);
    }
}
