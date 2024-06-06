package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

debug_x_pos: i32
debug_y_pos: i32
DEBUG_FONT_SIZE :: 2 * DISPLAY_SCALE
DEBUG_FONT_COLOR :: rl.MAGENTA

render_display :: proc(display: ^[DISPLAY_WIDTH * DISPLAY_HEIGHT]bool) {
	rl.ClearBackground(rl.BLACK)

	for y in 0..<DISPLAY_HEIGHT {
		for x in 0..<DISPLAY_WIDTH {
			if display[y * DISPLAY_WIDTH + x] {
				rl.DrawRectangle(i32(x * DISPLAY_SCALE), i32(y * DISPLAY_SCALE),
					DISPLAY_SCALE, DISPLAY_SCALE, rl.WHITE)
			}
		}
	}
}

render_debug :: proc(state: ^chip8_state) {
	// Darken chip8 display when drawing debug text on top
	tint_color: rl.Color = {0x0, 0x0, 0x0, 0xB0}
	rl.DrawRectangle(0, 0, DISPLAY_WIDTH * DISPLAY_SCALE, DISPLAY_HEIGHT *
		DISPLAY_SCALE, tint_color)

	debug_x_pos = 0
	debug_y_pos = 0

	draw_debug_text :: proc(text: string) {
		rl.DrawText(strings.clone_to_cstring(text), debug_x_pos, debug_y_pos,
			DEBUG_FONT_SIZE, DEBUG_FONT_COLOR)
		debug_y_pos += DEBUG_FONT_SIZE
	}

	// Draw program counter, next instruction, index register, and timers on
	// left side
	pc_text := fmt.aprintf("PC: 0x%3X", state.pc)
	draw_debug_text(pc_text)

	instruction: u16 = (u16(state.memory[state.pc]) << 8) |
		u16(state.memory[state.pc + 1])
	instruction_text := fmt.aprintf("INST: 0x%4X", instruction)
	draw_debug_text(instruction_text)

	i_reg_text := fmt.aprintf("I: 0x%3X", state.i_reg)
	draw_debug_text(i_reg_text)

	dt_text := fmt.aprintf("DT: %d", state.delay_timer)
	draw_debug_text(dt_text)

	st_text := fmt.aprintf("ST: %d", state.sound_timer)
	draw_debug_text(st_text)

	// Draw stack below
	sp_text := fmt.aprintf("SP: %d", state.sp)
	draw_debug_text(sp_text)

	draw_debug_text("Stack:")

	if state.sp == 0 {
		draw_debug_text("EMPTY")
	} else {
		for i in 0..<state.sp {
			stack_text := fmt.aprintf("%d: 0x%3X", i, state.stack[i])
			draw_debug_text(stack_text)
		}
	}

	// Draw instructions per frame in top center
	debug_x_pos = (DISPLAY_WIDTH / 2 - 3) * DISPLAY_SCALE
	debug_y_pos = 0
	ipf_text := fmt.aprintf("IPF: %d", state.instructions_per_frame)
	draw_debug_text(ipf_text)

	// Draw variable registers on right side
	debug_x_pos = (DISPLAY_WIDTH - 10) * DISPLAY_SCALE
	debug_y_pos = 0
	for i in 0x0..=0xF {
		v_reg_text := fmt.aprintf("V%X: 0x%2X", i, state.v_reg[i])
		draw_debug_text(v_reg_text)
	}
}
