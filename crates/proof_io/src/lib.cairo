mod hash;
mod public;

// Export hash functions
pub use hash::{
    blake2s_hash, 
    blake2s_to_felt,
    merkle_root, 
    merkle_proof_verify,
    hash_single,
    BLAKE2S_256_INITIAL_STATE
};

// Export public interface
pub use public::{
    PublicOutputs, 
    commit_programs, 
    commit_outputs, 
    commit_challenge,
    serialize_public_outputs, 
    deserialize_public_outputs
};