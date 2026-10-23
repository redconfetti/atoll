; Bikini Atoll - SNES flight game
; LoROM, 65816. Ground is Mode 7 with per-scanline matrix HDMA from ROM tables.
.p816
.smart -
.include "gen.inc"
.include "snes.inc"

.macro VRAM_LOAD src, dst, size
    lda #.loword(src)
    sta d_src
    lda #^(src)
    sta d_bank
    lda #(dst)
    sta d_dst
    lda #(size)
    sta d_size
    jsr dma_vram
.endmacro

; ------------------------------------------------------------------ variables
.segment "ZEROPAGE"
frame:      .res 2
nmi_ready:  .res 2
joy:        .res 2
joy_old:    .res 2
joy_new:    .res 2
px:         .res 4      ; plane x, 16.16
py:         .res 4      ; plane y, 16.16
heading:    .res 2      ; 8.8 angle, 256 = full turn, 0 = north
bank_ang:   .res 2      ; -256..256
altlvl:     .res 2      ; 0..3, camera height step nearest alt_ft
alt_ft:     .res 2      ; altitude in feet, ALT_MIN..ALT_MAX
alt_dir:    .res 2      ; 0 level, 1 climbing, 2 descending
crashed:    .res 2      ; frames since hitting the ocean, 0 = flying
speed:      .res 2      ; 8.8 map units per frame
sinv:       .res 2      ; sin/cos of heading, 8.8
cosv:       .res 2
cam_x:      .res 2
cam_y:      .res 2
cam_h:      .res 2      ; 0..255
cam_alt:    .res 2
m7_hofs:    .res 2
m7_vofs:    .res 2
m7a_ptr:    .res 2
m7b_ptr:    .res 2
m7c_ptr:    .res 2
m7d_ptr:    .res 2
sky_ptr:    .res 2
hdma_mask:  .res 2
bright:     .res 2
tgt:        .res 2
m_a:        .res 2      ; multiply operands / result
m_b:        .res 2
m_ua:       .res 2
m_ub:       .res 2
m_sign:     .res 2
m_r:        .res 4
tmp0:       .res 2
tmp1:       .res 2
tmp2:       .res 2
acc:        .res 4
d_src:      .res 2      ; DMA helper parameters
d_bank:     .res 2
d_dst:      .res 2
d_size:     .res 2
oam_n:      .res 2      ; sprites used this frame
spr_x:      .res 2
spr_y:      .res 2
spr_t:      .res 2      ; tile (low byte) + attributes (high byte)
spr_big:    .res 2
plane_frame: .res 2
plane_src:  .res 2
plane_dirty: .res 2
overlay:    .res 2      ; 1 = controls legend shown
paused:     .res 2
txt_attr:   .res 2
dec_val:    .res 2
dec_cnt:    .res 2
dec_lead:   .res 2
count:      .res 2
pj_x:       .res 2      ; projection input / output
pj_y:       .res 2
pj_z:       .res 2
pj_dx:      .res 2
pj_dy:      .res 2
pj_sx:      .res 2
pj_sy:      .res 2
pj_recip:   .res 2
cam_sin:    .res 2
cam_cos:    .res 2
r_sin:      .res 2
r_cos:      .res 2
r_lat:      .res 2
r_zf:       .res 2
at_x:       .res 2
at_z:       .res 2
lat_t:      .res 2      ; target relative to the plane
zf_t:       .res 2
dist:       .res 2
rel_deg:    .res 2      ; bearing to target, degrees, + = right
deg:        .res 2      ; heading in degrees
deg_q:      .res 2      ; heading / 10
deg_rem:    .res 2
throw:      .res 2      ; forward travel of a bomb dropped now
sight:      .res 2      ; 0 searching, 1 near, 2 over target
state:      .res 2      ; 0 armed, 1 bomb falling, 2 detonated
view:       .res 2      ; 0 chase camera, 1 tail camera
doors:      .res 2      ; 1 = bomb bay open
msg_timer:  .res 2      ; frames left for a temporary message
msg_ptr:    .res 2
pj_min:     .res 2      ; nearest distance project() will draw
screen:     .res 2      ; 0 title, 1 briefing, 2 playing, 3 fade out, 4 ending
txt_dst:    .res 3      ; where put_str / put_dec write (long pointer)
det_t:      .res 2      ; frames since detonation
cgwsel_v:   .res 2      ; colour math registers written each NMI
cgadsub_v:  .res 2
coldata_v:  .res 2
pal_lvl:    .res 2      ; ground tint level shown / wanted
pal_dirty:  .res 2
shake:      .res 2      ; frames of shaking left
shake_amp:  .res 2
shock1:     .res 2      ; det_t when each shock wave arrives
shock2:     .res 2
win_front:  .res 2      ; HDMA buffers in use (0 = A, 2 = B)
win_p:      .res 2      ; pointers to the buffers being built
col_p:      .res 2
cl_y:       .res 2      ; cloud geometry (screen space)
cl_cx:      .res 2
cl_by:      .res 2
cl_top:     .res 2
cl_capc:    .res 2
cl_rx:      .res 2
cl_ry:      .res 2
cl_ryb:     .res 2
cl_stem:    .res 2
cl_ring_y:  .res 2
cl_ring_hw: .res 2
cl_heat:    .res 2      ; ramp row offset: heat * 64
cl_hcap:    .res 2      ; cap height (for colour), clamped to 255
cl_hstem:   .res 2
cl_hw:      .res 2
cl_col:     .res 2
cl_rec:     .res 2

.segment "BSS"
m7d_bank:   .res 2
m7c_bank:   .res 2
m7b_bank:   .res 2
m7a_bank:   .res 2
blink_col:  .res 2
text_dirty: .res 2
text_bank:  .res 2
text_src:   .res 2      ; text screen to upload to VRAM $5000
bx:         .res 4      ; bomb position / velocity, 16.16
by:         .res 4
bz:         .res 4
bvx:        .res 4
bvy:        .res 4
bvz:        .res 4
release_h:  .res 2      ; heading when the bomb was released
turned:     .res 2      ; furthest turn away since release, degrees
det_frames: .res 2      ; frames until detonation
det_x:      .res 2
det_y:      .res 2
oam_buf:    .res 544
spr_hi:     .res 128
hud_buf:    .res 2048
apu_k:      .res 2      ; next IPL kick value for APUIO0
apu_i:      .res 2      ; byte index within an IPL block
apu_dst:    .res 2      ; APU RAM destination for apu_block
win_a:      .res 330    ; window / colour HDMA tables, double buffered
win_b:      .res 330
col_a:      .res 330
col_b:      .res 330

; ------------------------------------------------------------------ reset
.segment "CODE"
reset:
    sei
    clc
    xce
    rep #$38
    .a16
    .i16
    ldx #$1FFF
    txs
    lda #$0000
    tcd
    A8
    pha
    plb
    lda #$8F
    sta INIDISP
    stz NMITIMEN
    stz HDMAEN
    stz MDMAEN
    stz MEMSEL

    ; zero PPU registers $2101-$2133
    ldx #$2101
@clr_ppu:
    stz a:$0000,x
    inx
    cpx #$2134
    bne @clr_ppu

    ; clear WRAM $7E0000-$7EFFFF
    stz WMADDL
    stz WMADDM
    stz WMADDH
    lda #$08                ; fixed source, one register
    sta DMAP0
    lda #<WMDATA
    sta BBAD0
    ldx #.loword(zero_word)
    stx A1T0
    lda #^zero_word
    sta A1B0
    ldx #$0000              ; 64KB
    stx DAS0
    lda #$01
    sta MDMAEN

    ; clear VRAM
    lda #$80
    sta VMAIN
    ldx #$0000
    stx VMADD
    lda #$09                ; fixed source, two registers
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    ldx #.loword(zero_word)
    stx A1T0
    lda #^zero_word
    sta A1B0
    ldx #$0000
    stx DAS0
    lda #$01
    sta MDMAEN

    ; clear CGRAM
    stz CGADD
    lda #$08
    sta DMAP0
    lda #<CGDATA
    sta BBAD0
    ldx #.loword(zero_word)
    stx A1T0
    ldx #512
    stx DAS0
    lda #$01
    sta MDMAEN

    ; Mode 7 tilemap + tiles to VRAM $0000
    ldx #$0000
    stx VMADD
    lda #$01
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    ldx #.loword(m7vram)
    stx A1T0
    lda #^m7vram
    sta A1B0
    ldx #32768
    stx DAS0
    lda #$01
    sta MDMAEN

    ; full palette
    stz CGADD
    stz DMAP0
    lda #<CGDATA
    sta BBAD0
    ldx #.loword(cgram_init)
    stx A1T0
    lda #^cgram_init
    sta A1B0
    ldx #512
    stx DAS0
    lda #$01
    sta MDMAEN

    ; HUD map template into RAM
    ldx #.loword(hud_buf)
    stx WMADDL
    stz WMADDH
    stz DMAP0
    lda #<WMDATA
    sta BBAD0
    ldx #.loword(hudmap)
    stx A1T0
    lda #^hudmap
    sta A1B0
    ldx #2048
    stx DAS0
    lda #$01
    sta MDMAEN

    A16
    VRAM_LOAD font_tiles, $4000, 1568
    VRAM_LOAD legend_map, $5000, 2048
    VRAM_LOAD title_map, $4C00, 2048
    VRAM_LOAD logo_tiles, $4000 + (2 + 96) * 8, LOGO_BYTES
    VRAM_LOAD small_sprites, $6800, 1024
    VRAM_LOAD plane_frames + 2*3072, $6000, 3072
    A8

    ; PPU setup
    lda #$07
    sta BGMODE
    lda #$C0                ; outside the map: repeat tile 0 (ocean)
    sta M7SEL
    lda #$58                ; BG1 (Mode 1 parts): blank map at $5800
    sta BG1SC
    lda #$48                ; BG3 map at $4800
    sta BG3SC
    lda #$04
    sta BG12NBA
    sta BG34NBA
    lda #$63                ; sprites 16x16 / 32x32, tiles at $6000
    sta OBJSEL
    lda #$15                ; main screen: BG1, BG3, sprites
    sta TM
    lda #$30                ; colour math off
    sta CGWSEL

    ; HDMA channel setup (ch0 BGMODE, ch2-5 M7A-D, ch6 sky colour)
    jsr hdma_ch0_setup
    lda #$02
    sta DMAP2
    sta DMAP3
    sta DMAP4
    sta DMAP5
    lda #<M7A
    sta BBAD2
    lda #<M7B
    sta BBAD3
    lda #<M7C
    sta BBAD4
    lda #<M7D
    sta BBAD5
    lda #$03
    sta DMAP6
    lda #<CGADD
    sta BBAD6
    lda #$02                ; ch1: COLDATA, two writes per line
    sta DMAP1
    lda #<COLDATA
    sta BBAD1
    lda #$01                ; ch7: window 1 left/right
    sta DMAP7
    lda #<WH0
    sta BBAD7
    lda #$20                ; colour window = window 1, inside
    sta WOBJSEL

    A16
    ldx #.loword(win_a)
    lda #$00FF
    jsr init_hdma_buf
    ldx #.loword(win_b)
    lda #$00FF
    jsr init_hdma_buf
    ldx #.loword(col_a)
    lda #$E0E0
    jsr init_hdma_buf
    ldx #.loword(col_b)
    lda #$E0E0
    jsr init_hdma_buf
    jsr apu_init
    jsr title_init
    jsr update
    A8
    lda #$81                ; NMI + joypad auto-read
    sta NMITIMEN
    A16

