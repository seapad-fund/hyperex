/// The global config for liquidswap: fees and manager accounts (admins).
module hyperex::global_config {
    use hyperex::curves;
    use sui::transfer::{transfer, share_object};
    use sui::object::UID;
    use sui::object;
    use sui::tx_context::{TxContext, sender};
    use sui::event;
    #[test_only]
    use sui::test_scenario;

    friend hyperex::liquidity_pool;

    // Error codes.

    /// When config doesn't exists.
    const ERR_CONFIG_DOES_NOT_EXIST: u64 = 300;

    /// When user is not admin
    const ERR_NOT_ADMIN: u64 = 301;

    /// When invalid fee amount
    const ERR_INVALID_FEE: u64 = 302;

    /// Unreachable, is a bug if thrown
    const ERR_UNREACHABLE: u64 = 303;


    // Error codes.
    /// When the wrong account attempted to create an emergency resource.
    const ERR_NO_PERMISSIONS: u64 = 4000;

    /// When attempted to execute operation during an emergency.
    const ERR_EMERGENCY: u64 = 4001;

    /// When emergency functional disabled.
    const ERR_DISABLED: u64 = 4002;

    /// When attempted to resume, but we are not in an emergency state.
    const ERR_NOT_EMERGENCY: u64 = 4003;

    // Constants.

    /// Minimum value of fee, 0.01%
    const MIN_FEE: u64 = 1;

    /// Maximum value of fee, 1%
    const MAX_FEE: u64 = 100;

    /// Minimum value of dao fee, 0%
    const MIN_DAO_FEE: u64 = 0;

    /// Maximum value of dao fee, 100%
    const MAX_DAO_FEE: u64 = 100;

    /// The global configuration (fees and admin accounts).
    struct GlobalConfig has key, store{
        id: UID,
        dex_admin: address,
        dao_admin_address: address,
        emergency_admin_address: address,
        fee_admin_address: address,
        default_uncorrelated_fee: u64,
        default_stable_fee: u64,
        default_dao_fee: u64,
        emergency: bool,
        disabled: bool
    }

    /// Initializes admin contracts when initializing the liquidity pool.
    public(friend) fun initialize(dex_admin: address, ctx: &mut TxContext) {
        assert!(dex_admin == @dex_admin, ERR_UNREACHABLE);
        share_object(GlobalConfig {
            id: object::new(ctx),
            dex_admin,
            dao_admin_address: @dao_admin,
            emergency_admin_address: @emergency_admin,
            fee_admin_address: @fee_admin,
            default_uncorrelated_fee: 30,   // 0.3%
            default_stable_fee: 4,          // 0.04%
            default_dao_fee: 33,            // 33%
            emergency: false,
            disabled: false
        });
    }

    /// Pauses all operations.
    public entry fun emergency_pause(config: &mut GlobalConfig, ctx: &mut TxContext) {
        assert!(!emergency_is_disabled(config), ERR_DISABLED);
        assert_no_emergency(config);
        assert!(sender(ctx) == get_emergency_admin(config), ERR_NO_PERMISSIONS); //@todo review cap
        config.emergency = true;
    }

    /// Resumes all operations.
    public entry fun emergency_resume(config: &mut GlobalConfig, ctx: &mut TxContext) {
        assert!(!emergency_is_disabled(config), ERR_DISABLED);
        assert!(sender(ctx) == get_emergency_admin(config), ERR_NO_PERMISSIONS); //@todo review cap
        assert!(is_emergency(config), ERR_NOT_EMERGENCY);
        config.emergency = false;
    }

    /// Disable condition forever.
    public entry fun emergency_disable_forever(config: &mut GlobalConfig,  ctx: &mut TxContext) {
        assert!(!emergency_is_disabled(config), ERR_DISABLED);
        assert!(sender(ctx) == get_emergency_admin(config), ERR_NO_PERMISSIONS);
        config.disabled = true;
    }

    /// Get if it's paused or not.
    public fun is_emergency(config: &GlobalConfig): bool {
        config.emergency
    }

    /// Would abort if currently paused.
    public fun assert_no_emergency(config: &GlobalConfig) {
        assert!(!is_emergency(config), ERR_EMERGENCY);
    }

