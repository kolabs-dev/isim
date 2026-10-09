/* NSTextBlock / NSTextTable / NSTextTableBlock (NSTextTable.h) and their layout in attributed-string drawing.
 *
 * isim (adapted): TextKit lays text blocks out in its text containers; isim has no TextKit, so the attributed-string
 * paths (UILabel, CATextLayer, NSAttributedString draw / boundingRect, via UITextDrawing.m) lay them out with a box
 * model of their own. Paragraphs are grouped by their NSParagraphStyle.textBlocks, outermost first:
 *   - a block: margin, border and padding per edge (absolute, or a percentage of the available width), its width /
 *     minimum / maximum, height / minimum height, background and per-edge border colours, around its paragraphs;
 *   - table cells (NSTextTableBlock): consecutive cells of one table make a grid of numberOfColumns columns (or as
 *     many as the cells use), with row and column spans. Cells ask for column widths with their width; the other
 *     columns share the rest by their content's width (automatic: the table is as wide as its content when that
 *     fits, like an HTML table) or equally (fixed). A row is as tall as its tallest cell; cells align their content
 *     top, middle, bottom (baseline: top). collapsesBorders overlaps neighbouring borders; hidesEmptyCells draws no
 *     background or border for cells with only white space. The table's own block insets frame the grid.
 * The text of a run of paragraphs is drawn by Pango, as without blocks. Line limits do not apply to block layouts.
 */
#import "UIKitPrivate.h"
#include <math.h>

