import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test flexible energy listing workflow with metrics",
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
        
        // List energy for sale with 100 block duration
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'list-energy', [
                types.uint(500),
                types.uint(10),
                types.uint(100)
            ], seller.address)
        ]);
        const listingId = block.receipts[0].result.expectOk();
        
        // Buy energy
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'buy-energy', [
                types.principal(seller.address),
                listingId,
                types.uint(200)
            ], buyer.address)
        ]);
        block.receipts[0].result.expectOk();
        
        // Check trading metrics
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'get-user-metrics', [
                types.principal(seller.address)
            ], seller.address)
        ]);
        const sellerMetrics = block.receipts[0].result.expectSome();
        assertEquals(sellerMetrics['total-sold'], types.uint(200));
        
        // Cancel remaining listing
        block = chain.mineBlock([
            Tx.contractCall('energy-market', 'cancel-listing', [
                listingId
            ], seller.address)
        ]);
        block.receipts[0].result.expectOk();
    }
});
