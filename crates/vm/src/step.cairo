use core::bool::{True, False};
use core::option::Option;
use core::array::ArrayTrait;
use core::num::traits::WrappingSub;

use super::inst::{Inst, Op, Src, Dst, PortTag};
use super::state::{
    GridState, NodeState, StepResult,
    GRID_H, GRID_W, get_node, get_program, make_flags
};

// Port communication intent
#[derive(Copy, Drop)]
struct PortIntent {
    r: u32,
    c: u32,
    port: PortTag,
    value: u32,
    is_read: bool,  // true for read, false for write
}

// Result of executing an instruction
struct ExecResult {
    new_node: NodeState,     // Updated node state
    blocked: bool,           // Whether execution was blocked
    output: Option<u32>,     // Value to output (if any)
    consumed_input: bool,    // Whether input was consumed
}

// Step one cycle of the VM
pub fn step_cycle(ref grid: GridState) -> StepResult {
    let mut all_halted = True;
    let mut any_progress = False;
    
    // Pass 1: Collect port intentions from all nodes
    let mut port_intents: Array<PortIntent> = ArrayTrait::new();
    let mut r = 0_u32;
    while r < GRID_H {
        let mut c = 0_u32;
        while c < GRID_W {
            match get_node(@grid, r, c) {
                Option::Some(node) => {
                    if !(*node).halted {
                        all_halted = False;
                        
                        // Check what this node wants to do with ports
                        match get_port_intent(@grid, node, r, c) {
                            Option::Some(intent) => {
                                port_intents.append(intent);
                            },
                            Option::None => {}
                        }
                    }
                },
                Option::None => {}
            }
            c += 1;
        }
        r += 1;
    }
    
    // Pass 2: Execute nodes with port matching info
    let mut new_nodes: Array<Array<NodeState>> = ArrayTrait::new();
    r = 0_u32;
    while r < GRID_H {
        let mut new_row: Array<NodeState> = ArrayTrait::new();
        let mut c = 0_u32;
        while c < GRID_W {
            match get_node(@grid, r, c) {
                Option::Some(node) => {
                    if !(*node).halted {
                        // Try to execute instruction with port matching info
                        match execute_node_with_ports(@grid, node, r, c, @port_intents) {
                            Option::Some(result) => {
                                if !result.blocked {
                                    any_progress = True;
                                }
                                
                                // Handle output from node (1,1)
                                if r == 1 && c == 1 {
                                    match result.output {
                                        Option::Some(val) => {
                                            grid.out_stream.append(val);
                                            grid.msgs += 1;
                                        },
                                        Option::None => {}
                                    }
                                }
                                
                                // Handle input consumption from node (0,0)
                                if r == 0 && c == 0 && result.consumed_input {
                                    grid.in_cursor += 1;
                                }
                                
                                new_row.append(result.new_node);
                            },
                            Option::None => {
                                // No instruction or error - halt the node
                                let mut halted_node = *node;
                                halted_node.halted = true;
                                new_row.append(halted_node);
                            }
                        }
                    } else {
                        new_row.append(*node);
                    }
                },
                Option::None => {
                    // Should not happen with proper grid initialization
                    new_row.append(super::state::create_initial_node());
                }
            }
            c += 1;
        }
        new_nodes.append(new_row);
        r += 1;
    }
    
    // Update grid with new node states
    grid.nodes = new_nodes;
    grid.cycles += 1;
    
    // Determine result
    if all_halted {
        StepResult::Halted
    } else if !any_progress {
        StepResult::Deadlock
    } else {
        StepResult::Continue
    }
}


