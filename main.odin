package main

import "core:c/libc"
import "core:fmt"
import linalg "core:math/linalg"
import rand "core:math/rand"
import "core:os"
import slice "core:slice"
import SDL "vendor:sdl2"
import stb_image "vendor:stb/image"

draw_texture :: proc(
	renderer: ^SDL.Renderer,
	texture: ^SDL.Texture,
	sprite: Sprite,
	world_pos: vec2f,
	scale: f32 = 1,
	dst_addon: recti = {0, 0, 0, 0},
) -> recti {
	h := vec2i{20, 20}
	s := vec2f{0, 0}
	SDL.GetRendererOutputSize(renderer, &h[0], &h[1])
	SDL.RenderGetScale(renderer, &s[0], &s[1])
	h = vec2i{i32(f32(h.x) / s.x), i32(f32(h.y) / s.y)}

	src_rect := SDL.Rect{sprite.pos.x, sprite.pos.y, sprite.size.x, sprite.size.y}
	dst_rect := SDL.Rect {
		i32(world_pos.x) + h.x / 2 + dst_addon.x,
		i32(world_pos.y) + h.y / 2 + dst_addon.y,
		i32(f32(sprite.size.x) * scale) + dst_addon.z,
		i32(f32(sprite.size.y) * scale) + dst_addon.w,
	}

	SDL.RenderCopyEx(renderer, texture, &src_rect, &dst_rect, 0, nil, .NONE)

	return recti{dst_rect.x, dst_rect.y, dst_rect.w, dst_rect.h}
}

draw_texture_screen :: proc(
	renderer: ^SDL.Renderer,
	texture: ^SDL.Texture,
	sprite: Sprite,
	pos: vec2f,
	scale: f32 = 1,
	dst_addon: recti = {0, 0, 0, 0},
) -> recti {
	src_rect := SDL.Rect{sprite.pos.x, sprite.pos.y, sprite.size.x, sprite.size.y}
	dst_rect := SDL.Rect {
		i32(pos.x) + dst_addon.x,
		i32(pos.y) + dst_addon.y,
		i32(f32(sprite.size.x) * scale) + dst_addon.z,
		i32(f32(sprite.size.y) * scale) + dst_addon.w,
	}
	SDL.RenderCopyEx(renderer, texture, &src_rect, &dst_rect, 0, nil, .NONE)

	return recti{dst_rect.x, dst_rect.y, dst_rect.w, dst_rect.h}
}

draw_sprite :: proc(
	state: ^State,
	sprite: Sprite,
	pos: vec2f,
	screen: bool,
	dst_addon: recti = {0, 0, 0, 0},
) -> recti {
	if (screen) {
		return draw_texture_screen(state.renderer, state.texture, sprite, pos, 1, dst_addon)
	} else {
		return draw_texture(
			state.renderer,
			state.texture,
			sprite,
			pos - state.scene.camera.position,
			1,
			dst_addon,
		)
	}
}

FONT_GLYPH_SIZE :: vec2i{8, 8}
draw_character :: proc(state: ^State, c: byte, pos: vec2f, screen: bool, scale: f32) -> recti {
	tex_pos := vec2i{(i32(c) % 16) * FONT_GLYPH_SIZE.x, (i32(c) / 16) * FONT_GLYPH_SIZE.y}

	sprite := Sprite{tex_pos, FONT_GLYPH_SIZE}
	if (screen) {
		return draw_texture_screen(state.renderer, state.font_texture, sprite, pos, scale)
	} else {
		return draw_texture(
			state.renderer,
			state.font_texture,
			sprite,
			pos - state.scene.camera.position,
			scale,
		)
	}
}

draw_text :: proc(state: ^State, s: string, pos: vec2f, screen: bool, scale: f32) -> recti {
	font_glyph_offset := vec2f{f32(FONT_GLYPH_SIZE.x) * scale, 0}
	f := draw_character(state, s[0], pos + font_glyph_offset * f32(0), screen, scale)
	for c in 1 ..< len(s) {
		draw_character(state, s[c], pos + font_glyph_offset * f32(c), screen, scale)
	}
	return {f.x, f.y, f.z * i32(len(s)), f.w * i32(len(s))}
}

