import { Address } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { NftCollection } from "../build/NftTest/NftTest_NftCollection";

function cleanCollectionContent(hex: string) {
    hex = hex.replace(/^x\{/, "").replace(/\}$/, "");
    const buf = Buffer.from(hex, "hex");
    let str = buf.toString("utf8");
    if (str.charCodeAt(0) < 32) str = str.slice(1); // strip prefix
    return str;
}

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("kQDtZbTJHpY9mUXVe-Eh4vFy9MAw7bhb58tXeo-KM75fe7Ra");
    const collection = provider.open(NftCollection.fromAddress(collectionAddress));

    console.log("🔍 Fetching collection data from:", collectionAddress.toString());

    const collectionData = await collection.getGetCollectionData();
    const ownerAddress = collectionData.owner_address.toString({ bounceable: false });
    const collectionContentDecoded = cleanCollectionContent(collectionData.collection_content.toString());
    const mintCostTON = Number(await collection.getGetNftMintTotalCost()) / 1e9;

    console.log("\n🧾 Collection Data:");
    console.log({
        nextItemIndex: collectionData.next_item_index,
        ownerAddress,
        collectionContentDecoded,
    });
    console.log("getGetNftMintTotalCost (TON):", mintCostTON);

    console.log("\n🎨 NFT Addresses:");
    for (let i = 0; i < Number(collectionData.next_item_index); i++) {
        try {
            const nftAddr = await collection.getGetNftAddressByIndex(BigInt(i));
            console.log(`Index ${i}: ${nftAddr?.toString() ?? "Not minted yet"}`);
        } catch (err) {
            console.log(`Index ${i}: ❌ Error fetching address`, err);
        }
    }

    const royaltyParams = await collection.getRoyaltyParams();
    console.log("\n💰 Royalty Params:");
    console.log({
        numerator: royaltyParams.numerator.toString(),
        denominator: royaltyParams.denominator.toString(),
        destination: royaltyParams.destination.toString({ bounceable: false }),
    });
}