// Execute a single instruction with port match info
fn execute_instruction_with_ports(grid: @GridState, node: @NodeState, inst: Inst, r: u32, c: u32, port_match: Option<@PortIntent>) -> Option<ExecResult> {
    let mut new_node = *node;
    let mut blocked = false;
    let mut output: Option<u32> = Option::None;
    let mut consumed_input = false;
    
    match inst.op {
        Op::Nop => {
            new_node.pc += 1;
        },
        Op::Hlt => {
            // For auto-looping behavior, HLT acts like NOP
            new_node.pc += 1;
        },
        Op::Mov => {
            match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                Option::Some((val, consumed)) => {
                    consumed_input = consumed;
                    match write_destination_with_ports(ref new_node, inst.dst, val, port_match) {
                        Option::Some(out_val) => {
                            output = Option::Some(out_val);
                            new_node.pc += 1;
                        },
                        Option::None => {
                            // Check if this is a port destination
                            match inst.dst {
                                Dst::P(_) => {
                                    // Check if we have a matching reader
                                    match port_match {
                                        Option::Some(intent) => {
                                            if (*intent).is_read {
                                                // Successful port write
                                                new_node.pc += 1;
                                            } else {
                                                blocked = true;
                                            }
                                        },
                                        Option::None => {
                                            // No matching reader, block
                                            blocked = true;
                                        }
                                    }
                                },
                                Dst::Last => {
                                    // Last not implemented
                                    blocked = true;
                                },
                                _ => {
                                    // ACC, NIL writes always succeed
                                    new_node.pc += 1;
                                }
                            }
                        }
                    }
                },
                Option::None => {
                    blocked = true;
                }
            }
        },
        Op::Add => {
            match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                Option::Some((val, consumed)) => {
                    consumed_input = consumed;
                    new_node.acc = new_node.acc + val;
                    new_node.flags = make_flags(new_node.acc);
                    new_node.pc += 1;
                },
                Option::None => {
                    blocked = true;
                }
            }
        },
        Op::Sub => {
            match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                Option::Some((val, consumed)) => {
                    consumed_input = consumed;
                    new_node.acc = new_node.acc - val;
                    new_node.flags = make_flags(new_node.acc);
                    new_node.pc += 1;
                },
                Option::None => {
                    blocked = true;
                }
            }
        },
        Op::Neg => {
            new_node.acc = 0_u32.wrapping_sub(new_node.acc);
            new_node.flags = make_flags(new_node.acc);
            new_node.pc += 1;
        },
        Op::Sav => {
            new_node.bak = new_node.acc;
            new_node.pc += 1;
        },
        Op::Swp => {
            let temp = new_node.acc;
            new_node.acc = new_node.bak;
            new_node.bak = temp;
            new_node.flags = make_flags(new_node.acc);
            new_node.pc += 1;
        },
        Op::Jmp => {
            match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                Option::Some((val, consumed)) => {
                    consumed_input = consumed;
                    new_node.pc = val;
                },
                Option::None => {
                    blocked = true;
                }
            }
        },
        Op::Jz => {
            if new_node.flags.z {
                match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                    Option::Some((val, consumed)) => {
                        consumed_input = consumed;
                        new_node.pc = val;
                    },
                    Option::None => {
                        blocked = true;
                    }
                }
            } else {
                new_node.pc += 1;
            }
        },
        Op::Jnz => {
            if !new_node.flags.z {
                match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                    Option::Some((val, consumed)) => {
                        consumed_input = consumed;
                        new_node.pc = val;
                    },
                    Option::None => {
                        blocked = true;
                    }
                }
            } else {
                new_node.pc += 1;
            }
        },
        Op::Jgz => {
            // Greater than zero: not zero and not negative
            if !new_node.flags.z && !new_node.flags.n {
                match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                    Option::Some((val, consumed)) => {
                        consumed_input = consumed;
                        new_node.pc = val;
                    },
                    Option::None => {
                        blocked = true;
                    }
                }
            } else {
                new_node.pc += 1;
            }
        },
        Op::Jlz => {
            // Less than zero: negative flag set
            if new_node.flags.n {
                match read_source_with_ports(grid, @new_node, inst.src, r, c, port_match) {
                    Option::Some((val, consumed)) => {
                        consumed_input = consumed;
                        new_node.pc = val;
                    },
                    Option::None => {
                        blocked = true;
                    }
                }
            } else {
                new_node.pc += 1;
            }
        },
    }
    
    new_node.blocked = blocked;
    
    Option::Some(ExecResult {
        new_node: new_node,
        blocked: blocked,
        output: output,
        consumed_input: consumed_input,
    })
}

// Get neighbor coordinates based on port direction
fn get_neighbor_coords(r: u32, c: u32, port: PortTag) -> Option<(u32, u32)> {
    match port {
        PortTag::Up => {
            if r > 0 { Option::Some((r - 1, c)) } else { Option::None }
        },
        PortTag::Down => {
            if r < GRID_H - 1 { Option::Some((r + 1, c)) } else { Option::None }
        },
        PortTag::Left => {
            if c > 0 { Option::Some((r, c - 1)) } else { Option::None }
        },
        PortTag::Right => {
            if c < GRID_W - 1 { Option::Some((r, c + 1)) } else { Option::None }
        },
    }
}

