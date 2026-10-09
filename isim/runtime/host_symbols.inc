/*
 * Procedural stand-ins for common SF Symbols (included by host_image.c).
 *
 * These are isim's own simple drawings, not Apple's SF Symbols artwork (which is licensed for Apple platforms only and
 * is never shipped or copied here). Each glyph is a small path program on a 100x100 grid; variants compose generically:
 *   name.fill                      solid shape (outline otherwise)
 *   name.circle / .square / .triangle / .rectangle   the glyph inside an enclosure; with .fill the enclosure is
 *                                  solid and the glyph is cut out of it
 *   name.slash                     a diagonal strike-through (cut gap + line)
 * Strokes follow UIImage.SymbolConfiguration's weight (ultraLight ... black).
 *
 * Path program: parts separated by '|'; each part is "<role>[scale]:<commands>". Commands (grid units, angles in
 * degrees, y down): M x y | L x y | C x1 y1 x2 y2 x y | Z | A cx cy r a1 a2 (clockwise arc) | N cx cy r a1 a2
 * (counter-clockwise) | O cx cy r (circle) | R x y w h r (rounded rect) | E cx cy rx ry (ellipse) |
 * K x y angle len (open arrowhead with its tip at x,y pointing along angle).
 * Roles (outline variant / fill variant):
 *   B  stroke / fill+stroke       S  stroke / stroke         F  fill / fill
 *   D  stroke / stroke cut out    h  stroke / fill cut out   d  fill / fill cut out
 *   o  stroke / -                 f  - / fill
 */

struct glyph { const char *name; const char *path; int rot, flip; };   /* rot: degrees about the center; flip: 1 x, 2 y */

