package main

import "core:fmt"
import SDL "vendor:sdl2"

State :: struct {
	window:   ^SDL.Window,
	renderer: ^SDL.Renderer,
	time:     f32,
}

get_time :: proc() -> f32 {
	return f32(SDL.GetPerformanceCounter()) * 1000 / f32(SDL.GetPerformanceFrequency())
}

main :: proc() {
	state: State

	assert(SDL.Init(SDL.INIT_VIDEO) == 0, SDL.GetErrorString())
	defer SDL.Quit()

	state.window = SDL.CreateWindow(
		"Rogueday",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		1280,
		720,
		{},
	)
	assert(state.window != nil, SDL.GetErrorString())
	defer SDL.DestroyWindow(state.window)

	state.renderer = SDL.CreateRenderer(state.window, -1, {.PRESENTVSYNC | .ACCELERATED})
	assert(state.renderer != nil, SDL.GetErrorString())
	defer SDL.DestroyRenderer(state.renderer)

	state.time = get_time()
	tickrate: f32 = 240.0
	ticktime: f32 = 1000.0 / tickrate

	dt: f32 = 0.0
	event: SDL.Event
	event_loop: for {
		fmt.printf("TICKRATE: %f\n", get_time())
		for SDL.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				break event_loop
			}

			time := get_time()
			dt += time - state.time

			state.time = time

			// NOTE(calco): Same thread as rendering so limited by that in the end
			for dt >= ticktime {
				dt -= ticktime

				// TODO(calco): Update game
				fmt.println("UPDATING GAME")
			}

			SDL.SetRenderDrawColor(state.renderer, 0, 0, 0, 255)
			SDL.RenderClear(state.renderer)

			// TODO(calco): Render game
			SDL.RenderPresent(state.renderer)
		}
	}
}