; ------------------------------------------------------------------ main loop
main_loop:
    .a16
@wait:
    lda nmi_ready
    bne @wait
    A8
@autoread:
    lda HVBJOY
    and #$01
    bne @autoread
    A16
    lda joy
    sta joy_old
    lda JOY1L
.ifdef DEMO
    jsr demo_input
.endif
    sta joy
    eor joy_old
    and joy
    sta joy_new
    jsr update
    lda #$0001
    sta nmi_ready
    bra main_loop

; ------------------------------------------------------------------ NMI
nmi:
    rep #$30
    .a16
    .i16
    pha
    phx
    phy
    phb
    phd
    lda #$0000
    tcd
    A8
    pha
    plb
    lda RDNMI
    lda nmi_ready
    bne :+
    jmp @done
:
    lda bright
    sta INIDISP

    ; sprites
    stz OAMADDL
    stz OAMADDH
    stz DMAP0
    lda #<OAMDATA
    sta BBAD0
    ldx #.loword(oam_buf)
    stx A1T0
    stz A1B0
    ldx #544
    stx DAS0
    lda #$01
    sta MDMAEN

    A16
    lda text_dirty
    beq @no_text
    lda text_src
    sta d_src
    lda text_bank
    sta d_bank
    lda #$5000
    sta d_dst
    lda #2048
    sta d_size
    jsr dma_vram
    stz text_dirty
    jmp @no_plane           ; leave the plane upload for the next frame
@no_text:
    VRAM_LOAD hud_buf, $4800, 320               ; top HUD rows 0-4
    VRAM_LOAD hud_buf + 25*64, $4800 + 25*32, 192   ; bottom rows 25-27
    lda pal_dirty
    beq :+
    A8
    lda #32
    sta CGADD
    stz DMAP0
    lda #<CGDATA
    sta BBAD0
    A16
    lda pal_lvl
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    sta tmp0
    asl a
    clc
    adc tmp0                ; level * 192
    adc #.loword(map_tint)
    tax
    A8
    stx A1T0
    lda #^map_tint
    sta A1B0
    ldx #192
    stx DAS0
    lda #$01
    sta MDMAEN
    A16
    stz pal_dirty
:   lda plane_dirty
    beq @no_plane
    lda plane_src
    sta d_src
    lda #^plane_frames
    sta d_bank
    lda #$6000
    sta d_dst
    lda #3072
    sta d_size
    jsr dma_vram
    stz plane_dirty
@no_plane:
    A8
    lda #29                 ; blinking text colour (BG3 palette 7)
    sta CGADD
    lda blink_col
    sta CGDATA
    lda blink_col+1
    sta CGDATA

    lda cam_x
    sta M7X
    lda cam_x+1
    sta M7X
    lda cam_y
    sta M7Y
    lda cam_y+1
    sta M7Y
    lda m7_hofs
    sta BG1HOFS
    lda m7_hofs+1
    sta BG1HOFS
    lda m7_vofs
    sta BG1VOFS
    lda m7_vofs+1
    sta BG1VOFS

    ldx m7a_ptr
    stx A1T2
    lda m7a_bank
    sta A1B2
    ldx m7b_ptr
    stx A1T3
    lda m7b_bank
    sta A1B3
    ldx m7c_ptr
    stx A1T4
    lda m7c_bank
    sta A1B4
    ldx m7d_ptr
    stx A1T5
    lda m7d_bank
    sta A1B5
    ldx sky_ptr
    stx A1T6
    lda #^sky_tables
    sta A1B6
    A16
    lda win_front
    beq :+
    lda #.loword(win_b)
    ldx #.loword(col_b)
    bra :++
:   lda #.loword(win_a)
    ldx #.loword(col_a)
:   sta A1T7
    stx A1T1
    A8
    stz A1B7
    stz A1B1
    lda cgwsel_v
    sta CGWSEL
    lda cgadsub_v
    sta CGADSUB
    lda coldata_v
    sta COLDATA

    lda overlay
    beq @game_screen
    lda #$09                ; legend: plain Mode 1 text screen
    sta BGMODE
    lda #$50
    sta BG3SC
    lda #$04
    sta TM
    stz CGADD
    lda #$43
    sta CGDATA
    lda #$0C
    sta CGDATA
    lda #$30
    sta CGWSEL
    stz HDMAEN
    stz nmi_ready
    jmp @done
@game_screen:
    lda #$48
    ldx screen
    bne :+
    lda #$4C                ; title text
:   sta BG3SC
    lda #$15
    sta TM
    jsr hdma_ch0_setup
    lda hdma_mask
    sta HDMAEN
    stz nmi_ready
@done:
    rep #$30
    inc frame
    pld
    plb
    ply
    plx
    pla
    rti

; Channel 0 doubles as the general DMA channel during vblank, so its HDMA
; settings are rewritten each frame.
hdma_ch0_setup:
    .a8
    stz DMAP0
    lda #<BGMODE
    sta BBAD0
    ldx #.loword(bgmode_hdma)
    stx A1T0
    lda #^bgmode_hdma
    sta A1B0
    rts

; VRAM DMA: d_src/d_bank -> VRAM word address d_dst, d_size bytes.
dma_vram:
    .a16
    A8
    lda #$80
    sta VMAIN
    ldx d_dst
    stx VMADD
    lda #$01
    sta DMAP0
    lda #<VMDATAL
    sta BBAD0
    ldx d_src
    stx A1T0
    lda d_bank
    sta A1B0
    ldx d_size
    stx DAS0
    lda #$01
    sta MDMAEN
    A16
    rts

irq_stub:
    rti

; ------------------------------------------------------------------ game
game_init:
    .a16
    stz px
    lda #START_X
    sta px+2
    stz py
    lda #START_Y
    sta py+2
    lda #(START_HEADING << 8)
    sta heading
    stz bank_ang
    lda #ALT_START
    sta alt_ft
    jsr alt_level
    lda #94
    sta speed
    lda #.loword(sky_tables)
    sta sky_ptr
    lda #$7D                ; ch0, ch2-5, ch6
    sta hdma_mask
    lda #$0F
    sta bright
    lda #2
    sta plane_frame
    lda #.loword(plane_frames) + 2*3072
    sta plane_src
    lda #16
    sta pj_min
    lda #$30                ; colour math off
    sta cgwsel_v
    lda #$35
    sta cgadsub_v
    lda #$E0
    sta coldata_v
    stz state
    stz view
    stz doors
    stz paused
    stz overlay
    stz msg_timer
    stz det_t
    stz shake
    stz turned
    stz alt_dir
    stz crashed
    stz win_front
    stz pal_lvl
    lda #1
    sta pal_dirty
    sta plane_dirty
    lda #.loword(hud_buf)
    sta txt_dst
    A8
    stz txt_dst+2
    A16
    rts

title_init:
    .a16
    jsr game_init
    stz screen
    lda #34000
    sta alt_ft
    jsr alt_level
    stz heading
    rts

update:
    .a16
    lda screen
    asl a
    tax
    jmp (screen_tbl,x)

; Title: slow orbit around the atoll. START -> briefing, SELECT -> controls.
upd_title:
    lda #$237F              ; blink "PRESS START"
    sta blink_col
    lda frame
    and #$20
    beq :+
    lda #$0C21
    sta blink_col
