import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("kQB3jCnFIuS36RQFeI5aAoULmvWSL0VMCOHAr6zmIWKy9MrZ"); // replace with deployed address
    const nftCollection = provider.open(NftCollection.fromAddress(collectionAddress));

    // for (let i = 0; i < 3; i++) {
        await nftCollection.send(
            provider.sender(),
            { value: toNano('0.05') },
             "Mint"
        );
        console.log(`✅ Minted NFT `);
    // }
}
