import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { NftCollection } from '../build/NftTest/NftTest_NftCollection';
import { NftItemSimple } from '../build/NftTest/NftTest_NftItemSimple';

export async function run(provider: NetworkProvider) {
    // ------------------------------
    // 1️⃣ Connect to deployed collection
    // ------------------------------
    const collectionAddress = Address.parse("kQDtZbTJHpY9mUXVe-Eh4vFy9MAw7bhb58tXeo-KM75fe7Ra");
    const nftCollection = provider.open(NftCollection.fromAddress(collectionAddress));

    const owner = provider.sender();
    console.log("✅ Connected to collection:", collectionAddress.toString());

    // ------------------------------
    // 2️⃣ Withdraw TON from collection
    // ------------------------------
    async function withdrawCollection() {
        console.log("⏳ Withdrawing TON from collection...");
        await nftCollection.send(owner, { value: toNano("0.01") }, { $$type: "Withdraw" });
        console.log("✅ Withdraw request sent.");
    }

    // ------------------------------
    // 3️⃣ Interact with individual NFT
    // ------------------------------
    async function openNFT(index: number) {
        const nftAddress = await nftCollection.getGetNftAddressByIndex(BigInt(index));
        return provider.open(NftItemSimple.fromAddress(nftAddress!));
    }

    const payloadCell = beginCell()
        .storeUint(123, 32)
        .endCell();

    // Convert Cell -> Slice
    const payloadSlice = payloadCell.asSlice();

    // Prove ownership of NFT
    async function proveOwnership(index: number, dest: Address) {
        const nft = await openNFT(index);
        await nft.send(owner, { value: toNano("0.01") }, { 
            $$type: "ProveOwnership",
            query_id: 0n,
            dest,
            forward_payload: payloadSlice,
            with_content: true
        });
        console.log(`✅ ProveOwnership sent for NFT #${index}`);
    }

    // Request owner info
    async function requestOwner(index: number, dest: Address) {
        const nft = await openNFT(index);
        await nft.send(owner, { value: toNano("0.01") }, { 
            $$type: "RequestOwner",
            query_id: 0n,
            dest,
            forward_payload: payloadSlice,
            with_content: true
        });
        console.log(`✅ RequestOwner sent for NFT #${index}`);
    }

    // Destroy NFT
    async function destroyNFT(index: number) {
        const nft = await openNFT(index);
        await nft.send(owner, { value: toNano("0.01") }, { $$type: "Destroy" });
        console.log(`✅ Destroy sent for NFT #${index}`);
    }

    // Revoke NFT (only authority can call)
    async function revokeNFT(index: number) {
        const nft = await openNFT(index);
        await nft.send(owner, { value: toNano("0.01") }, { $$type: "Revoke" });
        console.log(`✅ Revoke sent for NFT #${index}`);
    }

    // await withdrawCollection();

    const recipient = Address.parse("kQB_hW6yVjMyyLtqhHpggmBK3X89f-QCSt-tGEP8ffaetlyq");

    // await proveOwnership(1, recipient);
    // await requestOwner(1, recipient);

    // await destroyNFT(0);
    await revokeNFT(0);
}
