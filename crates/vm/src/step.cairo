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