import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("EQD0zX_RM4MOgsq3UPmNETaVwn5g0xQPzHomqSbw3KO2dn6J"); // replace with deployed address
    const nftCollection = provider.open(NftCollection.fromAddress(collectionAddress));

    const res = await nftCollection.send(
        provider.sender(),
        {
            value: toNano("0.12"),
        },
        "Mint",
    );
    console.log(`✅ Minted NFT ${res}`);
    }