#define G_STAR "B:M 50 10 L 61.2 38.6 L 91.8 40.4 L 68.1 59.9 L 75.9 89.6 L 50 73 L 24.1 89.6 L 31.9 59.9 L 8.2 40.4 L 38.8 38.6 Z"
#define G_GEAR "B:M 79.3 43.5 L 91.6 44.6 L 91.6 55.4 L 79.3 56.5 L 75.3 66.1 L 83.3 75.6 L 75.6 83.3 L 66.1 75.3 L 56.5 79.3 L 55.4 91.6 L 44.6 91.6 L 43.5 79.3 L 33.9 75.3 L 24.4 83.3 L 16.7 75.6 L 24.7 66.1 L 20.7 56.5 L 8.4 55.4 L 8.4 44.6 L 20.7 43.5 L 24.7 33.9 L 16.7 24.4 L 24.4 16.7 L 33.9 24.7 L 43.5 20.7 L 44.6 8.4 L 55.4 8.4 L 56.5 20.7 L 66.1 24.7 L 75.6 16.7 L 83.3 24.4 L 75.3 33.9 Z|h:O 50 50 12"
#define G_SUN "B:O 50 50 17|S:M 80 50 L 92 50 M 71.2 71.2 L 79.7 79.7 M 50 80 L 50 92 M 28.8 71.2 L 20.3 79.7 M 20 50 L 8 50 M 28.8 28.8 L 20.3 20.3 M 50 20 L 50 8 M 71.2 28.8 L 79.7 20.3"
#define G_SPARKLES "F:M 40 24 C 46.1 51.9 46.1 51.9 74 58 C 46.1 64.1 46.1 64.1 40 92 C 33.9 64.1 33.9 64.1 6 58 C 33.9 51.9 33.9 51.9 40 24 Z M 76 6 C 78.9 19.1 78.9 19.1 92 22 C 78.9 24.9 78.9 24.9 76 38 C 73.1 24.9 73.1 24.9 60 22 C 73.1 19.1 73.1 19.1 76 6 Z M 80 66 C 82.2 75.8 82.2 75.8 92 78 C 82.2 80.2 82.2 80.2 80 90 C 77.8 80.2 77.8 80.2 68 78 C 77.8 75.8 77.8 75.8 80 66 Z"
#define G_ARROW "S:M 10 50 L 88 50|S:K 88 50 0 38"
#define G_CHEVRON "S1.15:M 34 12 L 70 50 L 34 88"
#define G_ARROW_CW "S:A 50 54 36 320 630|S:K 52 18 0 18"
#define G_UTURN "S:M 84 90 L 84 54 C 84 38 74 30 58 30 L 14 30|S:K 14 30 180 22"
#define G_THUMB "B:M 32 44 L 46 14 C 49 6 62 8 61 18 L 58 38 L 82 38 C 90 38 95 46 92 54 L 85 84 C 83 90 79 92 73 92 L 32 92 Z|B:R 8 44 16 48 3"
#define G_HEART "B:M 50 86 C 20 64 8 48 8 33 C 8 19 19 10 31 10 C 40 10 46 15 50 22 C 54 15 60 10 69 10 C 81 10 92 19 92 33 C 92 48 80 64 50 86 Z"
#define G_PERSON "B:O 50 28 18|B:M 14 92 C 14 68 30 56 50 56 C 70 56 86 68 86 92 Z"
#define G_PERSON_CIRCLE "o:O 50 50 42|f:O 50 50 42|h0.7:O 50 38 15|h0.7:M 24 80 C 30 66 40 60 50 60 C 60 60 70 66 76 80 C 68 88 60 92 50 92 C 40 92 32 88 24 80 Z"
#define G_SPEAKER "B:M 6 36 L 22 36 L 44 14 L 44 86 L 22 64 L 6 64 Z"
#define G_BUBBLE "B:M 50 12 C 74 12 92 26 92 46 C 92 66 74 80 50 80 C 44 80 38 79 33 77 L 12 88 L 18 70 C 11 63 8 55 8 46 C 8 26 26 12 50 12 Z"
#define G_DOC "B:M 20 6 L 60 6 L 82 28 L 82 94 L 20 94 Z|D:M 60 6 L 60 28 L 82 28"
#define G_SQUARE_ARROW "B:M 34 36 L 18 36 L 18 92 L 82 92 L 82 36 L 66 36"
#define G_MOON "B:M 58 8 C 34 12 18 32 18 54 C 18 76 36 92 58 92 C 72 92 84 86 92 74 C 62 78 40 58 46 30 C 48 20 52 13 58 8 Z"
#define G_FORWARD "B:M 6 18 L 48 50 L 6 82 Z|B:M 50 18 L 92 50 L 50 82 Z"
#define G_FORWARD_END "B:M 10 16 L 66 50 L 10 84 Z|F:R 76 16 12 68 3"
#define G_TIMER "B:O 50 56 36|S:M 40 8 L 60 8|S:M 50 8 L 50 20|D:M 50 56 L 50 36"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wmissing-field-initializers"
static const struct glyph glyphs[] = {
    /* marks */
    { "checkmark", "S1.1:M 14 52 L 38 78 L 86 20" }, { "xmark", "S1.1:M 18 18 L 82 82|S1.1:M 82 18 L 18 82" },
    { "multiply", "S:M 24 24 L 76 76|S:M 76 24 L 24 76" },
    { "plus", "S1.1:M 50 10 L 50 90|S1.1:M 10 50 L 90 50" }, { "minus", "S1.1:M 10 50 L 90 50" },
    { "divide", "S:M 14 50 L 86 50|F:O 50 22 8 O 50 78 8" }, { "equal", "S:M 14 36 L 86 36|S:M 14 64 L 86 64" },
    { "exclamationmark", "S1.3:M 50 10 L 50 62|F:O 50 86 8" },
    { "questionmark", "S1.2:M 28 30 C 28 16 38 8 50 8 C 64 8 72 18 72 29 C 72 46 50 46 50 64|F:O 50 87 8" },
    { "info", "F:O 50 16 8|S1.2:M 50 38 L 50 88|S:M 38 38 L 50 38|S:M 36 88 L 64 88" },
    { "ellipsis.rectangle", "B:R 4 22 92 56 14|d:O 30 50 6 O 50 50 6 O 70 50 6" },
    /* arrows and chevrons */
    { "arrow.right", G_ARROW }, { "arrow.forward", G_ARROW }, { "arrow.left", G_ARROW, 180 }, { "arrow.backward", G_ARROW, 180 },
    { "arrow.up", G_ARROW, 270 }, { "arrow.down", G_ARROW, 90 },
    { "arrow.up.right", G_ARROW, 315 }, { "arrow.down.right", G_ARROW, 45 }, { "arrow.down.left", G_ARROW, 135 }, { "arrow.up.left", G_ARROW, 225 },
    { "arrow.clockwise", G_ARROW_CW }, { "arrow.counterclockwise", G_ARROW_CW, 0, 1 },
    { "arrow.uturn.left", G_UTURN }, { "arrow.uturn.backward", G_UTURN }, { "arrow.uturn.right", G_UTURN, 0, 1 }, { "arrow.uturn.forward", G_UTURN, 0, 1 },
    { "arrow.uturn.up", G_UTURN, 90, 2 }, { "arrow.uturn.down", G_UTURN, 270, 2 },
    { "arrow.up.arrow.down", "S:M 32 88 L 32 12|S:K 32 12 270 20|S:M 68 12 L 68 88|S:K 68 88 90 20" },
    { "arrow.left.arrow.right", "S:M 88 32 L 12 32|S:K 12 32 180 20|S:M 12 68 L 88 68|S:K 88 68 0 20" },
    { "arrow.triangle.2.circlepath", "S:A 50 50 36 200 335|S:K 83 35 65 18|S:A 50 50 36 20 155|S:K 17 65 245 18" },
    { "arrow.down.to.line", "S:M 50 8 L 50 70|S:K 50 70 90 30|S:M 14 90 L 86 90" },
    { "arrow.up.to.line", "S:M 50 92 L 50 30|S:K 50 30 270 30|S:M 14 10 L 86 10" },
    { "chevron.right", G_CHEVRON }, { "chevron.forward", G_CHEVRON }, { "chevron.left", G_CHEVRON, 180 }, { "chevron.backward", G_CHEVRON, 180 },
    { "chevron.down", G_CHEVRON, 90 }, { "chevron.up", G_CHEVRON, 270 },
    /* lists and layout */
    { "line.3.horizontal", "S:M 12 24 L 88 24|S:M 12 50 L 88 50|S:M 12 76 L 88 76" },
    { "line.horizontal.3", "S:M 12 24 L 88 24|S:M 12 50 L 88 50|S:M 12 76 L 88 76" },
    { "line.3.horizontal.decrease", "S:M 8 24 L 92 24|S:M 24 50 L 76 50|S:M 40 76 L 60 76" },
    { "list.bullet", "F:O 14 24 7 O 14 50 7 O 14 76 7|S:M 36 24 L 90 24|S:M 36 50 L 90 50|S:M 36 76 L 90 76" },
    { "list.dash", "S:M 8 24 L 20 24 M 8 50 L 20 50 M 8 76 L 20 76|S:M 36 24 L 90 24|S:M 36 50 L 90 50|S:M 36 76 L 90 76" },
    { "square.grid.2x2", "B:R 10 10 32 32 7|B:R 58 10 32 32 7|B:R 10 58 32 32 7|B:R 58 58 32 32 7" },
    { "rectangle.grid.2x2", "B:R 6 14 40 32 6|B:R 54 14 40 32 6|B:R 6 54 40 32 6|B:R 54 54 40 32 6" },
    { "slider.horizontal.3", "S:M 8 24 L 92 24|S:M 8 50 L 92 50|S:M 8 76 L 92 76|F:O 30 24 10 O 68 50 10 O 42 76 10" },
    { "viewfinder", "S:M 10 30 L 10 10 L 30 10|S:M 70 10 L 90 10 L 90 30|S:M 90 70 L 90 90 L 70 90|S:M 30 90 L 10 90 L 10 70" },
    { "target", "S:O 50 50 40|S:O 50 50 22|F:O 50 50 7" },
    { "chart.bar", "B:R 10 56 18 34 3|B:R 41 32 18 58 3|B:R 72 12 18 78 3" },
    { "chart.pie", "B:M 50 50 L 50 8 A 50 50 42 270 630 Z|D:M 50 50 L 50 8|D:M 50 50 L 86 70" },
    { "chart.line.uptrend.xyaxis", "S:M 8 8 L 8 92 L 92 92|S:M 20 74 L 42 48 L 60 62 L 88 26" },
    { "waveform", "S:M 10 40 L 10 60 M 26 26 L 26 74 M 42 10 L 42 90 M 58 30 L 58 70 M 74 18 L 74 82 M 90 42 L 90 58" },
    { "cellularbars", "F:R 8 66 14 24 3 R 30 50 14 40 3 R 52 32 14 58 3 R 74 12 14 78 3" },
    /* basic shapes */
    { "square", "B:R 10 10 80 80 16" }, { "triangle", "B:M 50 10 L 92 86 L 8 86 Z" },
    { "diamond", "B:M 50 6 L 94 50 L 50 94 L 6 50 Z" }, { "rectangle", "B:R 4 22 92 56 12" },
    { "capsule", "B:R 4 26 92 48 24" }, { "seal", "B:M 50 6 L 61 16 L 76 13 L 80 28 L 94 36 L 88 50 L 94 64 L 80 72 L 76 87 L 61 84 L 50 94 L 39 84 L 24 87 L 20 72 L 6 64 L 12 50 L 6 36 L 20 28 L 24 13 L 39 16 Z" },
    { "hexagon", "B:M 50 6 L 88 28 L 88 72 L 50 94 L 12 72 L 12 28 Z" }, { "oval", "B:E 50 50 44 30" },
    /* common objects */
    { "heart", G_HEART }, { "star", G_STAR },
    { "bookmark", "B:M 24 8 L 76 8 L 76 92 L 50 72 L 24 92 Z" },
    { "tag", "B:M 12 12 L 50 12 L 90 52 L 52 90 L 12 50 Z|h:O 31 31 7" },
    { "flag", "S:M 18 94 L 18 10|B:M 18 12 C 40 2 56 20 84 10 L 84 56 C 56 66 40 48 18 58 Z" },
    { "bell", "B:M 50 10 C 30 10 24 26 24 42 L 24 62 L 14 74 L 86 74 L 76 62 L 76 42 C 76 26 70 10 50 10 Z|F:M 38 82 L 62 82 C 62 96 38 96 38 82 Z" },
    { "bell.badge", "B:M 46 12 C 28 12 22 28 22 44 L 22 62 L 12 74 L 82 74 L 72 62 L 72 50|F:M 36 82 L 58 82 C 58 96 36 96 36 82 Z|F:O 76 22 14" },
    { "paperplane", "B:M 8 46 L 92 10 L 64 90 L 46 56 Z|D:M 46 56 L 92 10" },
    { "envelope", "B:R 8 20 84 60 8|D:M 10 24 L 50 54 L 90 24" },
    { "envelope.open", "B:M 8 44 L 50 12 L 92 44 L 92 88 L 8 88 Z|D:M 10 46 L 50 72 L 90 46" },
    { "phone", "B:M 22 8 C 14 8 8 16 10 26 C 16 58 42 84 74 90 C 84 92 92 86 92 78 L 92 68 L 72 60 L 62 70 C 48 64 36 52 30 38 L 40 28 L 32 8 Z" },
    { "camera", "B:M 8 32 C 8 28 12 26 16 26 L 30 26 L 36 16 L 64 16 L 70 26 L 84 26 C 88 26 92 28 92 32 L 92 78 C 92 82 88 84 84 84 L 16 84 C 12 84 8 82 8 78 Z|h:O 50 54 15" },
    { "photo", "B:R 8 16 84 68 8|D:M 10 76 L 34 52 L 56 72 L 68 60 L 90 80|d:O 68 36 8" },
    { "mic", "B:R 36 6 28 52 14|S:M 20 44 C 20 62 32 74 50 74 C 68 74 80 62 80 44|S:M 50 74 L 50 92|S:M 36 92 L 64 92" },
    { "lock", "B:R 18 44 64 48 8|S:M 30 44 L 30 30 C 30 16 40 8 50 8 C 60 8 70 16 70 30 L 70 44|d:O 50 66 6" },
    { "lock.open", "B:R 10 44 64 48 8|S:M 62 44 L 62 30 C 62 16 72 8 80 8 C 90 8 94 16 94 30|d:O 42 66 6" },
    { "eye", "B:M 6 50 C 20 24 36 18 50 18 C 64 18 80 24 94 50 C 80 76 64 82 50 82 C 36 82 20 76 6 50 Z|d:O 50 50 13" },
    { "trash", "B:M 20 26 L 26 90 L 74 90 L 80 26 Z|S:M 10 24 L 90 24|S:M 38 24 L 38 12 L 62 12 L 62 24|D:M 40 40 L 41 76|D:M 60 40 L 59 76" },
    { "pencil", "B:M 70 8 L 92 30 L 36 86 L 10 92 L 14 64 Z|D:M 60 18 L 82 40" },
    { "gear", G_GEAR }, { "gearshape", G_GEAR }, { "gearshape.2", G_GEAR },
    { "cart", "S:M 6 14 L 20 14 L 30 66 L 84 66|B:M 24 24 L 92 24 L 84 54 L 28 54 Z|F:O 36 84 7 O 76 84 7" },
    { "bag", "B:M 16 32 L 84 32 L 88 92 L 12 92 Z|S:M 34 40 L 34 26 C 34 14 42 8 50 8 C 58 8 66 14 66 26 L 66 40" },
    { "creditcard", "B:R 6 18 88 64 8|D1.4:M 8 38 L 92 38|D:M 18 64 L 38 64" },
    { "banknote", "B:R 6 22 88 56 6|h:O 50 50 12" },
    { "house", "B:M 18 46 L 50 16 L 82 46 L 82 90 L 18 90 Z|S:M 6 52 L 50 10 L 94 52|h:R 40 62 20 28 2" },
    { "person", G_PERSON },
    { "person.2", "B:O 36 32 15|B:M 6 90 C 6 70 18 58 36 58 C 54 58 66 70 66 90 Z|B:O 70 24 11|S:M 64 50 C 82 46 94 58 94 76 L 76 76" },
    { "person.crop.circle", G_PERSON_CIRCLE }, { "person.circle", G_PERSON_CIRCLE },
    { "sun.max", G_SUN }, { "sun.min", "B:O 50 50 17|S0.9:M 74 50 L 82 50 M 67 67 L 72.6 72.6 M 50 74 L 50 82 M 33 67 L 27.4 72.6 M 26 50 L 18 50 M 33 33 L 27.4 27.4 M 50 26 L 50 18 M 67 33 L 72.6 27.4" },
    { "moon", G_MOON }, { "moon.stars", G_MOON "|F:M 76 10 C 77.6 17.4 77.6 17.4 85 19 C 77.6 20.6 77.6 20.6 76 28 C 74.4 20.6 74.4 20.6 67 19 C 74.4 17.4 74.4 17.4 76 10 Z" },
    { "cloud", "B:M 26 78 C 14 78 6 70 6 60 C 6 50 14 42 24 42 C 26 28 38 20 50 20 C 64 20 74 30 76 42 C 86 42 94 50 94 60 C 94 70 86 78 76 78 Z" },
    { "bolt", "B:M 56 6 L 18 56 L 46 56 L 40 94 L 82 40 L 54 40 Z" },
    { "flame", "B:M 50 6 C 56 24 80 38 80 62 C 80 80 66 92 50 92 C 34 92 20 80 20 62 C 20 48 28 40 34 34 C 34 46 38 52 44 54 C 40 36 44 18 50 6 Z" },
    { "drop", "B:M 50 6 C 60 24 80 44 80 62 C 80 80 66 92 50 92 C 34 92 20 80 20 62 C 20 44 40 24 50 6 Z" },
    { "leaf", "B:M 14 86 C 14 40 40 14 88 12 C 88 60 62 86 14 86 Z|D:M 14 86 L 60 40" },
    { "pawprint", "B:E 50 68 18 15|B:E 20 46 8 10|B:E 38 24 8 10|B:E 62 24 8 10|B:E 80 46 8 10" },
    { "timer", G_TIMER }, { "stopwatch", G_TIMER },
    { "clock", "B:O 50 50 42|D:M 50 24 L 50 50 L 68 62" },
    { "hourglass", "B:M 22 8 L 78 8 L 78 20 L 56 50 L 78 80 L 78 92 L 22 92 L 22 80 L 44 50 L 22 20 Z" },
    { "calendar", "B:R 8 14 84 78 8|D:M 8 34 L 92 34|S:M 30 6 L 30 20|S:M 70 6 L 70 20|d:O 30 52 5 O 50 52 5 O 70 52 5 O 30 72 5 O 50 72 5" },
    { "map", "B:M 8 20 L 34 10 L 66 22 L 92 12 L 92 80 L 66 90 L 34 78 L 8 88 Z|D:M 34 10 L 34 78|D:M 66 22 L 66 90" },
    { "mappin", "B:O 50 26 18|S:M 50 44 L 50 92" },
    { "mappin.and.ellipse", "B:O 50 24 16|S:M 50 40 L 50 74|S0.8:E 50 84 34 8" },
    { "location", "B:M 88 12 L 10 46 L 46 54 L 54 90 Z" },
    { "location.north", "B:M 50 8 L 84 90 L 50 72 L 16 90 Z" },
    { "magnifyingglass", "S:O 42 42 28|S1.2:M 63 63 L 90 90" },
    { "safari", "B:O 50 50 42|d:M 66 34 L 57 57 L 34 66 L 43 43 Z" },
    { "trophy", "B:M 26 10 L 74 10 L 74 34 C 74 52 62 62 50 62 C 38 62 26 52 26 34 Z|S:M 26 18 L 12 18 C 12 34 18 40 28 42|S:M 74 18 L 88 18 C 88 34 82 40 72 42|S:M 50 62 L 50 80|B:M 30 90 L 70 90 L 66 80 L 34 80 Z" },
    { "medal", "B:O 50 64 26|S:M 36 42 L 22 8|S:M 64 42 L 78 8" },
    { "rosette", "B:O 50 40 30|S:M 34 64 L 26 94 L 40 86 L 46 94 L 50 70|S:M 66 64 L 74 94 L 60 86 L 54 94 L 50 70" },
    { "crown", "B:M 10 30 L 30 56 L 50 18 L 70 56 L 90 30 L 82 82 L 18 82 Z" },
    { "gift", "B:R 10 32 80 20 4|B:M 16 52 L 84 52 L 84 90 L 16 90 Z|D:M 50 32 L 50 90|S:M 50 32 C 40 12 20 14 28 26 C 32 32 50 32 50 32|S:M 50 32 C 60 12 80 14 72 26 C 68 32 50 32 50 32" },
    { "gamecontroller", "B:M 28 26 L 72 26 C 86 26 94 40 94 60 C 94 76 86 82 78 78 C 70 74 66 66 60 66 L 40 66 C 34 66 30 74 22 78 C 14 82 6 76 6 60 C 6 40 14 26 28 26 Z|D:M 20 46 L 36 46|D:M 28 38 L 28 54|d:O 66 42 4.5 O 76 52 4.5" },
    { "music.note", "F:E 34 78 15 11|S:M 48 78 L 48 10 C 56 26 74 24 76 44" },
    { "headphones", "S:M 14 66 L 14 50 C 14 28 30 12 50 12 C 70 12 86 28 86 50 L 86 66|B:R 8 56 20 34 8|B:R 72 56 20 34 8" },
    { "wifi", "S:A 50 84 66 228 312|S:A 50 84 44 228 312|S:A 50 84 22 228 312|F:O 50 84 7" },
    { "battery.100", "B:R 6 30 80 40 9|S:M 94 42 L 94 58|F:R 15 39 62 22 3" }, { "battery.75", "B:R 6 30 80 40 9|S:M 94 42 L 94 58|F:R 15 39 46 22 3" },
    { "battery.50", "B:R 6 30 80 40 9|S:M 94 42 L 94 58|F:R 15 39 31 22 3" }, { "battery.25", "B:R 6 30 80 40 9|S:M 94 42 L 94 58|F:R 15 39 16 22 3" },
    { "battery.0", "o:R 6 30 80 40 9|f:R 6 30 80 40 9|S:M 94 42 L 94 58" },
    { "shield", "B:M 50 6 L 86 20 L 86 46 C 86 70 70 86 50 94 C 30 86 14 70 14 46 L 14 20 Z" },
    { "checkmark.shield", "B:M 50 6 L 86 20 L 86 46 C 86 70 70 86 50 94 C 30 86 14 70 14 46 L 14 20 Z|D:M 32 50 L 45 64 L 68 36" },
    { "hand.thumbsup", G_THUMB }, { "hand.thumbsdown", G_THUMB, 0, 2 },
    { "sparkles", G_SPARKLES }, { "sparkle", "F:M 50 6 C 57.9 42.1 57.9 42.1 94 50 C 57.9 57.9 57.9 57.9 50 94 C 42.1 57.9 42.1 57.9 6 50 C 42.1 42.1 42.1 42.1 50 6 Z" },
    { "wand.and.stars", "S1.3:M 12 90 L 58 44|F:M 66 6 C 68.9 19.1 68.9 19.1 82 22 C 68.9 24.9 68.9 24.9 66 38 C 63.1 24.9 63.1 24.9 50 22 C 63.1 19.1 63.1 19.1 66 6 Z M 86 42 C 87.8 50.2 87.8 50.2 96 52 C 87.8 53.8 87.8 53.8 86 62 C 84.2 53.8 84.2 53.8 76 52 C 84.2 50.2 84.2 50.2 86 42 Z M 36 3 C 37.6 10.4 37.6 10.4 45 12 C 37.6 13.6 37.6 13.6 36 21 C 34.4 13.6 34.4 13.6 27 12 C 34.4 10.4 34.4 10.4 36 3 Z" },
    { "key", "B:O 30 50 20|S:M 50 50 L 92 50|S:M 78 50 L 78 66|S:M 90 50 L 90 62|h:O 26 50 6" },
    { "power", "S:A 50 54 36 300 600|S:M 50 8 L 50 48" },
    { "link", "S:R 4 36 54 28 14|S:R 42 36 54 28 14", 315 },
    { "cross", "B:M 38 8 L 62 8 L 62 38 L 92 38 L 92 62 L 62 62 L 62 92 L 38 92 L 38 62 L 8 62 L 8 38 L 38 38 Z" },
    { "bubble.left", G_BUBBLE }, { "message", G_BUBBLE }, { "bubble.right", G_BUBBLE, 0, 1 },
    { "text.bubble", G_BUBBLE "|D:M 28 38 L 72 38|D:M 28 54 L 60 54" },
    { "doc", G_DOC }, { "clipboard", "B:R 18 14 64 80 7|F:R 36 6 28 15 4" }, { "doc.on.clipboard", "B:R 10 14 58 76 7|F:R 26 6 26 14 4|B:M 44 40 L 70 40 L 88 58 L 88 94 L 44 94 Z|D:M 70 40 L 70 58 L 88 58" }, { "doc.text", G_DOC "|D:M 34 50 L 68 50|D:M 34 64 L 68 64|D:M 34 78 L 56 78" },
    { "folder", "B:M 6 20 C 6 16 8 14 12 14 L 36 14 L 44 24 L 88 24 C 92 24 94 26 94 30 L 94 82 C 94 86 92 88 88 88 L 12 88 C 8 88 6 86 6 82 Z|D:M 6 36 L 94 36" },
    { "book", "B:M 50 22 C 38 12 22 12 8 16 L 8 84 C 22 80 38 80 50 90 C 62 80 78 80 92 84 L 92 16 C 78 12 62 12 50 22 Z|D:M 50 22 L 50 90" },
    { "video", "B:R 6 24 62 52 10|B:M 74 44 L 94 30 L 94 70 L 74 56 Z" },
    { "square.and.arrow.up", G_SQUARE_ARROW "|S:M 50 6 L 50 36|D:M 50 36 L 50 62|S:K 50 6 270 22" },
    { "square.and.arrow.up.on.square", G_SQUARE_ARROW "|S:M 50 6 L 50 36|D:M 50 36 L 50 62|S:K 50 6 270 22" },
    { "square.and.arrow.down", G_SQUARE_ARROW "|S:M 50 6 L 50 36|D:M 50 36 L 50 62|D:K 50 62 90 22" },
    /* media */
    { "play", "B:M 22 10 L 86 50 L 22 90 Z" }, { "pause", "B:R 18 12 22 76 4|B:R 60 12 22 76 4" },
    { "stop", "B:R 14 14 72 72 8" }, { "record.circle", "S:O 50 50 42|F:O 50 50 24" },
    { "forward", G_FORWARD }, { "backward", G_FORWARD, 0, 1 }, { "forward.end", G_FORWARD_END }, { "backward.end", G_FORWARD_END, 0, 1 },
    { "playpause", "B:M 6 18 L 46 50 L 6 82 Z|F:R 60 18 10 64 2 R 80 18 10 64 2" },
    { "speaker", G_SPEAKER }, { "speaker.wave.1", G_SPEAKER "|S:A 52 50 16 -45 45" },
    { "speaker.wave.2", G_SPEAKER "|S:A 52 50 16 -45 45|S:A 52 50 30 -45 45" },
    { "speaker.wave.3", G_SPEAKER "|S:A 52 50 16 -45 45|S:A 52 50 30 -45 45|S:A 52 50 44 -45 45" },
};

