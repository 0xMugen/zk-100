use core::array::ArrayTrait;
use core::option::Option;
use core::traits::Into;
use zk100_vm::{Score, Inst, Op, Src, Dst, PortTag};
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

pub fn encode_instruction(inst: @Inst) -> felt252 {
    // Enhanced encoding to preserve port directions and literal values
    // Format: lit(8) | src_port(2) | dst_port(2) | op(4) | src(3) | dst(3) = 22 bits used
    let op_val = op_to_u32(*inst.op);
    let src_val = src_to_u32(*inst.src);
    let dst_val = dst_to_u32(*inst.dst);
    
    // Get literal value (for Src::Lit or jump targets)
    let lit_val: u32 = match inst.src {
        Src::Lit(val) => *val,
        _ => match inst.dst {
            // For jumps, the target is in src as a literal
            Dst::Nil => match inst.src {
                Src::Lit(val) => *val,
                _ => 0,
            },
            _ => 0,
        },
    };
    
    // Get port directions
    let src_port: u32 = match inst.src {
        Src::P(port) => port_tag_to_u32(*port),
        _ => 0,
    };
    
    let dst_port: u32 = match inst.dst {
        Dst::P(port) => port_tag_to_u32(*port),
        _ => 0,
    };
    
    // Pack into felt252: lit << 24 | src_port << 22 | dst_port << 20 | op << 16 | src << 8 | dst
    let result: felt252 = (
        lit_val * 0x1000000 +      // bits 24-31 (8 bits for literal)
        src_port * 0x400000 +       // bits 22-23 (2 bits for src port)
        dst_port * 0x100000 +       // bits 20-21 (2 bits for dst port)
        op_val * 0x10000 +          // bits 16-19 (4 bits for op)
        src_val * 0x100 +           // bits 8-15  (8 bits for src type)
        dst_val                     // bits 0-7   (8 bits for dst type)
    ).into();
    result
}

// Convert port tag to u32 for encoding
fn port_tag_to_u32(port: PortTag) -> u32 {
    match port {
        PortTag::Up => 0,
        PortTag::Down => 1,
        PortTag::Left => 2,
        PortTag::Right => 3,
    }
}

// Convert types to u32 for encoding (simplified)
fn op_to_u32(op: Op) -> u32 {
    match op {
        Op::Mov => 1,
        Op::Add => 2,
        Op::Sub => 3,
        Op::Neg => 4,
        Op::Sav => 5,
        Op::Swp => 6,
        Op::Jmp => 7,
        Op::Jz => 8,
        Op::Jnz => 9,
        Op::Jgz => 10,
        Op::Jlz => 11,
        Op::Nop => 12,
        Op::Hlt => 13,
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
    // Assumes value fits in u64
    val.try_into().unwrap()
}

fn felt252_to_u32(val: felt252) -> u32 {
    // Assumes value fits in u32
    val.try_into().unwrap()
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
        assert_eq!(op_to_u32(Op::Mov), 1, "Mov should be 1");
        assert_eq!(op_to_u32(Op::Add), 2, "Add should be 2");
        assert_eq!(op_to_u32(Op::Sub), 3, "Sub should be 3");
        assert_eq!(op_to_u32(Op::Neg), 4, "Neg should be 4");
        assert_eq!(op_to_u32(Op::Sav), 5, "Sav should be 5");
        assert_eq!(op_to_u32(Op::Swp), 6, "Swp should be 6");
        assert_eq!(op_to_u32(Op::Jmp), 7, "Jmp should be 7");
        assert_eq!(op_to_u32(Op::Jz), 8, "Jz should be 8");
        assert_eq!(op_to_u32(Op::Jnz), 9, "Jnz should be 9");
        assert_eq!(op_to_u32(Op::Jgz), 10, "Jgz should be 10");
        assert_eq!(op_to_u32(Op::Jlz), 11, "Jlz should be 11");
        assert_eq!(op_to_u32(Op::Nop), 12, "Nop should be 12");
        assert_eq!(op_to_u32(Op::Hlt), 13, "Hlt should be 13");
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