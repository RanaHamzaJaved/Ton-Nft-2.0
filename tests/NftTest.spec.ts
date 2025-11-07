import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { NftTest } from '../build/NftTest/NftTest_NftTest';
import '@ton/test-utils';

describe('NftTest', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let nftTest: SandboxContract<NftTest>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        nftTest = blockchain.openContract(await NftTest.fromInit());

        deployer = await blockchain.treasury('deployer');

        const deployResult = await nftTest.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            null,
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: nftTest.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and nftTest are ready to use
    });
});