// Get the opposite port direction
fn opposite_port(port: PortTag) -> PortTag {
    match port {
        PortTag::Up => PortTag::Down,
        PortTag::Down => PortTag::Up,
        PortTag::Left => PortTag::Right,
        PortTag::Right => PortTag::Left,
    }
}

// Get port intent for a node (what it wants to do with ports)
fn get_port_intent(grid: @GridState, node: @NodeState, r: u32, c: u32) -> Option<PortIntent> {
    // Fetch instruction
    match get_program(grid, r, c) {
        Option::Some(prog) => {
            // Auto-wrap PC if program is not empty
            let pc_wrapped = if prog.len() > 0 {
                (*node).pc % prog.len()
            } else {
                0
            };
            match prog.get(pc_wrapped) {
                Option::Some(inst_box) => {
                    let inst = *inst_box.unbox();
                    
                    // Check if instruction involves port communication
                    match inst.op {
                        Op::Mov => {
                            // Check for port reads
                            match inst.src {
                                Src::P(port) => {
                                    Option::Some(PortIntent {
                                        r: r,
                                        c: c,
                                        port: port,
                                        value: 0, // Value doesn't matter for reads
                                        is_read: true,
                                    })
                                },
                                _ => {
                                    // Check for port writes
                                    match inst.dst {
                                        Dst::P(port) => {
                                            // Need to evaluate source to get value
                                            match read_source(grid, node, inst.src, r, c) {
                                                Option::Some((val, _)) => {
                                                    Option::Some(PortIntent {
                                                        r: r,
                                                        c: c,
                                                        port: port,
                                                        value: val,
                                                        is_read: false,
                                                    })
                                                },
                                                Option::None => Option::None,
                                            }
                                        },
                                        _ => Option::None,
                                    }
                                }
                            }
                        },
                        Op::Add | Op::Sub | Op::Jmp | Op::Jz | Op::Jnz | Op::Jgz | Op::Jlz => {
                            // These can read from ports
                            match inst.src {
                                Src::P(port) => {
                                    Option::Some(PortIntent {
                                        r: r,
                                        c: c,
                                        port: port,
                                        value: 0,
                                        is_read: true,
                                    })
                                },
                                _ => Option::None,
                            }
                        },
                        _ => Option::None,
                    }
                },
                Option::None => Option::None,
            }
        },
        Option::None => Option::None,
    }
}

// Check if two port intents match (one read, one write on opposite sides)
fn ports_match(intent1: @PortIntent, intent2: @PortIntent) -> bool {
    // One must be read, other must be write
    if *intent1.is_read == *intent2.is_read {
        return false;
    }
    
    // Check if they are neighbors with matching ports
    match get_neighbor_coords(*intent1.r, *intent1.c, *intent1.port) {
        Option::Some((nr, nc)) => {
            if nr == *intent2.r && nc == *intent2.c {
                // intent2 must be using opposite port
                opposite_port(*intent1.port) == *intent2.port
            } else {
                false
            }
        },
        Option::None => false,
    }
}

// Find matching port intent for a given intent
fn find_matching_port(intent: @PortIntent, all_intents: @Array<PortIntent>) -> Option<@PortIntent> {
    let mut i = 0;
    while i < all_intents.len() {
        match all_intents.get(i) {
            Option::Some(other_intent_box) => {
                let other_intent = other_intent_box.unbox();
                if ports_match(intent, other_intent) {
                    return Option::Some(other_intent);
                }
            },
            Option::None => {}
        }
        i += 1;
    }
    Option::None
}

// Execute node with port matching information
fn execute_node_with_ports(grid: @GridState, node: @NodeState, r: u32, c: u32, port_intents: @Array<PortIntent>) -> Option<ExecResult> {
    // Get this node's port intent if any
    let node_intent = get_port_intent(grid, node, r, c);
    
    // Check if we have a matching port communication
    let port_match = match node_intent {
        Option::Some(intent) => find_matching_port(@intent, port_intents),
        Option::None => Option::None,
    };
    
    // Execute the instruction with port match info
    match get_program(grid, r, c) {
        Option::Some(prog) => {
            // Auto-wrap PC if program is not empty
            let pc_wrapped = if prog.len() > 0 {
                (*node).pc % prog.len()
            } else {
                0
            };
            match prog.get(pc_wrapped) {
                Option::Some(inst_box) => {
                    let inst = *inst_box.unbox();
                    execute_instruction_with_ports(grid, node, inst, r, c, port_match)
                },
                Option::None => Option::None,
            }
        },
        Option::None => Option::None,
    }
}