get_text_size :: proc(s: string, scale: f32) -> vec2i {
	len := i32(len(s))
	return vec2i{i32(f32(FONT_GLYPH_SIZE.x * len) * scale), i32(f32(FONT_GLYPH_SIZE.y) * scale)}
}

get_text_rect :: proc(s: string, scale: f32, pos: vec2f) -> recti {
	size := get_text_size(s, scale)
	return recti{i32(pos.x), i32(pos.y), size.x, size.y}
}

vec2f :: [2]f32
vec2i :: [2]i32

Vec2i_Dirs := [4]vec2i{{0, 1}, {1, 0}, {-1, 0}, {0, -1}}

rectf :: [4]f32
recti :: [4]i32

rectf_from_relative :: proc(pos: vec2f, rect: rectf) -> rectf {
	return {rect.x + pos.x, rect.y + pos.y, rect.z, rect.w}
}

// RETURNS -1 -1 -1 -1 if there is no overlap
rectf_get_overlap :: proc(a: rectf, b: rectf) -> rectf {
	x := max(a.x, b.x)
	y := max(a.y, b.y)
	w := min(a.x + a.z, b.x + b.z) - x
	h := min(a.y + a.w, b.y + b.w) - y

	if w < 0 || h < 0 {
		return {-1, -1, -1, -1}
	}
	return {x, y, w, h}
}

Sprite :: struct {
	pos:  vec2i,
	size: vec2i,
}

// TODO(calco): Maybe add an array thing
Sprites :: enum {
	Player,
	ButtonSlice,
}

Sprite_Sprites :: [Sprites]Sprite {
	.Player      = {{0, 0}, {16, 16}},
	.ButtonSlice = {{64, 64}, {16, 16}},
}

// Megastruct, Randy style lmao
Entity :: struct {
	components:     Components,
	type:           EntityType,
	id:             i32,
	position:       vec2f,
	scale:          f32,

	// collisions
	coll_aabb:      rectf,
	coll_layer:     Layers,
	coll_mask:      Layers,
	coll_static:    bool,

	// sprite comp
	sprite:         Sprite,

	// ui 
	ui_rect:        recti,
	ui_text:        string,
	ui_screen:      bool,

	// button
	ui_btn_onclick: proc(scene: ^Scene, btn: ^Entity),
	ui_btn_padding: vec2i,
	ui_btn_down:    bool,
}

Component :: enum {
	None = 0,
	IsCamera,
	Sprite,
	Collider,
	UI_Text,
	UI_Button, // DOES NOT RENDER UI_TEXT, INSTEAD IT RENDERS A SPRITE
}
Components :: distinct bit_set[Component]

EntityType :: enum {
	None = 0,
	Camera,
	Player,
	UI,
	Skeleton,
	Zombie,
}

Layer :: enum {
	Default,
	Player,
	Tilemap,
}
Layers :: distinct bit_set[Layer]

entity_make_text :: proc(
	pos: vec2f,
	text: string,
	scale: f32,
	centered: bool,
	screen: bool,
) -> Entity {
	size := get_text_size(text, scale) / 2
	pos := pos if !centered else pos - vec2f{f32(size.x), f32(size.y)}

	return(
		Entity {
			position = pos,
			components = {.UI_Text},
			ui_text = text,
			ui_screen = screen,
			scale = scale,
			type = .UI,
		} \
	)
}

entity_make_button :: proc(
	pos: vec2f,
	text: string,
	scale: f32,
	centered: bool,
	padding: vec2i,
	screen: bool,
	on_click: proc(scene: ^Scene, btn: ^Entity),
) -> Entity {
	entity := entity_make_text(pos, text, scale, centered, screen)

	entity.ui_btn_padding = padding

	padding := padding / 2
	entity.ui_rect.x -= padding.x
	entity.ui_rect.y -= padding.y
	entity.ui_rect.z += 2 * padding.x
	entity.ui_rect.w += 2 * padding.y

	entity.ui_btn_down = false
	entity.ui_btn_onclick = on_click
	entity.components |= {.UI_Button}
	entity.sprite = Sprite_Sprites[Sprites.ButtonSlice]

	return entity
}

entity_actor_move :: proc(entity: ^Entity, scene: ^Scene, movement: vec2f) {
	entity.position.x += movement.x
	entity_no_collisions(entity, scene, true)
	entity.position.y += movement.y
	entity_no_collisions(entity, scene, false)
}

