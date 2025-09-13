module MyModule::SimpleDEX {
    use aptos_framework::signer;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;

    /// Struct representing a liquidity pool for token pairs
    struct LiquidityPool has store, key {
        token_a_reserve: u64,  // Reserve amount of token A (AptosCoin)
        token_b_reserve: u64,  // Reserve amount of token B (represented as AptosCoin for simplicity)
        total_liquidity: u64,  // Total liquidity tokens issued
    }

    /// Error codes
    const EPOOL_NOT_EXISTS: u64 = 1;
    const EINSUFFICIENT_LIQUIDITY: u64 = 2;
    const EINVALID_AMOUNT: u64 = 3;

    /// Function to add liquidity to the DEX pool
    public fun add_liquidity(
        provider: &signer,
        pool_signer: &signer,
        amount_a: u64,
        amount_b: u64
    ) acquires LiquidityPool {
        let pool_address = signer::address_of(pool_signer);
        
        // Check if pool exists, if not create it
        if (!exists<LiquidityPool>(pool_address)) {
            let pool = LiquidityPool {
                token_a_reserve: 0,
                token_b_reserve: 0,
                total_liquidity: 0,
            };
            move_to(pool_signer, pool);
        };

        let pool = borrow_global_mut<LiquidityPool>(pool_address);
        
        // Transfer tokens from provider to pool
        let tokens_a = coin::withdraw<AptosCoin>(provider, amount_a);
        let tokens_b = coin::withdraw<AptosCoin>(provider, amount_b);
        
        coin::deposit<AptosCoin>(pool_address, tokens_a);
        coin::deposit<AptosCoin>(pool_address, tokens_b);

        // Update pool reserves
        pool.token_a_reserve = pool.token_a_reserve + amount_a;
        pool.token_b_reserve = pool.token_b_reserve + amount_b;
        pool.total_liquidity = pool.total_liquidity + amount_a + amount_b;
    }

    /// Function to swap tokens in the DEX
    public fun swap_tokens(
        trader: &signer,
        pool_signer: &signer,
        amount_in: u64,
        is_a_to_b: bool
    ) acquires LiquidityPool {
        let pool_address = signer::address_of(pool_signer);
        assert!(exists<LiquidityPool>(pool_address), EPOOL_NOT_EXISTS);
        assert!(amount_in > 0, EINVALID_AMOUNT);

        let pool = borrow_global_mut<LiquidityPool>(pool_address);
        
        // Simple constant product formula: x * y = k
        let amount_out = if (is_a_to_b) {
            assert!(pool.token_b_reserve > 0, EINSUFFICIENT_LIQUIDITY);
            (amount_in * pool.token_b_reserve) / (pool.token_a_reserve + amount_in)
        } else {
            assert!(pool.token_a_reserve > 0, EINSUFFICIENT_LIQUIDITY);
            (amount_in * pool.token_a_reserve) / (pool.token_b_reserve + amount_in)
        };

        // Execute the swap - trader gives input tokens to pool
        let input_tokens = coin::withdraw<AptosCoin>(trader, amount_in);
        coin::deposit<AptosCoin>(pool_address, input_tokens);

        // Pool gives output tokens to trader
        let output_tokens = coin::withdraw<AptosCoin>(pool_signer, amount_out);
        coin::deposit<AptosCoin>(signer::address_of(trader), output_tokens);

        // Update reserves
        if (is_a_to_b) {
            pool.token_a_reserve = pool.token_a_reserve + amount_in;
            pool.token_b_reserve = pool.token_b_reserve - amount_out;
        } else {
            pool.token_b_reserve = pool.token_b_reserve + amount_in;
            pool.token_a_reserve = pool.token_a_reserve - amount_out;
        };
    }
}
