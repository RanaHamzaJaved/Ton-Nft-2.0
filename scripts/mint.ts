import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("EQBdxhd5i0ZrDkpanRypsusESwWaKhq_d8Qv0LJZ1h2kbOjy"); // replace with deployed address
    const nftCollection = provider.open(NftCollection.fromAddress(collectionAddress));

    await nftCollection.send(
            provider.sender(),
            { value: toNano("0.09") },
            { $$type: "Mint" }
        );
    console.log(`✅ Minted NFT`);
    }
