import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("EQCiBRK88EsFNAZf1J2fEHHql8NeYemKdqPpQROvPk0Qqdvz"); // replace with deployed address
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