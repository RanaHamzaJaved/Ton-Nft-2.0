import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const OFFCHAIN_CONTENT_PREFIX = 0x01;
    // const string_first = "https://mocki.io/v1/7d8e4449-9981-4120-b143-17096e822c4a"

    const string_first = "https://ipfs.io/ipfs/Qman15mmkvvTL4NuuVwioJhwvQWLWv3LncJAddc7wtvZmD#4984ns-mg0nm4sc"

    const collectionContent = beginCell()
        .storeInt(OFFCHAIN_CONTENT_PREFIX, 8)
        .storeStringRefTail(string_first)
        .endCell();

    const owner = Address.parse("0QCQWsy_Pc9O9kyTFvC2N_-8OYK8D8vMRHHqF1m27eE4gF0F");
    const nextItemIndex = 0n;

    const royaltyParams = {
        $$type: "RoyaltyParams" as const,
        numerator: 350n,         // 35%
        denominator: 1000n,
        destination: owner,
    };

    const nftCollection = provider.open(
        await NftCollection.fromInit(owner, collectionContent, royaltyParams, nextItemIndex)
    );

    await nftCollection.send(
        provider.sender(),
        { value: toNano('0.15') },
        "Mint"
    );

    await provider.waitForDeploy(nftCollection.address);

    console.log('✅ NftCollection deployed and Mint triggered!');
    console.log('📦 Contract Address:', nftCollection.address.toString());
}
