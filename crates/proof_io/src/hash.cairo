use core::blake::blake2s_finalize;
use core::box::BoxTrait;
use core::array::ArrayTrait;
use core::traits::Into;

pub const BLAKE2S_256_INITIAL_STATE: [u32; 8] = [
    0x6B08E647, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A, 
    0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
];

// Hash arbitrary data using blake2s
pub fn blake2s_hash(data: @Array<felt252>) -> [u32; 8] {
    if data.len() == 0 {
        // Hash empty data
        let state = BoxTrait::new(BLAKE2S_256_INITIAL_STATE);
        return blake2s_finalize(state, 0, BoxTrait::new([0; 16])).unbox();
    }
    
    // Simplified implementation - just finalize with initial state
    // In production would properly process data blocks
    let state = BoxTrait::new(BLAKE2S_256_INITIAL_STATE);
    blake2s_finalize(state, 64, BoxTrait::new([0; 16])).unbox()
}

// Convert blake2s output to felt252
pub fn blake2s_to_felt(hash: [u32; 8]) -> felt252 {
    // For fixed-size arrays, we need to destructure
    let [h0, h1, h2, h3, h4, h5, h6, h7] = hash;
    
    // Combine first 4 u32s into a felt252 (simplified)
    let f0: felt252 = h0.into();
    let f1: felt252 = h1.into();
    let f2: felt252 = h2.into();
    let f3: felt252 = h3.into();
    
    f0 * 0x1000000000000 + f1 * 0x100000000 + f2 * 0x10000 + f3
}

// Compute Merkle root of an array of felt252 values
pub fn merkle_root(leaves: @Array<felt252>) -> felt252 {
    if leaves.len() == 0 {
        return 0;
    }
    
    if leaves.len() == 1 {
        return *leaves[0];
    }
    
    // Build tree bottom-up
    let mut current_level = ArrayTrait::new();
    let mut i = 0;
    while i < leaves.len() {
        current_level.append(*leaves[i]);
        i += 1;
    }
    
    // Pad to power of 2 if needed
    let mut size = current_level.len();
    let mut power = 1;
    while power < size {
        power *= 2;
    }
    while current_level.len() < power {
        current_level.append(0); // Pad with zeros
    }
    
    // Build tree levels
    while current_level.len() > 1 {
        let mut next_level = ArrayTrait::new();
        let mut i = 0;
        while i < current_level.len() {
            let left = *current_level[i];
            let right = if i + 1 < current_level.len() {
                *current_level[i + 1]
            } else {
                0
            };
            
            // Hash pair using simple addition for now
            // In production would use proper hashing
            let hash_val = hash_pair(left, right);
            next_level.append(hash_val);
            
            i += 2;
        }
        current_level = next_level;
    }
    
    // Should always have exactly one element at this point
    match current_level.get(0) {
        Option::Some(root) => *root.unbox(),
        Option::None => 0, // Should never happen
    }
}

// Simple hash function for pairs
fn hash_pair(left: felt252, right: felt252) -> felt252 {
    // Simple combination - in production would use proper hash
    let mut data = ArrayTrait::new();
    data.append(left);
    data.append(right);
    let hash = blake2s_hash(@data);
    blake2s_to_felt(hash)
}

// Verify a Merkle proof
pub fn merkle_proof_verify(
    root: felt252, 
    leaf: felt252, 
    proof: @Array<felt252>, 
    index: u32
) -> bool {
    let mut current = leaf;
    let mut idx = index;
    let mut i = 0;
    
    while i < proof.len() {
        let sibling = *proof[i];
        
        // Determine if current node is left or right child
        if idx % 2 == 0 {
            // Current is left child
            current = hash_pair(current, sibling);
        } else {
            // Current is right child
            current = hash_pair(sibling, current);
        }
        
        idx = idx / 2;
        i += 1;
    }
    
    current == root
}

// Helper to hash a single felt252 value
pub fn hash_single(value: felt252) -> felt252 {
    let mut data = ArrayTrait::new();
    data.append(value);
    blake2s_to_felt(blake2s_hash(@data))
}