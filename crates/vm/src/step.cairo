use core::bool::{True, False};
use core::option::Option;
use core::array::ArrayTrait;

use super::inst::{Inst, Op, Src, Dst};
use super::state::{
    GridState, NodeState, StepResult,
    GRID_H, GRID_W, get_node, get_program, make_flags
};

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
    let mut new_nodes: Array<Array<NodeState>> = ArrayTrait::new();
    
    // Process each node
    let mut r = 0_u32;
    while r < GRID_H {
        let mut new_row: Array<NodeState> = ArrayTrait::new();
        let mut c = 0_u32;
        while c < GRID_W {
            match get_node(@grid, r, c) {
                Option::Some(node) => {
                    if !(*node).halted {
                        all_halted = False;
                        
                        // Try to execute instruction
                        match execute_node_step(@grid, node, r, c) {
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

// Execute one instruction for a node
fn execute_node_step(grid: @GridState, node: @NodeState, r: u32, c: u32) -> Option<ExecResult> {
    // Fetch instruction
    match get_program(grid, r, c) {
        Option::Some(prog) => {
            match prog.get((*node).pc) {
                Option::Some(inst_box) => {
                    let inst = *inst_box.unbox();
                    execute_instruction(grid, node, inst, r, c)
                },
                Option::None => Option::None  // PC out of bounds
            }
        },
        Option::None => Option::None
    }
}

// Execute a single instruction
fn execute_instruction(grid: @GridState, node: @NodeState, inst: Inst, r: u32, c: u32) -> Option<ExecResult> {
    let mut new_node = *node;
    let mut blocked = false;
    let mut output: Option<u32> = Option::None;
    let mut consumed_input = false;
    
    match inst.op {
        Op::Nop => {
            new_node.pc += 1;
        },
        Op::Hlt => {
            new_node.halted = true;
        },
        Op::Mov => {
            match read_source(grid, @new_node, inst.src, r, c) {
                Option::Some((val, consumed)) => {
                    consumed_input = consumed;
                    match write_destination(ref new_node, inst.dst, val) {
                        Option::Some(out_val) => {
                            output = Option::Some(out_val);
                            new_node.pc += 1;
                        },
                        Option::None => {
                            blocked = true;
                        }
                    }
                },
                Option::None => {
                    blocked = true;
                }
            }
        },
        Op::Add => {
            match read_source(grid, @new_node, inst.src, r, c) {
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
            match read_source(grid, @new_node, inst.src, r, c) {
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
            new_node.acc = 0_u32 - new_node.acc;  // Two's complement negation
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
            match read_source(grid, @new_node, inst.src, r, c) {
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
                match read_source(grid, @new_node, inst.src, r, c) {
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
                match read_source(grid, @new_node, inst.src, r, c) {
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
                match read_source(grid, @new_node, inst.src, r, c) {
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
                match read_source(grid, @new_node, inst.src, r, c) {
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
        Src::P(_) => {
            // Port communication not implemented in this simple version
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
    fn test_execute_add_instruction() {
        // Test ADD instruction execution
        let mut grid = create_empty_grid();
        let mut node = create_initial_node();
        node.acc = 10;
        
        let add_inst = Inst {
            op: Op::Add,
            src: Src::Lit(15),
            dst: Dst::Nil,
        };
        
        match execute_instruction(@grid, @node, add_inst, 0, 0) {
            Option::Some(result) => {
                assert_eq!(result.new_node.acc, 25, "Add should sum values");
                assert_eq!(result.new_node.pc, 1, "PC should advance");
                assert!(!result.blocked, "Should not be blocked");
                assert!(!result.new_node.flags.z, "Zero flag should be false");
            },
            Option::None => assert!(false, "Add execution should succeed"),
        }
    }

    #[test]
    fn test_execute_sub_instruction() {
        // Test SUB instruction
        let mut grid = create_empty_grid();
        let mut node = create_initial_node();
        node.acc = 20;
        
        let sub_inst = Inst {
            op: Op::Sub,
            src: Src::Lit(20),
            dst: Dst::Nil,
        };
        
        match execute_instruction(@grid, @node, sub_inst, 0, 0) {
            Option::Some(result) => {
                assert_eq!(result.new_node.acc, 0, "Sub should subtract values");
                assert!(result.new_node.flags.z, "Zero flag should be true for 0");
                assert!(!result.new_node.flags.n, "Negative flag should be false for 0");
            },
            Option::None => assert!(false, "Sub execution should succeed"),
        }
    }

    #[test]
    fn test_execute_mov_instruction() {
        // Test MOV instruction
        let mut grid = create_empty_grid();
        let node = create_initial_node();
        
        let mov_inst = Inst {
            op: Op::Mov,
            src: Src::Lit(42),
            dst: Dst::Acc,
        };
        
        match execute_instruction(@grid, @node, mov_inst, 0, 0) {
            Option::Some(result) => {
                assert_eq!(result.new_node.acc, 42, "Mov should set accumulator");
                assert_eq!(result.new_node.pc, 1, "PC should advance");
                assert!(!result.blocked, "Should not be blocked");
            },
            Option::None => assert!(false, "Mov execution should succeed"),
        }
    }

    #[test]
    fn test_execute_conditional_jumps() {
        // Test conditional jump instructions
        let grid = create_empty_grid();
        
        // Test JZ with zero flag set
        let mut node_zero = create_initial_node();
        node_zero.acc = 0;
        node_zero.flags = make_flags(0);
        
        let jz_inst = Inst {
            op: Op::Jz,
            src: Src::Lit(10),
            dst: Dst::Nil,
        };
        
        match execute_instruction(@grid, @node_zero, jz_inst, 0, 0) {
            Option::Some(result) => {
                assert_eq!(result.new_node.pc, 10, "JZ should jump when zero flag set");
            },
            Option::None => assert!(false, "JZ execution should succeed"),
        }
        
        // Test JZ with zero flag not set
        let mut node_nonzero = create_initial_node();
        node_nonzero.acc = 5;
        node_nonzero.flags = make_flags(5);
        
        match execute_instruction(@grid, @node_nonzero, jz_inst, 0, 0) {
            Option::Some(result) => {
                assert_eq!(result.new_node.pc, 1, "JZ should not jump when zero flag not set");
            },
            Option::None => assert!(false, "JZ execution should succeed"),
        }
    }
}