    /// Get if it's disabled or not.
    public fun emergency_is_disabled(config: &GlobalConfig): bool {
        config.disabled
    }


    /// Get DAO admin address.
    public fun get_dao_admin(config: &GlobalConfig): address {
        config.dao_admin_address
    }

    /// Set DAO admin account.
    public entry fun set_dao_admin(config: &mut GlobalConfig, new_addr: address, ctx: &mut TxContext) {
        assert!(config.dao_admin_address == sender(ctx), ERR_NOT_ADMIN);
        config.dao_admin_address = new_addr;
    }

    /// Get emergency admin address.
    public fun get_emergency_admin(config: &GlobalConfig): address {
        config.emergency_admin_address
    }

    /// Set emergency admin account.
    public entry fun set_emergency_admin(config: &mut GlobalConfig, new_addr: address, ctx: &mut TxContext) {
        assert!(config.emergency_admin_address == sender(ctx), ERR_NOT_ADMIN);
        config.emergency_admin_address = new_addr;
    }

    /// Get fee admin address.
    public fun get_fee_admin(config: &GlobalConfig): address {
        config.fee_admin_address
    }

    /// Set fee admin account.
    public entry fun set_fee_admin(config: &mut GlobalConfig, new_addr: address, ctx: &mut TxContext) {
        assert!(config.fee_admin_address == sender(ctx), ERR_NOT_ADMIN);
        config.fee_admin_address = new_addr;
    }

    /// Get default fee for pool.
    /// IMPORTANT: use functions in Liquidity Pool module as pool fees could be different from default ones.
    public fun get_default_fee<Curve>(config: &GlobalConfig): u64 {
        curves::assert_valid_curve<Curve>();

        if (curves::is_stable<Curve>()) {
            config.default_stable_fee
        } else if (curves::is_uncorrelated<Curve>()) {
            config.default_uncorrelated_fee
        } else {
            abort ERR_UNREACHABLE
        }
    }

    /// Set new default fee.
    public entry fun set_default_fee<Curve>(default_fee: u64, config: &mut GlobalConfig, ctx: &mut TxContext) {
        curves::assert_valid_curve<Curve>();

        assert!(config.fee_admin_address == sender(ctx), ERR_NOT_ADMIN);

        assert_valid_fee(default_fee);

        if (curves::is_stable<Curve>()) {
            config.default_stable_fee = default_fee;
            event::emit(
                UpdateDefaultFeeEvent { fee: default_fee }
            );
        } else if (curves::is_uncorrelated<Curve>()) {
            config.default_uncorrelated_fee = default_fee;
            event::emit(
                UpdateDefaultFeeEvent { fee: default_fee }
            );
        } else {
            abort ERR_UNREACHABLE
        };
    }

    /// Get default DAO fee.
    public fun get_default_dao_fee(config: &GlobalConfig): u64 {
        config.default_dao_fee
    }

    /// Set default DAO fee.
    public entry fun set_default_dao_fee(default_fee: u64, config: &mut GlobalConfig, ctx: &mut TxContext) {
        assert!(config.fee_admin_address == sender(ctx), ERR_NOT_ADMIN);
        assert_valid_dao_fee(default_fee);
        config.default_dao_fee = default_fee;
        event::emit(
            UpdateDefaultFeeEvent { fee: default_fee }
        );
    }

    /// Aborts if fee is valid.
    public fun assert_valid_fee(fee: u64) {
        assert!(MIN_FEE <= fee && fee <= MAX_FEE, ERR_INVALID_FEE);
    }

    /// Aborts if dao fee is valid.
    public fun assert_valid_dao_fee(dao_fee: u64) {
        assert!(MIN_DAO_FEE <= dao_fee && dao_fee <= MAX_DAO_FEE, ERR_INVALID_FEE);
    }

    /// Event struct when fee updates.
    struct UpdateDefaultFeeEvent has drop, store, copy {
        fee: u64,
    }

    #[test_only]
    public fun initialize_for_test(ctx: &mut TxContext) {
        //@todo create account for test
//        let liquidswap_admin = aptos_framework::account::create_account_for_test(@liquidswap);
        initialize(@dex_admin, ctx);
    }
}