/* ================= the model ================= */
@implementation NSTextBlock {
@public
    CGFloat _dim[7]; NSTextBlockValueType _dimType[7]; BOOL _dimSet[7];
    CGFloat _width[3][4]; NSTextBlockValueType _widthType[3][4];
    UIColor *_border[4];
}
- (instancetype)init { return [super init]; }
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        for (int d = 0; d < 7; d++) if ([coder containsValueForKey:[NSString stringWithFormat:@"dim%d", d]]) {
            _dim[d] = [coder decodeDoubleForKey:[NSString stringWithFormat:@"dim%d", d]];
            _dimType[d] = (NSTextBlockValueType)[coder decodeIntegerForKey:[NSString stringWithFormat:@"dimType%d", d]]; _dimSet[d] = YES;
        }
        for (int l = 0; l < 3; l++) for (int e = 0; e < 4; e++) {
            _width[l][e] = [coder decodeDoubleForKey:[NSString stringWithFormat:@"w%d.%d", l, e]];
            _widthType[l][e] = (NSTextBlockValueType)[coder decodeIntegerForKey:[NSString stringWithFormat:@"wt%d.%d", l, e]];
        }
        _verticalAlignment = (NSTextBlockVerticalAlignment)[coder decodeIntegerForKey:@"valign"];
        _backgroundColor = [coder decodeObjectOfClass:[UIColor class] forKey:@"background"];
        for (int e = 0; e < 4; e++) _border[e] = [coder decodeObjectOfClass:[UIColor class] forKey:[NSString stringWithFormat:@"border%d", e]];
    }
    return self;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder {
    for (int d = 0; d < 7; d++) if (_dimSet[d]) {
        [coder encodeDouble:_dim[d] forKey:[NSString stringWithFormat:@"dim%d", d]];
        [coder encodeInteger:(NSInteger)_dimType[d] forKey:[NSString stringWithFormat:@"dimType%d", d]];
    }
    for (int l = 0; l < 3; l++) for (int e = 0; e < 4; e++) {
        [coder encodeDouble:_width[l][e] forKey:[NSString stringWithFormat:@"w%d.%d", l, e]];
        [coder encodeInteger:(NSInteger)_widthType[l][e] forKey:[NSString stringWithFormat:@"wt%d.%d", l, e]];
    }
    [coder encodeInteger:(NSInteger)_verticalAlignment forKey:@"valign"];
    if (_backgroundColor) [coder encodeObject:_backgroundColor forKey:@"background"];
    for (int e = 0; e < 4; e++) if (_border[e]) [coder encodeObject:_border[e] forKey:[NSString stringWithFormat:@"border%d", e]];
}
- (void)_isim_copyInto:(NSTextBlock *)c {
    memcpy(c->_dim, _dim, sizeof _dim); memcpy(c->_dimType, _dimType, sizeof _dimType); memcpy(c->_dimSet, _dimSet, sizeof _dimSet);
    memcpy(c->_width, _width, sizeof _width); memcpy(c->_widthType, _widthType, sizeof _widthType);
    for (int e = 0; e < 4; e++) c->_border[e] = _border[e];
    c.verticalAlignment = _verticalAlignment; c.backgroundColor = _backgroundColor;
}
- (id)copyWithZone:(NSZone *)z { NSTextBlock *c = [[self class] new]; [self _isim_copyInto:c]; return c; }
static int dim_index(NSTextBlockDimension d) { return d <= 6 ? (int)d : 0; }
- (void)setValue:(CGFloat)v type:(NSTextBlockValueType)t forDimension:(NSTextBlockDimension)d { int i = dim_index(d); _dim[i] = v; _dimType[i] = t; _dimSet[i] = YES; }
- (CGFloat)valueForDimension:(NSTextBlockDimension)d { return _dim[dim_index(d)]; }
- (NSTextBlockValueType)valueTypeForDimension:(NSTextBlockDimension)d { return _dimType[dim_index(d)]; }
- (void)setContentWidth:(CGFloat)v type:(NSTextBlockValueType)t { [self setValue:v type:t forDimension:NSTextBlockWidth]; }
- (CGFloat)contentWidth { return _dim[NSTextBlockWidth]; }
- (NSTextBlockValueType)contentWidthValueType { return _dimType[NSTextBlockWidth]; }
static int layer_index(NSTextBlockLayer l) { return l == NSTextBlockPadding ? 0 : l == NSTextBlockBorder ? 1 : 2; }
- (void)setWidth:(CGFloat)v type:(NSTextBlockValueType)t forLayer:(NSTextBlockLayer)l { for (int e = 0; e < 4; e++) { _width[layer_index(l)][e] = v; _widthType[layer_index(l)][e] = t; } }
- (void)setWidth:(CGFloat)v type:(NSTextBlockValueType)t forLayer:(NSTextBlockLayer)l edge:(CGRectEdge)e { if (e > 3) return; _width[layer_index(l)][e] = v; _widthType[layer_index(l)][e] = t; }
- (CGFloat)widthForLayer:(NSTextBlockLayer)l edge:(CGRectEdge)e { return e > 3 ? 0 : _width[layer_index(l)][e]; }
- (NSTextBlockValueType)widthValueTypeForLayer:(NSTextBlockLayer)l edge:(CGRectEdge)e { return e > 3 ? NSTextBlockAbsoluteValueType : _widthType[layer_index(l)][e]; }
- (void)setBorderColor:(UIColor *)c { for (int e = 0; e < 4; e++) _border[e] = c; }
- (void)setBorderColor:(UIColor *)c forEdge:(CGRectEdge)e { if (e <= 3) _border[e] = c; }
- (UIColor *)borderColorForEdge:(CGRectEdge)e { return e <= 3 ? _border[e] : nil; }
@end

@implementation NSTextTable
- (instancetype)init { if ((self = [super init])) _numberOfColumns = 0; return self; }
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _numberOfColumns = (NSUInteger)[coder decodeIntegerForKey:@"columns"];
        _layoutAlgorithm = (NSTextTableLayoutAlgorithm)[coder decodeIntegerForKey:@"algorithm"];
        _collapsesBorders = [coder decodeBoolForKey:@"collapses"]; _hidesEmptyCells = [coder decodeBoolForKey:@"hidesEmpty"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeInteger:(NSInteger)_numberOfColumns forKey:@"columns"]; [coder encodeInteger:(NSInteger)_layoutAlgorithm forKey:@"algorithm"];
    [coder encodeBool:_collapsesBorders forKey:@"collapses"]; [coder encodeBool:_hidesEmptyCells forKey:@"hidesEmpty"];
}
- (id)copyWithZone:(NSZone *)z {
    NSTextTable *c = [super copyWithZone:z];
    c.numberOfColumns = _numberOfColumns; c.layoutAlgorithm = _layoutAlgorithm; c.collapsesBorders = _collapsesBorders; c.hidesEmptyCells = _hidesEmptyCells;
    return c;
}
@end

