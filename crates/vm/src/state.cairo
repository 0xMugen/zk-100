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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::inst::{Op, Src, Dst};

    #[test]
    fn test_port_enum() {
        // Test Port enum creation
        let _up = Port::Up;
        let _down = Port::Down;
        let _left = Port::Left;
        let _right = Port::Right;
        assert!(true, "All Port variants created");
    }

    #[test]
    fn test_flags_creation() {
        // Test flag creation
        let flags_zero = Flags { z: true, n: false };
        let flags_neg = Flags { z: false, n: true };
        let flags_pos = Flags { z: false, n: false };
        
        assert!(flags_zero.z, "Zero flag set correctly");
        assert!(!flags_zero.n, "Negative flag not set for zero");
        assert!(!flags_neg.z, "Zero flag not set for negative");
        assert!(flags_neg.n, "Negative flag set correctly");
    }

    #[test]
    fn test_make_flags() {
        // Test make_flags helper function
        // Test zero
        let flags_zero = make_flags(0);
        assert!(flags_zero.z, "Zero flag should be true for 0");
        assert!(!flags_zero.n, "Negative flag should be false for 0");
        
        // Test positive number
        let flags_pos = make_flags(42);
        assert!(!flags_pos.z, "Zero flag should be false for 42");
        assert!(!flags_pos.n, "Negative flag should be false for 42");
        
        // Test negative number (high bit set)
        let flags_neg = make_flags(0x80000001); // MSB set
        assert!(!flags_neg.z, "Zero flag should be false");
        assert!(flags_neg.n, "Negative flag should be true when MSB set");
    }

    #[test]
    fn test_node_state_creation() {
        // Test creating initial node state
        let node = create_initial_node();
        assert_eq!(node.acc, 0, "Initial accumulator should be 0");
        assert_eq!(node.bak, 0, "Initial backup should be 0");
        assert_eq!(node.pc, 0, "Initial PC should be 0");
        assert!(node.flags.z, "Initial zero flag should be true");
        assert!(!node.flags.n, "Initial negative flag should be false");
        assert!(!node.halted, "Initial halted should be false");
        assert!(!node.blocked, "Initial blocked should be false");
        
        // Test last port is None
        match node.last {
            Option::None => assert!(true, "Initial last port should be None"),
            Option::Some(_) => assert!(false, "Initial last port should be None"),
        }
    }

    #[test]
    fn test_score_struct() {
        // Test Score struct
        let score = Score {
            cycles: 100,
            msgs: 5,
            nodes_used: 3,
        };
        assert_eq!(score.cycles, 100, "Cycles set correctly");
        assert_eq!(score.msgs, 5, "Messages set correctly");
        assert_eq!(score.nodes_used, 3, "Nodes used set correctly");
    }

    #[test]
    fn test_within_grid() {
        // Test grid boundary checking
        assert!(within_grid(0, 0), "0,0 should be within grid");
        assert!(within_grid(0, 1), "0,1 should be within grid");
        assert!(within_grid(1, 0), "1,0 should be within grid");
        assert!(within_grid(1, 1), "1,1 should be within grid");
        
        assert!(!within_grid(2, 0), "2,0 should be outside grid");
        assert!(!within_grid(0, 2), "0,2 should be outside grid");
        assert!(!within_grid(2, 2), "2,2 should be outside grid");
        assert!(!within_grid(100, 100), "100,100 should be outside grid");
    }

    #[test]
    fn test_create_empty_grid() {
        // Test empty grid creation
        let grid = create_empty_grid();
        
        assert_eq!(grid.cycles, 0, "Initial cycles should be 0");
        assert_eq!(grid.msgs, 0, "Initial messages should be 0");
        assert_eq!(grid.in_cursor, 0, "Initial input cursor should be 0");
        assert_eq!(grid.in_stream.len(), 0, "Initial input stream should be empty");
        assert_eq!(grid.out_stream.len(), 0, "Initial output stream should be empty");
        assert_eq!(grid.nodes.len(), GRID_H, "Grid should have correct height");
        assert_eq!(grid.progs.len(), GRID_H, "Programs should have correct height");
        
        // Check each row
        let mut r = 0;
        while r < GRID_H {
            match grid.nodes.get(r) {
                Option::Some(row) => {
                    assert_eq!(row.unbox().len(), GRID_W, "Node row should have correct width");
                },
                Option::None => assert!(false, "Node row should exist"),
            }
            match grid.progs.get(r) {
                Option::Some(row) => {
                    assert_eq!(row.unbox().len(), GRID_W, "Program row should have correct width");
                },
                Option::None => assert!(false, "Program row should exist"),
            }
            r += 1;
        }
    }

    #[test]
    fn test_get_node() {
        // Test node access
        let grid = create_empty_grid();
        
        // Test valid positions
        match get_node(@grid, 0, 0) {
            Option::Some(node) => {
                assert_eq!(node.acc, 0, "Node at 0,0 should have acc=0");
            },
            Option::None => assert!(false, "Node at 0,0 should exist"),
        }
        
        match get_node(@grid, 1, 1) {
            Option::Some(node) => {
                assert_eq!(node.pc, 0, "Node at 1,1 should have pc=0");
            },
            Option::None => assert!(false, "Node at 1,1 should exist"),
        }
        
        // Test invalid positions
        match get_node(@grid, 2, 0) {
            Option::None => assert!(true, "Node at 2,0 should not exist"),
            Option::Some(_) => assert!(false, "Node at 2,0 should not exist"),
        }
    }

    #[test]
    fn test_get_program() {
        // Test program access
        let grid = create_empty_grid();
        
        // Test valid positions (should have empty programs)
        match get_program(@grid, 0, 0) {
            Option::Some(prog) => {
                assert_eq!(prog.len(), 0, "Initial program at 0,0 should be empty");
            },
            Option::None => assert!(false, "Program at 0,0 should exist"),
        }
        
        // Test invalid positions
        match get_program(@grid, 3, 3) {
            Option::None => assert!(true, "Program at 3,3 should not exist"),
            Option::Some(_) => assert!(false, "Program at 3,3 should not exist"),
        }
    }
}