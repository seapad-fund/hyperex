module hyperex::dao_storage {
    use hyperex::global_config;
    use sui::coin::Coin;
    use sui::object::UID;
    use sui::tx_context::{TxContext, sender};
    use sui::object;
    use sui::coin;
    use sui::event;
    use sui::transfer::share_object;
    use hyperex::coin_helper;
    use sui::dynamic_field;
    use hyperex::global_config::GlobalConfig;

    friend hyperex::liquidity_pool;

    // Error codes.

    /// When storage doesn't exists
    const ERR_NOT_REGISTERED: u64 = 401;

    /// When invalid DAO admin account
    const ERR_NOT_ADMIN_ACCOUNT: u64 = 402;

    /// Should never occur.
    const ERR_UNREACHABLE: u64 = 403;


    // Public functions.

    /// Storage for keeping coins
    struct Storage<phantom X, phantom Y, phantom Curve> has key, store {
        id: UID,
        coin_x: Coin<X>,
        coin_y: Coin<Y>
    }

    struct Storages has key, store {
        id: UID
    }

    /// Initializes admin contracts when initializing the liquidity pool.
    public(friend) fun initialize(dex_admin: address, ctx: &mut TxContext) {
        assert!(dex_admin == @dex_admin, ERR_UNREACHABLE);
        share_object(Storages {
            id: object::new(ctx)
        });
    }

    public fun getDao<X, Y, Curve>(daos: &mut Storages): &mut Storage<X, Y, Curve>{
        let name = coin_helper::genPoolName<X, Y, Curve>();
        assert!(dynamic_field::exists_<vector<u8>>(&mut daos.id, name), ERR_NOT_REGISTERED);
        dynamic_field::borrow_mut<vector<u8>, Storage<X, Y, Curve>>(&mut daos.id, name)
    }


    /// Register storage
    /// Parameters:
    /// * `owner` - owner of storage
    public(friend) fun register<X, Y, Curve>(daos: &mut Storages, ctx: &mut TxContext){
        let dao = Storage<X, Y, Curve> {
            id : object::new(ctx),
            coin_x: coin::zero<X>(ctx),
            coin_y: coin::zero<Y>(ctx)
        };
        dynamic_field::add(&mut daos.id, coin_helper::genPoolName<X, Y, Curve>(), dao);
        event::emit(StorageCreatedEvent<X, Y, Curve> {});
    }

    /// Deposit coins to storage from liquidity pool
    /// Parameters:
    /// * `pool_addr` - pool owner address
    /// * `coin_x` - X coin to deposit
    /// * `coin_y` - Y coin to deposit
    public(friend) fun deposit<X, Y, Curve>(storage: &mut Storage<X, Y, Curve>, coin_x: Coin<X>, coin_y: Coin<Y>) {
        let x_val = coin::value(&coin_x);
        let y_val = coin::value(&coin_y);
        coin::join(&mut storage.coin_x, coin_x);
        coin::join(&mut storage.coin_y, coin_y);

        event::emit(CoinDepositedEvent<X, Y, Curve> { x_val, y_val });
    }

    /// Withdraw coins from storage
    /// Parameters:
    /// * `dao_admin_acc` - DAO admin
    /// * `pool_addr` - pool owner address
    /// * `x_val` - amount of X coins to withdraw
    /// * `y_val` - amount of Y coins to withdraw
    /// Returns both withdrawn X and Y coins: `(Coin<X>, Coin<Y>)`.
    public fun withdraw<X, Y, Curve>(x_val: u64, y_val: u64, config: &GlobalConfig, storage: &mut Storage<X, Y, Curve>,ctx: &mut TxContext): (Coin<X>, Coin<Y>)
    {
        assert!(sender(ctx) == global_config::get_dao_admin(config), ERR_NOT_ADMIN_ACCOUNT);
        let coin_x = coin::split(&mut storage.coin_x, x_val, ctx);
        let coin_y = coin::split(&mut storage.coin_y, y_val, ctx);
        event::emit(CoinWithdrawnEvent<X, Y, Curve> { x_val, y_val });
        (coin_x, coin_y)
    }

    #[test_only]
    public fun get_storage_size<X, Y, Curve>(storage: &mut Storage<X, Y, Curve>): (u64, u64) {
        let x_val = coin::value(&storage.coin_x);
        let y_val = coin::value(&storage.coin_y);
        (x_val, y_val)
    }

    #[test_only]
    public fun register_for_test<X, Y, Curve>(storages: &mut Storages, ctx: &mut TxContext) {
        register<X, Y, Curve>(storages, ctx);
    }

    #[test_only]
    public fun deposit_for_test<X, Y, Curve>(
        storage: &mut Storage<X, Y, Curve>,
        coin_x: Coin<X>,
        coin_y: Coin<Y>
    ) {
        deposit<X, Y, Curve>(storage, coin_x, coin_y);
    }

    // Events

    struct StorageCreatedEvent<phantom X, phantom Y, phantom Curve> has store, drop, copy {}

    struct CoinDepositedEvent<phantom X, phantom Y, phantom Curve> has store, drop, copy  {
        x_val: u64,
        y_val: u64,
    }

    struct CoinWithdrawnEvent<phantom X, phantom Y, phantom Curve> has store, drop, copy {
        x_val: u64,
        y_val: u64,
    }
}