@implementation NSTextTableBlock
- (instancetype)initWithTable:(NSTextTable *)table startingRow:(NSInteger)row rowSpan:(NSInteger)rowSpan startingColumn:(NSInteger)col columnSpan:(NSInteger)colSpan {
    if ((self = [super init])) { _table = table; _startingRow = MAX(row, 0); _rowSpan = MAX(rowSpan, 1); _startingColumn = MAX(col, 0); _columnSpan = MAX(colSpan, 1); }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        _table = [coder decodeObjectOfClass:[NSTextTable class] forKey:@"table"];
        _startingRow = [coder decodeIntegerForKey:@"row"]; _rowSpan = MAX([coder decodeIntegerForKey:@"rowSpan"], 1);
        _startingColumn = [coder decodeIntegerForKey:@"column"]; _columnSpan = MAX([coder decodeIntegerForKey:@"columnSpan"], 1);
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    if (_table) [coder encodeObject:_table forKey:@"table"];
    [coder encodeInteger:_startingRow forKey:@"row"]; [coder encodeInteger:_rowSpan forKey:@"rowSpan"];
    [coder encodeInteger:_startingColumn forKey:@"column"]; [coder encodeInteger:_columnSpan forKey:@"columnSpan"];
}
- (id)copyWithZone:(NSZone *)z {             /* a cell keeps its table (the same object: cells are grouped by it) */
    NSTextTableBlock *c = [[NSTextTableBlock alloc] initWithTable:_table startingRow:_startingRow rowSpan:_rowSpan startingColumn:_startingColumn columnSpan:_columnSpan];
    [self _isim_copyInto:c];
    return c;
}
@end

/* ================= layout ================= */
NSString *isim_ui_markup(NSAttributedString *s, UIFont *defFont, UIColor *defColor, NSTextAlignment *align, CGFloat *spacing);
extern BOOL isim_ui_drawing_rtl;

typedef struct { NSRange range; __unsafe_unretained NSArray<NSTextBlock *> *blocks; } Para;
typedef struct {
    NSAttributedString *s; UIFont *font; UIColor *color;
    Para *paras; NSUInteger count;
    BOOL draw; CGFloat alpha;
} Ctx;

static BOOL has_blocks(NSAttributedString *s) {
    __block BOOL found = NO;
    [s enumerateAttribute:NSParagraphStyleAttributeName inRange:NSMakeRange(0, s.length) options:0 usingBlock:^(NSParagraphStyle *ps, NSRange r, BOOL *stop) {
        if ([ps isKindOfClass:[NSParagraphStyle class]] && ps.textBlocks.count) { found = YES; *stop = YES; }
    }];
    return found;
}
BOOL isim_ui_has_text_blocks(NSAttributedString *s) { return s.length && has_blocks(s); }

static CGFloat value_of(CGFloat v, NSTextBlockValueType t, CGFloat W) { return t == NSTextBlockPercentageValueType ? W * v / 100 : v; }
/* margin + border + padding on one edge */
static CGFloat inset(NSTextBlock *b, CGRectEdge e, CGFloat W) {
    CGFloat sum = 0;
    for (int l = 0; l < 3; l++) sum += value_of(b->_width[l][e], b->_widthType[l][e], W);
    return sum;
}
static CGFloat layer_w(NSTextBlock *b, int l, CGRectEdge e, CGFloat W) { return value_of(b->_width[l][e], b->_widthType[l][e], W); }
static CGFloat dim(NSTextBlock *b, NSTextBlockDimension d, CGFloat W, CGFloat dflt) { int i = dim_index(d); return b->_dimSet[i] ? value_of(b->_dim[i], b->_dimType[i], W) : dflt; }

static int pango_align_of(NSTextAlignment a) {
    if (a == NSTextAlignmentNatural) a = isim_ui_drawing_rtl ? NSTextAlignmentRight : NSTextAlignmentLeft;
    return a == NSTextAlignmentCenter ? 1 : a == NSTextAlignmentRight ? 2 : 0;
}
static void fill(CGFloat x, CGFloat y, CGFloat w, CGFloat h, UIColor *c, CGFloat alpha) {
    if (!c || w <= 0 || h <= 0) return;
    double rgba[4]; isim_ui_rgba(c, rgba); rgba[3] *= alpha;
    if (rgba[3] > 0) isim_gfx_fill_rounded(x, y, w, h, 0, rgba);
}

