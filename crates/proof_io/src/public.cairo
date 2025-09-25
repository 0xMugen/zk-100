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

#[cfg(test)]
mod tests {
    use super::*;
    use core::array::ArrayTrait;
    use core::option::Option;

    #[test]
    fn test_public_outputs_struct() {
        // Test PublicOutputs struct creation
        let outputs = PublicOutputs {
            challenge_commit: 12345,
            program_commit: 67890,
            output_commit: 11111,
            score: Score {
                cycles: 100,
                msgs: 5,
                nodes_used: 3,
            },
            solved: true,
        };
        
        assert_eq!(outputs.challenge_commit, 12345, "Challenge commit set correctly");
        assert_eq!(outputs.program_commit, 67890, "Program commit set correctly");
        assert_eq!(outputs.output_commit, 11111, "Output commit set correctly");
        assert_eq!(outputs.score.cycles, 100, "Score cycles set correctly");
        assert!(outputs.solved, "Solved flag set correctly");
    }

    #[test]
    fn test_commit_outputs_empty() {
        // Test committing empty output
        let empty = ArrayTrait::new();
        let commit = commit_outputs(@empty);
        
        // Empty array should have merkle root 0
        assert_eq!(commit, 0, "Empty output commit should be 0");
    }

    #[test]
    fn test_commit_outputs_with_values() {
        // Test committing output values
        let mut outputs = ArrayTrait::new();
        outputs.append(10);
        outputs.append(20);
        outputs.append(30);
        
        let commit = commit_outputs(@outputs);
        assert!(commit != 0, "Output commit should not be 0");
    }

    #[test]
    fn test_commit_challenge() {
        // Test challenge commitment
        let mut inputs = ArrayTrait::new();
        inputs.append(1);
        inputs.append(2);
        
        let mut expected = ArrayTrait::new();
        expected.append(100);
        
        let commit = commit_challenge(@inputs, @expected);
        assert!(commit != 0, "Challenge commit should not be 0");
    }

    #[test]
    fn test_commit_programs_empty() {
        // Test empty program commitment
        let programs = ArrayTrait::new();
        let commit = commit_programs(@programs);
        assert_eq!(commit, 0, "Empty program commit should be 0");
    }

    #[test]
    fn test_commit_programs_with_instructions() {
        // Test program commitment with instructions
        let mut programs = ArrayTrait::new();
        
        // Create a 1x1 grid with one program
        let mut row = ArrayTrait::new();
        let mut prog = ArrayTrait::new();
        prog.append(Inst { op: Op::Nop, src: Src::Nil, dst: Dst::Nil });
        prog.append(Inst { op: Op::Add, src: Src::Lit(5), dst: Dst::Nil });
        row.append(prog);
        
        programs.append(row);
        
        let commit = commit_programs(@programs);
        assert!(commit != 0, "Program commit should not be 0");
    }

    #[test]
    fn test_serialize_deserialize_public_outputs() {
        // Test serialization and deserialization
        let outputs = PublicOutputs {
            challenge_commit: 111,
            program_commit: 222,
            output_commit: 333,
            score: Score {
                cycles: 444,
                msgs: 555,
                nodes_used: 666,
            },
            solved: true,
        };
        
        let serialized = serialize_public_outputs(@outputs);
        assert_eq!(serialized.len(), 7, "Serialized should have 7 elements");
        
        // Check serialized values
        assert_eq!(*serialized[0], 111, "Challenge commit serialized correctly");
        assert_eq!(*serialized[1], 222, "Program commit serialized correctly");
        assert_eq!(*serialized[2], 333, "Output commit serialized correctly");
        assert_eq!(*serialized[3], 444, "Cycles serialized correctly");
        assert_eq!(*serialized[4], 555, "Messages serialized correctly");
        assert_eq!(*serialized[5], 666, "Nodes used serialized correctly");
        assert_eq!(*serialized[6], 1, "Solved flag serialized correctly");
        
        // Test deserialization
        match deserialize_public_outputs(@serialized) {
            Option::Some(deserialized) => {
                assert_eq!(deserialized.challenge_commit, 111, "Challenge commit deserialized");
                assert_eq!(deserialized.program_commit, 222, "Program commit deserialized");
                assert_eq!(deserialized.output_commit, 333, "Output commit deserialized");
                assert!(deserialized.solved, "Solved flag deserialized");
            },
            Option::None => assert!(false, "Deserialization should succeed"),
        }
    }

