import "./message.tact";
const minTonsForStorage: Int = ton("0.04");
const gasConsumption: Int = ton("0.03");

contract NftFactory {
    owner: Address;
    lastDeployedIndex: Int = 0;
    collections: map<Int, Address>;

    init(owner_address: Address) {
        self.owner = owner_address;
    }

    receive(msg: Deploy) {
    }

    receive(msg: ChangeOwner) {
        require(sender() == self.owner, "Only owner");
        self.owner = msg.new_owner;
    }

    receive(msg: DeployCollection) {
        require(sender() == self.owner, "Only factory owner can deploy");

        let ctx: Context = context();

        require(msg.deploy_value >= (minTonsForStorage + gasConsumption), "deploy_value too small");
        let idx = self.lastDeployedIndex;
        self.lastDeployedIndex += 1;

        let stateInit: StateInit = initOf NftCollection(
            msg.owner_address,
            msg.collection_content,
            msg.royalty_params,
            msg.nextItemIndex,
            msg.nft_price,
            idx,
            msg.totalEditions,
            msg.reservedEditions
        );

        let newAddr: Address = contractAddress(stateInit);
        self.collections.set(idx, newAddr);

        // deploy by sending the StateInit and initial funds to the computed address
        send(SendParameters{
            to: newAddr,
            value: msg.deploy_value,
            bounce: true,
            mode: 0, // don't revert factory if something odd happens
            body: "Factory deployment".asComment(),
            code: stateInit.code,
            data: stateInit.data
        });

        // reply back to caller with the deployed address (report)
        send(SendParameters{
            to: ctx.sender,
            value: 0,
            mode: 64, // reply-only mode
            bounce: false,
            body: ReportDeployment {
                query_id: 0,
                collection_address: newAddr
            }.toCell()
        });
    }

    get fun getNextCollectionAddress(nextItemIndex: Int, owner_address: Address, collection_content: Cell, royalty_params: RoyaltyParams?, nft_price: Int, totalEditions: Int, reservedEditions: Int): Address {
        let st = initOf NftCollection(
            owner_address,
            collection_content,
            royalty_params,
            nextItemIndex,
            nft_price,
            self.lastDeployedIndex,
            totalEditions,
            reservedEditions
        );
        return contractAddress(st);
    }

    get fun getLastCollection(): Address {
        require(self.lastDeployedIndex > 0, "No collections deployed yet");
        
        let maybeAddr = self.collections.get(self.lastDeployedIndex - 1);
        require(maybeAddr != null, "Collection not found");

        return maybeAddr!!;
    }

    get fun getCurrentIndex(): Int {
        return self.lastDeployedIndex;
    }

}

contract NftCollection {
    nextItemIndex: Int;
    ownerAddress: Address;
    royaltyParams: RoyaltyParams?;
    collectionContent: Cell;
    nftPrice: Int;
    uniqueIndex: Int;
    authorityAddress: Address;
    totalEditions: Int;
    reservedEditions: Int;
    reservedMinted: Int;

    init(owner_address: Address, collection_content: Cell, royalty_params: RoyaltyParams?, nextItemIndex: Int, nft_price: Int, index: Int, totalEditions: Int, reservedEditions: Int) {
        self.ownerAddress = owner_address;
        self.collectionContent = collection_content;
        self.nextItemIndex = nextItemIndex;
        self.nftPrice = nft_price;  
        self.authorityAddress = owner_address;
        self.totalEditions = totalEditions;
        self.reservedEditions = reservedEditions;
        self.uniqueIndex = index;
        self.reservedMinted = 0;
        if (royalty_params != null) {
            require(royalty_params!!.denominator > 0, "royalty denominator must be > 0");
            require(royalty_params!!.numerator >= 0, "royalty numerator >= 0");
            require(royalty_params!!.numerator <= royalty_params!!.denominator, "royalty <= 100%");
            self.royaltyParams = royalty_params;
        }
        
    }

    receive(msg: Deploy) {
    }

    receive("Mint"){
        require(self.nextItemIndex < (self.totalEditions - self.reservedEditions), "Sold out"); 

        let ctx: Context = context();
        let msgValue: Int = ctx.value;
        let totalCost: Int = self.get_nft_mint_total_cost();
        require(msgValue >= totalCost, "Insufficient funds for minting");

        msgValue = self.computeMintFee(msgValue);
        msgValue -= self.nftPrice;
        let currentIndex: Int = self.nextItemIndex;

        //Calling mint to deploy Nft contract and transfer ownership to buyer
        self.mint(ctx.sender, msgValue);

        //Distributing nft price automatically to the owner
        self.distributeNftPayment();

        emit(LogEventMintRecord{ minter: sender(), item_id: currentIndex, generate_number: nativeRandom() }.toCell());
    }

    receive("MintReserved"){
        require(sender() == self.ownerAddress, "Only owner can mint reserved");
        require(self.reservedMinted < self.reservedEditions, "All reserved NFTs minted");

        let ctx: Context = context();
        let msgValue: Int = ctx.value;
        require(msgValue >= minTonsForStorage + gasConsumption, "Insufficient funds for minting");

        msgValue = self.computeMintFee(msgValue);
        let currentIndex: Int = self.nextItemIndex;

        //Calling mint to deploy Nft contract and transfer ownership to buyer
        self.mint(self.ownerAddress, msgValue);
        self.reservedMinted += 1;

        emit(LogEventMintRecord{ minter: sender(), item_id: currentIndex, generate_number: nativeRandom() }.toCell());
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
                royalty_params: self.royalty_params(),
                custom_payload: self.collectionContent,
                forward_amount: 0,
                forward_payload: emptySlice()
            }.toCell(),
            code: nftInit.code,
            data: nftInit.data
        });
        self.nextItemIndex += 1;
    }

    fun computeMintFee(msgValue: Int): Int {
        let tonBalanceBeforeMsg = myBalance() - msgValue;
        let storageFee = max(0, minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage));
        return msgValue - storageFee - gasConsumption;
    }

    inline fun distributeNftPayment(){
        require(self.nftPrice > 0, "Nft price should be greater than zero");
        send(SendParameters{
            to: self.ownerAddress,
            value: self.nftPrice,
            bounce: false,
            mode: SendIgnoreErrors,
            body: "NFT Sale".asComment()
        });
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

    receive(msg: GetRoyaltyParams) {   
        let ctx: Context = context();
        let r: RoyaltyParams = self.royalty_params();
        send(SendParameters{
            to: ctx.sender,
            value: 0,
            mode: 64, 
            bounce: false,
            body: ReportRoyaltyParams {
                query_id: msg.query_id,
                numerator:  r.numerator,
                denominator: r.denominator,
                destination: r.destination
            }.toCell()
        });        
    }

    get fun get_nft_mint_total_cost(): Int {
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
        if (self.royaltyParams != null) {
            return self.royaltyParams!!;
        } else {
            return RoyaltyParams{ numerator: 0, denominator: 1, destination: self.ownerAddress };
        }    
    }
}