/* a run of paragraphs without (further) blocks: one Pango layout, as without blocks */
static CGSize text_run(Ctx *c, NSUInteger from, NSUInteger to, CGFloat x, CGFloat y, CGFloat W) {
    NSRange r = NSMakeRange(c->paras[from].range.location, NSMaxRange(c->paras[to - 1].range) - c->paras[from].range.location);
    NSAttributedString *sub = [c->s attributedSubstringFromRange:r];
    if ([sub.string hasSuffix:@"\n"]) sub = [sub attributedSubstringFromRange:NSMakeRange(0, sub.length - 1)];
    if (!sub.length) {                                   /* an empty paragraph: one line of the font */
        UIFont *f = [c->s attribute:NSFontAttributeName atIndex:r.location effectiveRange:NULL] ?: c->font ?: [UIFont systemFontOfSize:17];
        return CGSizeMake(0, ceil(f.lineHeight));
    }
    NSTextAlignment al = NSTextAlignmentNatural; CGFloat sp = 0;
    NSString *mk = isim_ui_markup(sub, c->font, c->color, &al, &sp);
    double w, h;
    isim_text_measure_markup(mk.UTF8String, W > 0 ? W : 0, 0, pango_align_of(al), sp, &w, &h);
    if (c->draw) { double rgba[4] = { 0, 0, 0, c->alpha }; isim_text_draw_markup(mk.UTF8String, x, y, W > 0 ? W : w, 0, pango_align_of(al), sp, rgba); }
    return CGSizeMake(ceil(w), ceil(h));
}

static CGSize layout_range(Ctx *c, NSUInteger from, NSUInteger to, NSUInteger depth, CGFloat x, CGFloat y, CGFloat W);

/* the frame of a block: background inside the margins, borders, then the content inside the padding */
static void draw_frame(Ctx *c, NSTextBlock *b, CGRect box, CGFloat W) {
    CGFloat ml = layer_w(b, 2, CGRectMinXEdge, W), mt = layer_w(b, 2, CGRectMinYEdge, W), mr = layer_w(b, 2, CGRectMaxXEdge, W), mb = layer_w(b, 2, CGRectMaxYEdge, W);
    CGRect bb = CGRectMake(box.origin.x + ml, box.origin.y + mt, box.size.width - ml - mr, box.size.height - mt - mb);
    fill(bb.origin.x, bb.origin.y, bb.size.width, bb.size.height, b.backgroundColor, c->alpha);
    CGFloat bl = layer_w(b, 1, CGRectMinXEdge, W), bt = layer_w(b, 1, CGRectMinYEdge, W), br = layer_w(b, 1, CGRectMaxXEdge, W), bo = layer_w(b, 1, CGRectMaxYEdge, W);
    fill(bb.origin.x, bb.origin.y, bb.size.width, bt, b->_border[CGRectMinYEdge], c->alpha);
    fill(bb.origin.x, CGRectGetMaxY(bb) - bo, bb.size.width, bo, b->_border[CGRectMaxYEdge], c->alpha);
    fill(bb.origin.x, bb.origin.y, bl, bb.size.height, b->_border[CGRectMinXEdge], c->alpha);
    fill(CGRectGetMaxX(bb) - br, bb.origin.y, br, bb.size.height, b->_border[CGRectMaxXEdge], c->alpha);
}

/* the content width a block offers its paragraphs, out of the width W it is given */
static CGFloat block_content_width(NSTextBlock *b, CGFloat W, CGFloat natural) {
    CGFloat ins = inset(b, CGRectMinXEdge, W) + inset(b, CGRectMaxXEdge, W);
    CGFloat cw = dim(b, NSTextBlockWidth, W, W > 0 ? W - ins : natural);
    cw = fmax(cw, dim(b, NSTextBlockMinimumWidth, W, 0));
    CGFloat mx = dim(b, NSTextBlockMaximumWidth, W, 0); if (mx > 0) cw = fmin(cw, mx);
    return fmax(cw, 1);
}
static CGFloat block_height(NSTextBlock *b, CGFloat W, CGFloat content) {
    CGFloat h = dim(b, NSTextBlockHeight, W, content);
    h = fmax(h, dim(b, NSTextBlockMinimumHeight, W, 0));
    CGFloat mx = dim(b, NSTextBlockMaximumHeight, W, 0); if (mx > 0) h = fmin(h, mx);
    return h;
}