#pragma GCC diagnostic pop

/* single characters drawn as text (in enclosures: "dollarsign.circle", "a.circle") */
static const struct { const char *name, *text; } text_glyphs[] = {
    { "dollarsign", "$" }, { "eurosign", "€" }, { "sterlingsign", "£" }, { "yensign", "¥" }, { "number", "#" },
    { "at", "@" }, { "percent", "%" }, { "textformat.abc", "abc" }, { "textformat.123", "123" },
};

static const struct glyph *find_glyph(const char *name) {
    for (size_t i = 0; i < sizeof glyphs / sizeof *glyphs; i++) if (!strcmp(glyphs[i].name, name)) return &glyphs[i];
    return NULL;
}
static const char *find_text_glyph(const char *name) {
    for (size_t i = 0; i < sizeof text_glyphs / sizeof *text_glyphs; i++) if (!strcmp(text_glyphs[i].name, name)) return text_glyphs[i].text;
    if (strlen(name) == 1 && name[0] >= 'a' && name[0] <= 'z') return name;      /* a.circle ... z.square */
    return NULL;
}

/* stroke width multiplier per UIImage.SymbolWeight (0 unspecified, 1 ultraLight ... 9 black) */
static double symbol_weight_factor(int weight) {
    static const double f[] = { 1, 0.45, 0.6, 0.78, 1, 1.14, 1.3, 1.48, 1.68, 1.9 };
    return weight >= 0 && weight <= 9 ? f[weight] : 1;
}

