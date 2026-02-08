package submarine

import rl "vendor:raylib"
import "core:math"
import "core:math/rand"

WIDTH :: 800
HEIGHT :: 800
FRAME_SPEED :: 8
PLAYER_MAX_SPEED :: 300
PLAYER_ACCELERATION :: 5
GROUND_POINTS :: 200
WORLD_WIDTH   :: 3000
WORLD_HEIGHT  :: 400
PLAYER_START_POSITION :: rl.Vector2{100,350}

PLAYER_SPRITE_WIDTH : f32

playerState :: enum{
    idle,
    sail
}
GlobalState :: struct{
    ground_points: [GROUND_POINTS]f32,
    time : f32
    
}
Player :: struct{
    frame_counter : int,
    current_animation : playerState,
    current_frame : int,
    position : rl.Vector2,
    is_left : bool,
    sprite_rec : rl.Rectangle,
    animation_sheet : [2]rl.Texture2D,
    speed : rl.Vector2,
}

global_state : GlobalState 

generate_ground :: proc() {
    base := f32(WORLD_HEIGHT) - 30
    
    for i in 0..<GROUND_POINTS {
        x := f32(i) / f32(GROUND_POINTS - 1) * f32(WORLD_WIDTH)
        
        noise: f32 = 0
        noise += -10+ math.pow(x,0.333)*math.sin(x * 0.0004+1) * 25
        noise += math.sin(x * 0.05 + 61.5) * 12
        noise += math.sin(x * 0.12 + 62.3) * 6
        noise += rand.float32_range(-15, 15)
        
        global_state.ground_points[i] = base + noise
    }
    
    for _ in 0..<4 {
        for i in 1..<GROUND_POINTS-1 {
            global_state.ground_points[i] = (
                global_state.ground_points[i-1] * 0.25 + 
                global_state.ground_points[i] * 0.5 + 
                global_state.ground_points[i+1] * 0.25
            )
        }
    }
    

    for i in GROUND_POINTS/5..<2*GROUND_POINTS/5 {
        global_state.ground_points[i] -= 20
    }
}

get_water_surface :: proc(x: f32, time: f32) -> f32 {
    wave: f32 = 0
    wave += math.sin(x*0.04 + time*2.5)*3.5
    wave += math.sin(x*0.21 + time*2.8 + 0.5)*1.5
    wave += math.sin(x*0.03 + time*2.1)*2.0
    
    
    return f32(PLAYER_START_POSITION.y+8) + wave
}

get_ground_height :: proc(x: f32) -> f32 {
    segment_width := f32(WORLD_WIDTH) / f32(GROUND_POINTS - 1)
    idx := int(x / segment_width)
    idx = clamp(idx, 0, GROUND_POINTS - 2)
    t := (x - f32(idx) * segment_width) / segment_width
    t = clamp(t, 0, 1)
    //smooth on segments edge
    return global_state.ground_points[idx] * (1 - t) + global_state.ground_points[idx + 1] * t
}

draw_water_surface :: proc(camera: rl.Camera2D) {
    cam_left := camera.target.x - f32(WIDTH) / 4
    cam_right := camera.target.x + f32(WIDTH) / 4 + 8
    
    for x := max(i32(cam_left) - 2,0); x < i32(cam_right) + 2; x += 1 {
        surface_y := get_water_surface(f32(x), global_state.time)
        y := i32(surface_y)
        
        // Animated wave crest
        wave_intensity := 0.7 + 0.3 * math.sin(f32(x) * 0.2 + global_state.time * 4)
        bright := u8(200 + wave_intensity * 55)
        
        // Main crest
        rl.DrawPixel(x, y, {bright, bright, bright, 255})
        
    }
}

draw_ground :: proc(camera: rl.Camera2D) {
    cam_left := camera.target.x - f32(WIDTH)/4
    cam_right := camera.target.x + f32(WIDTH)/4 
    cam_bottom := camera.target.y + f32(HEIGHT) / 4
    
    for x := i32(cam_left) - 1; x < i32(cam_right) + 1; x += 1 {
        ground_y := get_ground_height(f32(x))
        y := i32(ground_y)
    
        rl.DrawPixel(x, y, rl.WHITE)
        rl.DrawPixel(x, y + 1, {200, 200, 200, 255})
    
        for py := y + 2; py < i32(min(f32(y) + 300, cam_bottom + 10)); py += 1 {
            depth := py - y
            shade := u8(max(20, 70 - depth))
            rl.DrawPixel(x, py, {shade, shade, shade, 255})
        }
    }
}


update_animation_player :: proc(player :^Player){
    player.frame_counter +=1
        if player.frame_counter >= (60/FRAME_SPEED){
            player.frame_counter = 0
            player.current_frame+=1
            if player.current_frame > 3{
                player.current_frame = 0
            } 
            if (player.is_left) {
                player.sprite_rec.x = (f32(player.current_frame) + 1 ) *f32(player.animation_sheet[player.current_animation].width/4)
                player.sprite_rec.width = - PLAYER_SPRITE_WIDTH
            }
            else {
                player.sprite_rec.x = f32(player.current_frame) * f32(player.animation_sheet[player.current_animation].width/4)
                player.sprite_rec.width = PLAYER_SPRITE_WIDTH

            }
        }
}