entity_update :: proc(entity: ^Entity, scene: ^Scene) {
	// TODO(calco): MAKE THIS NOT STATIC LMAO
	@(static)
	prev_cam_zoom: f32 = 1

	// TODO(calco): Stuff
	if (entity.type == .Player) {
		move := vec2f {
			f32(
				i32(scene.state.keys[SDL.Keycode.D] == .Down) -
				i32(scene.state.keys[SDL.Keycode.A] == .Down),
			),
			f32(
				i32(scene.state.keys[SDL.Keycode.S] == .Down) -
				i32(scene.state.keys[SDL.Keycode.W] == .Down),
			),
		}
		move = linalg.vector_normalize0(move) * 100 * scene.state.dt
		entity_actor_move(entity, scene, move)
		// entity.position += move

		// TODO(calco): DEBUG TAKE THIS OUT
		if scene.state.mouse.buttons[1] == .Pressed {
			generate_map(&scene.tilemap)
		}
	} else if (entity.type == .Camera) {
		if (entity.scale != prev_cam_zoom) {
			SDL.RenderSetScale(scene.state.renderer, entity.scale, entity.scale)
			prev_cam_zoom = entity.scale
		}
	}

	if (entity.components & Components{.UI_Button} != {}) {
		mf := scene.state.mouse.click_pos[1]
		m := vec2i{i32(f32(mf.x) / scene.camera.scale), i32(f32(mf.y) / scene.camera.scale)}
		r := entity.ui_rect

		if (m.x >= r.x && m.x <= r.x + r.z && m.y >= r.y && m.y <= r.y + r.w) {
			if (scene.state.mouse.buttons[1] == .Pressed && !entity.ui_btn_down) {
				entity.ui_btn_down = true
				entity.ui_btn_onclick(scene, entity)
			} else if (scene.state.mouse.buttons[1] == .Released && entity.ui_btn_down) {
				entity.ui_btn_down = false
			}
		}
	}
}

entity_no_collisions :: proc(entity: ^Entity, scene: ^Scene, resolve_h: bool) {
	if (entity.components & Components{.Collider} != {}) {
		// TILEMAP collisions
		if (entity.coll_mask & Layers{.Tilemap} != {}) {
			// TODO(calco): tilemap collision
		}

		// TODO(Calco)): stop looping, have some hash thing
		for e2 in &scene.entities {
			e2 := &e2
			if (e2 == entity || e2.components & Components{.Collider} == {}) {
				continue
			}
			if (entity.coll_mask & e2.coll_layer == {}) {
				continue
			}

			e1_rect := rectf_from_relative(entity.position, entity.coll_aabb)
			e2_rect := rectf_from_relative(e2.position, e2.coll_aabb)

			// Check if entities are overlapping
			overlap := rectf_get_overlap(e1_rect, e2_rect)
			if overlap.x <= 0 {
				continue
			}

			// WE ARE COLLIDING
			movement := vec2f{overlap.z, overlap.w} * 1.02
			if (resolve_h) {
				movement.y = 0
			} else {
				movement.x = 0
			}

			if (entity.position.x < e2.position.x) {
				movement.x *= -1
			}
			if (entity.position.y < e2.position.y) {
				movement.y *= -1
			}

			if (!entity.coll_static && !e2.coll_static) {
				movement *= 0.5
				entity.position += movement
				e2.position -= movement
			} else if (e2.coll_static) {
				entity.position += movement
			} else {
				e2.position -= movement
			}
		}

	}
}

entity_late_update :: proc(entity: ^Entity, scene: ^Scene) {
	if entity.type == .Camera {
		if (scene.player != nil) {
			entity.position = scene.player.position
		}
	}
}

entity_render :: proc(entity: ^Entity, scene: ^Scene) {
	if (entity.components & Components{.Sprite} != {}) {
		entity.ui_rect = draw_sprite(scene.state, entity.sprite, entity.position, entity.ui_screen)
	}
	if (entity.components & Components{.UI_Button} != {}) {
		h := entity.ui_btn_padding / 2
		s := get_text_size(entity.ui_text, entity.scale)
		dst_rect := recti{-h.x, -h.y, 2 * h.x + s.x - 16, 2 * h.y + s.y - 16}

		entity.ui_rect = draw_sprite(
			scene.state,
			entity.sprite,
			entity.position,
			entity.ui_screen,
			dst_rect,
		)
	}
	if (entity.components & Components{.UI_Text} != {}) {
		v := draw_text(
			scene.state,
			entity.ui_text,
			entity.position,
			entity.ui_screen,
			entity.scale,
		)
		if (entity.components & Components{.UI_Button} == {}) {
			entity.ui_rect = v
		}
	}
}

