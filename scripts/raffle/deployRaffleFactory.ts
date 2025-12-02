import { toNano, Address } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { RaffleFactory } from "../../build/NftTest/NftTest_RaffleFactory";

export async function run(provider: NetworkProvider) {
    const owner = provider.sender().address!;

    const factory = provider.open(
        await RaffleFactory.fromInit(owner)
    );

    console.log("⏳ Deploying Raffle Factory...");

    await factory.send(
        provider.sender(),
        { value: toNano("0.05") },
        { $$type: "Deploy", queryId: 0n }
    );

    await provider.waitForDeploy(factory.address);
    console.log("✅ Factory deployed at:", factory.address.toString());
}
