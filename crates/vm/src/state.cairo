use core::option::Option;
use core::array::ArrayTrait;

use super::inst::Inst;

pub const GRID_W: u32 = 2;
pub const GRID_H: u32 = 2;

#[derive(Copy, Drop)]
pub enum Port { 
    Up,
    Down,
    Left,
    Right,
}

#[derive(Copy, Drop)]
pub struct Flags {
    pub z: bool, // acc == 0
    pub n: bool, // acc < 0 (we treat i32 via wrapping semantics; n means high bit set)
}

#[derive(Copy, Drop)]
pub struct NodeState {
    pub acc: u32,               // interpret as i32 in host if needed
    pub bak: u32,
    pub pc: u32,
    pub last: Option<Port>,
    pub flags: Flags,
    pub halted: bool,
    pub blocked: bool,
    // Program memory is external (held in GridState)
}

#[derive(Copy, Drop)]
pub struct Score {
    pub cycles: u64,
    pub msgs: u64,
    pub nodes_used: u32,
}

#[derive(Copy, Drop)]
pub enum StepResult {
    Continue,
    Halted,    // all nodes halted
    Deadlock,  // all non-halted blocked this cycle
}

// Grid holds programs, node states, in/out streams, and score counters.
// Using Array instead of fixed-size arrays for mutability
#[derive(Drop)]
pub struct GridState {
    pub nodes: Array<Array<NodeState>>,      // 2x2 grid of nodes
    pub progs: Array<Array<Array<Inst>>>,    // 2x2 grid of programs
    pub in_stream: Array<u32>,               // read by (0,0)
    pub in_cursor: u32,
    pub out_stream: Array<u32>,             // written by (1,1)
    // score counters
    pub cycles: u64,
    pub msgs: u64,
}

// Helper to create initial node state
pub fn create_initial_node() -> NodeState {
    NodeState {
        acc: 0,
        bak: 0,
        pc: 0,
        last: Option::None,
        flags: Flags { z: true, n: false },
        halted: false,
        blocked: false,
    }
}

// Helper to create an empty 2x2 grid state
pub fn create_empty_grid() -> GridState {
    let mut nodes = ArrayTrait::new();
    let mut progs = ArrayTrait::new();
    
    // Create 2 rows
    let mut row_idx = 0_u32;
    while row_idx < GRID_H {
        let mut node_row = ArrayTrait::new();
        let mut prog_row = ArrayTrait::new();
        
        // Create 2 columns
        let mut col_idx = 0_u32;
        while col_idx < GRID_W {
            node_row.append(create_initial_node());
            prog_row.append(ArrayTrait::new()); // Empty program
            col_idx += 1;
        }
        
        nodes.append(node_row);
        progs.append(prog_row);
        row_idx += 1;
    }
    
    GridState {
        nodes: nodes,
        progs: progs,
        in_stream: ArrayTrait::new(),
        in_cursor: 0,
        out_stream: ArrayTrait::new(),
        cycles: 0,
        msgs: 0,
    }
}

// Helpers
pub fn make_flags(acc: u32) -> Flags {
    let is_zero = acc == 0_u32;
    // "negative" when top bit is 1 (treating u32 as i32)
    let msb = (acc / 0x80000000_u32) & 1_u32;  // equivalent to >> 31
    Flags { z: is_zero, n: msb == 1_u32 }
}

pub fn within_grid(r: u32, c: u32) -> bool {
    r < GRID_H && c < GRID_W
}

// Get node at position (r, c) - returns Option since array access can fail
pub fn get_node(grid: @GridState, r: u32, c: u32) -> Option<@NodeState> {
    match grid.nodes.get(r) {
        Option::Some(row_box) => {
            let row = row_box.unbox();
            match row.get(c) {
                Option::Some(node) => Option::Some(node.unbox()),
                Option::None => Option::None,
            }
        },
        Option::None => Option::None,
    }
}

// Get program at position (r, c)
pub fn get_program(grid: @GridState, r: u32, c: u32) -> Option<@Array<Inst>> {
    match grid.progs.get(r) {
        Option::Some(row_box) => {
            let row = row_box.unbox();
            match row.get(c) {
                Option::Some(prog) => Option::Some(prog.unbox()),
                Option::None => Option::None,
            }
        },
        Option::None => Option::None,
    }
}