/// The module allows for emergency stop Liquidswap operations.
module liquidswap::emergency {
    use liquidswap::global_config;
    use sui::tx_context::{TxContext, sender};
    use sui::transfer::{transfer, share_object};
    use sui::object;
    use sui::object::UID;
    use liquidswap::global_config::GlobalConfig;

    friend liquidswap::liquidity_pool;

    // Error codes.
    /// When the wrong account attempted to create an emergency resource.
    const ERR_NO_PERMISSIONS: u64 = 4000;

    /// When attempted to execute operation during an emergency.
    const ERR_EMERGENCY: u64 = 4001;

    /// When emergency functional disabled.
    const ERR_DISABLED: u64 = 4002;

    /// When attempted to resume, but we are not in an emergency state.
    const ERR_NOT_EMERGENCY: u64 = 4003;

    /// Should never occur.
    const ERR_UNREACHABLE: u64 = 4004;

    struct IsEmergency has key, store {
        id: UID,
        emergency: bool,
        disabled: bool
    }

    struct EmergencyAccountCapability has key, store {
        id: UID
    }

    ///@fixme review cap owner perm
    public(friend) fun initialize(liquidswap_admin: address, ctx: &mut TxContext) {
        assert!(liquidswap_admin == @liquidswap_admin, ERR_UNREACHABLE);
        share_object(IsEmergency {
            id: object::new(ctx),
            emergency: false,
            disabled: false});
        transfer(EmergencyAccountCapability { id: object::new(ctx)}, liquidswap_admin); //@todo review cap
    }

    /// Pauses all operations.
    public entry fun pause(emergency: &mut IsEmergency,  config: &mut GlobalConfig, ctx: &mut TxContext) {
        assert!(!is_disabled(emergency), ERR_DISABLED);
        assert_no_emergency(emergency);
        assert!(sender(ctx) == global_config::get_emergency_admin(config), ERR_NO_PERMISSIONS); //@todo review cap
        emergency.emergency = true;
    }

    /// Resumes all operations.
    public entry fun resume(emergency: &mut IsEmergency, config: &GlobalConfig, ctx: &mut TxContext) {
        assert!(!is_disabled(emergency), ERR_DISABLED);
        assert!(sender(ctx) == global_config::get_emergency_admin(config), ERR_NO_PERMISSIONS); //@todo review cap
        assert!(is_emergency(emergency), ERR_NOT_EMERGENCY);
        emergency.emergency = false;
    }

    /// Get if it's paused or not.
    public fun is_emergency(emergency: &IsEmergency): bool {
       emergency.emergency
    }

    /// Would abort if currently paused.
    public fun assert_no_emergency(emergency: &IsEmergency) {
        assert!(!is_emergency(emergency), ERR_EMERGENCY);
    }

    /// Get if it's disabled or not.
    public fun is_disabled(emergency: &IsEmergency): bool {
        emergency.disabled
    }

    /// Disable condition forever.
    public entry fun disable_forever(emergency: &mut IsEmergency, config: &mut GlobalConfig,  ctx: &mut TxContext) {
        assert!(!is_disabled(emergency), ERR_DISABLED);
        assert!(sender(ctx) == global_config::get_emergency_admin(config), ERR_NO_PERMISSIONS);
        emergency.disabled = true;
    }
}
