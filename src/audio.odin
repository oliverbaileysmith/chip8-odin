package main

import "core:math"
import rl "vendor:raylib"

SAMPLE_RATE :: 44100
SAMPLE_SIZE :: 32
NUM_CHANNELS :: 1

FREQUENCY :: 440.0
AMPLITUDE :: 0.2

@(private="file")
stream: rl.AudioStream

audio_callback :: proc "c" (buffer_data: rawptr, frames: u32) {
	data: []f32 = (cast([^]f32) buffer_data)[:frames]

	for i in 0..<frames {
		sample := AMPLITUDE * math.sin_f32(FREQUENCY * 2.0 *
			(f32(i) / f32(SAMPLE_RATE)) * math.PI)

		data[i] = sample
	}
}

audio_init :: proc() {
	rl.InitAudioDevice()
	stream = rl.LoadAudioStream(SAMPLE_RATE, SAMPLE_SIZE, NUM_CHANNELS)
	rl.SetAudioStreamCallback(stream, audio_callback)
	rl.PlayAudioStream(stream)
}

audio_update :: proc(should_play: bool) {
	if should_play {
		rl.ResumeAudioStream(stream)
	} else {
		rl.PauseAudioStream(stream)
	}
}

audio_shut_down :: proc() {
	rl.StopAudioStream(stream)
	rl.UnloadAudioStream(stream)
	rl.CloseAudioDevice()
}
