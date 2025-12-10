import { Address, beginCell } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { RaffleCollection } from "../../build/NftTest/NftTest_RaffleCollection";
import { NftItemSimple } from "../../build/NftTest/NftTest_NftItemSimple";

// Utility to decode Cell content to string (if needed)
function cleanCollectionContent(hex: string) {
hex = hex.replace(/^x{/, "").replace(/}$/, "");
const buf = Buffer.from(hex, "hex");
let str = buf.toString("utf8");
if (str.charCodeAt(0) < 32) str = str.slice(1);
return str;
}

export async function run(provider: NetworkProvider) {
    const raffleAddress = Address.parse("0QCIXm3uVoJHMPNpw7PVpOmE8TQ2sViM4ZPN5VYH_itQcJkN");
    const raffle = provider.open(RaffleCollection.fromAddress(raffleAddress));

    console.log(`\n🔍 Fetching RaffleCollection data from: ${raffleAddress.toString()}`);  

    // Basic info  
    const endTime = await raffle.getGetEndTime();  
    console.log("Raffle End Time (unix timestamp):", endTime.toString());  

    // Winners and losers  
    const raffleResult = await raffle.getGetWinnersAndLosers();  
    console.log("\n🎉 Winners:");  
    for (const addr of raffleResult.winners.keys()) {  
        const val = raffleResult.winners.get(addr);  
        console.log(addr.toString(), val);  
    }  

    console.log("\n😞 Losers:");  
    for (const addr of raffleResult.losers.keys()) {  
        const amount = raffleResult.losers.get(addr);  
        console.log(addr.toString(), amount?.toString());  
    }  

    console.log("\n🎉 Winners Nft Addresses:");  
    for (const addr of raffleResult.winners.keys()) {  
        const val = raffleResult.winners.get(addr);  
        const nft = await raffle.getGetNftByWallet(addr)
        console.log(addr.toString(), nft);  
    }  

    // Collection content  
    const collectionData = await raffle.getGetCollectionData();  
    const collectionOwner = collectionData.owner_address.toString({ bounceable: false });  
    const collectionContentDecoded = cleanCollectionContent(collectionData.collection_content.toString());  

    console.log("\n🧾 Raffle Collection Data:");  
    console.log({  
        nextItemIndex: collectionData.next_item_index,  
        ownerAddress: collectionOwner,  
        collectionContentDecoded,  
    });  


    // NFT addresses and data  
    console.log("\n🎨 NFT Addresses and Data:");  
    for (let i = 0; i < Number(collectionData.next_item_index); i++) {  
        try {  
            const nftAddr = await raffle.getGetNftAddressByIndex(BigInt(i));  
            if (!nftAddr) {
                console.log(`Index ${i}: Not minted yet`);
                continue;
            }

            console.log(`\nIndex ${i}: ${nftAddr.toString()}`);

            const nftAddress = Address.parse(nftAddr.toString());
            const nftContract = provider.open(NftItemSimple.fromAddress(nftAddress));

            // Call get_nft_data for this NFT  
            const nftData = await nftContract.getGetNftData();  
            const individualContentDecoded = nftData.individual_content
                ? cleanCollectionContent(nftData.individual_content.toString())
                : null;

            console.log("NFT Data:", {  
                owner: nftData.owner_address.toString({ bounceable: false }),  
                editor: nftData.editorAddress?.toString({ bounceable: false }) ?? null,  
                isInitialized: nftData.is_initialized,  
                index: nftData.index,  
                individualContent: individualContentDecoded,  
            });  
        } catch (err) {  
            console.log(`Index ${i}: ❌ Error fetching NFT data`, err);  
        }  
    }  

    // NFT mint cost  
    const mintCostTON = Number(await raffle.getGetNftMintTotalCost()) / 1e9;  
    console.log("\n💰 NFT Mint Cost (TON):", mintCostTON);  

    // Royalty params  
    const royaltyParams = await raffle.getRoyaltyParams();  
    console.log("\n💎 Royalty Params:");  
    console.log({  
        numerator: royaltyParams.numerator.toString(),  
        denominator: royaltyParams.denominator.toString(),  
        destination: royaltyParams.destination.toString({ bounceable: false }),  
    });  

}