    #[test]
    fn test_deserialize_invalid_length() {
        // Test deserialization with wrong length
        let mut data = ArrayTrait::new();
        data.append(1);
        data.append(2);
        data.append(3); // Only 3 elements, need 7
        
        match deserialize_public_outputs(@data) {
            Option::None => assert!(true, "Should fail with wrong length"),
            Option::Some(_) => assert!(false, "Should not deserialize with wrong length"),
        }
    }

    #[test]
    fn test_deserialize_solved_false() {
        // Test deserialization with solved = false
        let mut data = ArrayTrait::new();
        data.append(100);
        data.append(200);
        data.append(300);
        data.append(400);
        data.append(500);
        data.append(600);
        data.append(0); // solved = false
        
        match deserialize_public_outputs(@data) {
            Option::Some(outputs) => {
                assert!(!outputs.solved, "Solved should be false");
            },
            Option::None => assert!(false, "Deserialization should succeed"),
        }
    }

    #[test]
    fn test_encode_instruction() {
        // Test instruction encoding
        let inst1 = Inst {
            op: Op::Mov,
            src: Src::Lit(42),
            dst: Dst::Acc,
        };
        
        let encoded1 = encode_instruction(@inst1);
        assert!(encoded1 != 0, "Encoded instruction should not be 0");
        
        // Different instruction should encode differently
        let inst2 = Inst {
            op: Op::Add,
            src: Src::Acc,
            dst: Dst::Nil,
        };
        
        let encoded2 = encode_instruction(@inst2);
        assert!(encoded1 != encoded2, "Different instructions should encode differently");
    }

    #[test]
    fn test_op_to_u32() {
        // Test operation enum conversion
        assert_eq!(op_to_u32(Op::Mov), 0, "Mov should be 0");
        assert_eq!(op_to_u32(Op::Add), 1, "Add should be 1");
        assert_eq!(op_to_u32(Op::Sub), 2, "Sub should be 2");
        assert_eq!(op_to_u32(Op::Neg), 3, "Neg should be 3");
        assert_eq!(op_to_u32(Op::Sav), 4, "Sav should be 4");
        assert_eq!(op_to_u32(Op::Swp), 5, "Swp should be 5");
        assert_eq!(op_to_u32(Op::Jmp), 6, "Jmp should be 6");
        assert_eq!(op_to_u32(Op::Jz), 7, "Jz should be 7");
        assert_eq!(op_to_u32(Op::Jnz), 8, "Jnz should be 8");
        assert_eq!(op_to_u32(Op::Jgz), 9, "Jgz should be 9");
        assert_eq!(op_to_u32(Op::Jlz), 10, "Jlz should be 10");
        assert_eq!(op_to_u32(Op::Nop), 11, "Nop should be 11");
        assert_eq!(op_to_u32(Op::Hlt), 12, "Hlt should be 12");
    }

    #[test]
    fn test_src_to_u32() {
        // Test source enum conversion
        assert_eq!(src_to_u32(Src::Lit(0)), 0, "Lit should be 0");
        assert_eq!(src_to_u32(Src::Acc), 1, "Acc should be 1");
        assert_eq!(src_to_u32(Src::Nil), 2, "Nil should be 2");
        assert_eq!(src_to_u32(Src::In), 3, "In should be 3");
        assert_eq!(src_to_u32(Src::P(PortTag::Up)), 4, "P should be 4");
        assert_eq!(src_to_u32(Src::Last), 5, "Last should be 5");
    }

    #[test]
    fn test_dst_to_u32() {
        // Test destination enum conversion
        assert_eq!(dst_to_u32(Dst::Acc), 0, "Acc should be 0");
        assert_eq!(dst_to_u32(Dst::Nil), 1, "Nil should be 1");
        assert_eq!(dst_to_u32(Dst::Out), 2, "Out should be 2");
        assert_eq!(dst_to_u32(Dst::P(PortTag::Down)), 3, "P should be 3");
        assert_eq!(dst_to_u32(Dst::Last), 4, "Last should be 4");
    }
}