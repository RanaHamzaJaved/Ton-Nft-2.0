import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { RaffleCollection } from '../../build/NftTest/NftTest_RaffleCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("EQDtRhuU8-1bnUis7OJoeM5RQVePl8ZtUoT1_E-vcdLhwWKg");
    const nftCollection = provider.open(RaffleCollection.fromAddress(collectionAddress));
    const owner = provider.sender();
    const randomSeed = BigInt(Date.now());
    const seedCell = beginCell().storeInt(randomSeed, 128).endCell();

    
    await nftCollection.send(owner, { value: toNano("0.2") }, { 
                $$type: "AnnounceWinners",
                seed: seedCell
            });
    console.log("🎉 AnnounceWinners tx sent!");
    
}