/* a plain block around paragraphs [from, to) */
static CGSize layout_block(Ctx *c, NSTextBlock *b, NSUInteger from, NSUInteger to, NSUInteger depth, CGFloat x, CGFloat y, CGFloat W) {
    BOOL d = c->draw; c->draw = NO;
    CGSize nat = W > 0 ? CGSizeZero : layout_range(c, from, to, depth + 1, 0, 0, 0);
    CGFloat cw = block_content_width(b, W, nat.width);
    CGSize content = layout_range(c, from, to, depth + 1, 0, 0, cw);
    c->draw = d;
    CGFloat l = inset(b, CGRectMinXEdge, W), t = inset(b, CGRectMinYEdge, W), r = inset(b, CGRectMaxXEdge, W), bo = inset(b, CGRectMaxYEdge, W);
    CGFloat ch = block_height(b, W, content.height);
    CGRect box = CGRectMake(x, y, l + cw + r, t + ch + bo);
    if (c->draw) {
        draw_frame(c, b, box, W);
        CGFloat dy = b.verticalAlignment == NSTextBlockMiddleAlignment ? (ch - content.height) / 2 : b.verticalAlignment == NSTextBlockBottomAlignment ? ch - content.height : 0;
        layout_range(c, from, to, depth + 1, x + l, y + t + fmax(0, dy), cw);
    }
    return box.size;
}

/* ---- tables ---- */
typedef struct { __unsafe_unretained NSTextTableBlock *b; NSUInteger from, to; NSInteger row, col, rs, cs; CGFloat nat, h; BOOL empty; } Cell;

