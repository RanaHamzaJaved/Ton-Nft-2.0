message(0x04) LogEventMintRecord {
    minter: Address;
    item_id: Int;
    generate_number: Int;
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
message(0x5fcc3d14) Transfer {
    query_id: Int as uint64;
    new_owner: Address;
    editor: Address;
    response_destination: Address?;
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

message(0x9abcdef0) EditorshipAssigned {
    queryId: Int as uint64;
    itemId: Int;
    previousEditor: Address;
}

message(0x6379aa0d) WithdrawExcessBeforeDestroy{
    queryId: Int as uint64;
}

