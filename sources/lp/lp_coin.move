/// Liquidswap LP coin.
module hyperex::lp_coin {
    use sui::tx_context::TxContext;
    use sui::object::UID;
    use sui::object;
    use sui::transfer::share_object;
    use hyperex::utils::genPoolName;
    use sui::dynamic_field;

    const ERR_WITNESS_VIOLATION: u64 = 700;

    /// LP coin type for Liquidswap.
    struct LP<phantom X, phantom Y, phantom Curve> has drop {}

    struct WitnessRegistry has key, store{
        id: UID,
    }

    ///@fixme: how to make sure witness ?
    ///
    public fun createOneTimeWitness<X, Y, Curve>(witnessReg: &mut WitnessRegistry): LP<X, Y, Curve> {
        let key = genPoolName<X, Y, Curve>();
        assert!(!dynamic_field::exists_<vector<u8>>(&witnessReg.id, key), ERR_WITNESS_VIOLATION);
        dynamic_field::add<vector<u8>, vector<u8>>(&mut witnessReg.id, key, key);
        LP<X, Y, Curve> {}
    }

    ///init the witness registry
    fun init(ctx: &mut TxContext){
        share_object(WitnessRegistry {
            id: object::new(ctx)
        });
    }

    #[test_only]
    public fun initializeForTesting(ctx: &mut TxContext){
        init(ctx);
    }
}


#[test_only]
module hyperex::lp_coin_test {

    use sui::test_scenario::Scenario;
    use sui::test_scenario;
    use hyperex::lp_coin;
    use hyperex::lp_coin::{WitnessRegistry, createOneTimeWitness};

    struct BTC {}
    struct ETH {}
    struct Stable {}

    fun scenario(): Scenario { test_scenario::begin(@0xC0FFEE) }

    #[test]
    fun test_create_witness_mustbe_success(){
        let scenario_val = scenario();
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, @0xC0FFEE);
            {
                let ctx = test_scenario::ctx(scenario);
                lp_coin::initializeForTesting(ctx);
            };

        test_scenario::next_tx(scenario, @0xC0FFEE);
            {
                let registry = test_scenario::take_shared<WitnessRegistry>(scenario);
                let _witness = createOneTimeWitness<BTC, ETH, Stable>(&mut registry);
                test_scenario::return_shared(registry);
            };
        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = hyperex::lp_coin::ERR_WITNESS_VIOLATION)]
    fun test_create_witness_mustbe_failed(){
        let scenario_val = scenario();
        let scenario = &mut scenario_val;

        test_scenario::next_tx(scenario, @0xC0FFEE);
            {
                let ctx = test_scenario::ctx(scenario);
                lp_coin::initializeForTesting(ctx);
            };

        test_scenario::next_tx(scenario, @0xC0FFEE);
            {
                let registry = test_scenario::take_shared<WitnessRegistry>(scenario);
                let _witness1 = createOneTimeWitness<BTC, ETH, Stable>(&mut registry);
                let _witness2 = createOneTimeWitness<BTC, ETH, Stable>(&mut registry);
                test_scenario::return_shared(registry);
            };
        test_scenario::end(scenario_val);
    }
}