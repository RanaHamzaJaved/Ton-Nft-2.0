import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { RaffleCollection } from '../../build/NftTest/NftTest_RaffleCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("EQDtRhuU8-1bnUis7OJoeM5RQVePl8ZtUoT1_E-vcdLhwWKg");
    const nftCollection = provider.open(RaffleCollection.fromAddress(collectionAddress));

    await nftCollection.send(
        provider.sender(),
        {
            value: toNano("0.02"),
        },
        "EnterRaffle",
    );
    console.log(`✅ Minted NFT`);
    
}