:   lda overlay
    beq :+
    lda joy_new
    and #(JOY_SELECT | JOY_START)
    beq @orbit
    stz overlay
    bra @orbit
:   lda joy_new
    bit #JOY_SELECT
    beq :+
    lda #.loword(legend_map)
    ldx #^legend_map
    jsr show_text
    bra @orbit
:   bit #JOY_START
    beq @orbit
    lda #1
    sta screen
    lda #.loword(brief_map)
    ldx #^brief_map
    jsr show_text
    rts
@orbit:
    lda heading
    clc
    adc #$0018
    sta heading
    jsr calc_trig
    lda sinv
    sta m_a
    lda #380
    sta m_b
    jsr mul16s
    lda #TARGET_X
    sec
    sbc m_r+1
    sta px+2
    lda cosv
    sta m_a
    lda #380
    sta m_b
    jsr mul16s
    lda #TARGET_Y
    clc
    adc m_r+1
    sta py+2
    stz joy_new
    jsr camera
    stz oam_n
    jsr oam_finish
    rts

upd_brief:
    lda joy_new
    bit #JOY_START
    beq :+
    jsr game_init
    lda #2
    sta screen
:   rts

; Fade to black after the test, then show the results.
upd_fade:
    lda frame
    and #1
    bne :+
    lda bright
    beq @done
    dec bright
:   rts
@done:
    jsr build_ending
    lda #4
    sta screen
    lda #$0F
    sta bright
    rts

upd_end:
    lda joy_new
    bit #JOY_START
    beq :+
    jsr title_init
:   rts

; A = text map address, X = bank.
show_text:
    .a16
    sta text_src
    stx text_bank
    lda #1
    sta text_dirty
    sta overlay
    rts

; Results screen: template copied to WRAM $7E2000, numbers filled in.
build_ending:
    .a16
    ldx #0
:   lda f:ending_map,x
    sta f:$7E2000,x
    inx
    inx
    cpx #2048
    bne :-
    lda #$2000
    sta txt_dst
    A8
    lda #$7E
    sta txt_dst+2
    A16

    lda det_x               ; miss distance ~ max + 3/8 min, 80 ft per unit
    sec
    sbc #TARGET_X
    jsr abs_a
    sta tmp0
    lda det_y
    sec
    sbc #TARGET_Y
    jsr abs_a
    cmp tmp0
    bcc :+
    ldx tmp0
    sta tmp0
    txa
:   lsr a
    lsr a
    sta tmp1
    lsr a
    clc
    adc tmp1
    clc
    adc tmp0
    cmp #800
    bcc :+
    lda #800
:   sta count
    sta m_ua
    lda #80
    sta m_ub
    jsr mul16u
    lda #$2400
    sta txt_attr
    stz dec_lead
    lda m_r
    ldx #5
    ldy #END_MISS_OFS
    jsr put_dec
    stz dec_lead
    lda turned
    ldx #3
    ldy #END_TURN_OFS
    jsr put_dec

    ldx #.loword(rate_bull)
    lda count
    cmp #6
    bcc @rate
    ldx #.loword(rate_on)
    cmp #25
    bcc @rate
    ldx #.loword(rate_near)
    cmp #75
    bcc @rate
    ldx #.loword(rate_wide)
@rate:
    ldy #END_BOMB_OFS
    jsr put_str
    ldx #.loword(rate_safe)
    lda turned
    cmp #150
    bcs :+
    ldx #.loword(rate_shallow)
:   ldy #END_TURN2_OFS
    jsr put_str

    lda #.loword(hud_buf)
    sta txt_dst
    A8
    stz txt_dst+2
    A16
    lda #$2000
    ldx #$7E
    jsr show_text
    rts

; The game itself.
upd_play:
    lda crashed
    beq :+
    jmp crash_update
:   lda state
    cmp #2
    bne :+
    lda det_t
    cmp #700
    bcc :+
    lda #3
    sta screen
    rts
:   lda overlay
    beq @playing
    lda joy_new
    and #(JOY_SELECT | JOY_START)
    beq :+
    stz overlay
:   rts
@playing:
    lda joy_new
    bit #JOY_SELECT
    beq :+
    lda #.loword(legend_map)
    ldx #^legend_map
    jsr show_text
    rts
:   lda joy_new
    bit #JOY_START
    beq :+
    lda paused
    eor #1
    sta paused
:   lda paused
    bne :+
    jsr steer
    jsr throttle
    jsr move_plane
    jsr bomb_controls
    jsr bomb_update
    jsr aftermath
:   jsr camera
    jsr target_info
    jsr hud
    jsr draw_sprites
    jsr cloud
    rts

; B button: bay doors. A button: release (doors must be open).
bomb_controls:
    .a16
    lda state
    bne @done
    lda joy_new
    bit #JOY_B
    beq :+
    lda doors
    eor #1
    sta doors
:   lda joy_new
    bit #JOY_A
    beq @done
    lda doors
    bne @release
    lda #.loword(msg_doors)
    sta msg_ptr
    lda #120
    sta msg_timer
@done:
    rts
@release:
    lda px
    sta bx
    lda px+2
    sta bx+2
    lda py
    sta by
    lda py+2
    sta by+2
    stz bz
    ldx altlvl
    lda camalt_table,x
    and #$00FF
    sec
    sbc #CAM_UP
    sta bz+2
    stz bvz
    stz bvz+2
    lda sinv
    sta m_a
    lda speed
    sta m_b
    jsr mul16s
    lda m_r
    sta bvx
    lda m_r+2
    sta bvx+2
    lda cosv
    sta m_a
    lda speed
    sta m_b
    jsr mul16s
    lda m_r
    eor #$FFFF
    clc
    adc #1
    sta bvy
    lda m_r+2
    eor #$FFFF
    adc #0
    sta bvy+2
    lda heading
    sta release_h
    stz turned
    lda altlvl
    asl a
    tax
    lda falln_table,x
    sta det_frames
    stz msg_timer
    lda #1
    sta state
    rts

; Bomb flight: drag on horizontal speed, gravity, detonation at DET_Z.
bomb_update:
    .a16
    lda state
    cmp #1
    beq :+
    rts
:   ldx #bvx
    jsr drag32
    ldx #bvy
    jsr drag32
    lda bx
    clc
    adc bvx
    sta bx
    lda bx+2
    adc bvx+2
    sta bx+2
    lda by
    clc
    adc bvy
    sta by
    lda by+2
    adc bvy+2
    sta by+2
    lda bvz
    sec
    sbc #GRAVITY
    sta bvz
    lda bvz+2
    sbc #0
    sta bvz+2
    lda bz
    clc
    adc bvz
    sta bz
    lda bz+2
    adc bvz+2
    sta bz+2

    ; how far has the plane turned away since release?
    lda heading
    sec
    sbc release_h
    jsr abs_a
    xba
    and #$00FF
    sta m_ua
    lda #45
    sta m_ub
    jsr mul16u
    lda m_r
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    cmp turned
    bcc :+
    sta turned
:   lda det_frames
    beq :+
    dec det_frames
:
    lda bz+2
    bmi @boom
    cmp #.hiword(DET_Z)
    bcc @boom
    bne @done
    lda bz
    cmp #.loword(DET_Z)
    bcs @done
@boom:
    ldx #.loword(dsp_boom)
    jsr dsp_write
    lda bx+2
    sta det_x
    lda by+2
    sta det_y
    lda #2
    sta state
    stz det_t
    ; shock waves arrive later the further away the plane is
    lda det_x
    sec
    sbc px+2
    jsr abs_a
    sta tmp0
    lda det_y
    sec
    sbc py+2
    jsr abs_a
    clc
    adc tmp0
    lsr a
    lsr a
    clc
    adc #110
    sta shock1
    clc
    adc #70
    sta shock2
@done:
    rts

; 32-bit value at X -= value >> 8 (signed)
drag32:
    .a16
    lda 3,x
    and #$00FF
    cmp #$0080
    bcc :+
    ora #$FF00
:   sta tmp1
    lda 1,x
    sta tmp0
    lda 0,x
    sec
    sbc tmp0
    sta 0,x
    lda 2,x
    sbc tmp1
    sta 2,x
    rts

; L / R shoulder buttons: slower / faster.
throttle:
    lda joy
    bit #JOY_R
    beq :+
    lda speed
    cmp #120
    bcs :+
    inc speed
:   lda joy
    bit #JOY_L
    beq :+
    lda speed
    cmp #71
    bcc :+
    dec speed
:   rts

; Bank towards the held direction, turn by bank angle, climb/descend in steps.
steer:
    stz tgt
    lda joy
    bit #JOY_LEFT
    beq :+
    lda #.loword(-256)
    sta tgt
:   lda joy
    bit #JOY_RIGHT
    beq :+
    lda #256
    sta tgt
:   lda tgt
    sec
    sbc bank_ang
    bmi @neg
    cmp #12
    bcc @add
    lda #12
    bra @add
@neg:
    cmp #.loword(-12)
    bcs @add
    lda #.loword(-12)
@add:
    clc
    adc bank_ang
    sta bank_ang

    sta m_a
    lda #106                ; full bank = ~35 degrees per second
    sta m_b
    jsr mul16s
    lda m_r+1
    clc
    adc heading
    sta heading

    ; Up / Down: climb or descend at ALT_RATE feet per frame. The camera
    ; snaps to the nearest of the four pre-rendered heights.
    stz alt_dir
    lda joy
    bit #JOY_UP
    beq @not_up
    lda alt_ft
    cmp #ALT_MAX
    bcs @set_lvl
    adc #ALT_RATE
    cmp #ALT_MAX
    bcc :+
    lda #ALT_MAX