entity_free :: proc(entity: ^Entity) {
	// TODO(calco): nothing for now
}

// not an entity for several reason
Tilemap :: struct {
	width:     i32,
	height:    i32,
	tile_size: vec2i,
	cells:     [dynamic]Tile,
	position:  vec2f,
}

Tile :: enum {
	None,
	Wall,
	Floor,
}

Tile_Sprites := [Tile]vec2i {
	.None  = {0, 0},
	.Wall  = {0, 64},
	.Floor = {16, 64},
}

tilemap_in_bounds :: proc(tilemap: ^Tilemap, pos: vec2i) -> bool {
	return pos.x >= 0 && pos.y >= 0 && pos.x < tilemap.width && pos.y < tilemap.height
}

tilemap_create_size :: proc(size: vec2i, tile_size: vec2i, pos: vec2f) -> Tilemap {
	s := size.x * size.y
	return(
		Tilemap {
			width = size.x,
			height = size.y,
			tile_size = tile_size,
			cells = make([dynamic]Tile, s, s),
			position = pos,
		} \
	)
}

tilemap_idx_to_v2 :: proc(tilemap: ^Tilemap, idx: i32) -> vec2i {
	return {idx % tilemap.width, idx / tilemap.width}
}

tilemap_v2_to_idx :: proc(tilemap: ^Tilemap, v: vec2i) -> i32 {
	return v.y * tilemap.width + v.x
}

tilemap_render :: proc(tilemap: ^Tilemap, scene: ^Scene) {
	cam_pos := vec2i{i32(scene.camera.position.x), i32(scene.camera.position.y)}

	w := vec2i{0, 0}
	s := vec2f{0, 0}
	SDL.GetRendererOutputSize(scene.state.renderer, &w[0], &w[1])
	SDL.RenderGetScale(scene.state.renderer, &s[0], &s[1])
	w = vec2i{i32(f32(w.x) / s.x), i32(f32(w.y) / s.y)}

	screen_half_size_tiles := ((w / 2) / tilemap.tile_size) + vec2i{3, 3}
	cam_pos_tiles := cam_pos / tilemap.tile_size

	map_pos_tiles := vec2i{i32(tilemap.position.x / 16), i32(tilemap.position.y / 16)}
	top_left := cam_pos_tiles - screen_half_size_tiles - map_pos_tiles
	bottom_right := cam_pos_tiles + screen_half_size_tiles - map_pos_tiles

	top_left = linalg.clamp(top_left, vec2i{0, 0}, vec2i{tilemap.width, tilemap.height})
	bottom_right = linalg.clamp(bottom_right, vec2i{0, 0}, vec2i{tilemap.width, tilemap.height})

	// SHOULD OFFSET BY THE TILEMAP POSITION BUT LMAO
	for y := top_left.y; y < bottom_right.y; y += 1 {
		for x := top_left.x; x < bottom_right.x; x += 1 {
			idx := tilemap_v2_to_idx(tilemap, vec2i{x, y})
			draw_sprite(
				scene.state,
				Sprite{Tile_Sprites[tilemap.cells[idx]], tilemap.tile_size},
				tilemap.position +
				vec2f{f32(x * tilemap.tile_size.x), f32(y * tilemap.tile_size.y)},
				false,
			)
		}
	}
}

tilemap_fill :: proc(tilemap: ^Tilemap, tile: Tile) {
	for i: i32 = 0; i < tilemap.width * tilemap.height; i += 1 {
		tilemap.cells[i] = tile
	}
}

tilemap_free :: proc(tilemap: ^Tilemap) {
	delete(tilemap.cells)
}

Scene :: struct {
	camera:          ^Entity,
	player:          ^Entity,
	entities:        [dynamic]Entity,
	state:           ^State,
	tilemap:         Tilemap,
	tilemap_enabled: bool,
}

