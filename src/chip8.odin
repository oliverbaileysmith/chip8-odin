package main

import "core:os"
import "core:fmt"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

DISPLAY_WIDTH :: 64
DISPLAY_HEIGHT :: 32
DISPLAY_SCALE :: 16

TARGET_FPS :: 60
INSTRUCTIONS_PER_SECOND :: 700
INSTRUCTIONS_PER_FRAME :: INSTRUCTIONS_PER_SECOND / TARGET_FPS

// TODO: Configurable ROM loading
ROM_PATH :: "roms/TETRIS"

chip8_state :: struct {
	memory: [4096]u8, // 4 KiB memory, zero-initialized
	display: [DISPLAY_WIDTH * DISPLAY_HEIGHT]bool,
	pc: u16, // Program counter
	i_reg: u16, // Index register
	v_reg: [16]u8, // Variable registers
	stack: [16]u16,
	sp: u8, // Stack pointer
	delay_timer: u8,
	sound_timer: u8
}

@(private="file")
state: chip8_state

font := []u8 {
	0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
	0x20, 0x60, 0x20, 0x20, 0x70, // 1
	0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
	0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
	0x90, 0x90, 0xF0, 0x10, 0x10, // 4
	0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
	0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
	0xF0, 0x10, 0x20, 0x40, 0x40, // 7
	0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
	0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
	0xF0, 0x90, 0xF0, 0x90, 0x90, // A
	0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
	0xF0, 0x80, 0x80, 0x80, 0xF0, // C
	0xE0, 0x90, 0x90, 0x90, 0xE0, // D
	0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
	0xF0, 0x80, 0xF0, 0x80, 0x80  // F
}

main :: proc() {
	chip8_init()
	chip8_run()
	chip8_shut_down()
}

chip8_init :: proc() {
	// Load font
	copy(state.memory[0x50:0xA0], font)

	// Load ROM
	file, err := os.open(ROM_PATH)
	if err != os.ERROR_NONE {
		fmt.println("Failed to open ROM:", ROM_PATH)
	}
	defer os.close(file)

	total_read: int
	total_read, err = os.read(file, state.memory[0x0200:0x0FFF])
	if err != os.ERROR_NONE {
		fmt.println("Failed to read data from ROM:", ROM_PATH)
	}

	state.pc = 0x200

	// Create window
	rl.InitWindow(DISPLAY_WIDTH * DISPLAY_SCALE, DISPLAY_HEIGHT * DISPLAY_SCALE,
		"chip8-odin")
	rl.SetTargetFPS(TARGET_FPS)
}

