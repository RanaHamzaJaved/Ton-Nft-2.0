import { Address } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { NftCollection } from "../build/NftTest/NftTest_NftCollection";

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("kQCY-hl4-_TDOOctkhJ1RCao57jdRt5A0YwTRlSj36Ca27iJ");

    const collection = provider.open(NftCollection.fromAddress(collectionAddress));

    console.log("🔍 Fetching collection data from:", collectionAddress.toString());

    const collectionData = await collection.getGetCollectionData();
    console.log("\n🧾 Collection Data:");
    console.log({
        nextItemIndex: collectionData.next_item_index,
        ownerAddress: collectionData.owner_address.toString(),
        collectionContent: collectionData.collection_content.toString(),
    });
    console.log("getEstimateMintCost ", await collection.getEstimateMintCost());
    console.log("\n🎨 NFT Addresses:");
    for (let i = 0; i < Number(collectionData.next_item_index); i++) {
        try {
            const nftAddr = await collection.getGetNftAddressByIndex(BigInt(i));
            console.log(`Index ${i}: ${nftAddr?.toString() ?? "Not minted yet"}`);
        } catch (err) {
            console.log(`Index ${i}: ❌ Error fetching address`, err);
        }
    }

    // const royaltyParams = await collection.getRoyaltyParams();
    // console.log("\n💰 Royalty Params:");
    // console.log({
    //     numerator: royaltyParams.numerator.toString(),
    //     denominator: royaltyParams.denominator.toString(),
    //     destination: royaltyParams.destination.toString(),
    // });
}
