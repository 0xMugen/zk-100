mod hash;
mod public;

// Export hash functions
pub use hash::{
    merkle_root, 
    merkle_proof_verify,
    hash_single,
    hash_pair
};

// Export public interface
pub use public::{
    PublicOutputs, 
    commit_programs, 
    commit_outputs, 
    commit_challenge,
    serialize_public_outputs, 
    deserialize_public_outputs,
    encode_instruction
};