// =========================================================
// ✅ Simplified NFT item (TIP-4.2-compatible)
// =========================================================

contract NftItemSimple {
        
    owner: Address?;
    editor: Address?;
    collectionAddress: Address;
    authority_address: Address?;
    royaltyParams: RoyaltyParams?;

    itemIndex: Int;
    revokedAt: Int as uint64 = 0;
    isInitialized: Bool;
    individualContent: Cell?;

    init(collection_address: Address, item_index: Int, authority_address: Address) {
        require(sender() == collection_address, "Not from collection");
        self.collectionAddress = collection_address;
        self.itemIndex = item_index;
        self.isInitialized = false;
        self.editor = null;
        self.authority_address = authority_address;
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
            self.royaltyParams = msg.royalty_params;

        } else {
            require(ctx.sender == self.owner, "Only current owner can transfer");
            let prevOwner: Address = self.owner!!;
            let valueToSend: Int = self.msgValue(ctx.value);

            //Send royality to collection owner
            if self.royaltyParams != null {
                let r: RoyaltyParams = self.royaltyParams!!;
                let royaltyAmount: Int = self.muldiv(valueToSend, r.numerator, r.denominator);
                if (royaltyAmount > 0 && r.destination != prevOwner) {
                    send(SendParameters{
                        to: r.destination,
                        value: royaltyAmount,
                        bounce: false,
                        mode: SendIgnoreErrors
                    });
                    valueToSend -= royaltyAmount;
                }
            }

            //Assign ownership to new owner
            send(SendParameters{
                to: msg.new_owner,
                value: valueToSend,
                mode: SendPayGasSeparately,
                body: OwnershipAssigned {
                    query_id: msg.query_id,
                    prev_owner: prevOwner,
                    forward_payload: msg.forward_payload
                }.toCell()
            });
            self.owner = msg.new_owner;

            //Transfer excess amount to previous owner while keeping safe amount inside
            let excess: Int = max(0, myBalance() - ((minTonsForStorage * 2 )- gasConsumption));
            if (excess > 0) {
                send(SendParameters{
                    to: prevOwner,
                    value: excess,
                    mode: SendIgnoreErrors,
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

    receive(msg: GetEditor) {
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: 64,
            bounce: false,
            body: ReportEditor{
                queryId: msg.queryId,
                editor: self.editor
            }.toCell()
        });
    }

    receive(msg: GetIndex) {
        send(SendParameters{
            to: sender(),
            value: 0,
            mode: 64,
            bounce: false,
            body: ReportIndex{
                queryId: msg.queryId,
                index: self.itemIndex
            }.toCell()
        });
    }

    receive(msg:Destroy) {
        require(sender() == self.owner, "Not owner");

        self.owner = null;
        self.editor = null;
        self.authority_address = null;
        self.revokedAt = 0;
        self.royaltyParams = null;
        self.individualContent = null;

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
        require(sender() == self.authority_address, "Not authorized");
        require(self.revokedAt == 0, "Already revoked");
        self.revokedAt = now();
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
    
    get fun royalty_params(): RoyaltyParams {
        if (self.royaltyParams != null) {
            return self.royaltyParams!!;
        } else {
            return RoyaltyParams{ numerator: 0, denominator: 1, destination: self.collectionAddress  };
        }
    }

    inline fun msgValue(value: Int): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - value;
        let storageFee: Int = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
        let roundingFee: Int = ton("0.005");
        return max(0, value - (storageFee + gasConsumption + roundingFee));
    }

    inline fun muldiv(a: Int, b: Int, c: Int): Int {
        require(c != 0, "division by zero");
        return (a * b) / c;
    }

    get fun get_authority_address(): Address? {
        return self.authority_address;
    }

    get fun get_editor_address(): Address? {
        return self.editor;
    }

    get fun get_revoked_time(): Int {
        return self.revokedAt;
    }
}