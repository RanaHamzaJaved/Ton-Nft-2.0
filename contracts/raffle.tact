import "./message.tact";
const minTonsForStorage: Int = ton("0.04");
const gasConsumption: Int = ton("0.03");

// =========================================================
//                      RaffleFactory
// =========================================================



// =========================================================
//         NftItemSimple (unchanged)
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