/* the path program of one part (see the top of this file) */
static void glyph_path(cairo_t *c, const char *p, const char *end) {
    char *e;
    double v[6];
    while (p < end) {
        while (p < end && *p == ' ') p++;
        if (p >= end) break;
        char cmd = *p++;
        int n = cmd == 'M' || cmd == 'L' ? 2 : cmd == 'C' ? 6 : cmd == 'A' || cmd == 'N' || cmd == 'R' ? 5 : cmd == 'O' ? 3 : cmd == 'E' || cmd == 'K' ? 4 : 0;
        for (int i = 0; i < n; i++) { v[i] = strtod(p, &e); if (e == p) return; p = e; }
        switch (cmd) {
        case 'M': cairo_move_to(c, v[0], v[1]); break;
        case 'L': cairo_line_to(c, v[0], v[1]); break;
        case 'C': cairo_curve_to(c, v[0], v[1], v[2], v[3], v[4], v[5]); break;
        case 'Z': cairo_close_path(c); break;
        case 'A': cairo_arc(c, v[0], v[1], v[2], v[3] * M_PI / 180, v[4] * M_PI / 180); break;
        case 'N': cairo_arc_negative(c, v[0], v[1], v[2], v[3] * M_PI / 180, v[4] * M_PI / 180); break;
        case 'O': cairo_new_sub_path(c); cairo_arc(c, v[0], v[1], v[2], 0, 2 * M_PI); cairo_close_path(c); break;
        case 'E': cairo_new_sub_path(c); cairo_save(c); cairo_translate(c, v[0], v[1]); cairo_scale(c, v[2], v[3]);
                  cairo_arc(c, 0, 0, 1, 0, 2 * M_PI); cairo_restore(c); cairo_close_path(c); break;
        case 'R': {
            double x = v[0], y = v[1], w = v[2], h = v[3], r = fmin(v[4], fmin(w, h) / 2);
            cairo_new_sub_path(c);
            cairo_arc(c, x + w - r, y + r, r, -M_PI / 2, 0); cairo_arc(c, x + w - r, y + h - r, r, 0, M_PI / 2);
            cairo_arc(c, x + r, y + h - r, r, M_PI / 2, M_PI); cairo_arc(c, x + r, y + r, r, M_PI, 3 * M_PI / 2);
            cairo_close_path(c); break; }
        case 'K': {            /* open arrowhead: tip (x, y), pointing along angle, arms of length len at +-42 degrees */
            double a = v[2] * M_PI / 180, l = v[3], s = 42 * M_PI / 180;
            cairo_move_to(c, v[0] - l * cos(a - s), v[1] - l * sin(a - s));
            cairo_line_to(c, v[0], v[1]);
            cairo_line_to(c, v[0] - l * cos(a + s), v[1] - l * sin(a + s));
            break; }
        default: return;
        }
    }
}