chip8_decode :: proc() -> bool {
	// Fetch instruction
	instruction: u16 = (u16(state.memory[state.pc]) << 8) |
	u16(state.memory[state.pc + 1])

	type: u8 = u8(instruction >> 12) // First 4 bits
	x: u8 = u8((instruction & 0x0F00) >> 8) // Second 4 bits
	y: u8 = u8((instruction & 0x00F0) >> 4) // Third 4 bits
	n: u8 = u8(instruction & 0x000F) // Last 4 bits
	nn: u8 = u8(instruction & 0x00FF) // Last 8 bits
	nnn: u16 = instruction & 0x0FFF // Last 12 bits

	state.pc += 2

	switch type {
	case 0x0:
		switch nn {
		// Clear display
		case 0xE0:
			mem.zero(&state.display, DISPLAY_WIDTH * DISPLAY_HEIGHT)

		// Return from subroutine
		case 0xEE:
			state.sp -= 1
			state.pc = state.stack[state.sp]
			state.stack[state.sp] = 0

		// 0nnn ignored on modern interpreters
		}

	// Jump
	case 0x1:
		state.pc = nnn

	// Call subroutine
	case 0x2:
		state.stack[state.sp] = state.pc
		state.sp += 1
		state.pc = nnn

	// Skip one instruction if value in variable register x == nn
	case 0x3:
		if state.v_reg[x] == nn {
			state.pc += 2
		}

	// Skip one instruction if value in variable register x != nn
	case 0x4:
		if state.v_reg[x] != nn {
			state.pc += 2
		}

	// Skip one instruction if values in variable registers x and y are equal
	case 0x5:
		if state.v_reg[x] == state.v_reg[y] {
			state.pc += 2
		}

	// Set variable register
	case 0x6:
		state.v_reg[x] = nn

	// Add to variable register
	case 0x7:
		state.v_reg[x] += nn

	case 0x8:
		switch n {
		// Set
		case 0x0:
			state.v_reg[x] = state.v_reg[y]

		// OR
		case 0x1:
			state.v_reg[x] |= state.v_reg[y]

		// AND
		case 0x2:
			state.v_reg[x] &= state.v_reg[y]

		// XOR
		case 0x3:
			state.v_reg[x] ~= state.v_reg[y]

		// Add
		case 0x4:
			sum: u16 = u16(state.v_reg[x]) + u16(state.v_reg[y])
			if sum > 255 {
				state.v_reg[0xF] = 1
			} else {
				state.v_reg[0xF] = 0
			}
			state.v_reg[x] = u8(sum)

		// Subtract y from x
		case 0x5:
			state.v_reg[0xF] = state.v_reg[x] > state.v_reg[y] ? 1 : 0
			state.v_reg[x] -= state.v_reg[y]

		// Shift right
		case 0x6:
			if state.v_reg[x] & 0x1 == 1 {
				state.v_reg[0xF] = 1
			} else {
				state.v_reg[0xF] = 0
			}
			state.v_reg[x] >>= 1

		// Subtract x from y
		case 0x7:
			state.v_reg[0xF] = state.v_reg[y] > state.v_reg[x] ? 1 : 0
			state.v_reg[x] = state.v_reg[y] - state.v_reg[x]

		// Shift left
		case 0xE:
			state.v_reg[0xF] = state.v_reg[x] >> 7
			state.v_reg[x] <<= 1

		// Default case
		case:
			fmt.printfln("Unrecognized instruction 0x%X", instruction)
			return false
		}

	// Skip one instruction if values in variable registers x and y are not
	// equal
	case 0x9:
		if state.v_reg[x] != state.v_reg[y] {
			state.pc += 2
		}

	// Set index register
	case 0xA:
		state.i_reg = nnn

	// Jump with offset
	case 0xB:
		state.pc = u16(state.v_reg[0x0]) + nnn

	// Random
	case 0xC:
		state.v_reg[x] = u8(rl.GetRandomValue(0, 255)) & nn

	// Draw
	case 0xD:
		state.v_reg[0xF] = 0
		sprite_x_pos := state.v_reg[x] % DISPLAY_WIDTH
		sprite_y_pos := state.v_reg[y] % DISPLAY_HEIGHT

		for row in 0..<n {
			pixel_y_pos := sprite_y_pos + row
			if pixel_y_pos >= DISPLAY_HEIGHT {
				break
			}

			sprite_row: u8 = state.memory[state.i_reg + u16(row)]

			for col in 0..<8 {
				pixel_x_pos := sprite_x_pos + u8(col)
				if pixel_x_pos >= DISPLAY_WIDTH {
					break
				}

				pixel_index: u16 = u16(pixel_y_pos) * DISPLAY_WIDTH +
					u16(pixel_x_pos)

				should_swap_pixel: bool =
					bool((sprite_row >> (7 - u8(col))) & 1)
				pixel_is_on: bool = state.display[pixel_index]

				if should_swap_pixel {
					if pixel_is_on {
						state.display[pixel_index] = false
						state.v_reg[0xF] = 1
					} else {
						state.display[pixel_index] = true
					}
				}
			}
		}

	case 0xE:
		switch nn {
		// Skip one instruction if key named in variable register x is down
		case 0x9E:
			if is_key_down(state.v_reg[x]) {
				state.pc += 2
			}

		// Skip one instruction if key named in variable register x is up
		case 0xA1:
			if !is_key_down(state.v_reg[x]) {
				state.pc += 2
			}

		// Default case
		case:
			fmt.printfln("Unrecognized instruction 0x%X", instruction)
			return false
		}

	case 0xF:
		switch nn {
		// Set value of register x to value of delay timer
		case 0x07:
			state.v_reg[x] = state.delay_timer

		// Await key press and store value in register x
		case 0x0A:
			for key in 0x0..=0xF {
				if is_key_down(u8(key)) {
					state.v_reg[x] = u8(key)
					return true
				}
			}
			state.pc -= 2

		// Set value of delay timer to value of register x
		case 0x15:
			state.delay_timer = state.v_reg[x]

		// Set value of sound timer to value of register x
		case 0x18:
			state.sound_timer = state.v_reg[x]

		// Add value in register x to index register
		case 0x1E:
			state.i_reg += u16(state.v_reg[x])

		// Set index register to point to sprite address of font character in
		// register x 
		case 0x29:
			character: u8 = state.v_reg[x]
			state.i_reg = 0x50 + u16(character) * 5

		// Store binary coded decimal representation of value in register x
		// starting at address pointed to by index register
		case 0x33:
			value: u8 = state.v_reg[x]

			ones: u8 = value % 10
			value /= 10
			tens: u8 = value % 10
			value /= 10
			hundreds: u8 = value

			state.memory[state.i_reg] = hundreds
			state.memory[state.i_reg + 1] = tens
			state.memory[state.i_reg + 2] = ones

		// Store register values in memory pointed to by index register
		case 0x55:
			for offset in 0x0..=x {
				value := state.v_reg[offset]
				address := state.i_reg + u16(offset)
				state.memory[address] = value
			}
		
		// Load register values from memory pointed to by index register
		case 0x65:
			for offset in 0x0..=x {
				address := state.i_reg + u16(offset)
				state.v_reg[offset] = state.memory[address]
			}

		// Default case
		case:
			fmt.printfln("Unrecognized instruction 0x%X", instruction)
			return false
		}

	// Default case
	case:
		fmt.printfln("Unrecognized instruction 0x%X", instruction)
		return false
	}

	return true
}