controll_update :: proc(player : ^Player){
    if (player.speed.y > PLAYER_MAX_SPEED / 6){
        player.speed.y = clamp(player.speed.y - 1.5, -PLAYER_MAX_SPEED / 2, PLAYER_MAX_SPEED)
    } 
    else if (player.speed.y < PLAYER_MAX_SPEED / 6){
        player.speed.y = clamp(player.speed.y + 1.5, -PLAYER_MAX_SPEED / 2, PLAYER_MAX_SPEED / 6)
    } 
    
    if rl.IsKeyDown(rl.KeyboardKey.LEFT) {
        player.is_left = true
        player.speed.x = clamp(player.speed.x - PLAYER_ACCELERATION, -PLAYER_MAX_SPEED, PLAYER_MAX_SPEED)
        // player.position.x -= rl.GetFrameTime() * player.speed
    }
    if rl.IsKeyDown(rl.KeyboardKey.RIGHT) {
        player.is_left = false
        player.speed.x = clamp(player.speed.x + PLAYER_ACCELERATION, -PLAYER_MAX_SPEED, PLAYER_MAX_SPEED)
        // player.position.x += rl.GetFrameTime() * player.speed
    }

    if rl.IsKeyDown(rl.KeyboardKey.SPACE) {
        player.speed.y = clamp(player.speed.y - 2*PLAYER_ACCELERATION, -PLAYER_MAX_SPEED/2, PLAYER_MAX_SPEED/6)
    }

    if rl.IsKeyDown(rl.KeyboardKey.LEFT_SHIFT) || rl.IsKeyDown(rl.KeyboardKey.RIGHT_SHIFT) {
        player.speed.y = clamp(player.speed.y + 2*PLAYER_ACCELERATION, -PLAYER_MAX_SPEED/2, PLAYER_MAX_SPEED / 3)
    }

    if (player.speed.x > 0){
        player.speed.x -= 2
    } 
    else if (player.speed.x < 0){
        player.speed.x += 2
    } 
    
    player.position += player.speed*rl.GetFrameTime()

    ground_y := get_ground_height(player.position.x+ player.sprite_rec.width/2)

    max_y := ground_y - player.sprite_rec.height - 4
    
    if player.position.y > max_y {
        player.position.y = max_y
        player.speed.y = min(player.speed.y, 0)  
    }
}

main :: proc(){
    generate_ground()

    rl.InitWindow(WIDTH,HEIGHT,"Yellow")
    defer rl.CloseWindow()
    rl.SetTargetFPS(60)
    sail_sheet: rl.Texture2D = rl.LoadTexture("Beach3-Sheet.png")
    defer rl.UnloadTexture(sail_sheet)
    PLAYER_SPRITE_WIDTH = f32(sail_sheet.width / 4)
    render_target := rl.LoadRenderTexture(WIDTH, HEIGHT)
    rl.SetTextureFilter(render_target.texture, .POINT)

    idle_sprite : rl.Texture2D = rl.LoadTexture("Beach3.png")
    defer rl.UnloadTexture(idle_sprite)
    animationArray : [2]rl.Texture2D = {idle_sprite,sail_sheet}
    spriteRec : rl.Rectangle = {0.0, 0.0, -PLAYER_SPRITE_WIDTH, f32(sail_sheet.height)}

    player : Player = {0, .sail, 0, PLAYER_START_POSITION, false, spriteRec, animationArray, rl.Vector2{0, 0}}
    camera := rl.Camera2D{rl.Vector2{WIDTH/2 + player.sprite_rec.width/2,HEIGHT/2 -player.sprite_rec.height/2},player.position,0,2}
    for !rl.WindowShouldClose(){
        dt := rl.GetFrameTime()
        global_state.time += dt
        update_animation_player(&player)
        controll_update(&player)
        camera.target = player.position
        rl.BeginTextureMode(render_target)
            rl.ClearBackground({5, 5, 10, 255})
            rl.BeginMode2D(camera)
                draw_water_surface(camera)
                draw_ground(camera)
                rl.DrawTextureRec(sail_sheet,player.sprite_rec,player.position,rl.WHITE)
                rl.DrawFPS(50+i32(player.position.x),50+i32(player.position.y))
            rl.BeginMode2D(camera)
        rl.EndTextureMode()

        rl.BeginDrawing()
            rl.ClearBackground(rl.BLACK)
            rl.DrawTexturePro(
                render_target.texture,
                {0, 0, f32(WIDTH), -f32(HEIGHT)},
                {0, 0, f32(WIDTH), f32(HEIGHT)},
                {0, 0},
                0,
                rl.WHITE,
            )
        rl.EndDrawing()
    }

}