/* draws a path program in the 100x100 grid. fill: the .fill variant. invert: inside a solid enclosure (ink cuts). */
static void glyph_paint(cairo_t *c, const char *prog, int fill, int invert, double lw) {
    cairo_operator_t ink = invert ? CAIRO_OPERATOR_CLEAR : CAIRO_OPERATOR_OVER, cut = invert ? CAIRO_OPERATOR_OVER : CAIRO_OPERATOR_CLEAR;
    const char *p = prog;
    while (*p) {
        const char *end = strchr(p, '|'); if (!end) end = p + strlen(p);
        char role = *p++;
        char *e; double k = strtod(p, &e); if (e == p) k = 1; p = e;
        if (*p == ':') p++;
        cairo_new_path(c);
        glyph_path(c, p, end);
        cairo_set_line_width(c, lw * k);
        switch (role) {
        case 'B': cairo_set_operator(c, ink); if (fill) cairo_fill_preserve(c); cairo_stroke(c); break;
        case 'S': cairo_set_operator(c, ink); cairo_stroke(c); break;
        case 'F': cairo_set_operator(c, ink); cairo_fill(c); break;
        case 'D': cairo_set_operator(c, fill ? cut : ink); cairo_stroke(c); break;
        case 'h': if (fill) { cairo_set_operator(c, cut); cairo_fill(c); } else { cairo_set_operator(c, ink); cairo_stroke(c); } break;
        case 'd': cairo_set_operator(c, fill ? cut : ink); cairo_fill(c); break;
        case 'o': if (!fill) { cairo_set_operator(c, ink); cairo_stroke(c); } break;
        case 'f': if (fill) { cairo_set_operator(c, ink); cairo_fill(c); } break;
        }
        cairo_new_path(c);
        p = *end ? end + 1 : end;
    }
    cairo_set_operator(c, CAIRO_OPERATOR_OVER);
}

