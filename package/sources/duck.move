module goose_bumps::duck {
    use std::option::Option;
    use std::string::String;
    use std::ascii::AsciiString;

    use goose_bumps::coin::{self, Coin, TreasuryCap, CoinMetadata};
    use goose_bumps::transfer;
    use goose_bumps::tx_context::TxContext;
    use goose_bumps::url;
    use goose_bumps::object::{self, UID};
    use goose_bumps::clock::{self, Clock};
    use goose_bumps::math64;

    friend goose_bumps::pond;

    struct DUCK {
        // Duck structure definition
    }

    struct DuckManager {
        id: UID,
        cap: TreasuryCap<DUCK>,
        reserve: u64,
        publish_timestamp: u64,
        average_start_time: u64,
        target_average_age: u64,
        adjustment_period_ms: u64,
        last_period_adjusted: u64,
        adjustment_mul: u64,
        min_accrual_param: u64,
        accrual_param: u64,
    } 

    fun init(
        otw: DUCK, 
        ctx: &mut TxContext
    ) {
        let (cap, metadata) = coin::create_currency(
            otw, 
            9, 
            b"DUCK", 
            b"Duck", 
            b"BUCK with a boosted yield that gives you goose bumps",  
            Option::Some(url::Url::new_unsafe_from_bytes(b"https://twitter.com/goosebumps_farm/photo")),
            ctx
        );

        transfer::public_share_object(metadata);
        
        transfer::share_object(DuckManager {
            id: object::new(ctx),
            cap,
            reserve: 0,
            publish_timestamp: 0,
            average_start_time: 0,
            target_average_age: 0,
            adjustment_period_ms: 0,
            last_period_adjusted: 0,
            adjustment_mul: 0,
            min_accrual_param: 0,
            accrual_param: 0,
        });
    }

    // TODO: admin only + guard
    // called only once
    fun init_duck_manager(
        manager: &mut DuckManager,
        clock: &Clock, 
        target_average_age: u64,
        adjustment_period_ms: u64,
        adjustment_mul: u64,
        min_accrual_param: u64
    ) {
        manager.publish_timestamp = clock.timestamp_ms();
        manager.target_average_age = target_average_age;
        manager.adjustment_period_ms = adjustment_period_ms;
        manager.adjustment_mul = adjustment_mul;
        manager.min_accrual_param = min_accrual_param;
    }

    // === Friend functions ===

    public(friend) fun supply(
        manager: &DuckManager
    ) -> u64 {
        coin::total_supply(&manager.cap)
    }

    public(friend) fun cap(
        manager: &mut DuckManager
    ) -> &mut TreasuryCap<DUCK> {
        &mut manager.cap
    }

    public(friend) fun mint(
        treasury_cap: &mut TreasuryCap<DUCK>, 
        amount: u64, 
        ctx: &mut TxContext
    ) -> Coin<DUCK> {
        coin::mint(treasury_cap, amount, ctx)
    }

    public(friend) fun burn(
        treasury_cap: &mut TreasuryCap<DUCK>, 
        coin: Coin<DUCK>
    ) {
        coin::burn(treasury_cap, coin);
    }

    public(friend) fun current_period(manager: &DuckManager, clock: &Clock) -> u64 {
        let duration = clock.timestamp_ms() - manager.publish_timestamp;
        duration / manager.adjustment_period_ms
    }

    public(friend) fun handle_accrual_param(manager: &mut DuckManager, clock: &Clock) -> u64 {
        // accrual param can't go lower than minimum
        if manager.accrual_param == manager.min_accrual_param {
            return manager.accrual_param;
        }
        
        let current_period = current_period(manager, clock);
        if current_period > manager.last_period_adjusted {
            let target_adjustment_period = math64::div_up(
                manager.average_start_time + manager.target_average_age - manager.publish_timestamp,
                manager.adjustment_period_ms
            );
            // adjustment period not reached
            if current_period < target_adjustment_period {
                return manager.accrual_param;
            }
            // how many times accrual param should be adjusted
            let adjustments = current_period - target_adjustment_period;
            let adjusted_accrual_param 
                = manager.accrual_param * math64::pow(manager.adjustment_mul, adjustments);
            // accrual param can't go lower than minimum
            if adjusted_accrual_param > manager.min_accrual_param {
                manager.accrual_param = adjusted_accrual_param;
            }
        }

        manager.last_period_adjusted = current_period;
        manager.accrual_param
    }

    // === Admin only ===

    // TODO: add admin cap
    fun update_name(
        manager: &DuckManager, 
        metadata: &mut CoinMetadata<DUCK>, 
        name: String
    ) {
        coin::update_name(&manager.cap, metadata, name);
    }
    fun update_symbol(
        manager: &DuckManager, 
        metadata: &mut CoinMetadata<DUCK>, 
        name: AsciiString
    ) {
        coin::update_symbol(&manager.cap, metadata, name);
    }
    fun update_description(
        manager: &DuckManager, 
        metadata: &mut CoinMetadata<DUCK>, 
        description: String
    ) {
        coin::update_description(&manager.cap, metadata, description);
    }
    fun update_icon_url(
        manager: &DuckManager, 
        metadata: &mut CoinMetadata<DUCK>, 
        icon_url: AsciiString
    ) {
        coin::update_icon_url(&manager.cap, metadata, icon_url);
    }

    // === Test functions ===

    #[test_only]
    friend goose_bumps::bucket_tank_tests;

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(DUCK {}, ctx);
    }

    #[test_only]
    public fun init_manager_for_testing(
        manager: &mut DuckManager,
        clock: &Clock, 
        target_average_age: u64,
        adjustment_period_ms: u64,
        adjustment_mul: u64,
        min_accrual_param: u64
    ) {
        init_duck_manager(
            manager,
            clock,
            target_average_age,
            adjustment_period_ms,
            adjustment_mul,
            min_accrual_param
        );
    }
}
