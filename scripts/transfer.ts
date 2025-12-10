import { toNano, beginCell, Address } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { NftItemSimple } from "../build/NftTest/NftTest_NftItemSimple";

export async function run(provider: NetworkProvider) {
    const nftAddress = Address.parse("kQDcas490PkqRF3lPb_53_Nu-IH5OCGymgEES6zcE6MHZV3b");

    const NFT = provider.open(NftItemSimple.fromAddress(nftAddress));

    const owner = provider.sender().address!;
    
    const newOwner = Address.parse("0QDBL5SnQlxPD2PzZxJdhTjqFJOkeRLhBrEENv_G4ZhBMx9e");
    const emptyRoyalty = {
        $$type: "RoyaltyParams" as const,
        numerator: 0n,
        denominator: 1n,
        destination: owner,
    };
    console.log("⏳ Sending transfer request...");

    await NFT.send(
        provider.sender(),
        { value: toNano("0.7") },
        {
            $$type: "Transfer",
            query_id: 0n,
            new_owner: newOwner,
            editor: newOwner,
            response_destination: owner,
            royalty_params: emptyRoyalty,
            custom_payload: beginCell().endCell(),
            forward_amount: 0n,
            forward_payload: beginCell().endCell().beginParse()
        }
    );

    console.log("✅ Transfer message sent successfully!");
}
