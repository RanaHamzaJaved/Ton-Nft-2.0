import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("EQDXyTILmid8gexv0juEt96kyjL22GdPWj4MFWSrPxr8ME7K");
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
