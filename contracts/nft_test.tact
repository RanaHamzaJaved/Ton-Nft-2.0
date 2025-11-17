import "./message.tact";
const minTonsForStorage: Int = ton("0.04");
const gasConsumption: Int = ton("0.03");

contract NftCollection {
    nextItemIndex: Int;
    ownerAddress: Address;
    royaltyParams: RoyaltyParams?;
    collectionContent: Cell;
    nftPrice: Int;
    authorityAddress: Address;

    init(owner_address: Address, collection_content: Cell, royalty_params: RoyaltyParams?, nextItemIndex: Int, nft_price: Int) {
        self.ownerAddress = owner_address;
        self.collectionContent = collection_content;
        self.royaltyParams = royalty_params;
        self.nextItemIndex = nextItemIndex;
        self.nftPrice = nft_price;  
        self.authorityAddress = owner_address;
    }

    receive(msg: Deploy) {
    }

    receive(msg: Mint) {
        let ctx: Context = context();
        require(ctx.sender == self.ownerAddress, "Only owner can mint");

        let msgValue: Int = ctx.value;
        let totalCost: Int = self.estimateMintCost();
        require(msgValue >= totalCost, "Insufficient funds for minting");

        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = max(0, minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage));
        msgValue -= storageFee + gasConsumption + self.nftPrice;

        if (self.nftPrice > 0) {
            send(SendParameters{
                to: self.ownerAddress,
                value: self.nftPrice,
                bounce: false,
                mode: SendIgnoreErrors,
                body: "NFT Sale".asComment()
            });
        }

        self.mint(ctx.sender, msgValue);

        emit(LogEventMintRecord{ minter: sender(), item_id: self.nextItemIndex - 1, generate_number: nativeRandom() }.toCell());
    }

    receive(msg: Withdraw) {
        require(sender() == self.ownerAddress, "Only owner can withdraw");
        let withdrawAmount: Int = myBalance() - context().value - minTonsForStorage;
        require(withdrawAmount > 0, "No TON to withdraw");
        send(SendParameters{
            to: sender(),
            bounce: true,
            value: withdrawAmount,
            mode: SendRemainingValue + SendIgnoreErrors
        });
    }

    inline fun mint(sender: Address, msgValue: Int) {
        require(self.nextItemIndex >= 0, "non-sequential NFTs");
        let nftInit: StateInit = self.getNftItemInit(self.nextItemIndex);
        send(SendParameters{
            to: contractAddress(nftInit),
            value: msgValue,
            bounce: false,
            mode: SendIgnoreErrors,
            body: Transfer{
                query_id: 0,
                new_owner: sender,
                editor: sender,
                response_destination: self.ownerAddress,
                custom_payload: self.collectionContent,
                forward_amount: 0,
                forward_payload: emptySlice()
            }.toCell(),
            code: nftInit.code,
            data: nftInit.data
        });
        self.nextItemIndex += 1;
    }

    receive(msg: GetRoyaltyParams) {   
        let ctx: Context = context();
        send(SendParameters{
            to: ctx.sender,
            value: 0,
            mode: 64, 
            bounce: false,
            body: ReportRoyaltyParams {
                query_id: msg.queryId,
                numerator:  (self.royaltyParams!!).numerator,
                denominator: (self.royaltyParams!!).denominator,
                destination: self.ownerAddress
            }.toCell()
        });        
    }

    get fun estimateMintCost(): Int {
        return (minTonsForStorage + gasConsumption + self.nftPrice);
    }

    get fun get_collection_data(): CollectionData {     
        let b: StringBuilder = beginString();
        let collectionDataString: String = self.collectionContent.asSlice().asString();
        b.append(collectionDataString);
        b.append("collection.json");
        return CollectionData{
            next_item_index: self.nextItemIndex, 
            collection_content: b.toCell(), 
            owner_address: self.ownerAddress
        };
    }

    get fun get_nft_address_by_index(item_index: Int): Address?{      
        let initCode: StateInit = self.getNftItemInit(item_index);
        return contractAddress(initCode);
    }

    get fun getNftItemInit(item_index: Int): StateInit {
        return initOf NftItemSimple(myAddress(), item_index, self.authorityAddress);
    }

    get fun get_nft_content(index: Int, individual_content: Cell): Cell { 
        let b: StringBuilder = beginString();
        let ic: String = individual_content.asSlice().asString();
        b.append(ic);
        return b.toCell();
    }

    get fun royalty_params(): RoyaltyParams {
        return self.royaltyParams!!;
    }
}


// =========================================================
// ✅ Simplified NFT item (TIP-4.2-compatible)
// =========================================================