static void glyph_text(cairo_t *c, const char *text, int invert) {
    PangoLayout *l = pango_cairo_create_layout(c);
    PangoFontDescription *fd = pango_font_description_from_string("Adwaita Sans Bold");
    pango_font_description_set_absolute_size(fd, (strlen(text) > 1 ? 44 : 78) * PANGO_SCALE);
    pango_layout_set_font_description(l, fd); pango_layout_set_text(l, text, -1);
    PangoRectangle ink, logical; pango_layout_get_pixel_extents(l, &ink, &logical);
    cairo_set_operator(c, invert ? CAIRO_OPERATOR_CLEAR : CAIRO_OPERATOR_OVER);
    cairo_move_to(c, 50 - (ink.x + ink.width / 2.0), 50 - (ink.y + ink.height / 2.0));
    pango_cairo_show_layout(c, l);
    cairo_set_operator(c, CAIRO_OPERATOR_OVER);
    pango_font_description_free(fd); g_object_unref(l);
}

enum { ENCL_NONE, ENCL_CIRCLE, ENCL_SQUARE, ENCL_TRIANGLE, ENCL_RECT };
static const char *const enclosure_names[] = { NULL, "circle", "square", "triangle", "rectangle" };

/* a glyph (path program, text or Adwaita SVG) with its variants into w x h (current user space). part: 0 the whole
   symbol in one colour (monochrome: a .fill enclosure's glyph is cut out), 1 the primary layer (the glyph and its
   slash, drawn, not cut out), 2 the secondary layer (the enclosure); layered rendering modes draw 2 then 1 */