:   sta alt_ft
    lda #1
    sta alt_dir
    bra @set_lvl
@not_up:
    bit #JOY_DOWN
    beq @set_lvl
    lda alt_ft
    cmp #(ALT_MIN + ALT_RATE)
    bcs :+
    lda #(ALT_MIN + ALT_RATE)
:   sec
    sbc #ALT_RATE
    cmp alt_ft
    beq @set_lvl
    sta alt_ft
    lda #2
    sta alt_dir
@set_lvl:
    lda alt_ft
    cmp #ALT_CRASH
    bcs alt_level
    jsr crash_start
    ; fall through

; altlvl = camera height step for alt_ft.
alt_level:
    .a16
    ldx #0
    lda alt_ft
:   cmp alt_steps,x
    bcc :+
    inx
    inx
    cpx #((NLVL - 1) * 2)
    bcc :-
:   txa
    lsr a
    sta altlvl
    rts

; Too low: the plane hits the ocean.
crash_start:
    .a16
    lda #1
    sta crashed
    stz alt_dir
    lda #45
    sta shake
    lda #4
    sta shake_amp
    ldx #.loword(dsp_boom)
    jmp dsp_write

; After a crash: white flash, shaking, then START returns to the title.
crash_update:
    .a16
    inc crashed
    lda crashed
    cmp #32
    bcs :+
    eor #$001F
    and #$001F
    ora #$00E0
    sta coldata_v
    stz cgwsel_v            ; colour math everywhere, no clipping
    lda #$3F
    sta cgadsub_v
    bra @shake
:   lda #$E0
    sta coldata_v
@shake:
    lda shake
    beq :+
    dec shake
:   lda crashed
    cmp #90
    bcc @draw
    lda joy_new
    bit #JOY_START
    beq @draw
    jmp title_init
@draw:
    jsr camera
    jsr target_info
    jsr hud
    jsr draw_sprites
    jmp cloud

move_plane:
    jsr calc_trig
    jmp move_body

calc_trig:
    .a16
    lda heading
    xba
    and #$00FF
    asl
    tax
    lda sin_table,x
    sta sinv
    txa
    clc
    adc #128                ; +64 entries = cos
    and #$01FF
    tax
    lda sin_table,x
    sta cosv
    rts

move_body:
    lda sinv
    sta m_a
    lda speed
    sta m_b
    jsr mul16s
    lda px
    clc
    adc m_r
    sta px
    lda px+2
    adc m_r+2
    sta px+2

    lda cosv
    sta m_a
    lda speed
    sta m_b
    jsr mul16s
    lda py
    sec
    sbc m_r
    sta py
    lda py+2
    sbc m_r+2
    sta py+2

    ; keep within the Mode 7 coordinate range
    ldx #px+2
    jsr clamp_coord
    ldx #py+2
    jsr clamp_coord
    rts

clamp_coord:
    lda 0,x
    bpl @pos
    cmp #.loword(-800)
    bcs @ok
    lda #.loword(-800)
    sta 0,x
    rts
@pos:
    cmp #1800
    bcc @ok
    lda #1800
    sta 0,x
@ok:
    rts

; Chase camera CAM_BACK units behind the plane, or tail camera looking back.
camera:
    lda joy_new
    bit #JOY_X
    beq :+
    lda view
    eor #1
    sta view
:   lda heading
    xba
    and #$00FF
    sta cam_h
    lda view
    beq @chase
    lda cam_h
    eor #$0080
    sta cam_h
    lda px+2
    sta cam_x
    lda py+2
    sta cam_y
    lda sinv
    eor #$FFFF
    inc a
    sta cam_sin
    lda cosv
    eor #$FFFF
    inc a
    sta cam_cos
    bra @placed
@chase:

    lda sinv
    sta m_a
    lda #CAM_BACK
    sta m_b
    jsr mul16s
    lda px+2
    sec
    sbc m_r+1
    sta cam_x
    lda cosv
    sta m_a
    lda #CAM_BACK
    sta m_b
    jsr mul16s
    lda py+2
    clc
    adc m_r+1
    sta cam_y

    lda sinv
    sta cam_sin
    lda cosv
    sta cam_cos
@placed:
    lda cam_x
    sec
    sbc #128
    sta m7_hofs
    lda cam_y
    sec
    sbc #HOR
    sta m7_vofs
    lda shake
    beq @no_shake
    lda frame
    lsr a
    bcc :+
    lda m7_hofs
    clc
    adc shake_amp
    sta m7_hofs
    bra :++
:   lda m7_vofs
    sec
    sbc shake_amp
    sta m7_vofs
:
@no_shake:

    ldx altlvl
    lda camalt_table,x
    and #$00FF
    sta cam_alt

    ; A = P1[h], B = P2[h-64], C = P1[h-64], D = P2[h+128]
    lda #M7_P1_BANK
    sta tmp0
    lda cam_h
    jsr table_addr
    sta m7a_ptr
    lda tmp1
    sta m7a_bank
    lda cam_h
    sec
    sbc #64
    jsr table_addr
    sta m7c_ptr
    lda tmp1
    sta m7c_bank
    lda #M7_P2_BANK
    sta tmp0
    lda cam_h
    sec
    sbc #64
    jsr table_addr
    sta m7b_ptr
    lda tmp1
    sta m7b_bank
    lda cam_h
    clc
    adc #128
    jsr table_addr
    sta m7d_ptr
    lda tmp1
    sta m7d_bank
    rts

; In: A = angle, tmp0 = family bank base. Out: A = address, tmp1 = bank.
table_addr:
    and #$00FF
    pha
    and #$007F
    xba
    ora #$8000
    sta tmp2
    pla
    asl
    xba
    and #$0001
    clc
    adc tmp0
    sta tmp1
    lda altlvl
    asl
    clc
    adc tmp1
    sta tmp1
    lda tmp2
    rts

; ------------------------------------------------------------------ targeting
; Target position relative to the plane, distance, bearing and bombsight.
target_info:
    .a16
    lda #TARGET_X
    sec
    sbc px+2
    sta pj_dx
    lda #TARGET_Y
    sec
    sbc py+2
    sta pj_dy
    lda sinv
    sta r_sin
    lda cosv
    sta r_cos
    jsr rotate
    lda r_lat
    sta lat_t
    lda r_zf
    sta zf_t

    ; distance ~ max + 3/8 min
    lda pj_dx
    bpl :+
    eor #$FFFF
    inc a
:   sta tmp0
    lda pj_dy
    bpl :+
    eor #$FFFF
    inc a
:   sta tmp1
    cmp tmp0
    bcc :+
    ldx tmp0                ; swap so tmp0 = max, tmp1 = min
    sta tmp0
    stx tmp1
:   lda tmp1
    lsr a
    lsr a
    sta tmp2
    lsr a
    clc
    adc tmp2
    clc
    adc tmp0
    sta dist

    ; bearing in degrees
    jsr atan2
    sta tmp0
    bpl :+
    eor #$FFFF
    inc a
:   sta m_ua
    lda #45
    sta m_ub
    jsr mul16u
    lda m_r
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    ldx tmp0
    bpl :+
    eor #$FFFF
    inc a
:   sta rel_deg

    ; bombsight: where would a bomb dropped now land?
    ldx altlvl
    lda throwf_table,x
    and #$00FF
    sta m_ua
    lda speed
    sta m_ub
    jsr mul16u
    lda m_r+1
    and #$00FF
    sta throw

    stz sight
    lda zf_t
    sec
    sbc throw
    jsr abs_a
    cmp #12
    bcs @not_over
    lda lat_t
    jsr abs_a
    cmp #10
    bcs @not_over
    lda #2
    sta sight
    rts
@not_over:
    lda dist
    cmp #240
    bcs :+
    lda #1
    sta sight
:   rts

abs_a:
    .a16
    cmp #$8000
    bcc :+
    eor #$FFFF
    inc a
:   rts

; ------------------------------------------------------------------ HUD
hud:
    .a16
    ; heading in degrees and the compass tape
    lda heading
    xba
    and #$00FF
    sta m_ua
    lda #45
    sta m_ub
    jsr mul16u
    lda m_r
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    sta deg
    ldx #10
    jsr divide
    sta deg_q
    lda RDMPYL
    sta deg_rem

    lda deg_q
    sec
    sbc #12
    bpl :+
    clc
    adc #36
:   sta tmp0
    ldy #(1*64 + 4*2)
    lda #25
    sta count
@tape:
    lda tmp0
    asl a
    tax
    lda tape_table,x
    sta hud_buf,y
    iny
    iny
    lda tmp0
    inc a
    cmp #36
    bcc :+
    lda #0
:   sta tmp0
    dec count
    bne @tape

    ; message line (row 3)
    lda #$2400              ; yellow
    sta txt_attr
    lda crashed
    beq @not_crashed
    lda #$2800              ; red
    sta txt_attr
    ldx #.loword(msg_crash)
    lda crashed
    cmp #90
    bcc :+
    lda frame
    and #$20
    beq :+
    ldx #.loword(msg_restart)
:   jmp @msg
@not_crashed:
    ldx #.loword(msg_paused)
    lda paused
    beq :+
    jmp @msg
