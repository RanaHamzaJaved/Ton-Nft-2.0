message(0x04) LogEventMintRecord {
    minter: Address;
    item_id: Int;
    generate_number: Int;
}

message(0x61300e88) LogRaffleEntry{
    participant: Address;
    amount: Int;
}

message LogRaffleWinners{
    winners: map<Address, Bool>;
}

struct MintNft {
    meta_link: String;
}

message(0x05) Deploy {
    queryId: Int as uint64;
}

message(0x01) Mint{
}

message (0x02)Withdraw {
}

message(0x693d3950) GetRoyaltyParams {
    query_id: Int as uint64;
}
message(0xa8cb00ad) ReportRoyaltyParams {
    query_id: Int as uint64;
    numerator: Int as uint16;
    denominator: Int as uint16;
    destination: Address;
}
struct CollectionData {
    next_item_index: Int;
    collection_content: Cell;
    owner_address: Address;
}
struct RoyaltyParams {
    numerator: Int;
    denominator: Int;
    destination: Address;
}

message(0x431e88b3) DeployRaffleCollection {
    owner_address: Address;        
    collection_content: Cell;       
    royalty_params: RoyaltyParams?;         
    nft_price: Int;                
    totalParticipants: Int;         
    maxWinners: Int;                
    endTime: Int;                     
    deploy_value: Int;          
}

message(0x5fcc3d14) Transfer {
    query_id: Int as uint64;
    new_owner: Address;
    editor: Address;
    response_destination: Address?;
    royalty_params: RoyaltyParams;
    custom_payload: Cell?;
    forward_amount: Int as coins;
    forward_payload: Slice as remaining;
}
message(0x05138d91) OwnershipAssigned {
    query_id: Int as uint64;
    prev_owner: Address;
    forward_payload: Slice as remaining;
}
message(0xd53276db) Excesses {
    query_id: Int as uint64;
}
message(0x2fcb26a2) GetStaticData {
    query_id: Int as uint64;
}
message(0x8b771735) ReportStaticData {
    query_id: Int as uint64;
    index_id: Int;
    collection: Address;
}
struct GetNftData {
    is_initialized: Bool;
    index: Int;
    collection_address: Address;
    owner_address: Address;
    individual_content: Cell;
    editorAddress: Address?;
}

// message(0x61f12cf1) AnnounceWinners {
//     seed: Cell;
// }

struct RaffleResult {
    winners: map<Address, Bool>;
    losers: map<Address, Int>;
}

message(0x51e3b1e5) ProveOwnership {
    query_id: Int as uint64;
    dest: Address;
    forward_payload: Slice;
    with_content: Bool;
}

message(0x3b3f6fcb) OwnershipProof {
    query_id: Int as uint64;
    item_id: Int;
    owner: Address;
    data: Slice;
    revoked_at: Int as uint64;
    content: Cell?;
}

message(0x6a69df03) RequestOwner {
    query_id: Int as uint64;
    dest: Address;
    forward_payload: Slice;
    with_content: Bool;
}

message(0x5fcb6e07) OwnerInfo {
    query_id: Int as uint64;
    item_id: Int;
    initiator: Address;
    owner: Address;
    data: Slice;
    revoked_at: Int as uint64;
    content: Cell?;
}

message(0x6efc5fd7) Revoke {}

message(0x03)Destroy{}

message(0x7e1f9abc) TransferEditorship {
    queryId: Int as uint64;
    newEditor: Address;
}

message(0x1a2b3c4d) EditContent {
    newContent: Cell;
}

message(0x501edecd) ReportEditor{
    queryId: Int as uint64;
    editor: Address?;
}

message(0x351f6fd3) GetIndex {
    queryId: Int as uint64;
}

message(0xa4a37580) ReportIndex {
    queryId: Int as uint64;
    index: Int;
}

message(0x2f7cb721) GetEditor {
    queryId: Int as uint64;
}

message(0x9abcdef0) EditorshipAssigned {
    queryId: Int as uint64;
    itemId: Int;
    previousEditor: Address;
}

message(0x6379aa0d) WithdrawExcessBeforeDestroy{
    queryId: Int as uint64;
}

message(0x174ae5d6) DeployCollection {
    owner_address: Address;
    collection_content: Cell;
    royalty_params: RoyaltyParams?;
    nextItemIndex: Int;
    nft_price: Int;

    // amount of value (in nanograms) to send to the newly created collection
    // Caller should provide at least enough to cover storage & gas (checked below)
    deploy_value: Int;
    totalEditions: Int;
    reservedEditions: Int;
}

message EditDeployCost{
    newDeploymentCost: Int;
}

message(0x9416b783) ReportDeployment {
    query_id: Int;
    collection_address: Address;
}

message ChangeOwner{
    new_owner: Address;
}