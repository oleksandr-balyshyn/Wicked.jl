module Core

import Base: clamp, contains, fill!, merge!, split, union
using Unicode

include("core/geometry.jl")
include("core/style.jl")
include("core/text.jl")
include("core/east_asian_width.jl")
include("core/cell.jl")
include("core/buffer.jl")
include("core/frame.jl")
include("core/diff.jl")

"""
Return the content region for a rendered surface.

This fallback keeps callers typed to the geometric API safe even when called with
non-block containers. Block-specific behavior is defined by concrete methods.
"""
inner(block, area::Rect) = area

export AbstractWidthPolicy,
       AnsiColor,
       BarCursor,
       BOLD,
       BLINK,
       BlockCursor,
       Buffer,
       BufferRowView,
       BufferRows,
       Cell,
       CellChange,
       CenterAlign,
       Color,
       CursorRequest,
       CursorShape,
       DefaultCursor,
       DEFAULT_WIDTH_POLICY,
       DIM,
       DOUBLE_UNDERLINE,
       DefaultColor,
       Frame,
       HIDDEN,
       HorizontalAlignment,
       ITALIC,
       IndexedColor,
       LeftAlign,
       Line,
       Margin,
       Modifiers,
       Position,
       REVERSED,
       RGBColor,
       Rect,
       RectSplitDirection,
       RowSplit,
       ColumnSplit,
       RightAlign,
       STRIKETHROUGH,
       Size,
       Span,
       Style,
       StylePatch,
       Text,
       TerminalCapabilities,
       UNDERLINE,
       UnderlineCursor,
       UnicodeWidthPolicy,
       apply,
       buffer_rows,
       clear!,
       clamp,
       contains,
       diff_buffers,
       draw_grapheme!,
       draw_line!,
       draw_span!,
       draw_text!,
       fill!,
       grapheme_width,
       inner,
       inset,
       intersection,
       measure,
       merge!,
       render!,
       reset!,
       request_cursor!,
       split,
       text_width,
       union

end