:   lda alt_ft
    cmp #ALT_WARN
    bcs :++
    lda #$2800
    sta txt_attr
    ldx #.loword(msg_pullup)
    lda frame
    and #$10
    beq :+
    ldx #.loword(msg_blank)
:   jmp @msg
:   lda msg_timer
    beq @no_tmp
    dec msg_timer
    ldx msg_ptr
    jmp @msg
@no_tmp:
    lda state
    beq @guide
    cmp #1
    bne @after
    ldx #.loword(msg_break)
    lda turned
    cmp #150
    bcc @msg
    ldx #.loword(msg_clear)
    lda #$2C00
    sta txt_attr
    bra @msg
@after:
    ldx #.loword(msg_blank)
    lda det_t
    cmp #600
    bcc @msg
    ldx #.loword(msg_home)
    lda #$2C00
    sta txt_attr
    bra @msg
@guide:
    lda rel_deg
    jsr abs_a
    cmp #5
    bcs :+
    ldx #.loword(msg_oncourse)
    lda #$2C00              ; green
    sta txt_attr
    bra @msg
:   cmp #150
    bcc :+
    ldx #.loword(msg_around)
    bra @msg
:   ldx #.loword(msg_right)
    lda rel_deg
    bpl @msg
    ldx #.loword(msg_left)
@msg:
    ldy #(3*64)
    jsr put_str

    ; row 4: turn progress and countdown while the bomb falls
    lda #$2000
    sta txt_attr
    ldx #.loword(msg_blank)
    lda state
    cmp #1
    bne :+
    ldx #.loword(msg_turn)
:   ldy #(4*64)
    jsr put_str
    lda state
    cmp #1
    bne @row4_done
    lda #$2400
    sta txt_attr
    lda #1
    sta dec_lead
    lda turned
    ldx #3
    ldy #(4*64 + 8*2)
    jsr put_dec
    lda det_frames
    clc
    adc #59
    ldx #60
    jsr divide
    ldx #2
    ldy #(4*64 + 28*2)
    pha
    lda #1
    sta dec_lead
    pla
    jsr put_dec
@row4_done:

    ; camera label (row 0)
    lda #$3800              ; cyan
    sta txt_attr
    ldx #.loword(lbl_noview)
    lda view
    beq :+
    ldx #.loword(lbl_tail)
:   ldy #0
    jsr put_str

    ; bomb and bay status
    lda #$2C00
    sta txt_attr
    ldx #.loword(st_armed)
    lda state
    beq :+
    lda #$2400
    sta txt_attr
    ldx #.loword(st_away)
:   ldy #(25*64 + 26*2)
    jsr put_str
    lda #$2000
    sta txt_attr
    ldx #.loword(st_shut)
    lda doors
    beq :+
    lda #$2400
    sta txt_attr
    ldx #.loword(st_open)
:   ldy #(26*64 + 26*2)
    jsr put_str

    ; numbers
    lda #$2000
    sta txt_attr
    lda alt_ft
    ldx #5
    ldy #(25*64 + 5*2)
    stz dec_lead
    jsr put_dec
    lda #(' ' - 30) | $2000
    ldx alt_dir
    beq :+
    lda #('{' - 30) | $2400 ; climbing arrow
    dex
    beq :+
    lda #('}' - 30) | $2400 ; descending arrow
:   sta hud_buf + 25*64 + 12*2

    lda speed
    sta m_ua
    lda #7
    sta m_ub
    jsr mul16u
    lda m_r
    lsr a
    ldx #3
    ldy #(25*64 + 18*2)
    stz dec_lead
    jsr put_dec

    lda deg
    ldx #3
    ldy #(26*64 + 5*2)
    lda #1
    sta dec_lead
    lda deg
    jsr put_dec

    lda dist                ; tenths of a mile
    sta m_ua
    lda #39
    sta m_ub
    jsr mul16u
    lda m_r+1
    cmp #999
    bcc :+
    lda #999
:   ldx #10
    jsr divide
    pha
    lda RDMPYL
    sta tmp0
    pla
    ldx #2
    ldy #(26*64 + 14*2)
    stz dec_lead
    jsr put_dec
    lda #('.' - 30) | $2000
    sta hud_buf + 26*64 + 16*2
    lda #1
    sta dec_lead
    lda tmp0
    ldx #1
    ldy #(26*64 + 17*2)
    jsr put_dec

    ; sight status
    ldx #.loword(st_search)
    lda #$3400              ; grey
    sta txt_attr
    lda state
    beq :+
    ldx #.loword(st_none)
    bra @st
:   lda sight
    beq @st
    ldx #.loword(st_near)
    lda #$2400
    sta txt_attr
    lda sight
    cmp #2
    bne @st
    ldx #.loword(st_over)
    lda #$2800              ; red, blinking
    sta txt_attr
    lda frame
    and #8
    beq @st
    lda #$2000
    sta txt_attr
@st:
    ldy #(27*64 + 7*2)
    jsr put_str
    rts

; X = zero-terminated string (bank 0), Y = hud_buf offset, txt_attr.
put_str:
    .a16
@loop:
    lda a:0,x
    and #$00FF
    beq @done
    sec
    sbc #30
    ora txt_attr
    sta [txt_dst],y
    inx
    iny
    iny
    bra @loop
@done:
    rts

; A = value, X = digits (1-5), Y = hud_buf offset, dec_lead = 1 for zeros.
put_dec:
    .a16
    sta dec_val
    txa
    asl a
    sta tmp2
    lda #10
    sec
    sbc tmp2
    tax
@digit:
    stz dec_cnt
    lda dec_val
@sub:
    cmp pow10,x
    bcc @out
    sbc pow10,x
    inc dec_cnt
    bra @sub
@out:
    sta dec_val
    lda dec_cnt
    bne @nz
    cpx #8
    beq @nz
    lda dec_lead
    bne @nz
    lda #(' ' - 30)
    bra @store
@nz:
    lda #1
    sta dec_lead
    lda dec_cnt
    clc
    adc #('0' - 30)
@store:
    ora txt_attr
    sta [txt_dst],y
    iny
    iny
    inx
    inx
    cpx #10
    bne @digit
    rts

; ------------------------------------------------------------------ sprites
draw_sprites:
    .a16
    stz oam_n
    lda view
    ora crashed
    beq :+
    jmp @no_plane
:
    ; plane: pick the bank frame
    lda #2
    ldx bank_ang
    cpx #.loword(-160)
    bcs :+
    cpx #$8000
    bcc :+
    lda #0
    bra @frame
:   cpx #.loword(-60)
    bcs :+
    cpx #$8000
    bcc :+
    lda #1
    bra @frame
:   cpx #161
    bcc :+
    cpx #$8000
    bcs :+
    lda #4
    bra @frame
:   cpx #61
    bcc @frame
    cpx #$8000
    bcs @frame
    lda #3
@frame:
    cmp plane_frame
    beq :+
    sta plane_frame
    asl a
    tax
    lda plane_ofs,x
    clc
    adc #.loword(plane_frames)
    sta plane_src
    lda #1
    sta plane_dirty
:
    lda alt_ft              ; higher altitude draws the plane higher
    sec
    sbc #ALT_MIN
    xba
    and #$00FF
    lsr a
    lsr a
    eor #$FFFF
    sec
    adc #PLANE_Y_LOW
    sta tmp2
    lda alt_dir             ; nose up while climbing, down while descending
    beq :+
    dec tmp2
    dec tmp2
    lsr a
    bcs :+
    inc tmp2
    inc tmp2
    inc tmp2
    inc tmp2
:
    lda #1
    sta spr_big
    lda tmp2
    sta spr_y
    lda #$2000
    sta spr_t
    lda #80
    sta spr_x
    jsr add_sprite
    lda #$2004
    sta spr_t
    lda #112
    sta spr_x
    jsr add_sprite
    lda #$2008
    sta spr_t
    lda #144
    sta spr_x
    jsr add_sprite
    stz spr_big
    lda tmp2
    clc
    adc #32
    sta spr_y
    lda #$2040
    sta spr_t
    lda #80
    sta spr_x
@lower:
    jsr add_sprite
    lda spr_t
    inc a
    inc a
    sta spr_t
    lda spr_x
    clc
    adc #16
    sta spr_x
    cmp #176
    bcc @lower
@no_plane:

    ; falling bomb
    lda state
    cmp #1
    bne @no_bomb
    lda bx+2
    sta pj_x
    lda by+2
    sta pj_y
    lda bz+2
    sta pj_z
    lda #4
    sta pj_min
    jsr project
    lda #16
    sta pj_min
    bcs @no_bomb
    lda #$2284              ; near bomb
    ldx pj_recip
    cpx #700
    bcs :+
    lda #$2286              ; far bomb
:   sta spr_t
    lda #8
    jsr place_scene_sprite
@no_bomb:

    ; bombsight ring where the bomb would land (chase view, still armed)
    lda view
    ora state
    bne @no_ring
    lda throw
    sta m_a
    lda sinv
    sta m_b
    jsr mul16s
    lda px+2
    clc
    adc m_r+1
    sta pj_x
    lda throw
    sta m_a
    lda cosv
    sta m_b
    jsr mul16s
    lda py+2
    sec
    sbc m_r+1
    sta pj_y
    stz pj_z
    jsr project
    bcs @no_ring
    lda sight
    inc a
    asl a
    ora #$20
    xba
    ora #$80                ; tile 128
    sta spr_t
    lda #8
    jsr place_scene_sprite
