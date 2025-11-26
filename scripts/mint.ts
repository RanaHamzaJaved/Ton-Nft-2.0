import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("0QCs9ZcTeqNeR16dwfCWQDab60raCdY3iOZLee_lXFdT0qnD");
    const nftCollection = provider.open(NftCollection.fromAddress(collectionAddress));

    await nftCollection.send(
        provider.sender(),
        {
            value: toNano("0.08"),
        },
        "Mint",
    );
    console.log(`✅ Minted NFT`);
    }