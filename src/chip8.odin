package main

import "core:os"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

DISPLAY_WIDTH :: 64
DISPLAY_HEIGHT :: 32
DISPLAY_SCALE :: 16

FONT_ADDRESS :: 0x50
FONT_SIZE :: 0x50
FONT_CHARACTER_SIZE :: 0x5

ROM_ADDRESS :: 0x200
ROM_SIZE :: 0xE00

TARGET_FPS :: 60
INSTRUCTIONS_PER_SECOND :: 700
DEFAULT_INSTRUCTIONS_PER_FRAME :: INSTRUCTIONS_PER_SECOND / TARGET_FPS
MAX_INSTRUCTIONS_PER_FRAME :: 64
MIN_INSTRUCTIONS_PER_FRAME :: 1

chip8_state :: struct {
	// Interpreter state
	memory: [4096]u8, // 4 KiB memory, zero-initialized
	display: [DISPLAY_WIDTH * DISPLAY_HEIGHT]bool,
	pc: u16, // Program counter
	i_reg: u16, // Index register
	v_reg: [16]u8, // Variable registers
	stack: [16]u16,
	sp: u8, // Stack pointer
	delay_timer: u8,
	sound_timer: u8,

	// Application state
	instructions_per_frame: u8,
	rom_path: string
}

@(private="file")
state: chip8_state

@(private="file")
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
	if chip8_init() {
		chip8_run()
		chip8_shut_down()
	}
}

chip8_init :: proc() -> bool {
	// Load font
	copy(state.memory[FONT_ADDRESS:FONT_ADDRESS + FONT_SIZE], font)

	// Load ROM
	state.rom_path = os.args[1]
	file, err := os.open(state.rom_path)
	if err != os.ERROR_NONE {
		fmt.println("Failed to open ROM:", state.rom_path)
		os.close(file)
		return false
	}

	total_read: int
	total_read, err = os.read(file, state.memory[ROM_ADDRESS:ROM_ADDRESS +
		ROM_SIZE])
	if err != os.ERROR_NONE {
		fmt.println("Failed to read data from ROM:", state.rom_path)
		os.close(file)
		return false
	}

	state.pc = ROM_ADDRESS
	state.instructions_per_frame = DEFAULT_INSTRUCTIONS_PER_FRAME

	// Create window
	rl.InitWindow(DISPLAY_WIDTH * DISPLAY_SCALE, DISPLAY_HEIGHT * DISPLAY_SCALE,
		"chip8-odin")
	rl.SetTargetFPS(TARGET_FPS)

	audio_init()
	return true
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

	// Set variable register x to immediate
	case 0x6:
		state.v_reg[x] = nn

	// Add immediate to variable register x
	case 0x7:
		state.v_reg[x] += nn

	case 0x8:
		switch n {
		// Set variable register x to variable register y
		case 0x0:
			state.v_reg[x] = state.v_reg[y]

		// OR variable registers x and y
		case 0x1:
			state.v_reg[x] |= state.v_reg[y]

		// AND variable registers x and y
		case 0x2:
			state.v_reg[x] &= state.v_reg[y]

		// XOR variable registers x and y
		case 0x3:
			state.v_reg[x] ~= state.v_reg[y]

		// Add variable registers x and y
		case 0x4:
			sum: u16 = u16(state.v_reg[x]) + u16(state.v_reg[y])
			if sum > 255 {
				state.v_reg[0xF] = 1
			} else {
				state.v_reg[0xF] = 0
			}
			state.v_reg[x] = u8(sum)

		// Subtract variable register y from variable register x
		case 0x5:
			state.v_reg[0xF] = state.v_reg[x] > state.v_reg[y] ? 1 : 0
			state.v_reg[x] -= state.v_reg[y]

		// Shift variable register x right one
		case 0x6:
			if state.v_reg[x] & 0x1 == 1 {
				state.v_reg[0xF] = 1
			} else {
				state.v_reg[0xF] = 0
			}
			state.v_reg[x] >>= 1

		// Subtract variable register x from variable register y
		case 0x7:
			state.v_reg[0xF] = state.v_reg[y] > state.v_reg[x] ? 1 : 0
			state.v_reg[x] = state.v_reg[y] - state.v_reg[x]

		// Shift variable register x left one
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

	// Set index register to immediate
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
			if is_hex_key_down(state.v_reg[x]) {
				state.pc += 2
			}

		// Skip one instruction if key named in variable register x is up
		case 0xA1:
			if !is_hex_key_down(state.v_reg[x]) {
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
				if is_hex_key_down(u8(key)) {
					state.v_reg[x] = u8(key)
					return true
				}
			}
			state.pc -= 2

		// Set value of delay timer to value of variable register x
		case 0x15:
			state.delay_timer = state.v_reg[x]

		// Set value of sound timer to value of variable register x
		case 0x18:
			state.sound_timer = state.v_reg[x]

		// Add value in variable register x to index register
		case 0x1E:
			state.i_reg += u16(state.v_reg[x])

		// Set index register to point to sprite address of font character in
		// register x 
		case 0x29:
			character: u8 = state.v_reg[x]
			state.i_reg = FONT_ADDRESS + u16(character) * FONT_CHARACTER_SIZE

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

		// Store values in registers 0 to x in memory starting at address in
		// index register
		case 0x55:
			for offset in 0x0..=x {
				value := state.v_reg[offset]
				address := state.i_reg + u16(offset)
				state.memory[address] = value
			}
		
		// Load values into registers 0 to x from memory starting at address in
		// index register
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
	state.instructions_per_frame = DEFAULT_INSTRUCTIONS_PER_FRAME

	for !rl.WindowShouldClose() {
		// chip8 keypad
		input_update()

		// Debug keys
		if rl.IsKeyPressed(rl.KeyboardKey.P) {
			is_paused = !is_paused
		}

		if rl.IsKeyPressed(rl.KeyboardKey.I) {
			debug_enabled = !debug_enabled
		}

		if rl.IsKeyPressed(rl.KeyboardKey.RIGHT_BRACKET) {
			if state.instructions_per_frame < MAX_INSTRUCTIONS_PER_FRAME {
				state.instructions_per_frame += 1
			}
		}

		if rl.IsKeyPressed(rl.KeyboardKey.LEFT_BRACKET) {
			if state.instructions_per_frame > MIN_INSTRUCTIONS_PER_FRAME {
				state.instructions_per_frame -= 1
			}
		}

		// Update
		rl.BeginDrawing()
		if !is_paused {
			for i in 0..=state.instructions_per_frame {
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

		// Audio
		should_play := (state.sound_timer > 0) && !is_paused
		audio_update(should_play)

		// Render
		render_display(&state.display)
		if debug_enabled {
			render_debug(&state)
		}

		rl.EndDrawing()
	}
}

decrement_timers :: proc() {
	delay: i16 = i16(state.delay_timer) - 1
	delay = max(delay, 0)
	state.delay_timer = u8(delay)

	sound: i16 = i16(state.sound_timer) - 1
	sound = max(sound, 0)
	state.sound_timer = u8(sound)
}

chip8_shut_down :: proc() {
	audio_shut_down()
	rl.CloseWindow()
}