@no_ring:

    ; target marker
    lda state
    cmp #2
    bcs @no_mark
    lda frame
    and #$18
    beq @no_mark
    lda #TARGET_X
    sta pj_x
    lda #TARGET_Y
    sta pj_y
    stz pj_z
    jsr project
    bcs @no_mark
    lda #$2282
    sta spr_t
    lda #15
    jsr place_scene_sprite
@no_mark:

    ; compass marker under the tape
    lda rel_deg
    clc
    adc deg_rem
    sta m_a
    lda #13
    sta m_b
    jsr mul16s
    lda m_r
    ldx #4
:   cmp #$8000
    ror a
    dex
    bne :-
    clc
    adc #132
    bpl :+
    lda #0
:   cmp #36
    bcs :+
    lda #36
:   cmp #221
    bcc :+
    lda #220
:   sec
    sbc #8
    sta spr_x
    lda #16
    sta spr_y
    lda #$2288
    sta spr_t
    stz spr_big
    jsr add_sprite

    jsr oam_finish
    rts

; Small sprite at the projected point (pj_sx, pj_sy), A = y offset up.
; Only drawn inside the ground part of the screen.
place_scene_sprite:
    .a16
    sta tmp0
    lda pj_sy
    cmp #74
    bmi @off
    cmp #198
    bpl @off
    sec
    sbc tmp0
    sta spr_y
    lda pj_sx
    sec
    sbc #8
    sta spr_x
    stz spr_big
    jsr add_sprite
@off:
    rts

add_sprite:
    .a16
    ldx oam_n
    cpx #128
    bcs @done
    lda spr_x
    cmp #.loword(-31)
    bcs :+
    cmp #256
    bcs @done
:   txa
    asl a
    asl a
    tay
    A8
    lda spr_x
    sta oam_buf,y
    lda spr_y
    sta oam_buf+1,y
    A16
    lda spr_t
    sta oam_buf+2,y
    lda spr_x+1
    and #$0001
    sta tmp1
    lda spr_big
    asl a
    ora tmp1
    A8
    sta spr_hi,x
    A16
    inc oam_n
@done:
    rts

oam_finish:
    .a16
    ldx oam_n
@fill:
    cpx #128
    bcs @pack
    txa
    asl a
    asl a
    tay
    A8
    lda #240
    sta oam_buf+1,y
    stz spr_hi,x
    A16
    inx
    bra @fill
@pack:
    ldx #0
    ldy #0
    A8
@p:
    lda spr_hi+3,x
    asl a
    asl a
    ora spr_hi+2,x
    asl a
    asl a
    ora spr_hi+1,x
    asl a
    asl a
    ora spr_hi,x
    sta oam_buf+512,y
    inx
    inx
    inx
    inx
    iny
    cpy #32
    bne @p
    A16
    rts

; ------------------------------------------------------------------ 3D helpers
; (pj_dx, pj_dy) rotated by (r_sin, r_cos) -> r_lat (right), r_zf (forward)
rotate:
    .a16
    lda pj_dx
    sta m_a
    lda r_sin
    sta m_b
    jsr mul16s
    lda m_r
    sta acc
    lda m_r+2
    sta acc+2
    lda pj_dy
    sta m_a
    lda r_cos
    sta m_b
    jsr mul16s
    lda acc
    sec
    sbc m_r
    sta acc
    lda acc+2
    sbc m_r+2
    sta acc+2
    lda acc+1
    sta r_zf

    lda pj_dx
    sta m_a
    lda r_cos
    sta m_b
    jsr mul16s
    lda m_r
    sta acc
    lda m_r+2
    sta acc+2
    lda pj_dy
    sta m_a
    lda r_sin
    sta m_b
    jsr mul16s
    lda acc
    clc
    adc m_r
    sta acc
    lda acc+2
    adc m_r+2
    sta acc+2
    lda acc+1
    sta r_lat
    rts

; World (pj_x, pj_y, pj_z) -> screen (pj_sx, pj_sy), pj_recip = pixels per
; unit (8.8). Carry set if behind the camera.
project:
    .a16
    lda pj_x
    sec
    sbc cam_x
    sta pj_dx
    lda pj_y
    sec
    sbc cam_y
    sta pj_dy
    lda cam_sin
    sta r_sin
    lda cam_cos
    sta r_cos
    jsr rotate
    lda r_zf
    bmi @hidden
    cmp pj_min
    bcc @hidden
    cmp #1020
    bcc :+
    lda #1020
:   lsr a
    lsr a
    tax
    lda #8192
    jsr divide
    sta pj_recip
    lda r_lat
    sta m_a
    lda pj_recip
    sta m_b
    jsr mul16s
    lda m_r+1
    clc
    adc #128
    sta pj_sx
    lda cam_alt
    sec
    sbc pj_z
    sta m_a
    lda pj_recip
    sta m_b
    jsr mul16s
    lda m_r+1
    clc
    adc #HOR
    sta pj_sy
    clc
    rts
@hidden:
    sec
    rts

; Angle of (r_lat, r_zf) from straight ahead: A = -128..127, + = right.
atan2:
    .a16
    lda r_lat
    jsr abs_a
    sta at_x
    lda r_zf
    jsr abs_a
    sta at_z
@scale:
    lda at_x
    ora at_z
    and #$FF00
    beq @ok
    lsr at_x
    lsr at_z
    bra @scale
@ok:
    lda at_x
    ora at_z
    bne :+
    rts
:   lda at_x
    cmp at_z
    beq @xle
    bcc @xle
    lda at_z
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    ldx at_x
    jsr divide
    tax
    lda atan_table,x
    and #$00FF
    sta tmp1
    lda #64
    sec
    sbc tmp1
    bra @quad
@xle:
    lda at_x
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    ldx at_z
    jsr divide
    tax
    lda atan_table,x
    and #$00FF
@quad:
    sta tmp1
    lda r_zf
    bpl :+
    lda #128
    sec
    sbc tmp1
    sta tmp1
:   lda r_lat
    bpl :+
    lda tmp1
    eor #$FFFF
    inc a
    rts
:   lda tmp1
    rts

; A (16-bit) / X (8-bit, non-zero) -> A quotient; remainder in RDMPYL.
divide:
    .a16
    sta WRDIVL
    A8
    txa
    sta WRDIVB
    A16
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    lda RDDIVL
    rts

; ------------------------------------------------------------------ explosion
; Timeline after detonation: flash, cut to the tail camera, tint the sky and
; ground, shock waves.
aftermath:
    .a16
    lda state
    cmp #2
    beq :+
    rts
:   inc det_t
    lda det_t
    cmp #6
    bne :+
    lda #1
    sta view
:
    lda det_t
    cmp #64
    bcs @no_flash
    lsr a
    eor #$001F
    and #$001F
    ora #$00E0
    sta coldata_v
    stz cgwsel_v            ; colour math everywhere, no clipping
    lda #$3F
    sta cgadsub_v
    bra @tint
@no_flash:
    lda #$E0
    sta coldata_v
@tint:
    lda det_t
    lsr a
    lsr a
    lsr a
    cmp #16
    bcc :+
    lda #15
:   xba                     ; level * 336 = *256 + *64 + *16
    sta tmp0
    lsr a
    lsr a
    sta tmp1
    lsr a
    lsr a
    clc
    adc tmp1
    adc tmp0
    adc #.loword(sky_tables)
    sta sky_ptr

    lda det_t
    lsr a
    lsr a
    lsr a
    lsr a
    cmp #16
    bcc :+
    lda #15
:   cmp pal_lvl
    beq :+
    sta pal_lvl
    lda #1
    sta pal_dirty
:
    lda det_t
    cmp shock1
    bne :+
    lda #40
    sta shake
    lda #3
    sta shake_amp
    lda #.loword(msg_shock)
    sta msg_ptr
    lda #90
    sta msg_timer
:   lda det_t
    cmp shock2
    bne :+
    lda #30
    sta shake
    lda #2
    sta shake_amp
:   lda shake
    beq :+
    dec shake
:   rts

; Mushroom cloud: per-scanline window spans (HDMA ch7) filled with per-line
; fixed colours (HDMA ch1) through colour math.
cloud:
    .a16
    lda state
    cmp #2
    beq :+
    jmp @off
:   lda det_t
    cmp #64
    bcs :+
    jmp @off
:   lda det_x
    sta pj_x
    lda det_y
    sta pj_y
    stz pj_z
    jsr project
    bcc :+
    jmp @off
:   lda pj_sx
    cmp #.loword(-120)
    bcs :+
    cmp #376
    bcc :+
    jmp @off
:   sta cl_cx
    lda pj_sy
    sta cl_by

    ; keep the cloud large as the plane flies away
    lda r_zf
    cmp #201
    bcc @near
    sec
    sbc #200
    lsr a
    lsr a
    lsr a
    clc
    adc #200
    cmp #1020
    bcc :+
    lda #1020
:   lsr a
    lsr a
    tax
    lda #8192
    jsr divide
    bra @rec
@near:
    lda pj_recip
@rec:
    sta cl_rec

    ; growth 0..255
    lda det_t
    sec
    sbc #64
    lsr a
    lsr a
    cmp #256
    bcc :+
    lda #255
