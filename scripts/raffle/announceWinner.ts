import { toNano, beginCell, Address } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { RaffleCollection } from '../../build/NftTest/NftTest_RaffleCollection';

export async function run(provider: NetworkProvider) {
    const collectionAddress = Address.parse("0QCIXm3uVoJHMPNpw7PVpOmE8TQ2sViM4ZPN5VYH_itQcJkN");
    const nftCollection = provider.open(RaffleCollection.fromAddress(collectionAddress));
    const owner = provider.sender();
    const randomSeed = BigInt(Date.now());
    const seedCell = beginCell().storeInt(randomSeed, 128).endCell();

    
    await nftCollection.send(owner, { value: toNano("0.2") },
                "AnnounceWinners"
            );
    console.log("🎉 AnnounceWinners tx sent!");
    
}