scene_screen_to_world_coords :: proc(scene: ^Scene, screen: vec2i) -> vec2f {
	w := vec2i{0, 0}
	SDL.GetWindowSize(scene.state.window, &w[0], &w[1])
	p := vec2f{f32(screen.x) / f32(w.x), f32(screen.y) / f32(w.y)} - vec2f{0.5, 0.5}

	y := vec2f{0, 0}
	SDL.RenderGetScale(scene.state.renderer, &y[0], &y[1])

	return scene.camera.position + (p / y) * vec2f{f32(w.x), f32(w.y)}
}

scene_empty :: proc(state: ^State) -> Scene {
	scene := Scene {
		state           = state,
		tilemap_enabled = false,
	}
	camera := scene_spawn_entity(
		&scene,
		Entity{components = {.IsCamera}, type = .Camera, position = {0, 0}, scale = 1},
	)
	scene.camera = camera
	return scene
}

scene_add_tilemap :: proc(scene: ^Scene, size: vec2i, tile_size: vec2i, pos: vec2f) -> ^Tilemap {
	scene.tilemap_enabled = true
	scene.tilemap = tilemap_create_size(size, tile_size, pos)
	tilemap_fill(&scene.tilemap, Tile.Wall)

	return &scene.tilemap
}

scene_free :: proc(scene: ^Scene) {
	tilemap_free(&scene.tilemap)
	for entity in &scene.entities {
		entity_free(&entity)
	}
	delete(scene.entities)
}

scene_spawn_entity :: proc(scene: ^Scene, entity: Entity) -> ^Entity {
	entity := entity
	entity.id = i32(len(scene.entities))
	append(&scene.entities, entity)

	if (entity.type == .Player) {
		scene.player = &scene.entities[entity.id]
	}

	return &scene.entities[entity.id]
}

scene_update :: proc(scene: ^Scene) {
	for entity in &scene.entities {
		entity_update(&entity, scene)
	}
}

scene_late_update :: proc(scene: ^Scene) {
	for entity in &scene.entities {
		entity_late_update(&entity, scene)
	}
}

scene_render :: proc(scene: ^Scene) {
	if (scene.tilemap_enabled) {
		tilemap_render(&scene.tilemap, scene)
	}

	// TODO(calco): Maybe sort by depth or sth
	for entity in &scene.entities {
		entity_render(&entity, scene)
	}
}

KeyState :: enum {
	Pressed,
	Down,
	Released,
	Up,
}

keystate_update :: proc(state: ^KeyState, is_pressed: bool) {
	ret_state := state^

	switch (state^) {
	case .Down:
		if (!is_pressed) {
			ret_state = .Released
		}
	case .Up:
		if (is_pressed) {
			ret_state = .Pressed
		}
	case .Pressed:
		ret_state = .Down if is_pressed else .Released
	case .Released:
		ret_state = .Pressed if is_pressed else .Up
	}

	state^ = ret_state
}

MAX_KEY_COUNT :: 322
MAX_MOUSE_COUNT :: 4

State :: struct {
	window:       ^SDL.Window,
	renderer:     ^SDL.Renderer,
	surface:      ^SDL.Surface,
	texture:      ^SDL.Texture,
	font_texture: ^SDL.Texture,
	time:         u32,
	dt:           f32,
	scene:        Scene,
	keys:         [MAX_KEY_COUNT]KeyState,
	mouse:        struct {
		buttons:   [MAX_MOUSE_COUNT]KeyState,
		click_pos: [MAX_MOUSE_COUNT]vec2i,
		pos:       vec2i,
	},
}

// GAME SCENES
// btn_play_onclick :: proc(scene: ^Scene, btn: ^Entity) {
// 	fmt.println("CLICKED")
// }

state_make_menu_scene :: proc(state: ^State) -> Scene {
	scene := scene_empty(state)
	scene.camera.scale = 4
	scene_spawn_entity(&scene, entity_make_text({0, 0}, "Rogueday", 1, true, false))
	scene_spawn_entity(
		&scene,
		entity_make_button(
			{0, 40},
			"Play",
			1,
			true,
			{20, 20},
			false,
			proc(scene: ^Scene, btn: ^Entity) {
				state_switch_scene(scene.state, state_make_gameplay_scene(scene.state))
			},
		),
	)
	return scene
}