:   tax
    lda grow_table,x
    and #$00FF
    sta m_ua

    lda #150                ; top height = 10 + 150*g
    jsr scale_g
    clc
    adc #10
    sta m_ua+0
    pha
    lda cl_rec
    sta m_ub
    jsr mul16u
    lda cl_by
    sec
    sbc m_r+1
    sta cl_top
    pla

    lda det_t               ; recompute g (m_ua was reused)
    sec
    sbc #64
    lsr a
    lsr a
    cmp #256
    bcc :+
    lda #255
:   tax
    lda grow_table,x
    and #$00FF
    sta tmp2
    sta m_ua
    lda #75                 ; cap radius = 8 + 75*g
    jsr scale_g
    clc
    adc #8
    sta m_ua
    lda cl_rec
    sta m_ub
    jsr mul16u
    lda m_r+1
    cmp #200
    bcc :+
    lda #200
:   cmp #2
    bcs :+
    lda #2
:   sta cl_rx
    sta tmp0                ; ry = rx * 11 / 16
    asl a
    asl a
    sta tmp1
    asl a
    clc
    adc tmp1
    sec
    sbc tmp0
    lsr a
    lsr a
    lsr a
    lsr a
    bne :+
    lda #1
:   sta cl_ry
    lsr a                   ; ryb = ry * 3 / 4
    sta tmp1
    lsr a
    clc
    adc tmp1
    bne :+
    lda #1
:   sta cl_ryb
    lda cl_top
    clc
    adc cl_ry
    sta cl_capc

    lda tmp2
    sta m_ua
    lda #16                 ; stem half width = 3 + 16*g
    jsr scale_g
    clc
    adc #3
    sta m_ua
    lda cl_rec
    sta m_ub
    jsr mul16u
    lda m_r+1
    cmp #100
    bcc :+
    lda #100
:   cmp #1
    bcs :+
    lda #1
:   sta cl_stem

    ; heat 15 -> 0 over ~8 seconds, as a ramp row offset (64 bytes)
    lda det_t
    sec
    sbc #64
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    cmp #15
    bcc :+
    lda #15
:   eor #$000F
    xba
    lsr a
    lsr a
    sta cl_heat

    lda cl_capc             ; colour scaling heights
    clc
    adc cl_ryb
    sec
    sbc cl_top
    inc a
    jsr clamp_1_255
    sta cl_hcap
    lda cl_by
    sec
    sbc cl_capc
    inc a
    jsr clamp_1_255
    sta cl_hstem

    ; condensation ring partway up the stem for a few seconds
    lda #.loword(-1000)
    sta cl_ring_y
    lda det_t
    cmp #150
    bcc @no_ring
    cmp #700
    bcs @no_ring
    lda cl_by
    sec
    sbc cl_capc
    bmi @no_ring
    sta m_ua
    lda #85
    sta m_ub
    jsr mul16u
    lda m_r+1
    clc
    adc cl_capc
    sta cl_ring_y
    lda cl_rx
    asl a
    asl a
    clc
    adc cl_rx
    lsr a
    lsr a
    lsr a
    sta cl_ring_hw
@no_ring:

    ; build into the buffers not on screen
    lda win_front
    eor #2
    sta count
    beq :+
    lda #.loword(win_b)
    sta win_p
    lda #.loword(col_b)
    sta col_p
    bra :++
:   lda #.loword(win_a)
    sta win_p
    lda #.loword(col_a)
    sta col_p
:
    ldy #4
    lda #40
    sta cl_y
@line:
    jsr cloud_line
    iny
    iny
    lda cl_y
    inc a
    sta cl_y
    cmp #120
    bne :+
    iny                     ; skip the second HDMA header byte
:   cmp #200
    bcc @line

    lda count
    sta win_front
    lda #$90                ; black inside the window, then add fixed colour
    sta cgwsel_v
    lda #$35
    sta cgadsub_v
    lda #$FF
    sta hdma_mask
    rts

@off:
    lda #$7D
    sta hdma_mask
    lda state
    cmp #2
    bne :+
    lda det_t
    cmp #64
    bcc @keep               ; flash in progress
:   lda #$30
    sta cgwsel_v
@keep:
    rts

; A = factor, m_ua = growth (0..255) -> A = factor * g / 256
scale_g:
    .a16
    sta m_ub
    jsr mul16u
    lda m_r+1
    and #$00FF
    rts

clamp_1_255:
    .a16
    bmi @one
    beq @one
    cmp #256
    bcc @ok
    lda #255
    rts
@one:
    lda #1
@ok:
    rts

; One scanline of the cloud at cl_y; writes window span and colour at Y.
cloud_line:
    .a16
    stz cl_hw
    lda cl_y
    sec
    sbc cl_top
    bpl :+
    jmp @off
:   lda cl_by
    sec
    sbc cl_y
    bpl :+
    jmp @off
:
    ; cap: an ellipse, flatter underneath
    lda cl_y
    sec
    sbc cl_capc
    bpl @below
    eor #$FFFF
    inc a
    ldx cl_ry
    bra @cdiv
@below:
    cmp cl_ryb
    beq :+
    bcs @stem
:   ldx cl_ryb
@cdiv:
    asl a
    asl a
    asl a
    asl a
    asl a
    asl a
    jsr divide
    cmp #65
    bcs @stem
    tax
    lda circ_table,x
    A8
    sta WRMPYA
    lda cl_rx
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    xba
    and #$00FF
    sta cl_hw
    cmp #4
    bcc :+
    lda det_t
    lsr a
    lsr a
    lsr a
    clc
    adc cl_y
    and #$000F
    tax
    lda lump_table,x
    and #$00FF
    clc
    adc cl_hw
    sta cl_hw
:   lda cl_y
    sec
    sbc cl_top
    asl a
    asl a
    asl a
    asl a
    asl a
    ldx cl_hcap
    jsr divide
    cmp #32
    bcc :+
    lda #31
:   asl a
    clc
    adc cl_heat
    tax
    lda cloud_cols,x
    sta cl_col

@stem:
    lda cl_y
    sec
    sbc cl_capc
    bmi @ring
    beq @ring
    lda cl_stem
    sta tmp0
    lda cl_y
    sec
    sbc cl_by
    clc
    adc #6
    bmi @no_skirt
    beq @no_skirt
    A8
    sta WRMPYA
    lda cl_rx
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    lsr a
    lsr a
    lsr a
    clc
    adc tmp0
    sta tmp0
@no_skirt:
    lda tmp0
    cmp cl_hw
    bcc @ring
    beq @ring
    sta cl_hw
    lda cl_y
    sec
    sbc cl_capc
    asl a
    asl a
    asl a
    asl a
    asl a
    ldx cl_hstem
    jsr divide
    cmp #32
    bcc :+
    lda #31
:   asl a
    clc
    adc cl_heat
    adc #1024               ; stem ramps follow the cap ramps
    tax
    lda cloud_cols,x
    sta cl_col

@ring:
    lda cl_y
    sec
    sbc cl_ring_y
    jsr abs_a
    cmp #2
    bcs @emit
    lda cl_ring_hw
    cmp cl_hw
    bcc @emit
    sta cl_hw
    lda #RING_COL
    sta cl_col

@emit:
    lda cl_hw
    beq @off
    lda cl_cx
    sec
    sbc cl_hw
    bpl :+
    lda #0
:   cmp #256
    bcs @off
    sta tmp0
    lda cl_cx
    clc
    adc cl_hw
    bmi @off
    cmp #256
    bcc :+
    lda #255
:   xba
    ora tmp0
    sta (win_p),y
    lda cl_col
    sta (col_p),y
    rts
@off:
    lda #$00FF
    sta (win_p),y
    lda #$E0E0
    sta (col_p),y
    rts

; X = buffer, A = "off" value for every line. Layout:
;   [40, off] [$D0, 80 lines] [$D0, 80 lines] [24, off] [0]
init_hdma_buf:
    .a16
    sta tmp0
    A8
    lda #40
    sta a:0,x
    lda #$D0
    sta a:3,x
    sta a:164,x
    lda #24
    sta a:325,x
    stz a:328,x
    A16
    lda tmp0
    sta a:1,x
    sta a:326,x
    ldy #80
:   sta a:4,x
    sta a:165,x
    inx
    inx
    dey
    bne :-
    rts

; ------------------------------------------------------------------ math
; m_a * m_b (signed 16) -> m_r (signed 32)
mul16s:
    .a16
    lda m_a
    eor m_b
    sta m_sign
    lda m_a
    bpl :+
    eor #$FFFF
    inc a
:   sta m_ua
    lda m_b
    bpl :+
    eor #$FFFF
    inc a
:   sta m_ub
    jsr mul16u
    lda m_sign
    bpl @done
    lda m_r
    eor #$FFFF
    clc
    adc #1
    sta m_r
    lda m_r+2
    eor #$FFFF
    adc #0
    sta m_r+2
@done:
    rts

; m_ua * m_ub (unsigned 16) -> m_r (32), using the 8x8 hardware multiplier
mul16u:
    .a16
    stz m_r+2
    A8
    lda m_ua
    sta WRMPYA
    lda m_ub
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    sta m_r
    A8
    lda m_ub+1
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    clc
    adc m_r+1
    sta m_r+1
    A8
    lda #0
    adc #0
    sta m_r+3
    lda m_ua+1
    sta WRMPYA
    lda m_ub
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    clc
    adc m_r+1
    sta m_r+1
    A8
    lda m_r+3
    adc #0
    sta m_r+3
    lda m_ub+1
    sta WRMPYB
    nop
    nop
    nop
    nop
    A16
    lda RDMPYL
    clc
    adc m_r+2
    sta m_r+2
    rts