chip8_run :: proc() {
	is_paused := false
	debug_enabled := false
	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(rl.KeyboardKey.P) {
			is_paused = !is_paused
		}

		if rl.IsKeyPressed(rl.KeyboardKey.I) {
			debug_enabled = !debug_enabled
		}

		input_update()

		rl.BeginDrawing()
		if !is_paused {
			for i in 0..=INSTRUCTIONS_PER_FRAME {
				if !chip8_decode() {
					break
				}
			}
			decrement_timers()
		} else {
			if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
				if !chip8_decode() {
					break
				}
			}
			if rl.IsKeyPressed(rl.KeyboardKey.T) {
				decrement_timers()
			}
		}

		// Render
		render_display()
		if debug_enabled {
			render_debug()
		}

		rl.EndDrawing()
	}
}

decrement_timers :: proc() {
	// TODO: Verify and fix timing
	delay: i16 = i16(state.delay_timer) - 1
	delay = max(delay, 0)
	state.delay_timer = u8(delay)

	sound: i16 = i16(state.sound_timer) - 1
	sound = max(sound, 0)
	state.sound_timer = u8(sound)
}

chip8_shut_down :: proc() {
	rl.CloseWindow()
}

render_display :: proc() {
	rl.ClearBackground(rl.BLACK)

	for y in 0..<DISPLAY_HEIGHT {
		for x in 0..<DISPLAY_WIDTH {
			if state.display[y * DISPLAY_WIDTH + x] {
				rl.DrawRectangle(i32(x * DISPLAY_SCALE),
					i32(y * DISPLAY_SCALE), DISPLAY_SCALE, DISPLAY_SCALE,
				rl.WHITE)
			}
		}
	}
}

render_debug :: proc() {
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
