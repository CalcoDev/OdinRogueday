package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import SDL "vendor:sdl2"
import stb_image "vendor:stb/image"

State :: struct {
	window:   ^SDL.Window,
	renderer: ^SDL.Renderer,
	surface:  ^SDL.Surface,
	texture:  ^SDL.Texture,
	time:     f32,
}

slurp_file :: proc(file_path: string) -> []byte {
	data, ok := os.read_entire_file_from_filename(file_path)
	assert(ok, "ERROR: Could not read file!")
	return data
}

get_time :: proc() -> f32 {
	return f32(SDL.GetPerformanceCounter()) * 1000 / f32(SDL.GetPerformanceFrequency())
}

tick_update :: proc(state: ^State) {

}

render :: proc(state: ^State) {
	SDL.SetRenderDrawColor(state.renderer, 0, 0, 0, 255)
	SDL.RenderClear(state.renderer)

	SDL.RenderCopy(
		state.renderer,
		state.texture,
		&SDL.Rect{x = 0, y = 0, w = 16, h = 16},
		&SDL.Rect{x = 128, y = 128, w = 128, h = 128},
	)

	SDL.RenderPresent(state.renderer)
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

	atlas_data := slurp_file("atlas.png")
	defer delete(atlas_data)

	width: libc.int
	height: libc.int
	channels: libc.int

	stb_image.set_flip_vertically_on_load(0)
	image := stb_image.load_from_memory(
		raw_data(atlas_data),
		i32(len(atlas_data)),
		&width,
		&height,
		&channels,
		4,
	)
	defer libc.free(image)

	fmt.printf("W: %d, H: %d, C: %d", width, height, channels)
	state.surface = SDL.CreateRGBSurfaceWithFormatFrom(
		image,
		width,
		height,
		channels,
		width * 4,
		u32(SDL.PixelFormatEnum.ABGR8888),
	)
	assert(state.surface != nil, SDL.GetErrorString())
	defer SDL.FreeSurface(state.surface)

	state.texture = SDL.CreateTextureFromSurface(state.renderer, state.surface)
	assert(state.texture != nil, SDL.GetErrorString())
	defer SDL.DestroyTexture(state.texture)

	state.time = get_time()
	tickrate: f32 = 240.0
	ticktime: f32 = 1000.0 / tickrate

	dt: f32 = 0.0
	event: SDL.Event
	event_loop: for {
		for SDL.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				break event_loop
			}

			time := get_time()
			dt += time - state.time
			state.time = time

			for dt >= ticktime {
				dt -= ticktime
				tick_update(&state)
			}
			render(&state)
		}
	}
}
