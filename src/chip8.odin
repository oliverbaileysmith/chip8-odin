package main

import "core:os"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

DISPLAY_WIDTH :: 64
DISPLAY_HEIGHT :: 32
DISPLAY_SCALE :: 16

INSTRUCTIONS_PER_SECOND :: 700
TARGET_INSTRUCTION_TIME :: 1 / INSTRUCTIONS_PER_SECOND

// TODO: Configurable ROM loading
ROM_PATH :: "roms/IBM Logo.ch8"

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
}

chip8_decode :: proc() -> bool {
	// Fetch instruction
	instruction: u16 = (u16(state.memory[state.pc]) << 8) |
	u16(state.memory[state.pc + 1])
	fmt.printfln("instruction: 0x%X", instruction)

	type: u8 = u8(instruction >> 12) // First 4 bits
	x: u8 = u8((instruction & 0x0F00) >> 8) // Second 4 bits
	y: u8 = u8((instruction & 0x00F0) >> 4) // Third 4 bits
	n: u8 = u8(instruction & 0x000F) // Last 4 bits
	nn: u8 = u8(instruction & 0x00FF) // Last 8 bits
	nnn: u16 = instruction & 0x0FFF // Last 12 bits
	fmt.printfln("details: 0x%X, 0x%X, 0x%X, 0x%X, 0x%X, 0x%X", type, x, y, n,
		nn, nnn)

	state.pc += 2

	switch type {
	case 0x0:
		// Clear display
		if instruction == 0x00E0 {
			fmt.println("Clearing display")
			mem.zero(&state.display, DISPLAY_WIDTH * DISPLAY_HEIGHT)
		// Return from subroutine
		/*
		} else if instruction == 0x00EE {
			state.pc = state.stack[state.sp]
			state.stack[state.sp] = 0
			state.sp -= 1
		*/
		} else {
			fmt.printfln("Unrecognized instruction 0x%X", instruction)
			return false
		}

	// Jump
	case 0x1:
		fmt.printfln("Jumping to 0x%X", nnn)
		state.pc = nnn

	// Call subroutine
	/*
	case 0x2:
		state.stack[state.sp] = state.pc
		state.sp += 1
		state.pc = nnn
	*/

	// Set variable register
	case 0x6:
		fmt.printfln("Setting register 0x%X to 0x%X", x, nn)
		state.v_reg[x] = nn

	// Add to variable register
	case 0x7:
		fmt.printfln("Adding 0x%X to 0x%X", nn, x)
		state.v_reg[x] += nn

	// Set index register
	case 0xA:
		fmt.printfln("Setting index register to 0x%X", nnn)
		state.i_reg = nnn

	// Draw
	case 0xD:
		state.v_reg[0xF] = 0
		sprite_x_pos := state.v_reg[x] % DISPLAY_WIDTH
		sprite_y_pos := state.v_reg[y] % DISPLAY_HEIGHT
		fmt.printfln("Drawing %d rows at %d, %d", n, sprite_x_pos, sprite_y_pos)

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

	// Default case
	case:
		fmt.printfln("Unrecognized instruction 0x%X", instruction)
		return false
	}

	return true
}

chip8_run :: proc() {
	for !rl.WindowShouldClose() {
		start_time := rl.GetTime()

		// Update
		input_update()
		if !chip8_decode() {
			break
		}

		// Render
		render()

		// Limit instructions per second by blocking
		end_time := rl.GetTime()
		elapsed_time := end_time - start_time

		if (elapsed_time) < TARGET_INSTRUCTION_TIME {
			wait_time := TARGET_INSTRUCTION_TIME - elapsed_time
			rl.WaitTime(wait_time)
		}
	}
}

chip8_shut_down :: proc() {
	rl.CloseWindow()
}

render :: proc() {
	rl.BeginDrawing()
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
	rl.EndDrawing()
}