; ------------------------------------------------------------------ sound
; No SPC700 program: the APU stays in its boot ROM (IPL) loader, which copies
; blocks of bytes to any APU address. A two-byte block written to $00F2
; ($F2 = DSP register number, $F3 = value) therefore sets one DSP register.

apu_init:
    .a16
    lda #$BBAA              ; IPL ready signature
:   cmp APUIO0
    bne :-
    lda #$CC
    sta apu_k
    lda #SND_DIR            ; sample directory + rumble sample
    sta apu_dst
    ldx #.loword(snd_data)
    ldy #SND_BYTES
    jsr apu_block
    ldx #.loword(dsp_init)
    ; fall through

; In: X = list of DSP register/value byte pairs, ended by $FF.
dsp_write:
    .a16
:   lda a:0,x
    and #$00FF
    cmp #$00FF
    beq :+
    lda #$00F2
    sta apu_dst
    phx
    ldy #2
    jsr apu_block
    plx
    inx
    inx
    bra :-
:   rts

; Send one IPL block. In: apu_dst = APU address, X = source (bank 0), Y = length.
apu_block:
    .a16
    lda apu_dst
    sta APUIO2
    A8
    lda #1                  ; non-zero: another block follows, don't execute
    sta APUIO1
    lda apu_k
    sta APUIO0
:   cmp APUIO0
    bne :-
    stz apu_i
@byte:
    lda a:0,x
    sta APUIO1
    lda apu_i
    sta APUIO0
:   cmp APUIO0
    bne :-
    inc apu_i
    inx
    dey
    bne @byte
    lda apu_i               ; next kick: last index + 2, never zero
    inc a
    bne :+
    inc a
:   sta apu_k
    A16
    rts

.ifdef DEMO
; Autopilot for headless testing: fly the whole bomb run.
demo_input:
    .a16
    lda frame
    and #1
    sta tmp2                ; buttons are pressed on odd frames only
    lda screen
    cmp #2
    beq @in_game
    lda screen
    cmp #3
    bcc :+
    lda #0                  ; stay on the results screen
    rts
:   lda #$3F
    sta tmp0
    lda frame
    and tmp0
    cmp tmp0
    bne :+
    lda #JOY_START
    rts
:   lda #0
    rts
@in_game:
    lda state
    bne @released
    lda doors
    bne :+
    lda dist
    cmp #300
    bcs :+
    lda tmp2
    beq :+
    lda #JOY_B
    rts
:   lda sight
    cmp #2
    bne @steer
    lda tmp2
    beq @steer
    lda #JOY_A
    rts
@steer:
    lda #JOY_R
    sta tmp0
    lda rel_deg
    cmp #4
    bmi :+
    lda #(JOY_R | JOY_RIGHT)
    sta tmp0
    bra @out
:   cmp #.loword(-3)
    bpl @out
    lda #(JOY_R | JOY_LEFT)
    sta tmp0
@out:
.ifdef DEMO_HOLD
    lda #DEMO_HOLD          ; e.g. JOY_UP to climb all the way, JOY_DOWN to crash
    ora tmp0
    sta tmp0
.endif
.ifdef DEMO_ALT
    lda frame               ; alternate ~8 s descending, ~8 s climbing
    and #$0200
    beq :+
    lda #JOY_UP
    bra :++
:   lda #JOY_DOWN
:   ora tmp0
    sta tmp0
.endif
    lda tmp0
    rts
@released:
    lda view
    bne @turn
    lda turned
    cmp #90
    bcc @turn
    lda tmp2
    beq @turn
    lda #JOY_X
    rts
@turn:
    lda turned
    cmp #155
    bcs :+
    lda #JOY_RIGHT
    rts
:   lda #0
    rts
.endif

; ------------------------------------------------------------------ data
.segment "RODATA"
snd_data:   .incbin "snd.bin"
; S-DSP setup: voice 0 and 2 play the rumble loop (2 is pitched lower),
; voice 1 is the noise generator. Instant attack, then a long fade.
dsp_init:
    .byte $6C, $38          ; FLG: unmute, echo writes off, noise clock 3.2 kHz
    .byte $0C, $7F, $1C, $7F ; master volume
    .byte $2C, $00, $3C, $00 ; echo volume
    .byte $4D, $00, $2D, $00 ; no echo, no pitch modulation
    .byte $3D, $02          ; voice 1 = noise
    .byte $5D, >SND_DIR     ; sample directory page
    .byte $5C, $00          ; key off: none
    .byte $00, $60, $01, $60, $02, $00, $03, $04, $04, $00, $05, $8F, $06, $EA
    .byte $10, $1C, $11, $1C, $12, $00, $13, $10, $14, $00, $15, $8F, $16, $ED
    .byte $20, $58, $21, $58, $22, $00, $23, $03, $24, $00, $25, $8F, $26, $E9
    .byte $FF
dsp_boom:
    .byte $4C, $07          ; key on voices 0-2
    .byte $FF
zero_word:   .word 0
sin_table:   .incbin "sin.bin"
camalt_table: .incbin "camalt.bin"
atan_table: .incbin "atan.bin"
throwf_table: .incbin "throwf.bin"
falln_table: .incbin "falln.bin"
cloud_cols: .incbin "cloudcol.bin"
grow_table: .incbin "grow.bin"
circ_table: .incbin "circ.bin"
lump_table: .incbin "lump.bin"
; alt_ft at or above alt_steps[i] uses camera height step i + 1
alt_steps:   .incbin "altstep.bin"
tape_table: .incbin "tape.bin"
pow10:      .word 10000, 1000, 100, 10, 1
plane_ofs:  .word 0, 3072, 6144, 9216, 12288

.macro MSG text
    .res (32 - .strlen(text)) / 2, ' '
    .byte text
    .res 32 - .strlen(text) - (32 - .strlen(text)) / 2, ' '
    .byte 0
.endmacro
msg_paused:   MSG "PAUSED"
msg_oncourse: MSG "ON COURSE"
msg_left:     MSG "<< TURN LEFT"
msg_right:    MSG "TURN RIGHT >>"
msg_around:   MSG "TURN AROUND"
st_search:    .byte "SEARCHING  ", 0
st_near:      .byte "TARGET NEAR", 0
st_over:      .byte "OVER TARGET", 0
st_none:      .byte "-----------", 0
st_armed:     .byte "ARMED", 0
st_away:      .byte " AWAY", 0
st_shut:      .byte "SHUT", 0
st_open:      .byte "OPEN", 0
lbl_tail:     .byte "TAIL VIEW", 0
lbl_noview:   .byte "         ", 0
msg_doors:    MSG "OPEN THE BOMB BAY DOORS FIRST"
msg_break:    MSG "BOMB AWAY! BREAK AWAY 155 DEG"
msg_clear:    MSG "BREAKAWAY COMPLETE"
msg_shock:    MSG "SHOCK WAVE!"
msg_pullup:   MSG "PULL UP!  PULL UP!"
msg_crash:    MSG "CRASHED INTO THE OCEAN"
msg_restart:  MSG "PRESS START"
msg_home:     MSG "TEST COMPLETE - RETURN TO BASE"
msg_blank:    .res 32, ' '
              .byte 0
rate_bull:    .byte "BULLSEYE", 0
rate_on:      .byte "ON TARGET", 0
rate_near:    .byte "NEAR MISS", 0
rate_wide:    .byte "WIDE MISS", 0
rate_safe:    .byte "SAFE DISTANCE", 0
rate_shallow: .byte "TOO SHALLOW", 0
screen_tbl:   .word upd_title, upd_brief, upd_play, upd_fade, upd_end
msg_turn:     .byte " TURNED ###/155  DETONATION ##S ", 0
bgmode_hdma:
    .byte M7_START, $09     ; Mode 1 (BG3 priority) for the sky / top HUD
    .byte 120, $07          ; Mode 7 ground
    .byte 24, $09           ; Mode 1 bottom HUD
    .byte 0

.segment "BANK1"
m7vram:     .incbin "m7vram.bin"

.segment "BANK2"
mappal:     .incbin "mappal.bin"
sky_tables: .incbin "sky.bin"
cgram_init: .incbin "cgram.bin"
map_tint:   .incbin "maptint.bin"
hudmap:     .incbin "hudmap.bin"
font_tiles: .incbin "font.bin"
legend_map: .incbin "legend.bin"
title_map:  .incbin "title.bin"
brief_map:  .incbin "brief.bin"
ending_map: .incbin "ending.bin"
logo_tiles: .incbin "logo.bin"
small_sprites: .incbin "small.bin"

.segment "BANK3"
plane_frames: .incbin "plane.bin"

.segment "HEADER"
    .byte "BIKINI ATOLL         "   ; 21 bytes
    .byte $20               ; LoROM, slow
    .byte $00               ; ROM only
    .byte $0C               ; 4MB
    .byte $00               ; no SRAM
    .byte $01               ; North America
    .byte $00               ; developer
    .byte $00               ; version
    .word $FFFF, $0000      ; checksum complement / checksum (fixed by mkrom)

.segment "VECTORS"
    ; native mode
    .word 0, 0, irq_stub, irq_stub, irq_stub, nmi, 0, irq_stub
    ; emulation mode
    .word 0, 0, irq_stub, 0, irq_stub, irq_stub, reset, irq_stub
