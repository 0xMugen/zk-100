use core::array::ArrayTrait;
use core::option::Option;
use core::traits::Into;
use zk100_vm::{Score, Inst, Op, Src, Dst};
use super::hash::merkle_root;

// Public outputs structure containing all commitments and results
#[derive(Drop, Copy)]
pub struct PublicOutputs {
    pub challenge_commit: felt252,  // Commitment to challenge/input
    pub program_commit: felt252,    // Merkle root of programs
    pub output_commit: felt252,     // Merkle root of outputs
    pub score: Score,              // From VM execution
    pub solved: bool,              // Whether target was achieved
}

// Commit to a 2x2 grid of programs
pub fn commit_programs(programs: @Array<Array<Array<Inst>>>) -> felt252 {
    let mut leaves = ArrayTrait::new();
    
    // Flatten all programs into leaves
    let mut r = 0;
    while r < programs.len() {
        match programs.get(r) {
            Option::Some(row_box) => {
                let row = row_box.unbox();
                let mut c = 0;
                while c < row.len() {
                    match row.get(c) {
                        Option::Some(prog_box) => {
                            let prog = prog_box.unbox();
                            
                            // Hash each instruction in the program
                            let mut prog_data = ArrayTrait::new();
                            let mut i = 0;
                            while i < prog.len() {
                                match prog.get(i) {
                                    Option::Some(inst_box) => {
                                        let inst = inst_box.unbox();
                                        // Simple encoding: combine op, src, dst into single felt
                                        let inst_encoded = encode_instruction(inst);
                                        prog_data.append(inst_encoded);
                                    },
                                    Option::None => { }
                                }
                                i += 1;
                            }
                            
                            // Hash the program
                            let prog_hash = merkle_root(@prog_data);
                            leaves.append(prog_hash);
                        },
                        Option::None => { }
                    }
                    c += 1;
                }
            },
            Option::None => { }
        }
        r += 1;
    }
    
    // Return merkle root of all programs
    merkle_root(@leaves)
}

// Commit to output stream
pub fn commit_outputs(outputs: @Array<u32>) -> felt252 {
    let mut leaves = ArrayTrait::new();
    
    let mut i = 0;
    while i < outputs.len() {
        let val: felt252 = (*outputs[i]).into();
        leaves.append(val);
        i += 1;
    }
    
    merkle_root(@leaves)
}

// Commit to challenge (input stream and expected output)
pub fn commit_challenge(inputs: @Array<u32>, expected: @Array<u32>) -> felt252 {
    let mut data = ArrayTrait::new();
    
    // Add input stream
    let input_commit = commit_outputs(inputs);
    data.append(input_commit);
    
    // Add expected output
    let expected_commit = commit_outputs(expected);
    data.append(expected_commit);
    
    merkle_root(@data)
}

// Serialize PublicOutputs to array of felt252
pub fn serialize_public_outputs(outputs: @PublicOutputs) -> Array<felt252> {
    let mut result = ArrayTrait::new();
    
    result.append(*outputs.challenge_commit);
    result.append(*outputs.program_commit);
    result.append(*outputs.output_commit);
    result.append((*outputs.score.cycles).into());
    result.append((*outputs.score.msgs).into());
    result.append((*outputs.score.nodes_used).into());
    result.append(if *outputs.solved { 1 } else { 0 });
    
    result
}

// Deserialize array of felt252 to PublicOutputs
pub fn deserialize_public_outputs(data: @Array<felt252>) -> Option<PublicOutputs> {
    if data.len() != 7 {
        return Option::None;
    }
    
    let score = Score {
        cycles: felt252_to_u64(*data[3]),
        msgs: felt252_to_u64(*data[4]),
        nodes_used: felt252_to_u32(*data[5]),
    };
    
    Option::Some(PublicOutputs {
        challenge_commit: *data[0],
        program_commit: *data[1],
        output_commit: *data[2],
        score: score,
        solved: *data[6] != 0,
    })
}

// Helper functions for encoding

fn encode_instruction(inst: @Inst) -> felt252 {
    // Simple encoding - in production would need proper serialization
    // Combine op (4 bits), src type (4 bits), dst type (4 bits), and values
    let op_val = op_to_u32(*inst.op);
    let src_val = src_to_u32(*inst.src);
    let dst_val = dst_to_u32(*inst.dst);
    
    // Pack into single felt252
    let result: felt252 = (op_val * 0x10000 + src_val * 0x100 + dst_val).into();
    result
}

// Convert types to u32 for encoding (simplified)
fn op_to_u32(op: Op) -> u32 {
    match op {
        Op::Mov => 0,
        Op::Add => 1,
        Op::Sub => 2,
        Op::Neg => 3,
        Op::Sav => 4,
        Op::Swp => 5,
        Op::Jmp => 6,
        Op::Jz => 7,
        Op::Jnz => 8,
        Op::Jgz => 9,
        Op::Jlz => 10,
        Op::Nop => 11,
        Op::Hlt => 12,
    }
}

fn src_to_u32(src: Src) -> u32 {
    match src {
        Src::Lit(_) => 0,
        Src::Acc => 1,
        Src::Nil => 2,
        Src::In => 3,
        Src::P(_) => 4,
        Src::Last => 5,
    }
}

fn dst_to_u32(dst: Dst) -> u32 {
    match dst {
        Dst::Acc => 0,
        Dst::Nil => 1,
        Dst::Out => 2,
        Dst::P(_) => 3,
        Dst::Last => 4,
    }
}

// Helper conversions (simplified - in production would use proper libraries)
fn felt252_to_u64(val: felt252) -> u64 {
    // Very simplified - assumes value fits
    // In real implementation would need proper conversion
    0_u64  // Placeholder
}

fn felt252_to_u32(val: felt252) -> u32 {
    // Very simplified - assumes value fits
    0_u32  // Placeholder
}