// Read from a source operand, returns (value, consumed_input)
fn read_source(grid: @GridState, node: @NodeState, src: Src, r: u32, c: u32) -> Option<(u32, bool)> {
    match src {
        Src::Lit(val) => Option::Some((val, false)),
        Src::Acc => Option::Some(((*node).acc, false)),
        Src::Nil => Option::Some((0, false)),
        Src::In => {
            // Only node (0,0) can read input
            if r == 0 && c == 0 {
                let cursor = *grid.in_cursor;
                if cursor < grid.in_stream.len() {
                    match grid.in_stream.get(cursor) {
                        Option::Some(val) => Option::Some((*val.unbox(), true)),
                        Option::None => Option::None
                    }
                } else {
                    Option::None  // Input exhausted, block
                }
            } else {
                Option::None  // Wrong node position
            }
        },
        Src::P(_port) => {
            // Port reads are handled in execute_instruction_with_ports
            // This function is called during intent collection, so just block
            Option::None
        },
        Src::Last => {
            // Last port communication not implemented
            Option::None
        }
    }
}

// Write to a destination operand
fn write_destination(ref node: NodeState, dst: Dst, val: u32) -> Option<u32> {
    match dst {
        Dst::Acc => {
            node.acc = val;
            node.flags = make_flags(val);
            Option::None
        },
        Dst::Nil => {
            // Discard value
            Option::None
        },
        Dst::Out => {
            // Return value to be output
            Option::Some(val)
        },
        Dst::P(_) => {
            // Port communication not implemented
            Option::None
        },
        Dst::Last => {
            // Last port communication not implemented
            Option::None
        }
    }
}

// Read from source with port match info
fn read_source_with_ports(grid: @GridState, node: @NodeState, src: Src, r: u32, c: u32, port_match: Option<@PortIntent>) -> Option<(u32, bool)> {
    match src {
        Src::P(_port) => {
            // Check if we have a matching port write
            match port_match {
                Option::Some(intent) => {
                    // Verify this is the write we're looking for
                    if !(*intent).is_read {
                        // Read the value from the matching write
                        Option::Some(((*intent).value, false))
                    } else {
                        Option::None  // Wrong type of match
                    }
                },
                Option::None => Option::None,  // No matching port
            }
        },
        _ => read_source(grid, node, src, r, c),  // Delegate to normal read
    }
}

