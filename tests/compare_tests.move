module 0x22::sui {
    struct SUI has drop {}
}

module 0x22::coins_a {
    struct BTC has drop {}
}

module 0x22::coins_b {
    struct BTC has drop {}
}

#[test_only]
module hyperex::compare_tests {
    use hyperex::coin_helper;
    use test_coin_admin::test_coins::{BTC, USDC, USDT};
    use hyperex::comparator;
    use sui::sui::SUI;

    #[test]
    fun test_coins_equal() {
        assert!(comparator::is_equal(&coin_helper::compare<BTC, BTC>()), 1);
        assert!(comparator::is_equal(&coin_helper::compare<USDC, USDC>()), 2);
        assert!(comparator::is_equal(&coin_helper::compare<USDT, USDT>()), 3);
        assert!(comparator::is_equal(&coin_helper::compare<SUI, SUI>()), 4);
    }

    #[test]
    fun test_coins_compared_with_struct_name_first() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<BTC, USDC>()), 1);
        assert!(comparator::is_smaller_than(&coin_helper::compare<USDC, USDT>()), 2);
        assert!(comparator::is_smaller_than(&coin_helper::compare<SUI, BTC>()), 3);

        assert!(comparator::is_greater_than(&coin_helper::compare<USDC, BTC>()), 4);
        assert!(comparator::is_greater_than(&coin_helper::compare<USDT, USDC>()), 5);
        assert!(comparator::is_greater_than(&coin_helper::compare<USDT, SUI>()), 6);
    }

    #[test]
    fun test_coins_compared_with_module_name_if_struct_name_is_equal() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<0x22::coins_a::BTC, 0x22::coins_b::BTC>()), 1);
        assert!(comparator::is_greater_than(&coin_helper::compare<0x22::coins_b::BTC, 0x22::coins_a::BTC>()), 2);
    }

    #[test]
    fun test_coins_compared_with_address_if_all_others_are_equal() {
        assert!(comparator::is_smaller_than(&coin_helper::compare<SUI, 0x22::sui::SUI>()), 1);
        assert!(comparator::is_greater_than(&coin_helper::compare<0x22::sui::SUI, SUI>()), 1);
    }

    #[test]
    fun test_is_sorted() {
        assert!(coin_helper::is_sorted<SUI, BTC>(), 1);
        assert!(coin_helper::is_sorted<USDC, USDT>(), 2);
        assert!(coin_helper::is_sorted<SUI, 0x22::sui::SUI>(), 3);

        assert!(!coin_helper::is_sorted<BTC, SUI>(), 4);
        assert!(!coin_helper::is_sorted<USDT, USDC>(), 5);
    }

    #[test]
    #[expected_failure(abort_code = hyperex::coin_helper::ERR_CANNOT_BE_THE_SAME_COIN)]
    fun test_is_sorted_cannot_be_equal() {
        assert!(coin_helper::is_sorted<SUI, SUI>(), 1);
    }
}
