## Tetris in Mips Assembly

![Demo](out.gif)

## Implementation Details
- Mutable globals maintain the current and shadow piece state, gravity timing, the random bag buffers, and line-clear scratch space.
- Registers `$s7` and `$s6` act as global variables: `$s7` caches the framebuffer base address, while `$s6` toggles shadow rendering so that the draw and erase routines can be shared to handle both piece types.
- Movement routines follow an erase-update-redraw flow (`erase_piece`, coordinate mutation, `draw_piece`).
- `handle_Harddrop` copies the shadow metadata into the active piece, redraws, and marks the piece as dropped for the next spawn.
- `handle_line_clear` performs a two-phase "condensation": collect surviving rows into buffers, wipe the grid, then redraw the compressed stack of tetrominoes.

## Closing
- Runs on "MARS" - a MIPS CPU simulator
- Made for CSCB58 (Computer Organization) at University of Toronto
- Significant parts of the source are removed due to University guidelines