// Write to destination with port match info
fn write_destination_with_ports(ref node: NodeState, dst: Dst, val: u32, port_match: Option<@PortIntent>) -> Option<u32> {
    match dst {
        Dst::P(_port) => {
            // Check if we have a matching port read
            match port_match {
                Option::Some(intent) => {
                    // Verify this is a read waiting for our write
                    if (*intent).is_read {
                        // Write succeeds because someone is reading
                        Option::None  // No output value, just success
                    } else {
                        Option::None  // Wrong type of match, block
                    }
                },
                Option::None => Option::None,  // No matching reader, block
            }
        },
        _ => write_destination(ref node, dst, val),  // Delegate to normal write
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::inst::{Op, Src, Dst};
    use crate::state::{create_empty_grid, create_initial_node};
    use core::array::ArrayTrait;

    // Helper to create a simple test grid with a program
    fn create_test_grid_with_program() -> GridState {
        let mut grid = create_empty_grid();
        
        // Add a simple program to node (0,0)
        let mut prog = ArrayTrait::new();
        prog.append(Inst { op: Op::Nop, src: Src::Nil, dst: Dst::Nil });
        prog.append(Inst { op: Op::Add, src: Src::Lit(5), dst: Dst::Nil });
        prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        // Clear and rebuild programs array
        grid.progs = ArrayTrait::new();
        let mut row0 = ArrayTrait::new();
        row0.append(prog);
        row0.append(ArrayTrait::new()); // Empty program at (0,1)
        let mut row1 = ArrayTrait::new();
        row1.append(ArrayTrait::new()); // Empty program at (1,0)
        row1.append(ArrayTrait::new()); // Empty program at (1,1)
        grid.progs.append(row0);
        grid.progs.append(row1);
        
        grid
    }

    #[test]
    fn test_step_cycle_nop() {
        // Test NOP instruction
        let mut grid = create_test_grid_with_program();
        
        let result = step_cycle(ref grid);
        assert_eq!(grid.cycles, 1, "Cycles should increment");
        match result {
            StepResult::Continue => assert!(true, "Should continue after NOP"),
            _ => assert!(false, "Expected Continue result"),
        }
        
        // Check that PC advanced
        match get_node(@grid, 0, 0) {
            Option::Some(node) => {
                assert_eq!(*node.pc, 1, "PC should advance after NOP");
            },
            Option::None => assert!(false, "Node should exist"),
        }
    }

    #[test]
    fn test_step_cycle_halt() {
        // Test halt detection
        let mut grid = create_empty_grid();
        
        // Create a program with just HLT
        let mut prog = ArrayTrait::new();
        prog.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        grid.progs = ArrayTrait::new();
        let mut row0 = ArrayTrait::new();
        row0.append(prog);
        row0.append(ArrayTrait::new());
        let mut row1 = ArrayTrait::new();
        row1.append(ArrayTrait::new());
        row1.append(ArrayTrait::new());
        grid.progs.append(row0);
        grid.progs.append(row1);
        
        // First step should halt node (0,0)
        let _result = step_cycle(ref grid);
        
        // All other nodes have empty programs, so they should halt too
        // This should result in all nodes halted
        let result2 = step_cycle(ref grid);
        match result2 {
            StepResult::Halted => assert!(true, "Should detect all halted"),
            _ => assert!(false, "Expected Halted result"),
        }
    }

    #[test]
    fn test_read_source() {
        // Test reading from various sources
        let grid = create_empty_grid();
        let mut node = create_initial_node();
        node.acc = 42;
        
        // Test Lit source
        match read_source(@grid, @node, Src::Lit(100), 0, 0) {
            Option::Some((val, consumed)) => {
                assert_eq!(val, 100, "Should read literal value");
                assert!(!consumed, "Literal should not consume input");
            },
            Option::None => assert!(false, "Literal read should succeed"),
        }
        
        // Test Acc source
        match read_source(@grid, @node, Src::Acc, 0, 0) {
            Option::Some((val, consumed)) => {
                assert_eq!(val, 42, "Should read accumulator value");
                assert!(!consumed, "Acc should not consume input");
            },
            Option::None => assert!(false, "Acc read should succeed"),
        }
        
        // Test Nil source
        match read_source(@grid, @node, Src::Nil, 0, 0) {
            Option::Some((val, consumed)) => {
                assert_eq!(val, 0, "Nil should read as 0");
                assert!(!consumed, "Nil should not consume input");
            },
            Option::None => assert!(false, "Nil read should succeed"),
        }
    }

    #[test]
    fn test_read_source_input() {
        // Test input reading
        let mut grid = create_empty_grid();
        grid.in_stream = array![10, 20, 30];
        grid.in_cursor = 0;
        
        let node = create_initial_node();
        
        // Test reading input at (0,0)
        match read_source(@grid, @node, Src::In, 0, 0) {
            Option::Some((val, consumed)) => {
                assert_eq!(val, 10, "Should read first input value");
                assert!(consumed, "Input should be consumed");
            },
            Option::None => assert!(false, "Input read should succeed at (0,0)"),
        }
        
        // Test reading input at wrong position
        match read_source(@grid, @node, Src::In, 1, 1) {
            Option::None => assert!(true, "Input read should fail at (1,1)"),
            Option::Some(_) => assert!(false, "Input read should fail at wrong position"),
        }
    }

    #[test]
    fn test_write_destination() {
        // Test writing to various destinations
        let mut node = create_initial_node();
        
        // Test Acc destination
        let result = write_destination(ref node, Dst::Acc, 123);
        match result {
            Option::None => assert!(true, "Acc write should return None"),
            Option::Some(_) => assert!(false, "Acc write should not return value"),
        }
        assert_eq!(node.acc, 123, "Acc should be updated");
        assert!(!node.flags.z, "Zero flag should be false");
        
        // Test Nil destination
        node.acc = 999; // Set to something else
        let result2 = write_destination(ref node, Dst::Nil, 456);
        match result2 {
            Option::None => assert!(true, "Nil write should return None"),
            Option::Some(_) => assert!(false, "Nil write should not return value"),
        }
        assert_eq!(node.acc, 999, "Acc should not change for Nil write");
        
        // Test Out destination
        let result3 = write_destination(ref node, Dst::Out, 789);
        match result3 {
            Option::Some(val) => assert_eq!(val, 789, "Out should return the value"),
            Option::None => assert!(false, "Out write should return value"),
        }
    }


    #[test]
    fn test_port_intent_collection() {
        // Test that port intents are correctly identified
        let mut grid = create_empty_grid();
        let node = create_initial_node();
        
        // Test write intent
        let mut prog_write = ArrayTrait::new();
        prog_write.append(Inst { op: Op::Mov, src: Src::Lit(42), dst: Dst::P(PortTag::Right) });
        
        grid.progs = ArrayTrait::new();
        let mut row0 = ArrayTrait::new();
        row0.append(prog_write);
        row0.append(ArrayTrait::new());
        grid.progs.append(row0);
        grid.progs.append(ArrayTrait::new());
        
        match get_port_intent(@grid, @node, 0, 0) {
            Option::Some(intent) => {
                assert_eq!(intent.r, 0, "Row should be 0");
                assert_eq!(intent.c, 0, "Col should be 0");
                assert!(!intent.is_read, "Should be a write");
                assert_eq!(intent.value, 42, "Value should be 42");
            },
            Option::None => assert!(false, "Should get write intent"),
        }
    }

    #[test]
    fn test_ports_match() {
        // Test the port matching logic
        let intent1 = PortIntent {
            r: 0,
            c: 0,
            port: PortTag::Right,
            value: 42,
            is_read: false,  // Write
        };
        
        let intent2 = PortIntent {
            r: 0,
            c: 1,
            port: PortTag::Left,
            value: 0,
            is_read: true,  // Read
        };
        
        assert!(ports_match(@intent1, @intent2), "Should match write right with read left");
        assert!(ports_match(@intent2, @intent1), "Should match in reverse order too");
        
        // Test non-matching
        let intent3 = PortIntent {
            r: 0,
            c: 1,
            port: PortTag::Right,  // Wrong port
            value: 0,
            is_read: true,
        };
        
        assert!(!ports_match(@intent1, @intent3), "Should not match with wrong port");
    }

    #[test]
    fn test_port_communication() {
        // Test port communication between nodes
        let mut grid = create_empty_grid();
        
        // Node (0,0): MOV 42, RIGHT
        let mut prog00 = ArrayTrait::new();
        prog00.append(Inst { op: Op::Mov, src: Src::Lit(42), dst: Dst::P(PortTag::Right) });
        prog00.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        // Node (0,1): MOV LEFT, ACC
        let mut prog01 = ArrayTrait::new();
        prog01.append(Inst { op: Op::Mov, src: Src::P(PortTag::Left), dst: Dst::Acc });
        prog01.append(Inst { op: Op::Hlt, src: Src::Nil, dst: Dst::Nil });
        
        // Set up grid with programs
        grid.progs = ArrayTrait::new();
        let mut row0 = ArrayTrait::new();
        row0.append(prog00);
        row0.append(prog01);
        let mut row1 = ArrayTrait::new();
        row1.append(ArrayTrait::new());
        row1.append(ArrayTrait::new());
        grid.progs.append(row0);
        grid.progs.append(row1);
        
        // Execute one cycle - both nodes should execute their MOV in same cycle
        let result = step_cycle(ref grid);
        match result {
            StepResult::Continue => assert!(true, "Should continue after port communication"),
            _ => assert!(false, "Expected Continue result"),
        }
        
        // Check that node (0,1) received the value
        match get_node(@grid, 0, 1) {
            Option::Some(node) => {
                assert_eq!(*node.acc, 42, "Node (0,1) should have received 42");
                assert_eq!(*node.pc, 1, "Both nodes should advance PC");
            },
            Option::None => assert!(false, "Node should exist"),
        }
        
        // Check that both nodes advanced
        match get_node(@grid, 0, 0) {
            Option::Some(node) => {
                assert_eq!(*node.pc, 1, "Node (0,0) should also advance PC");
            },
            Option::None => assert!(false, "Node should exist"),
        }
    }

}