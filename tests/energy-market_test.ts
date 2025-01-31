import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test energy listing and trading workflow",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const seller = accounts.get('wallet_1')!;
        const buyer = accounts.get('wallet_2')!;
        
        // Add energy to seller's balance
        let block = chain.mineBlock([
            Tx.contractCall('energy-market', 'add-energy', [
                types.uint(1000)
            ], seller.address)
        ]);
        block.receipts[0].result.expectOk();
        
        // List energy for sale
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'list-energy', [
                types.uint(500),
                types.uint(10)
            ], seller.address)
        ]);
        block.receipts[0].result.expectOk();
        
        // Buy energy
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'buy-energy', [
                types.principal(seller.address),
                types.uint(200)
            ], buyer.address)
        ]);
        block.receipts[0].result.expectOk();
        
        // Check balances
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'get-energy-balance', [
                types.principal(buyer.address)
            ], buyer.address)
        ]);
        block.receipts[0].result.expectSome().assertEquals(types.uint(200));
    }
});