// MAP GENERATION
generate_map_ca :: proc(tilemap: ^Tilemap) {
	step_count :: 5
	random := rand.create(rand._system_random())
	for y in 0 ..< tilemap.height {
		for x in 0 ..< tilemap.width {
			idx := tilemap_v2_to_idx(tilemap, {x, y})
			tilemap.cells[idx] = .Floor if rand.float32(&random) < 0.65 else .Wall
		}
	}
	new_cells := make([dynamic]Tile, tilemap.width * tilemap.height)
	for _ in 0 ..< step_count {
		for y in 0 ..< tilemap.height {
			for x in 0 ..< tilemap.width {
				idx := tilemap_v2_to_idx(tilemap, {x, y})
				tile := tilemap.cells[idx]
				neighbours := 0
				for yoff in -1 ..< 2 {
					for xoff in -1 ..< 2 {
						npos := vec2i{x + i32(xoff), y + i32(yoff)}
						if npos.x >= 0 &&
						   npos.x < tilemap.width &&
						   npos.y >= 0 &&
						   npos.y < tilemap.height {
							neighbours += int(
								tilemap.cells[tilemap_v2_to_idx(tilemap, npos)] == .Wall,
							)
						}
					}
				}

				if (tile == .Wall && neighbours >= 4) || (tile != .Wall && neighbours >= 5) {
					new_cells[idx] = .Wall
				} else {
					new_cells[idx] = .Floor
				}
			}
		}

		for y in 0 ..< tilemap.height {
			for x in 0 ..< tilemap.width {
				idx := tilemap_v2_to_idx(tilemap, {x, y})
				tilemap.cells[idx] = new_cells[idx]
			}
		}
	}
	delete(new_cells)
}

generate_map_walker :: proc(tilemap: ^Tilemap, pos: vec2i, step_count: i32) {
	pos := pos
	step_count := step_count

	for {
		if !tilemap_in_bounds(tilemap, pos) || step_count == 0 {
			return
		}
		tilemap.cells[tilemap_v2_to_idx(tilemap, pos)] = .Floor

		rand_dir := Vec2i_Dirs[rand._system_random() % 4]
		pos += rand_dir
		step_count -= 1
	}
}

generate_map :: proc(tilemap: ^Tilemap) {
	walker_cnt :: 20
	walker_step :: 500

	tilemap_fill(tilemap, .Wall)

	random := rand.create(rand._system_random())
	floors := make([dynamic]vec2i, 1)
	floors[0] = vec2i{tilemap.width / 2, tilemap.height / 2}
	for w in 0 ..< walker_cnt {
		pos := floors[rand.int31(&random) % i32(len(floors))]
		generate_map_walker(tilemap, pos, walker_step)
	}
}

state_make_gameplay_scene :: proc(state: ^State) -> Scene {
	scene := scene_empty(state)
	scene.camera.scale = 2
	// scene_spawn_entity(&scene, entity_make_text({0, 0}, "GAMEPLAY OVER HERE", 10, true, false))
	scene_spawn_entity(
		&scene,
		Entity {
			position = {0, 0},
			scale = 1,
			sprite = Sprite_Sprites[Sprites.Player],
			type = .Player,
			components = {.Sprite, .Collider},
			coll_aabb = {1, 1, 13, 14},
			coll_layer = {.Player},
			coll_mask = {.Tilemap, .Default},
		},
	)

	scene_spawn_entity(
		&scene,
		Entity {
			position = {32, 32},
			scale = 1,
			sprite = Sprite_Sprites[Sprites.Player],
			type = .Skeleton,
			components = {.Sprite, .Collider},
			coll_aabb = {1, 1, 13, 14},
			coll_layer = {.Default},
			coll_mask = {},
			coll_static = true,
		},
	)

	tilemap := scene_add_tilemap(&scene, {100, 100}, {16, 16}, {-50 * 16, -50 * 16})
	generate_map(tilemap)

	return scene
}

state_make_gameover_scene :: proc(state: ^State) -> Scene {
	scene := scene_empty(state)
	scene_spawn_entity(&scene, entity_make_text({0, 0}, "GAME OVER", 1, true, true))
	return scene
}

state_switch_scene :: proc(state: ^State, scene: Scene) {
	scene_free(&state.scene)
	state.scene = scene
	SDL.RenderSetScale(scene.state.renderer, scene.camera.scale, scene.camera.scale)
}