static CGSize layout_table(Ctx *c, NSTextTable *t, Cell *cells, NSUInteger n, NSUInteger depth, CGFloat x, CGFloat y, CGFloat W) {
    BOOL d = c->draw; c->draw = NO;
    NSInteger cols = (NSInteger)t.numberOfColumns, rows = 0;
    for (NSUInteger i = 0; i < n; i++) { cols = MAX(cols, cells[i].col + cells[i].cs); rows = MAX(rows, cells[i].row + cells[i].rs); }
    if (cols < 1) cols = 1;
    /* natural widths: each cell's content laid out unbounded, plus its insets */
    CGFloat *nat = calloc((size_t)cols, sizeof(CGFloat)), *want = calloc((size_t)cols, sizeof(CGFloat)), *colw = calloc((size_t)cols, sizeof(CGFloat));
    for (NSUInteger i = 0; i < n; i++) {
        Cell *e = &cells[i];
        CGFloat ins = inset(e->b, CGRectMinXEdge, 0) + inset(e->b, CGRectMaxXEdge, 0);
        e->nat = layout_range(c, e->from, e->to, depth + 1, 0, 0, 0).width + ins;
        NSString *txt = [[c->s.string substringWithRange:NSMakeRange(c->paras[e->from].range.location, NSMaxRange(c->paras[e->to - 1].range) - c->paras[e->from].range.location)]
                         stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        e->empty = txt.length == 0;
        if (e->cs == 1) nat[e->col] = fmax(nat[e->col], e->nat);
    }
    /* the table's content width */
    CGFloat tl = inset(t, CGRectMinXEdge, W), tr = inset(t, CGRectMaxXEdge, W), tt = inset(t, CGRectMinYEdge, W), tb = inset(t, CGRectMaxYEdge, W);
    CGFloat natSum = 0; for (NSInteger k = 0; k < cols; k++) natSum += nat[k];
    BOOL explicitWidth = t->_dimSet[NSTextBlockWidth];
    CGFloat TW = explicitWidth ? dim(t, NSTextBlockWidth, W, 0) : W > 0 ? W - tl - tr : natSum;
    TW = fmax(TW, 1);
    /* columns asked for by span-1 cells with a width */
    CGFloat fixed = 0; NSInteger open = 0;
    for (NSUInteger i = 0; i < n; i++) {
        Cell *e = &cells[i];
        if (e->cs == 1 && e->b->_dimSet[NSTextBlockWidth])
            want[e->col] = fmax(want[e->col], dim(e->b, NSTextBlockWidth, TW, 0) + inset(e->b, CGRectMinXEdge, TW) + inset(e->b, CGRectMaxXEdge, TW));
    }
    for (NSInteger k = 0; k < cols; k++) { if (want[k] > 0) { colw[k] = want[k]; fixed += want[k]; } else open++; }
    CGFloat rest = fmax(0, TW - fixed);
    if (open) {
        CGFloat openNat = 0; for (NSInteger k = 0; k < cols; k++) if (want[k] <= 0) openNat += nat[k];
        if (t.layoutAlgorithm == NSTextTableFixedLayoutAlgorithm || openNat <= 0) {
            for (NSInteger k = 0; k < cols; k++) if (want[k] <= 0) colw[k] = rest / open;
        } else if (openNat <= rest && !explicitWidth) {           /* automatic: as wide as the content */
            for (NSInteger k = 0; k < cols; k++) if (want[k] <= 0) colw[k] = nat[k];
        } else {                                                  /* shared by content width, none below its share's quarter */
            CGFloat floor_ = rest / open / 4, spare = rest - floor_ * open;
            for (NSInteger k = 0; k < cols; k++) if (want[k] <= 0) colw[k] = floor_ + spare * nat[k] / openNat;
        }
    }
    CGFloat gridW = 0; for (NSInteger k = 0; k < cols; k++) gridW += colw[k];
    /* row heights */
    CGFloat *rowh = calloc((size_t)MAX(rows, 1), sizeof(CGFloat));
    for (int pass = 0; pass < 2; pass++)                   /* single-row cells first, then spans add what they lack */
        for (NSUInteger i = 0; i < n; i++) {
            Cell *e = &cells[i];
            if ((e->rs == 1) != (pass == 0)) continue;
            CGFloat w = 0; for (NSInteger k = e->col; k < e->col + e->cs; k++) w += colw[k];
            CGFloat ins = inset(e->b, CGRectMinXEdge, TW) + inset(e->b, CGRectMaxXEdge, TW);
            CGFloat ch = layout_range(c, e->from, e->to, depth + 1, 0, 0, fmax(1, w - ins)).height;
            e->h = ch;
            CGFloat need = inset(e->b, CGRectMinYEdge, TW) + block_height(e->b, TW, ch) + inset(e->b, CGRectMaxYEdge, TW);
            CGFloat have = 0; for (NSInteger r = e->row; r < e->row + e->rs; r++) have += rowh[r];
            if (need > have) rowh[e->row + e->rs - 1] += need - have;
        }
    CGFloat gridH = 0; for (NSInteger r = 0; r < rows; r++) gridH += rowh[r];
    c->draw = d;
    CGSize size = CGSizeMake(tl + gridW + tr, tt + gridH + tb);
    if (c->draw) {
        draw_frame(c, t, CGRectMake(x, y, size.width, size.height), W);
        CGFloat gx = x + tl, gy = y + tt;
        for (NSUInteger i = 0; i < n; i++) {
            Cell *e = &cells[i];
            CGFloat cx = gx, cy = gy, cw = 0, chh = 0;
            for (NSInteger k = 0; k < e->col; k++) cx += colw[k];
            for (NSInteger r = 0; r < e->row; r++) cy += rowh[r];
            for (NSInteger k = e->col; k < e->col + e->cs; k++) cw += colw[k];
            for (NSInteger r = e->row; r < e->row + e->rs; r++) chh += rowh[r];
            if (t.collapsesBorders) {                      /* neighbouring borders overlap into one */
                CGFloat bl = e->col > 0 ? layer_w(e->b, 1, CGRectMinXEdge, TW) : 0, bt = e->row > 0 ? layer_w(e->b, 1, CGRectMinYEdge, TW) : 0;
                cx -= bl; cw += bl; cy -= bt; chh += bt;
            }
            if (!(t.hidesEmptyCells && e->empty)) draw_frame(c, e->b, CGRectMake(cx, cy, cw, chh), TW);
            CGFloat l = inset(e->b, CGRectMinXEdge, TW), tp = inset(e->b, CGRectMinYEdge, TW), r = inset(e->b, CGRectMaxXEdge, TW), bo = inset(e->b, CGRectMaxYEdge, TW);
            CGFloat room = chh - tp - bo;
            CGFloat dy = e->b.verticalAlignment == NSTextBlockMiddleAlignment ? (room - e->h) / 2 : e->b.verticalAlignment == NSTextBlockBottomAlignment ? room - e->h : 0;
            layout_range(c, e->from, e->to, depth + 1, cx + l, cy + tp + fmax(0, dy), fmax(1, cw - l - r));
        }
    }
    free(nat); free(want); free(colw); free(rowh);
    return size;
}

static NSTextBlock *block_at(Ctx *c, NSUInteger i, NSUInteger depth) { NSArray *b = c->paras[i].blocks; return depth < b.count ? b[depth] : nil; }

/* paragraphs [from, to) at nesting depth: text runs, blocks and tables stacked vertically */
static CGSize layout_range(Ctx *c, NSUInteger from, NSUInteger to, NSUInteger depth, CGFloat x, CGFloat y, CGFloat W) {
    CGFloat h = 0, w = 0;
    NSUInteger i = from;
    while (i < to) {
        NSTextBlock *b = block_at(c, i, depth);
        NSUInteger j = i + 1;
        CGSize s;
        if (!b) {
            while (j < to && !block_at(c, j, depth)) j++;
            s = text_run(c, i, j, x, y + h, W);
        } else if ([b isKindOfClass:[NSTextTableBlock class]]) {
            NSTextTable *t = ((NSTextTableBlock *)b).table;
            NSMutableData *cd = [NSMutableData data];
            j = i;
            while (j < to) {                                /* consecutive cells of this table, each a run of paragraphs */
                NSTextBlock *cb = block_at(c, j, depth);
                if (![cb isKindOfClass:[NSTextTableBlock class]] || ((NSTextTableBlock *)cb).table != t) break;
                NSUInteger k = j + 1;
                while (k < to && block_at(c, k, depth) == cb) k++;
                NSTextTableBlock *tb = (NSTextTableBlock *)cb;
                Cell e = { tb, j, k, tb.startingRow, tb.startingColumn, tb.rowSpan, tb.columnSpan, 0, 0, NO };
                [cd appendBytes:&e length:sizeof e];
                j = k;
            }
            s = layout_table(c, t ?: [NSTextTable new], cd.mutableBytes, cd.length / sizeof(Cell), depth, x, y + h, W);
        } else {
            while (j < to && block_at(c, j, depth) == b) j++;
            s = layout_block(c, b, i, j, depth, x, y + h, W);
        }
        h += s.height; w = fmax(w, s.width);
        i = j;
    }
    return CGSizeMake(w, h);
}

/* the paragraphs of the string with their blocks; draw at origin (top left) when draw is set */
CGSize isim_ui_text_blocks_layout(NSAttributedString *s, UIFont *font, UIColor *color, CGFloat maxw, CGPoint origin, BOOL draw, CGFloat alpha) {
    NSString *str = s.string;
    NSMutableData *pd = [NSMutableData data];
    NSMutableArray *keep = [NSMutableArray array];        /* keeps the paragraphs' block arrays alive */
    for (NSUInteger at = 0; at < str.length; ) {
        NSRange pr = [str paragraphRangeForRange:NSMakeRange(at, 0)];
        NSParagraphStyle *ps = [s attribute:NSParagraphStyleAttributeName atIndex:pr.location effectiveRange:NULL];
        NSArray *blocks = [ps isKindOfClass:[NSParagraphStyle class]] ? ps.textBlocks : @[];
        [keep addObject:blocks];
        Para p = { pr, blocks };
        [pd appendBytes:&p length:sizeof p];
        at = NSMaxRange(pr);
        if (pr.length == 0) break;
    }
    Ctx c = { s, font, color, pd.mutableBytes, pd.length / sizeof(Para), draw, alpha };
    if (!c.count) return CGSizeZero;
    if (!draw) return layout_range(&c, 0, c.count, 0, 0, 0, maxw);
    isim_gfx_save();
    if (alpha < 1) { c.alpha = 1; isim_gfx_push_group(); }
    CGSize size = layout_range(&c, 0, c.count, 0, origin.x, origin.y, maxw);
    if (alpha < 1) isim_gfx_pop_group(alpha);
    isim_gfx_restore();
    return size;
}