static void draw_symbol(cairo_t *c, const struct glyph *g, const char *text, RsvgHandle *svg, int fill, int encl, int slash,
                        double w, double h, double weight, int part) {
    double s = fmin(w, h), lw = 8.5 * weight;
    cairo_save(c);
    cairo_translate(c, (w - s) / 2, (h - s) / 2);
    cairo_scale(c, s / 100, s / 100);
    cairo_set_line_cap(c, CAIRO_LINE_CAP_ROUND); cairo_set_line_join(c, CAIRO_LINE_JOIN_ROUND);
    double k = 1, cy = 50;
    if (encl) {
        static const char *const shape[] = { NULL, "B:O 50 50 43", "B:R 7 7 86 86 18", "B:M 50 8 L 93 88 L 7 88 Z", "B:R 3 20 94 60 14" };
        if (part != 1) glyph_paint(c, shape[encl], fill, 0, lw);
        k = encl == ENCL_CIRCLE ? 0.52 : encl == ENCL_SQUARE ? 0.56 : encl == ENCL_TRIANGLE ? 0.42 : 0.44;
        if (encl == ENCL_TRIANGLE) cy = 60;
    }
    if (part == 2) { cairo_restore(c); return; }   /* the enclosure only */
    int invert = encl && fill && part == 0;         /* one colour: the glyph is cut out of a solid enclosure */
    cairo_save(c);
    cairo_translate(c, 50, cy); cairo_scale(c, k, k);
    if (g) { cairo_rotate(c, g->rot * M_PI / 180); cairo_scale(c, g->flip & 1 ? -1 : 1, g->flip & 2 ? -1 : 1); }
    cairo_translate(c, -50, -50);
    double ilw = encl ? lw * 0.9 / k : lw;
    if (g) glyph_paint(c, g->path, encl && part == 1 ? 0 : fill, invert, ilw);   /* layered: the glyph outline on its enclosure */
    else if (text) glyph_text(c, text, invert);
    else if (svg) {
        cairo_push_group(c);
        RsvgRectangle vp = { 8, 8, 84, 84 };
        rsvg_handle_render_document(svg, c, &vp, NULL);
        cairo_pattern_t *pat = cairo_pop_group(c);
        cairo_set_operator(c, invert ? CAIRO_OPERATOR_CLEAR : CAIRO_OPERATOR_OVER);
        cairo_set_source_rgba(c, 0, 0, 0, 1);
        cairo_mask(c, pat);
        cairo_pattern_destroy(pat);
        cairo_set_operator(c, CAIRO_OPERATOR_OVER);
    }
    cairo_restore(c);
    if (slash) {                                   /* gap, then the strike line */
        cairo_set_operator(c, CAIRO_OPERATOR_CLEAR); cairo_set_line_width(c, lw * 2.8);
        cairo_move_to(c, 12, 8); cairo_line_to(c, 88, 92); cairo_stroke(c);
        cairo_set_operator(c, CAIRO_OPERATOR_OVER); cairo_set_line_width(c, lw);
        cairo_move_to(c, 12, 8); cairo_line_to(c, 88, 92); cairo_stroke(c);
    }
    cairo_restore(c);
}

/* splits "<glyph>[.slash][.circle|.square|.triangle|.rectangle][.fill]" */
static int parse_symbol_name(const char *name, char *base, size_t cap, int *fill, int *encl, int *slash) {
    snprintf(base, cap, "%s", name);
    *fill = *encl = *slash = 0;
    size_t n = strlen(base);
    if (n > 5 && !strcmp(base + n - 5, ".fill")) { *fill = 1; base[n -= 5] = 0; }
    for (int e = ENCL_CIRCLE; e <= ENCL_RECT; e++) {
        size_t l = strlen(enclosure_names[e]);
        if (n > l + 1 && base[n - l - 1] == '.' && !strcmp(base + n - l, enclosure_names[e])) { *encl = e; base[n -= l + 1] = 0; break; }
    }
    if (n > 6 && !strcmp(base + n - 6, ".slash")) { *slash = 1; base[n -= 6] = 0; }
    return 1;
}