// RANDOM STUFF
slurp_file :: proc(file_path: string) -> []byte {
	data, ok := os.read_entire_file_from_filename(file_path)
	assert(ok, "ERROR: Could not read file!")
	return data
}

tick_update :: proc(state: ^State) {
	scene_update(&state.scene)
	scene_late_update(&state.scene)
}

render :: proc(state: ^State) {
	SDL.SetRenderDrawColor(state.renderer, 0, 0, 0, 255)
	SDL.RenderClear(state.renderer)

	scene_render(&state.scene)

	SDL.RenderPresent(state.renderer)
}

// MAIN

main :: proc() {
	state: State

	for i in 0 ..< MAX_KEY_COUNT {
		state.keys[i] = .Up
	}
	for i in 0 ..< MAX_MOUSE_COUNT {
		state.mouse.buttons[i] = .Up
	}

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

	state.renderer = SDL.CreateRenderer(state.window, -1, {})
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

	surface := SDL.CreateRGBSurfaceWithFormatFrom(
		image,
		width,
		height,
		channels,
		width * 4,
		u32(SDL.PixelFormatEnum.ABGR8888),
	)
	assert(surface != nil, SDL.GetErrorString())
	defer SDL.FreeSurface(surface)

	state.texture = SDL.CreateTextureFromSurface(state.renderer, surface)
	assert(state.texture != nil, SDL.GetErrorString())
	defer SDL.DestroyTexture(state.texture)

	// FONT FILE
	font_data := slurp_file("font.png")
	defer delete(font_data)

	font_image := stb_image.load_from_memory(
		raw_data(font_data),
		i32(len(font_data)),
		&width,
		&height,
		&channels,
		4,
	)
	defer libc.free(font_image)
	font_surface := SDL.CreateRGBSurfaceWithFormatFrom(
		font_image,
		width,
		height,
		channels,
		width * 4,
		u32(SDL.PixelFormatEnum.ABGR8888),
	)
	assert(font_surface != nil, SDL.GetErrorString())
	defer SDL.FreeSurface(font_surface)

	state.font_texture = SDL.CreateTextureFromSurface(state.renderer, font_surface)
	assert(state.font_texture != nil, SDL.GetErrorString())
	defer SDL.DestroyTexture(state.font_texture)

	// INIT SCENE
	state.time = SDL.GetTicks()
	ticktime: u32 = 1000 / 60

	state.scene = state_make_menu_scene(&state)
	defer scene_free(&state.scene)

	dt: u32 = 0
	event: SDL.Event
	event_loop: for {
		for SDL.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				break event_loop
			case .KEYDOWN:
				idx := i32(event.key.keysym.sym)
				if (idx >= 0 && idx < 322) {
					keystate_update(&state.keys[idx], true)
				}
			case .KEYUP:
				idx := i32(event.key.keysym.sym)
				if (idx >= 0 && idx < 322) {
					keystate_update(&state.keys[idx], false)
				}
			case .MOUSEBUTTONDOWN:
				idx := event.button.button
				if (idx >= 0 && idx < 4) {
					keystate_update(&state.mouse.buttons[idx], true)
					state.mouse.click_pos[idx] = vec2i{event.button.x, event.button.y}
				}
			case .MOUSEBUTTONUP:
				idx := event.button.button
				if (idx >= 0 && idx < 4) {
					keystate_update(&state.mouse.buttons[idx], false)
				}
			}
		}

		{
			using state.mouse
			SDL.GetMouseState(&pos.x, &pos.y)
		}

		time := SDL.GetTicks()
		dt += time - state.time
		state.time = time
		for dt >= ticktime {
			delta := min(ticktime, dt)
			dt -= delta
			state.dt = f32(delta) / 1000.0
			tick_update(&state)

			for i in 0 ..< MAX_KEY_COUNT {
				is_pressed := state.keys[i] == .Down || state.keys[i] == .Pressed
				keystate_update(&state.keys[i], is_pressed)
			}
			for i in 0 ..< MAX_MOUSE_COUNT {
				is_pressed := state.mouse.buttons[i] == .Down || state.mouse.buttons[i] == .Pressed
				keystate_update(&state.mouse.buttons[i], is_pressed)
			}
		}
		render(&state)
	}
}
