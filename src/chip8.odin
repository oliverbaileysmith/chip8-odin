package main

import "core:os"
import "core:fmt"
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

chip8_decode :: proc(should_redraw: ^bool) -> bool {
	// Fetch instruction
	instruction: u16 = (u16(state.memory[state.pc]) << 8) |
	u16(state.memory[state.pc + 1])
	fmt.printfln("instruction: 0x%X", instruction)

	type := instruction >> 12
	x := (instruction & 0x0F00) >> 8
	y := (instruction & 0x00F0) >> 4
	n := instruction & 0x000F
	nn := instruction & 0x00FF
	nnn := instruction & 0x0FFF
	fmt.printfln("details: 0x%X, 0x%X, 0x%X, 0x%X, 0x%X, 0x%X", type, x, y, n,
		nn, nnn)

	state.pc += 2

	// TODO: Decode and execute instruction
	switch type {
	case 0x0:
		if instruction == 0x00E0 {
			should_redraw^ = true
		}
	case:
		fmt.printfln("Unrecognized instruction 0x%X", instruction)
		return false
	}

	return true
}

chip8_run :: proc() {
	for !rl.WindowShouldClose() {
		start_time := rl.GetTime()
		should_redraw := false

		// Update
		input_update()
		if !chip8_decode(&should_redraw) {
			break
		}

		// Render
		if should_redraw {
			render()
		}

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
