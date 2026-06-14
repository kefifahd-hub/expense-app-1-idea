# Paper Parkour 🎨

A small 3D ball-parkour game inspired by a paper-craft marble course (colorful
strips, loops, a zig-zag staircase, a spiral climb, and a flag at the top).
Roll and jump a ball all the way through the course to the flag.

## Play

Just open `index.html` in any modern browser (Chrome, Safari, Firefox, Edge).
No build step and no install — it loads [three.js](https://threejs.org) from a
CDN, so the first load needs an internet connection.

If you prefer a local server:

```bash
cd parkour
python3 -m http.server 8000
# then open http://localhost:8000
```

## Controls

| Action | Keys |
| --- | --- |
| Move forward / back / left / right | `W` `A` `S` `D` or arrow keys |
| Jump | `Space` |
| Look around | drag the mouse |
| Zoom | scroll wheel |
| Respawn at last checkpoint | `R` |

On phones/tablets a touch joystick and a **JUMP** button appear automatically.

## The course

The layout echoes the craft in the photos:

1. **Black board + start pad** — the cardboard base.
2. **Stepping stones** — jump across gaps that climb upward.
3. **Ramp + loop arch** — roll up the brown strip, under the paper rings.
4. **Zig-zag stairs** — the pink accordion, climbing left/right.
5. **Narrow bridge** — balance along a thin strip.
6. **Floating platforms** — sideways hops.
7. **Spiral climb** — wind up around a rolled-paper column.
8. **Goal** — through the big loop to the **red flag**.

Movement is real physics: gravity, jumping, friction, and sphere-vs-oriented-box
collision so the ball rolls down ramps and off edges. Touching a checkpoint
platform saves your respawn point; falling off returns you there. Your best
completion time is saved in the browser.
