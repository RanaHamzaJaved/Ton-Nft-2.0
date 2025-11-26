import { toNano, Address } from "@ton/core";
import { NetworkProvider } from "@ton/blueprint";
import { NftFactory } from "../build/NftTest/NftTest_NftFactory";

export async function run(provider: NetworkProvider) {
    const owner = provider.sender().address!;

    const factory = provider.open(
        await NftFactory.fromInit(owner)
    );

    console.log("⏳ Deploying Factory...");

    await factory.send(
        provider.sender(),
        { value: toNano("0.05") },
        { $$type: "Deploy", queryId: 0n }
    );

    await provider.waitForDeploy(factory.address);
    console.log("✅ Factory deployed at:", factory.address.toString());
}
