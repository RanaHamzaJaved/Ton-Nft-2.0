import { toNano, beginCell, Address, contractAddress, StateInit  } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { NftFactory } from "../build/NftTest/NftTest_NftFactory";
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';

export async function run(provider: NetworkProvider) {
    const OFFCHAIN_CONTENT_PREFIX = 0x01;

    const factoryAddress = Address.parse(
        "EQDsoE7L2Zgt5AKzCrSJ4DIVZBOQ-oh6QUXS3KmRzCiIY1KJ"
    );

    const factory = provider.open(NftFactory.fromAddress(factoryAddress));

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
        numerator: 350n,
        denominator: 1000n,
        destination: owner,
    };

    const lastIndex: bigint = await factory.getGetCurrentIndex();
    console.log("Last deployed index:", lastIndex.toString());
    const nextIndex = lastIndex; 

    // -------------------------------
    // Deploy Collection using Factory
    // -------------------------------
    console.log("⏳ Requesting deployment from factory...");

    const deployValue = toNano("0.15"); // value forwarded to collection

    const st: StateInit = await NftCollection.init(
        owner,
        collectionContent,
        royaltyParams,
        0n, // nextItemIndex
        toNano("0.001"),
        nextIndex,
        100n,
        10n
    );

    const addr = contractAddress(0, st);
    console.log("Computed collection address:", addr.toString());


    await factory.send(
        provider.sender(),
        { value: toNano("0.25") },
        {
            $$type: "DeployCollection",
            owner_address: owner,
            collection_content: collectionContent,
            royalty_params: royaltyParams,
            nextItemIndex: 0n,
            nft_price: toNano("0.001"),
            deploy_value: deployValue,
            totalEditions: 100n,
            reservedEditions: 10n
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