contract NftItemSimple {
        
    owner: Address?;
    editor: Address?;
    collectionAddress: Address;
    authorityAddress: Address?;

    itemIndex: Int;
    revokedAt: Int as uint64 = 0;
    isInitialized: Bool;

    individualContent: Cell?;

    init(collection_address: Address, item_index: Int, authority_address: Address) {
        require(sender() == collection_address, "Not from collection");
        self.collectionAddress = collection_address;
        self.itemIndex = item_index;
        self.isInitialized = false;
        self.authorityAddress = authority_address;
        self.editor = null;
    }

    receive(msg: Transfer){
        let ctx: Context = context(); 
        let msgValue: Int = self.msgValue(ctx.value);
        require(self.revokedAt == 0, "NFT revoked");

        if (self.isInitialized == false) { 
            require(ctx.sender == self.collectionAddress, "Must come from collection");
            self.isInitialized = true;
            self.owner = msg.new_owner;
            self.individualContent = msg.custom_payload;
            self.editor = msg.editor;
            if (msgValue > 0) {
                    send(SendParameters{
                    to: msg.new_owner,
                    value: msgValue,
                    mode: SendPayGasSeparately,
                    body: Excesses { query_id: msg.query_id }.toCell()
                });
            }
        } else {
            require(ctx.sender == self.owner, "Only current owner can transfer");
            let prevOwner: Address = self.owner!!;

            send(SendParameters{
                to: msg.new_owner,
                value: msgValue,
                mode: SendPayGasSeparately,
                body: OwnershipAssigned {
                    query_id: msg.query_id,
                    prev_owner: prevOwner,
                    forward_payload: msg.forward_payload
                }.toCell()
            });

            self.owner = msg.new_owner;
            // self.editor = msg.new_owner; //should we let owner to transfer it forcefully or he can do it in other call 

            let storageReserve: Int = minTonsForStorage;
            let gasReserve: Int = gasConsumption;
            let excess: Int = max(0, myBalance() - storageReserve - gasReserve);

            if (excess > 0) {
                send(SendParameters{
                    to: prevOwner,
                    value: excess,
                    mode: SendIgnoreErrors + SendRemainingValue,
                    bounce: false
                });
            }
        }
    }

    receive(msg: TransferEditorship) {
        require(sender() == self.editor, "Not current editor");
        let newEditor: Address = msg.newEditor;
        let prevEditor: Address = self.editor!!;

        send(SendParameters {
            to: newEditor,
            value: 0,
            mode: 64,
            body: EditorshipAssigned {
                queryId: msg.queryId,
                itemId: self.itemIndex,
                previousEditor: prevEditor
            }.toCell()
        });
        self.editor = newEditor;
    }

    receive(msg: EditContent) {
        require(sender() == self.editor, "Not editor");
        self.individualContent = msg.newContent;
    }

    receive(msg: GetStaticData){ 
        send(SendParameters {
            to: sender(),
            value: 0,
            mode: 64,
            bounce: true,
            body: ReportStaticData{
                query_id: msg.query_id,
                index_id: self.itemIndex,
                collection: self.collectionAddress
            }.toCell()
        });
    }

    receive(msg: ProveOwnership) {
        require(sender() == self.owner, "Not owner");
        send(SendParameters{
            to: msg.dest,
            value: 0,
            mode: 64,
            body: OwnershipProof {
                query_id: msg.query_id,
                item_id: self.itemIndex,
                owner: self.owner!!,
                data: msg.forward_payload,
                revoked_at: self.revokedAt,
                content: msg.with_content ? self.individualContent : null
            }.toCell()
        });
    }

    receive(msg: RequestOwner) {
        send(SendParameters{
            to: msg.dest,
            value: 0,
            mode: 64,
            body: OwnerInfo {
                query_id: msg.query_id,
                item_id: self.itemIndex,
                initiator: sender(),
                owner: self.owner!!,
                data: msg.forward_payload,
                revoked_at: self.revokedAt,
                content: msg.with_content ? self.individualContent : null
            }.toCell()
        });
    }

    receive(msg:Destroy) {
        require(sender() == self.owner, "Not owner");

        self.owner = null;
        self.editor = null;
        self.authorityAddress = null;
        self.revokedAt = 0;

        let excess: Int = myBalance() - context().value - minTonsForStorage;
        if (excess > 0) {
            send(SendParameters{
                to: sender(),
                bounce: false,
                value: excess,
                mode: SendRemainingValue + SendIgnoreErrors
            });
        }
    }

    receive(msg: WithdrawExcessBeforeDestroy) {
        require(sender() == self.owner, "Not owner");
        let excess: Int = max(0, myBalance() - minTonsForStorage - gasConsumption);
        require(excess > 0, "No excess to withdraw");

        send(SendParameters{
            to: sender(),
            value: excess,
            mode: SendRemainingValue + SendIgnoreErrors,
            bounce: false
        });
    }

    receive(msg: Revoke) {
        require(sender() == self.authorityAddress, "Not authorized");
        require(self.revokedAt == 0, "Already revoked");
        self.revokedAt = now();
    }

    inline fun msgValue(value: Int): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - value;
        let storageFee: Int = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
        let roundingFee: Int = ton("0.005");
        return max(0, value - (storageFee + gasConsumption + roundingFee));
    }

    get fun get_nft_data(): GetNftData {
        let b: StringBuilder = beginString();
        let collectionData: String = (self.individualContent!!).asSlice().asString();
        b.append(collectionData);
        b.append(self.itemIndex.toString());
        b.append(".json");

        return GetNftData {
            is_initialized: self.isInitialized,
            index: self.itemIndex,
            collection_address: self.collectionAddress,
            owner_address: self.owner!!,
            individual_content: b.toCell(),
            editorAddress: self.editor,
        };
    }
    
    get fun get_authority_address(): Address? {
        return self.authorityAddress;
    }

    get fun get_editor_address(): Address? {
        return self.editor;
    }

    get fun get_revoked_time(): Int {
        return self.revokedAt;
    }
}
