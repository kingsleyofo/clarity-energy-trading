import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Ensures input validation for energy listings",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const seller = accounts.get('wallet_1')!;
        
        // Test invalid amount
        let block = chain.mineBlock([
            Tx.contractCall('energy-market', 'list-energy', [
                types.uint(0),  // Invalid amount
                types.uint(10),
                types.uint(100)
            ], seller.address)
        ]);
        block.receipts[0].result.expectErr(types.uint(406));
        
        // Test invalid price
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'list-energy', [
                types.uint(100),
                types.uint(1000000001),  // Invalid price
                types.uint(100)
            ], seller.address)
        ]);
        block.receipts[0].result.expectErr(types.uint(407));
    }
});

[Previous tests remain unchanged...]
