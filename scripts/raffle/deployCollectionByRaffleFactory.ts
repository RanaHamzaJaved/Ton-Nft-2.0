import { toNano, beginCell, Address, contractAddress, StateInit  } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { RaffleFactory } from "../../build/NftTest/NftTest_RaffleFactory";
import { RaffleCollection } from '../../build/NftTest/NftTest_RaffleCollection';

export async function run(provider: NetworkProvider) {
    const OFFCHAIN_CONTENT_PREFIX = 0x01;

    const factoryAddress = Address.parse(
        "EQB4k6wJq9Hb0D6n5Bk9AEe-mOStF6F2mixwGVF3za3XjMRO"
    );

    const factory = provider.open(RaffleFactory.fromAddress(factoryAddress));

    // -------------------------------
    // Collection off-chain metadata
    // -------------------------------
    const baseCollectionURL =
        "https://ipfs.io/ipfs/bafybeic43zx3ondseawdkifbg4hdjkcvqtxtricq7yq43tc22745yf74pu/";

    const collectionContent = beginCell()
        .storeInt(OFFCHAIN_CONTENT_PREFIX, 8)
        .storeStringRefTail(baseCollectionURL)
        .endCell();

    const owner = provider.sender().address!;

    const royaltyParams = {
        $$type: "RoyaltyParams" as const,
        numerator: 150n,
        denominator: 1000n,
        destination: owner,
    };

    // const lastIndex: bigint = await factory.getGetCurrentIndex();
    // console.log("Last deployed index:", lastIndex.toString());
    // const nextIndex = lastIndex; 

    // -------------------------------
    // Deploy Collection using Factory
    // -------------------------------
    console.log("⏳ Requesting deployment from factory...");

    const deployValue = toNano("0.3"); // value forwarded to collection

    const st: StateInit = await RaffleCollection.init(
        owner,
        collectionContent,
        royaltyParams,
        toNano("0.001"),
        0n,
        100n,
        10n,
        BigInt(Math.floor(Date.now() / 1000) + 3600)    
    );

    const addr = contractAddress(0, st);
    console.log("Computed collection address:", addr.toString());


    await factory.send(
        provider.sender(),
        { value: toNano("0.5") },
        {
            $$type: "DeployRaffleCollection",
            owner_address: owner,
            collection_content: collectionContent,
            royalty_params: royaltyParams,
            nft_price: toNano("0.001"),
            totalParticipants: 100n,
            maxWinners: 10n,
            endTime: BigInt(Math.floor(Date.now() / 1000) + 3600),
            deploy_value: deployValue,
        }
    );

    console.log("⏳ Waiting for collection address (computed)…");

    // const addrStr = await factory.getGetCollectionAddressByParams(
    //     owner,
    //     collectionContent,
    //     royaltyParams,
    //     0n,
    //     toNano("0.001")
    // );

    // console.log("Collection address:", addrStr);



    console.log("⏳ Waiting for deployment...", addr);
    await provider.waitForDeploy(addr);

    console.log("✅ Collection deployed at:", addr.toString());

}
