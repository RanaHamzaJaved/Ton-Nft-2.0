import "./message.tact";
const minTonsForStorage: Int = ton("0.02");
const gasConsumption: Int = ton("0.02");

contract NftCollection {
    nextItemIndex: Int;
    ownerAddress: Address;
    royaltyParams: RoyaltyParams?;                      
    collectionContent: Cell;   

    init(owner_address: Address, collection_content: Cell, royalty_params: RoyaltyParams, nextItemIndex: Int){
        self.ownerAddress = owner_address;
        self.collectionContent = collection_content; 
        self.royaltyParams = royalty_params;
        self.nextItemIndex = nextItemIndex;
    }

    receive("Mint"){
        let ctx: Context = context(); // get sender Info
        let msgValue: Int = ctx.value;
        let tonBalanceBeforeMsg: Int = myBalance() - msgValue;
        let storageFee: Int = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
        msgValue -= storageFee + gasConsumption;
        self.mint(ctx.sender, msgValue);

        emit(LogEventMintRecord{ minter: sender(), item_id: self.nextItemIndex, generate_number: nativeRandom() }.toCell());
    }

    // ===== Private Methods ===== //
    inline fun mint(sender: Address, msgValue: Int) {
        require(self.nextItemIndex >= 0, "non-sequential NFTs");
        let nftInit: StateInit = self.getNftItemInit(self.nextItemIndex);
        send(SendParameters{
                to: contractAddress(nftInit), 
                value: msgValue, 
                bounce: false,
                mode: SendIgnoreErrors,
                body: Transfer {
                    query_id: 0,
                    new_owner: sender,
                    response_destination: self.ownerAddress,
                    custom_payload: self.collectionContent,
                    forward_amount: 0,
                    forward_payload: emptySlice()
                }.toCell(),
                code: nftInit.code,
                data: nftInit.data
            });
        // dump(self.next_item_index); // Reference at: https://tact-by-example.org/03-emit
        self.nextItemIndex += 1;
    }

    receive(msg: GetRoyaltyParams) {   
        let ctx: Context = context(); // get sender Info
        send(SendParameters{
            to: ctx.sender,
            value: 0,
            mode: 64, 
            bounce: false,
            body: ReportRoyaltyParams {
                query_id: msg.query_id,
                numerator:  (self.royaltyParams!!).numerator,
                denominator: (self.royaltyParams!!).denominator,
                destination: self.ownerAddress
            }.toCell()
        });        
    }

    // ------------------ Get Function  ------------------ //
    get fun get_collection_data(): CollectionData {     
        let b: StringBuilder = beginString();
        let collectionDataString: String = self.collectionContent.asSlice().asString();
        b.append(collectionDataString);
        b.append("meta.json"); // You can changed this your self.
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
        return initOf NftItemSimple(myAddress(), item_index);
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

contract NftItemSimple {
    collectionAddress: Address;
    itemIndex: Int; 
    isInitialized: Bool;

    owner: Address?;
    individualContent: Cell?;

    init(collection_address: Address, item_index: Int){
        require(sender() == collection_address, "not from collection");
        self.collectionAddress = collection_address;
        self.itemIndex = item_index;
        self.isInitialized = false;
    }

    receive(msg: Transfer){
        let ctx: Context = context(); // Reference: https://docs.tact-lang.org/language/ref/common#context
        let msgValue: Int = self.msgValue(ctx.value);
        
        if (self.isInitialized == false) {  // Initial Transfer, aka the "Minting" of the NFT
            require(ctx.sender == self.collectionAddress, "initialized tx need from collection");
            self.isInitialized = true;
            self.owner = msg.new_owner;
            self.individualContent = msg.custom_payload;
            send(SendParameters{
                to: msg.response_destination!!,
                value: msgValue,
                mode: SendPayGasSeparately,
                body: Excesses { query_id: msg.query_id }.toCell()
            });
        } else {
            require(ctx.sender == self.owner!!, "not owner");
            self.owner = msg.new_owner;  // change current owner to the new_owner
            if (msg.forward_amount > 0) {
                send(SendParameters{
                    to: msg.new_owner,
                    value: msg.forward_amount,
                    mode:  SendPayGasSeparately, 
                    bounce: true,
                    body: OwnershipAssigned{
                        query_id: msg.query_id,
                        prev_owner: ctx.sender,
                        forward_payload: msg.forward_payload
                    }.toCell()
                }); 
            }

            msgValue -= ctx.readForwardFee(); 
            if (msg.response_destination != null) { 
                send(SendParameters{ 
                    to: msg.response_destination!!,
                    value: msgValue - msg.forward_amount,
                    mode: SendPayGasSeparately,
                    bounce: true,
                    body: Excesses { query_id: msg.query_id }.toCell()
                });
            } 
        }
    }
    
    receive(msg: GetStaticData){ 
        let ctx: Context = context();
        send(SendParameters {
            to: ctx.sender,
            value: 0,
            mode: 64,  // (return msg amount except gas fees) 
            bounce: true,
            body: ReportStaticData{
                query_id: msg.query_id,
                index_id: self.itemIndex,
                collection: self.collectionAddress
            }.toCell()
        });
    }

    inline fun msgValue(value: Int): Int {
        let tonBalanceBeforeMsg: Int = myBalance() - value;
        let storageFee: Int = minTonsForStorage - min(tonBalanceBeforeMsg, minTonsForStorage);
        return value - (storageFee + gasConsumption);
    }

    // --------- Get Function  --------- //
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
            individual_content: self.individualContent!! 
        };
        //b.toCell()

    }
}
