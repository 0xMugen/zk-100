mod inst;
mod state;
mod step;
mod check;

pub use inst::{Op, Src, Dst, Inst, PortTag};
pub use state::{
    Port, NodeState, GridState, Score, StepResult, GRID_H, GRID_W,
    create_empty_grid, create_initial_node, make_flags, within_grid,
    get_node, get_program
};
pub use step::step_cycle;
pub use check::check_target;