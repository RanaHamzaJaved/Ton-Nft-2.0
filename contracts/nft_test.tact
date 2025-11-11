import "./message.tact";
import "@stdlib/deploy";
import "@stdlib/ownable";
const minTonsForStorage: Int = ton("0.05");
const gasConsumption: Int = ton("0.03");

contract NftCollection with Deployable {
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

    receive("Mint"){
        let ctx: Context = context();
        let msgValue: Int = ctx.value;

        let totalCost: Int = self.get_nft_mint_total_cost();
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
        return self.royaltyParams!!;
    }
}


// =========================================================
// ✅ Simplified NFT item (TIP-4.2-compatible)
// =========================================================

contract NftItemSimple {
    collectionAddress: Address;
    itemIndex: Int;
    isInitialized: Bool;
    authority_address: Address?;

    owner: Address?;
    individualContent: Cell?;

    init(collection_address: Address, item_index: Int, authority_address: Address) {
        require(sender() == collection_address, "Not from collection");
        self.collectionAddress = collection_address;
        self.itemIndex = item_index;
        self.isInitialized = false;
        self.authority_address = authority_address;
    }

    receive(msg: Transfer){
        let ctx: Context = context(); 
        let msgValue: Int = self.msgValue(ctx.value);
        
        if (self.isInitialized == false) { 
            require(ctx.sender == self.collectionAddress, "Initialized tx need from collection");
            self.isInitialized = true;
            self.owner = msg.new_owner;
            self.individualContent = msg.custom_payload;
            if (msgValue > 0) {
                    send(SendParameters{
                    to: msg.new_owner,
                    value: msgValue,
                    mode: SendPayGasSeparately,
                    body: Excesses { query_id: msg.query_id }.toCell()
                });
            }
        } else {
            require(false, "SBT cannot be transferred");
        }
    }

    receive(msg: GetStaticData){ 
        send(SendParameters {
            to: sender(),
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
            individual_content: b.toCell()
        };
    }
    
    get fun get_authority_address(): Address? {
        return self.authority_address;
    }
}
