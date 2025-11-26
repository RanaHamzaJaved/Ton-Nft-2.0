import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const OFFCHAIN_CONTENT_PREFIX = 0x01;

    const baseCollectionURL =
        "https://ipfs.io/ipfs/bafybeic43zx3ondseawdkifbg4hdjkcvqtxtricq7yq43tc22745yf74pu/";
    const collectionContent = beginCell()
        .storeInt(OFFCHAIN_CONTENT_PREFIX, 8)
        .storeStringRefTail(baseCollectionURL)
        .endCell();

    const owner = Address.parse("0QCQWsy_Pc9O9kyTFvC2N_-8OYK8D8vMRHHqF1m27eE4gF0F");

    const royaltyParams = {
        $$type: "RoyaltyParams" as const,
        numerator: 350n,
        denominator: 1000n,
        destination: owner,
    };

    const nftCollection = provider.open(
        await NftCollection.fromInit(owner, collectionContent, royaltyParams, 0n, toNano("0.001"), 0n, 100n, 10n)
    );

    console.log("⏳ Deploying collection...");
    await nftCollection.send(
        provider.sender(),
        {
            value : toNano("0.05")
        },
        {
            $$type: "Deploy",
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(nftCollection.address);
    console.log("✅ Deployed:", nftCollection.address.toString());
    console.log("✅ Now Minting:");

    async function mintNFT(index: number) {
        await nftCollection.send(provider.sender(), { value: toNano("0.08") }, "Mint");
        console.log(`✅ Minted NFT #${index}`);
    }

    // for (let i = 1; i <= 1; i++) {
        await mintNFT(1);
    // }
}