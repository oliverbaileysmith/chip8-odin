package main

import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

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

	x_pos: i32
	y_pos: i32
	DEBUG_FONT_SIZE :: 2 * DISPLAY_SCALE

	// Draw program counter, next instruction, index register, and timers on
	// left side
	pc_text := fmt.aprintf("PC: 0x%3X", state.pc)
	rl.DrawText(strings.clone_to_cstring(pc_text), x_pos, y_pos,
		DEBUG_FONT_SIZE, rl.MAGENTA)
	y_pos += DEBUG_FONT_SIZE

	instruction: u16 = (u16(state.memory[state.pc]) << 8) |
		u16(state.memory[state.pc + 1])
	instruction_text := fmt.aprintf("INST: 0x%4X", instruction)
	rl.DrawText(strings.clone_to_cstring(instruction_text), x_pos, y_pos,
		DEBUG_FONT_SIZE, rl.MAGENTA)
	y_pos += DEBUG_FONT_SIZE

	i_reg_text := fmt.aprintf("I: 0x%3X", state.i_reg)
	rl.DrawText(strings.clone_to_cstring(i_reg_text), x_pos, y_pos,
		DEBUG_FONT_SIZE, rl.MAGENTA)
	y_pos += DEBUG_FONT_SIZE

	dt_text := fmt.aprintf("DT: %d", state.delay_timer)
	rl.DrawText(strings.clone_to_cstring(dt_text), x_pos, y_pos,
		DEBUG_FONT_SIZE, rl.MAGENTA)
	y_pos += DEBUG_FONT_SIZE

	st_text := fmt.aprintf("ST: %d", state.sound_timer)
	rl.DrawText(strings.clone_to_cstring(st_text), x_pos, y_pos,
		DEBUG_FONT_SIZE, rl.MAGENTA)
	y_pos += DEBUG_FONT_SIZE

	// Draw stack below
	sp_text := fmt.aprintf("SP: %d", state.sp)
	rl.DrawText(strings.clone_to_cstring(sp_text), x_pos, y_pos,
		DEBUG_FONT_SIZE, rl.MAGENTA)
	y_pos += DEBUG_FONT_SIZE

	rl.DrawText("Stack:", x_pos, y_pos, DEBUG_FONT_SIZE, rl.MAGENTA)
	y_pos += DEBUG_FONT_SIZE

	if state.sp == 0 {
		rl.DrawText("EMPTY", x_pos, y_pos, DEBUG_FONT_SIZE, rl.MAGENTA)
	} else {
		for i in 0..<state.sp {
			stack_text := fmt.aprintf("%d: 0x%3X", i, state.stack[i])
			rl.DrawText(strings.clone_to_cstring(stack_text), x_pos, y_pos,
				DEBUG_FONT_SIZE, rl.MAGENTA)
			y_pos += DEBUG_FONT_SIZE
		}
	}

	// Draw instructions per frame in top center
	x_pos = (DISPLAY_WIDTH / 2 - 3) * DISPLAY_SCALE
	y_pos = 0
	ipf_text := fmt.aprintf("IPF: %d", state.instructions_per_frame)
	rl.DrawText(strings.clone_to_cstring(ipf_text), x_pos, y_pos,
		DEBUG_FONT_SIZE, rl.MAGENTA)

	// Draw variable registers on right side
	x_pos = (DISPLAY_WIDTH - 10) * DISPLAY_SCALE
	y_pos = 0
	for i in 0x0..=0xF {
		v_reg_text := fmt.aprintf("V%X: 0x%2X", i, state.v_reg[i])
		rl.DrawText(strings.clone_to_cstring(v_reg_text), x_pos, y_pos,
			DEBUG_FONT_SIZE, rl.MAGENTA)
		y_pos += DEBUG_FONT_SIZE
	}
}
