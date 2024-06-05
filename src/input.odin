package main

import rl "vendor:raylib"

@(private="file")
input_state : [16]bool

input_update :: proc() {
	// Key press
	if rl.IsKeyPressed(rl.KeyboardKey.X) {
		input_state[0x0] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.ONE) {
		input_state[0x1] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.TWO) {
		input_state[0x2] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.THREE) {
		input_state[0x3] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.Q) {
		input_state[0x4] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.W) {
		input_state[0x5] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.E) {
		input_state[0x6] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.A) {
		input_state[0x7] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.S) {
		input_state[0x8] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.D) {
		input_state[0x9] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.Z) {
		input_state[0xA] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.C) {
		input_state[0xB] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.FOUR) {
		input_state[0xC] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.R) {
		input_state[0xD] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.F) {
		input_state[0xE] = true
	}
	if rl.IsKeyPressed(rl.KeyboardKey.V) {
		input_state[0xF] = true
	}

	// Key release
	if rl.IsKeyReleased(rl.KeyboardKey.X) {
		input_state[0x0] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.ONE) {
		input_state[0x1] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.TWO) {
		input_state[0x2] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.THREE) {
		input_state[0x3] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.Q) {
		input_state[0x4] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.W) {
		input_state[0x5] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.E) {
		input_state[0x6] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.A) {
		input_state[0x7] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.S) {
		input_state[0x8] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.D) {
		input_state[0x9] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.Z) {
		input_state[0xA] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.C) {
		input_state[0xB] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.FOUR) {
		input_state[0xC] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.R) {
		input_state[0xD] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.F) {
		input_state[0xE] = false
	}
	if rl.IsKeyReleased(rl.KeyboardKey.V) {
		input_state[0xF] = false
	}
}

is_key_down :: proc(key: u8) -> bool {
	assert(key >= 0x0 && key <= 0xF)
	return input_state[key]
}
