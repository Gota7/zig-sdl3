const c = @import(
    "c.zig",
).c;
const errors = @import(
    "errors.zig",
);
const gpu = @import(
    "gpu.zig",
);
const io_stream = @import(
    "io_stream.zig",
);
const properties = @import(
    "properties.zig",
);
const rect = @import(
    "rect.zig",
);
const render = @import(
    "render.zig",
);
const std = @import(
    "std",
);
const surface = @import(
    "surface.zig",
);

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn toSdl(
        self: Color,
    ) c.SDL_Color {
        return .{
            .r = self.r,
            .g = self.g,
            .b = self.b,
            .a = self.a,
        };
    }
};

/// Printable format: "%d.%d.%d", major_version, minor_version, micro_version
pub const major_version = c.SDL_TTF_MAJOR_VERSION;
/// Printable format: "%d.%d.%d", major_version, minor_version, micro_version
pub const minor_version = c.SDL_TTF_MINOR_VERSION;
/// Printable format: "%d.%d.%d", major_version, minor_version, micro_version
pub const micro_version = c.SDL_TTF_MICRO_VERSION;

/// This is the version number for the current SDL_ttf version.
pub fn version() u32 {
    return c.SDL_TTF_VERSION;
}

pub const Version = packed struct {
    value: c_int,

    /// Extracts the major version from a version number.
    pub fn getMajor(
        self: Version,
    ) u32 {
        return @intCast(c.SDL_VERSIONNUM_MAJOR(
            self.value,
        ));
    }

    /// Extracts the minor version from a version number.
    pub fn getMinor(
        self: Version,
    ) u32 {
        return @intCast(c.SDL_VERSIONNUM_MINOR(
            self.value,
        ));
    }

    /// Extracts the micro version from a version number.
    pub fn getMicro(
        self: Version,
    ) u32 {
        return @intCast(c.SDL_VERSIONNUM_MICRO(
            self.value,
        ));
    }

    /// Returns `true` if compiled with SDL_ttf at least X.Y.Z.
    pub fn atLeast(
        comptime x: u8,
        comptime y: u8,
        comptime z: u8,
    ) bool {
        return c.SDL_TTF_VERSION_ATLEAST(
            x,
            y,
            z,
        );
    }

    pub fn format(
        self: Version,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        return writer.print(
            "{d}.{d}.{d}",
            .{ self.getMajor(), self.getMinor(), self.getMicro() },
        );
    }
};

/// This function gets the version of the dynamically linked SDL_ttf library.
///
/// ## Return Value
/// Returns SDL_ttf version.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn getVersion() Version {
    return .{ .value = c.TTF_Version() };
}

/// Query the version of the FreeType library in use.
///
/// ## Remarks
/// `init()` should be called before calling this function.
///
/// ## Return Value
/// Returns a struct with the major, minor, and patch version numbers.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn getFreeTypeVersion() struct { major: c_int, minor: c_int, patch: c_int } {
    var major: c_int = undefined;
    var minor: c_int = undefined;
    var patch: c_int = undefined;
    c.TTF_GetFreeTypeVersion(
        &major,
        &minor,
        &patch,
    );
    return .{ .major = major, .minor = minor, .patch = patch };
}

/// Query the version of the HarfBuzz library in use.
///
/// ## Remarks
/// If HarfBuzz is not available, the version reported is 0.0.0.
///
/// ## Return Value
/// Returns a struct with the major, minor, and patch version numbers.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn getHarfBuzzVersion() struct { major: c_int, minor: c_int, patch: c_int } {
    var major: c_int = undefined;
    var minor: c_int = undefined;
    var patch: c_int = undefined;
    c.TTF_GetHarfBuzzVersion(
        &major,
        &minor,
        &patch,
    );
    return .{ .major = major, .minor = minor, .patch = patch };
}

/// Initialize SDL_ttf.
///
/// ## Remarks
/// You must successfully call this function before it is safe to call any other function in this library.
///
/// It is safe to call this more than once, and each successful `init()` call should be paired with a matching `quit()` call.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn init() !void {
    return errors.wrapCallBool(
        c.TTF_Init(),
    );
}

/// Deinitialize SDL_ttf.
///
/// ## Remarks
/// You must call this when done with the library, to free internal resources.
/// It is safe to call this when the library isn't initialized, as it will just return immediately.
///
/// Once you have as many quit calls as you have had successful calls to `init()`, the library will actually deinitialize.
///
/// Please note that this does not automatically close any fonts that are still open at the time of deinitialization,
/// and it is possibly not safe to close them afterwards, as parts of the library will no longer be initialized to deal with it.
/// A well-written program should call `Font.deinit()` on any open fonts before calling this function!
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn quit() void {
    c.TTF_Quit();
}

/// Check if SDL_ttf is initialized.
///
/// ## Remarks
/// This reports the number of times the library has been initialized by a call to `init()`, without a paired deinitialization request from `quit()`.
///
/// In short: if it's greater than zero, the library is currently initialized and ready to work. If zero, it is not initialized.
///
/// Despite the return value being a signed integer, this function should not return a negative number.
///
/// ## Return Value
/// Returns the current number of initialization calls, that need to eventually be paired with this many calls to `quit()`.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn wasInit() c_int {
    return c.TTF_WasInit();
}

/// Convert from a 4 character string to a 32-bit tag.
///
/// ## Function Parameters
/// * `string`: The 4 character string to convert.
///
/// ## Return Value
/// Returns the 32-bit representation of the string.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Remarks
/// The string must be 4 characters long.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn stringToTag(
    string: [:0]const u8,
) u32 {
    std.debug.assert(
        string.len == 4,
    ); // the string must be 4 characters long.
    return c.TTF_StringToTag(
        string.ptr,
    );
}

/// Convert from a 32-bit tag to a 4 character string.
///
/// ## Function Parameters
/// * `tag`: The 32-bit tag to convert.
///
/// ## Return Value
/// Returns the 4 character representation of the tag.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn tagToString(
    tag: u32,
) [4]u8 {
    var buf: [5]u8 = undefined;
    c.TTF_TagToString(
        tag,
        &buf,
        buf.len,
    );
    return [4]u8{ buf[0], buf[1], buf[2], buf[3] };
}

/// Get the script used by a 32-bit codepoint.
///
/// ## Function Parameters
/// * `ch`: The character code to check.
///
/// ## Return Value
/// Returns an ISO 15924 code on success.
///
/// ## Thread Safety
/// This function is thread-safe.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn getGlyphScript(
    ch: u32,
) !u32 {
    return errors.wrapCall(
        u32,
        c.TTF_GetGlyphScript(
            ch,
        ),
        0,
    );
}

/// Thin (100,) named font weight value
pub const font_weight_thin = c.TTF_FONT_WEIGHT_THIN;
/// ExtraLight (200,) named font weight value
pub const font_weight_extra_light = c.TTF_FONT_WEIGHT_EXTRA_LIGHT;
/// Light (300,) named font weight value
pub const font_weight_light = c.TTF_FONT_WEIGHT_LIGHT;
/// Normal (400,) named font weight value
pub const font_weight_normal = c.TTF_FONT_WEIGHT_NORMAL;
/// Medium (500,) named font weight value
pub const font_weight_medium = c.TTF_FONT_WEIGHT_MEDIUM;
/// SemiBold (600,) named font weight value
pub const font_weight_semi_bold = c.TTF_FONT_WEIGHT_SEMI_BOLD;
/// Bold (700,) named font weight value
pub const font_weight_bold = c.TTF_FONT_WEIGHT_BOLD;
/// ExtraBold (800,) named font weight value
pub const font_weight_extra_bold = c.TTF_FONT_WEIGHT_EXTRA_BOLD;
/// Black (900,) named font weight value
pub const font_weight_black = c.TTF_FONT_WEIGHT_BLACK;
/// ExtraBlack (950,) named font weight value
pub const font_weight_extra_black = c.TTF_FONT_WEIGHT_EXTRA_BLACK;

/// Font style flags for `Font`
///
/// ## Remarks
/// These are the flags which can be used to set the style of a font in
/// SDL_ttf. A combination of these flags can be used with functions that set
/// or query font style, such as `Font.setFontStyle` or `Font.getFontStyle`.
///
/// ## Version
/// This datatype is available since SDL_ttf 3.0.0.
pub const FontStyleFlags = packed struct {
    /// Bold style
    bold: bool = false,
    /// Italic style
    italic: bool = false,
    /// Underlined text
    underline: bool = false,
    /// Strikethrough text
    strikethrough: bool = false,

    pub fn toSdl(
        self: FontStyleFlags,
    ) c.TTF_FontStyleFlags {
        var result: c.TTF_FontStyleFlags = 0;
        if (self.bold) result |= c.TTF_STYLE_BOLD;
        if (self.italic) result |= c.TTF_STYLE_ITALIC;
        if (self.underline) result |= c.TTF_STYLE_UNDERLINE;
        if (self.strikethrough) result |= c.TTF_STYLE_STRIKETHROUGH;
        return result;
    }

    pub fn fromSdl(
        flags: c.TTF_FontStyleFlags,
    ) FontStyleFlags {
        return .{
            .bold = (flags & c.TTF_STYLE_BOLD != 0),
            .italic = (flags & c.TTF_STYLE_ITALIC != 0),
            .underline = (flags & c.TTF_STYLE_UNDERLINE != 0),
            .strikethrough = (flags & c.TTF_STYLE_STRIKETHROUGH != 0),
        };
    }
};

/// Hinting flags for TTF (TrueType Fonts,)
///
/// ## Remarks
/// This enum specifies the level of hinting to be applied to the font
/// rendering. The hinting level determines how much the font's outlines are
/// adjusted for better alignment on the pixel grid.
///
/// ## Version
/// This enum is available since SDL_ttf 3.0.0.
pub const HintingFlags = enum(c.TTF_HintingFlags) {
    invalid = c.TTF_HINTING_INVALID,
    /// Normal hinting applies standard grid-fitting.
    normal = c.TTF_HINTING_NORMAL,
    /// Light hinting applies subtle adjustments to improve rendering.
    light = c.TTF_HINTING_LIGHT,
    /// Monochrome hinting adjusts the font for better rendering at lower resolutions.
    mono = c.TTF_HINTING_MONO,
    /// No hinting, the font is rendered without any grid-fitting.
    none = c.TTF_HINTING_NONE,
    /// Light hinting with subpixel rendering for more precise font edges.
    light_subpixel = c.TTF_HINTING_LIGHT_SUBPIXEL,
};

/// The horizontal alignment used when rendering wrapped text.
///
/// ## Version
/// This enum is available since SDL_ttf 3.0.0.
pub const HorizontalAlignment = enum(c.TTF_HorizontalAlignment) {
    invalid = c.TTF_HORIZONTAL_ALIGN_INVALID,
    left = c.TTF_HORIZONTAL_ALIGN_LEFT,
    center = c.TTF_HORIZONTAL_ALIGN_CENTER,
    right = c.TTF_HORIZONTAL_ALIGN_RIGHT,
};

/// Direction flags
///
/// ## Remarks
/// The values here are chosen to match
/// [hb_direction_t](https://harfbuzz.github.io/harfbuzz-hb-common.html#hb-direction-t,)
///
/// ## Version
/// This enum is available since SDL_ttf 3.0.0.
pub const Direction = enum(c.TTF_Direction) {
    invalid = c.TTF_DIRECTION_INVALID,
    /// Left to Right
    ltr = c.TTF_DIRECTION_LTR,
    /// Right to Left
    rtl = c.TTF_DIRECTION_RTL,
    /// Top to Bottom
    ttb = c.TTF_DIRECTION_TTB,
    /// Bottom to Top
    btt = c.TTF_DIRECTION_BTT,
};

/// The type of data in a glyph image
///
/// ## Version
/// This enum is available since SDL_ttf 3.0.0.
pub const ImageType = enum(c.TTF_ImageType) {
    invalid = c.TTF_IMAGE_INVALID,
    /// The color channels are white
    alpha = c.TTF_IMAGE_ALPHA,
    /// The color channels have image data
    color = c.TTF_IMAGE_COLOR,
    /// The alpha channel has signed distance field information
    sdf = c.TTF_IMAGE_SDF,
};

/// The winding order of the vertices returned by `Text.getGpuDrawData`
///
/// ## Version
/// This enum is available since SDL_ttf 3.0.0.
pub const GpuTextEngineWinding = enum(c.TTF_GPUTextEngineWinding) {
    invalid = c.TTF_GPU_TEXTENGINE_WINDING_INVALID,
    clockwise = c.TTF_GPU_TEXTENGINE_WINDING_CLOCKWISE,
    counter_clockwise = c.TTF_GPU_TEXTENGINE_WINDING_COUNTER_CLOCKWISE,
};

/// Flags for `SubString`
///
/// ## Version
/// This datatype is available since SDL_ttf 3.0.0.
pub const SubStringFlags = packed struct {
    /// The flow direction for this substring
    direction: Direction,
    /// This substring contains the beginning of the text
    text_start: bool = false,
    /// This substring contains the beginning of line `line_index`
    line_start: bool = false,
    /// This substring contains the end of line `line_index`
    line_end: bool = false,
    /// This substring contains the end of the text
    text_end: bool = false,

    pub fn fromSdl(
        flags: c.TTF_SubStringFlags,
    ) SubStringFlags {
        return .{
            .direction = @enumFromInt(
                flags & c.TTF_SUBSTRING_DIRECTION_MASK,
            ),
            .text_start = (flags & c.TTF_SUBSTRING_TEXT_START != 0),
            .line_start = (flags & c.TTF_SUBSTRING_LINE_START != 0),
            .line_end = (flags & c.TTF_SUBSTRING_LINE_END != 0),
            .text_end = (flags & c.TTF_SUBSTRING_TEXT_END != 0),
        };
    }

    pub fn toSdl(
        self: SubStringFlags,
    ) c.TTF_SubStringFlags {
        var result: c.TTF_SubStringFlags = @intFromEnum(
            self.direction,
        );
        if (self.text_start) result |= c.TTF_SUBSTRING_TEXT_START;
        if (self.line_start) result |= c.TTF_SUBSTRING_LINE_START;
        if (self.line_end) result |= c.TTF_SUBSTRING_LINE_END;
        if (self.text_end) result |= c.TTF_SUBSTRING_TEXT_END;
        return result;
    }
};

/// The internal structure containing font information.
///
/// ## Remarks
/// Opaque data!
pub const Font = struct {
    value: *c.TTF_Font,

    /// Create a font from a file, using a specified point size.
    ///
    /// ## Function Parameters
    /// * `file`: Path to font file.
    /// * `ptsize`: Point size to use for the newly-opened font.
    ///
    /// ## Return Value
    /// Returns a valid `Font`.
    ///
    /// ## Remarks
    /// Some .fon fonts will have several sizes embedded in the file, so the point
    /// size becomes the index of choosing which size. If the value is too high,
    /// the last indexed size will be the default.
    ///
    /// When done with the returned `Font`, use `deinit()` to dispose of it.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn init(
        file: [:0]const u8,
        ptsize: f32,
    ) !Font {
        return .{
            .value = try errors.wrapCallNull(*c.TTF_Font, c.TTF_OpenFont(
                file.ptr,
                ptsize,
            )),
        };
    }

    /// Create a font from an `io_stream.Stream`, using a specified point size.
    ///
    /// ## Function Parameters
    /// * `src`: An `io_stream.Stream` to provide a font file's data.
    /// * `close_io`: `true` to close `src` when the font is closed, `false` to leave it open.
    /// * `ptsize`: Point size to use for the newly-opened font.
    ///
    /// ## Return Value
    /// Returns a valid `Font`.
    ///
    /// ## Remarks
    /// Some .fon fonts will have several sizes embedded in the file, so the point
    /// size becomes the index of choosing which size. If the value is too high,
    /// the last indexed size will be the default.
    ///
    /// If `close_io` is true, `src` will be automatically closed once the font is
    /// closed. Otherwise you should close `src` yourself after closing the font.
    ///
    /// When done with the returned `Font`, use `deinit()` to dispose of it.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn initFromIO(
        src: io_stream.Stream,
        close_io: bool,
        ptsize: f32,
    ) !Font {
        return .{
            .value = try errors.wrapCallNull(*c.TTF_Font, c.TTF_OpenFontIO(
                src.value,
                close_io,
                ptsize,
            )),
        };
    }

    /// Properties to use for font creation.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    pub const CreateProperties = struct {
        /// The font file to open, if an `io_stream.Stream` isn't being used.
        /// This is required if `io_stream` and `existing_font` aren't set.
        filename: ?[:0]const u8 = null,
        /// An `io_stream.Stream` containing the font to be opened.
        /// This should not be closed until the font is closed.
        /// This is required if `filename` and `existing_font` aren't set.
        io_stream: ?io_stream.Stream = null,
        /// The offset in the iostream for the beginning of the font, defaults to 0.
        io_stream_offset: ?i64 = null,
        /// `true` if closing the font should also close the associated `io_stream.Stream`.
        io_stream_autoclose: ?bool = null,
        /// The point size of the font.
        /// Some .fon fonts will have several sizes embedded in the file, so the point size becomes the index of choosing which size.
        /// If the value is too high, the last indexed size will be the default.
        size: ?f32 = null,
        /// The face index of the font, if the font contains multiple font faces.
        face: ?i64 = null,
        /// The horizontal DPI to use for font rendering, defaults to `vertical_dpi` if set, or 72 otherwise.
        horizontal_dpi: ?i64 = null,
        /// The vertical DPI to use for font rendering, defaults to `horizontal_dpi` if set, or 72 otherwise.
        vertical_dpi: ?i64 = null,
        /// An optional `Font` that, if set, will be used as the font data source and the initial size and style of the new font.
        existing_font: ?Font = null,

        /// Convert to an SDL properties group.
        ///
        /// ## Remarks
        /// The returned group must be freed with `properties.Group.deinit()`.
        pub fn toProperties(
            self: CreateProperties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            if (self.filename) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_FILENAME_STRING,
                .{ .string = val },
            );
            if (self.io_stream) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_IOSTREAM_POINTER,
                .{ .pointer = val.value },
            );
            if (self.io_stream_offset) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_IOSTREAM_OFFSET_NUMBER,
                .{ .number = val },
            );
            if (self.io_stream_autoclose) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN,
                .{ .boolean = val },
            );
            if (self.size) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_SIZE_FLOAT,
                .{ .float = val },
            );
            if (self.face) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_FACE_NUMBER,
                .{ .number = val },
            );
            if (self.horizontal_dpi) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_HORIZONTAL_DPI_NUMBER,
                .{ .number = val },
            );
            if (self.vertical_dpi) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_VERTICAL_DPI_NUMBER,
                .{ .number = val },
            );
            if (self.existing_font) |val| try ret.set(
                c.TTF_PROP_FONT_CREATE_EXISTING_FONT,
                .{ .pointer = val.value },
            );
            return ret;
        }
    };

    /// Create a font with the specified properties.
    ///
    /// ## Function Parameters
    /// * `props`: The properties to use.
    ///
    /// ## Return Value
    /// Returns a valid `Font`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn initWithProperties(
        props: CreateProperties,
    ) !Font {
        const group = try props.toProperties();
        defer group.deinit();
        return .{ .value = try errors.wrapCallNull(*c.TTF_Font, c.TTF_OpenFontWithProperties(
            group.value,
        )) };
    }

    /// Dispose of a previously-created font.
    ///
    /// ## Remarks
    /// Call this when done with a font. This function will free any resources
    /// associated with it. It is safe to call this function on a `null` `Font`.
    ///
    /// The font is not valid after being passed to this function. String pointers
    /// from functions that return information on this font, such as
    /// `getFamilyName()` and `getStyleName()`, are no longer valid
    /// after this call, as well.
    ///
    /// ## Thread Safety
    /// This function should not be called while any other thread is
    /// using the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn deinit(
        self: Font,
    ) void {
        c.TTF_CloseFont(
            self.value,
        );
    }

    /// Create a copy of an existing font.
    ///
    /// ## Return Value
    /// Returns a valid `Font`.
    ///
    /// ## Remarks
    /// The copy will be distinct from the original, but will share the font file
    /// and have the same size and style as the original.
    ///
    /// When done with the returned `Font`, use `deinit()` to dispose of it.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the
    /// original font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn copy(
        self: Font,
    ) !Font {
        return .{
            .value = try errors.wrapCallNull(*c.TTF_Font, c.TTF_CopyFont(
                self.value,
            )),
        };
    }

    /// Properties associated with a font.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    pub const Properties = struct {
        /// The FT_Stroker_LineCap value used when setting the font outline, defaults to `FT_STROKER_LINECAP_ROUND`.
        outline_line_cap: ?i64 = null,
        /// The FT_Stroker_LineJoin value used when setting the font outline, defaults to `FT_STROKER_LINEJOIN_ROUND`.
        outline_line_join: ?i64 = null,
        /// The FT_Fixed miter limit used when setting the font outline, defaults to 0.
        outline_miter_limit: ?i64 = null,

        /// Convert from an SDL properties group.
        pub fn fromSdl(
            value: properties.Group,
        ) Properties {
            return .{
                .outline_line_cap = if (value.get(c.TTF_PROP_FONT_OUTLINE_LINE_CAP_NUMBER)) |val| val.number else null,
                .outline_line_join = if (value.get(c.TTF_PROP_FONT_OUTLINE_LINE_JOIN_NUMBER)) |val| val.number else null,
                .outline_miter_limit = if (value.get(c.TTF_PROP_FONT_OUTLINE_MITER_LIMIT_NUMBER)) |val| val.number else null,
            };
        }

        /// Convert to an SDL properties group.
        pub fn toSdl(
            self: Properties,
            value: properties.Group,
        ) !void {
            if (self.outline_line_cap) |val| try value.set(
                c.TTF_PROP_FONT_OUTLINE_LINE_CAP_NUMBER,
                .{ .number = val },
            );
            if (self.outline_line_join) |val| try value.set(
                c.TTF_PROP_FONT_OUTLINE_LINE_JOIN_NUMBER,
                .{ .number = val },
            );
            if (self.outline_miter_limit) |val| try value.set(
                c.TTF_PROP_FONT_OUTLINE_MITER_LIMIT_NUMBER,
                .{ .number = val },
            );
        }
    };

    /// Get the properties associated with a font.
    ///
    /// ## Return Value
    /// Returns the properties for a font.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getProperties(
        self: Font,
    ) !Properties {
        const group = properties.Group{ .value = try errors.wrapCall(
            c.SDL_PropertiesID,
            c.TTF_GetFontProperties(
                self.value,
            ),
            0,
        ) };
        return .fromSdl(
            group,
        );
    }

    /// Set the properties associated with a font.
    ///
    /// ## Function Parameters
    /// * `props`: The properties to set.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setProperties(
        self: Font,
        props: Properties,
    ) !void {
        const group = properties.Group{ .value = try errors.wrapCall(
            c.SDL_PropertiesID,
            c.TTF_GetFontProperties(
                self.value,
            ),
            0,
        ) };
        try props.toSdl(
            group,
        );
    }

    /// Get the font generation.
    ///
    /// ## Return Value
    /// Returns the font generation.
    ///
    /// ## Remarks
    /// The generation is incremented each time font properties change that require
    /// rebuilding glyphs, such as style, size, etc.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getGeneration(
        self: Font,
    ) !u32 {
        return errors.wrapCall(
            u32,
            c.TTF_GetFontGeneration(
                self.value,
            ),
            0,
        );
    }

    /// Add a fallback font.
    ///
    /// ## Function Parameters
    /// * `fallback`: The font to add as a fallback.
    ///
    /// ## Remarks
    /// Add a font that will be used for glyphs that are not in the current font.
    /// The fallback font should have the same size and style as the current font.
    ///
    /// If there are multiple fallback fonts, they are used in the order added.
    ///
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created both fonts.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn addFallback(
        self: Font,
        fallback: Font,
    ) !void {
        return errors.wrapCallBool(c.TTF_AddFallbackFont(
            self.value,
            fallback.value,
        ));
    }

    /// Remove a fallback font.
    ///
    /// ## Function Parameters
    /// * `fallback`: The font to remove as a fallback.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created both fonts.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn removeFallback(
        self: Font,
        fallback: Font,
    ) void {
        c.TTF_RemoveFallbackFont(
            self.value,
            fallback.value,
        );
    }

    /// Remove all fallback fonts.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn clearFallbackFonts(
        self: Font,
    ) void {
        c.TTF_ClearFallbackFonts(
            self.value,
        );
    }

    /// Set a font's size dynamically.
    ///
    /// ## Function Parameters
    /// * `ptsize`: The new point size.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font, and clears
    /// already-generated glyphs, if any, from the cache.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setSize(
        self: Font,
        ptsize: f32,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetFontSize(
            self.value,
            ptsize,
        ));
    }

    /// Set font size dynamically with target resolutions, in dots per inch.
    ///
    /// ## Function Parameters
    /// * `ptsize`: The new point size.
    /// * `hdpi`: The target horizontal DPI.
    /// * `vdpi`: The target vertical DPI.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font, and clears
    /// already-generated glyphs, if any, from the cache.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setSizeDpi(
        self: Font,
        ptsize: f32,
        hdpi: c_int,
        vdpi: c_int,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetFontSizeDPI(
            self.value,
            ptsize,
            hdpi,
            vdpi,
        ));
    }

    /// Get the size of a font.
    ///
    /// ## Return Value
    /// Returns the size of the font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getSize(
        self: Font,
    ) !f32 {
        return errors.wrapCall(
            f32,
            c.TTF_GetFontSize(
                self.value,
            ),
            0.0,
        );
    }

    /// Get font target resolutions, in dots per inch.
    ///
    /// ## Return Value
    /// Returns a struct with the horizontal and vertical DPI.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getDpi(
        self: Font,
    ) !struct { hdpi: c_int, vdpi: c_int } {
        var hdpi: c_int = undefined;
        var vdpi: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetFontDPI(
            self.value,
            &hdpi,
            &vdpi,
        ));
        return .{ .hdpi = hdpi, .vdpi = vdpi };
    }

    /// Set a font's current style.
    ///
    /// ## Function Parameters
    /// * `style`: The new style values to set.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font, and clears
    /// already-generated glyphs, if any, from the cache.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setStyle(
        self: Font,
        style: FontStyleFlags,
    ) void {
        c.TTF_SetFontStyle(
            self.value,
            style.toSdl(),
        );
    }

    /// Query a font's current style.
    ///
    /// ## Return Value
    /// Returns the current font style.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getStyle(
        self: Font,
    ) FontStyleFlags {
        return FontStyleFlags.fromSdl(c.TTF_GetFontStyle(
            self.value,
        ));
    }

    /// Set a font's current outline.
    ///
    /// ## Function Parameters
    /// * `outline`: Positive outline value, 0 to default.
    ///
    /// ## Remarks
    /// This uses the font properties `ttf.font_outline_line_cap_number`,
    /// `ttf.font_outline_line_join_number`, and
    /// `ttf.font_outline_miter_limit_number` when setting the font outline.
    ///
    /// This updates any `Text` objects using this font, and clears
    /// already-generated glyphs, if any, from the cache.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setOutline(
        self: Font,
        outline: c_int,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetFontOutline(
            self.value,
            outline,
        ));
    }

    /// Query a font's current outline.
    ///
    /// ## Return Value
    /// Returns the font's current outline value.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getOutline(
        self: Font,
    ) c_int {
        return c.TTF_GetFontOutline(
            self.value,
        );
    }

    /// Set a font's current hinter setting.
    ///
    /// ## Function Parameters
    /// * `hinting`: The new hinter setting.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font, and clears
    /// already-generated glyphs, if any, from the cache.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setHinting(
        self: Font,
        hinting: HintingFlags,
    ) void {
        c.TTF_SetFontHinting(self.value, @intFromEnum(
            hinting,
        ));
    }

    /// Query a font's current FreeType hinter setting.
    ///
    /// ## Return Value
    /// Returns the font's current hinter value.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getHinting(
        self: Font,
    ) HintingFlags {
        return @enumFromInt(c.TTF_GetFontHinting(
            self.value,
        ));
    }

    /// Query the number of faces of a font.
    ///
    /// ## Return Value
    /// Returns the number of FreeType font faces.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getNumFaces(
        self: Font,
    ) c_int {
        return c.TTF_GetNumFontFaces(
            self.value,
        );
    }

    /// Enable Signed Distance Field rendering for a font.
    ///
    /// ## Function Parameters
    /// * `enabled`: `true` to enable SDF, `false` to disable.
    ///
    /// ## Remarks
    /// SDF is a technique that helps fonts look sharp even when scaling and
    /// rotating, and requires special shader support for display.
    ///
    /// This works with Blended APIs, and generates the raw signed distance values
    /// in the alpha channel of the resulting texture.
    ///
    /// This updates any `Text` objects using this font, and clears
    /// already-generated glyphs, if any, from the cache.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setSdf(
        self: Font,
        enabled: bool,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetFontSDF(
            self.value,
            enabled,
        ));
    }

    /// Query whether Signed Distance Field rendering is enabled for a font.
    ///
    /// ## Return Value
    /// Returns `true` if enabled, `false` otherwise.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getSdf(
        self: Font,
    ) bool {
        return c.TTF_GetFontSDF(
            self.value,
        );
    }

    /// Query a font's weight, in terms of the lightness/heaviness of the strokes.
    ///
    /// ## Return Value
    /// Returns the font's current weight.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.4.0.
    pub fn getWeight(
        self: Font,
    ) c_int {
        return c.TTF_GetFontWeight(
            self.value,
        );
    }

    /// Set a font's current wrap alignment option.
    ///
    /// ## Function Parameters
    /// * `align`: The new wrap alignment option.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setWrapAlignment(
        self: Font,
        @"align": HorizontalAlignment,
    ) void {
        c.TTF_SetFontWrapAlignment(self.value, @intFromEnum(
            @"align",
        ));
    }

    /// Query a font's current wrap alignment option.
    ///
    /// ## Return Value
    /// Returns the font's current wrap alignment option.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getWrapAlignment(
        self: Font,
    ) HorizontalAlignment {
        return @enumFromInt(c.TTF_GetFontWrapAlignment(
            self.value,
        ));
    }

    /// Query the total height of a font.
    ///
    /// ## Return Value
    /// Returns the font's height.
    ///
    /// ## Remarks
    /// This is usually equal to point size.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getHeight(
        self: Font,
    ) c_int {
        return c.TTF_GetFontHeight(
            self.value,
        );
    }

    /// Query the offset from the baseline to the top of a font.
    ///
    /// ## Return Value
    /// Returns the font's ascent.
    ///
    /// ## Remarks
    /// This is a positive value, relative to the baseline.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getAscent(
        self: Font,
    ) c_int {
        return c.TTF_GetFontAscent(
            self.value,
        );
    }

    /// Query the offset from the baseline to the bottom of a font.
    ///
    /// ## Return Value
    /// Returns the font's descent.
    ///
    /// ## Remarks
    /// This is a negative value, relative to the baseline.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getDescent(
        self: Font,
    ) c_int {
        return c.TTF_GetFontDescent(
            self.value,
        );
    }

    /// Set the spacing between lines of text for a font.
    ///
    /// ## Function Parameters
    /// * `lineskip`: The new line spacing for the font.
    ///
    /// ## Remarks
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setLineSkip(
        self: Font,
        lineskip: c_int,
    ) void {
        c.TTF_SetFontLineSkip(
            self.value,
            lineskip,
        );
    }

    /// Query the spacing between lines of text for a font.
    ///
    /// ## Return Value
    /// Returns the font's recommended spacing.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getLineSkip(
        self: Font,
    ) c_int {
        return c.TTF_GetFontLineSkip(
            self.value,
        );
    }

    /// Set if kerning is enabled for a font.
    ///
    /// ## Function Parameters
    /// * `enabled`: `true` to enable kerning, `false` to disable.
    ///
    /// ## Remarks
    /// Newly-opened fonts default to allowing kerning. This is generally a good
    /// policy unless you have a strong reason to disable it, as it tends to
    /// produce better rendering (with kerning disabled, some fonts might render
    /// the word `kerning` as something that looks like `keming` for example,).
    ///
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setKerning(
        self: Font,
        enabled: bool,
    ) void {
        c.TTF_SetFontKerning(
            self.value,
            enabled,
        );
    }

    /// Query whether or not kerning is enabled for a font.
    ///
    /// ## Return Value
    /// Returns `true` if kerning is enabled, `false` otherwise.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getKerning(
        self: Font,
    ) bool {
        return c.TTF_GetFontKerning(
            self.value,
        );
    }

    /// Query whether a font is fixed-width.
    ///
    /// ## Return Value
    /// Returns `true` if the font is fixed-width, `false` otherwise.
    ///
    /// ## Remarks
    /// A "fixed-width" font means all glyphs are the same width across; a
    /// lowercase 'i' will be the same size across as a capital 'W', for example.
    /// This is common for terminals and text editors, and other apps that treat
    /// text as a grid. Most other things (WYSIWYG word processors, web pages, etc,)
    /// are more likely to not be fixed-width in most cases.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn isFixedWidth(
        self: Font,
    ) bool {
        return c.TTF_FontIsFixedWidth(
            self.value,
        );
    }

    /// Query whether a font is scalable or not.
    ///
    /// ## Return Value
    /// Returns `true` if the font is scalable, `false` otherwise.
    ///
    /// ## Remarks
    /// Scalability lets us distinguish between outline and bitmap fonts.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn isScalable(
        self: Font,
    ) bool {
        return c.TTF_FontIsScalable(
            self.value,
        );
    }

    /// Query a font's family name.
    ///
    /// ## Return Value
    /// Returns the font's family name.
    ///
    /// ## Remarks
    /// This string is dictated by the contents of the font file.
    ///
    /// Note that the returned string is to internal storage, and should not be
    /// modified or free'd by the caller. The string becomes invalid, with the rest
    /// of the font, when `font` is handed to `deinit()`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getFamilyName(
        self: Font,
    ) [:0]const u8 {
        return std.mem.sliceTo(
            c.TTF_GetFontFamilyName(
                self.value,
            ),
            0,
        );
    }

    /// Query a font's style name.
    ///
    /// ## Return Value
    /// Returns the font's style name.
    ///
    /// ## Remarks
    /// This string is dictated by the contents of the font file.
    ///
    /// Note that the returned string is to internal storage, and should not be
    /// modified or free'd by the caller. The string becomes invalid, with the rest
    /// of the font, when `font` is handed to `deinit()`.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getStyleName(
        self: Font,
    ) [:0]const u8 {
        return std.mem.sliceTo(
            c.TTF_GetFontStyleName(
                self.value,
            ),
            0,
        );
    }

    /// Set the direction to be used for text shaping by a font.
    ///
    /// ## Function Parameters
    /// * `direction`: The new direction for text to flow.
    ///
    /// ## Remarks
    /// This function only supports left-to-right text shaping if SDL_ttf was not
    /// built with HarfBuzz support.
    ///
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setDirection(
        self: Font,
        direction: Direction,
    ) !void {
        return errors.wrapCallBool(
            c.TTF_SetFontDirection(self.value, @intFromEnum(
                direction,
            )),
        );
    }

    /// Get the direction to be used for text shaping by a font.
    ///
    /// ## Return Value
    /// Returns the direction to be used for text shaping.
    ///
    /// ## Remarks
    /// This defaults to `Direction.invalid` if it hasn't been set.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getDirection(
        self: Font,
    ) Direction {
        return @enumFromInt(c.TTF_GetFontDirection(
            self.value,
        ));
    }

    /// Set the script to be used for text shaping by a font.
    ///
    /// ## Function Parameters
    /// * `script`: An ISO 15924 code.
    ///
    /// ## Remarks
    /// This returns `error.SdlError` if SDL_ttf isn't built with HarfBuzz support.
    ///
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setScript(
        self: Font,
        script: u32,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetFontScript(
            self.value,
            script,
        ));
    }

    /// Get the script used for text shaping a font.
    ///
    /// ## Return Value
    /// Returns an ISO 15924 code or 0 if a script hasn't been set.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getScript(
        self: Font,
    ) u32 {
        return c.TTF_GetFontScript(
            self.value,
        );
    }

    /// Set language to be used for text shaping by a font.
    ///
    /// ## Function Parameters
    /// * `language_bcp47`: A null-terminated string containing the desired language's BCP47 code. Or `null` to reset the value.
    ///
    /// ## Remarks
    /// If SDL_ttf was not built with HarfBuzz support, this function returns `error.SdlError`.
    ///
    /// This updates any `Text` objects using this font.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setLanguage(
        self: Font,
        language_bcp47: ?[:0]const u8,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetFontLanguage(
            self.value,
            if (language_bcp47) |l| l.ptr else null,
        ));
    }

    /// Check whether a glyph is provided by the font for a UNICODE codepoint.
    ///
    /// ## Function Parameters
    /// * `ch`: The codepoint to check.
    ///
    /// ## Return Value
    /// Returns `true` if font provides a glyph for this character, `false` if not.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn hasGlyph(
        self: Font,
        ch: u32,
    ) bool {
        return c.TTF_FontHasGlyph(
            self.value,
            ch,
        );
    }

    /// Get the pixel image for a UNICODE codepoint.
    ///
    /// ## Function Parameters
    /// * `ch`: The codepoint to check.
    ///
    /// ## Return Value
    /// Returns a struct containing an `surface.Surface` with the glyph and the `ImageType`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getGlyphImage(
        self: Font,
        ch: u32,
    ) !struct { image: surface.Surface, image_type: ImageType } {
        var image_type: c.TTF_ImageType = undefined;
        const surf = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_GetGlyphImage(
            self.value,
            ch,
            &image_type,
        ));
        return .{
            .image = .{ .value = surf },
            .image_type = @enumFromInt(
                image_type,
            ),
        };
    }

    /// Get the pixel image for a character index.
    ///
    /// ## Function Parameters
    /// * `glyph_index`: The index of the glyph to return.
    ///
    /// ## Return Value
    /// Returns a struct containing an `surface.Surface` with the glyph and the `ImageType`.
    ///
    /// ## Remarks
    /// This is useful for text engine implementations, which can call this with
    /// the `glyph_index` in a TTF_CopyOperation
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getGlyphImageForIndex(
        self: Font,
        glyph_index: u32,
    ) !struct { image: surface.Surface, image_type: ImageType } {
        var image_type: c.TTF_ImageType = undefined;
        const surf = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_GetGlyphImageForIndex(
            self.value,
            glyph_index,
            &image_type,
        ));
        return .{
            .image = .{ .value = surf },
            .image_type = @enumFromInt(
                image_type,
            ),
        };
    }

    /// Query the metrics (dimensions,) of a font's glyph for a UNICODE codepoint.
    ///
    /// ## Function Parameters
    /// * `ch`: The codepoint to check.
    ///
    /// ## Return Value
    /// Returns a struct with the glyph metrics.
    ///
    /// ## Remarks
    /// To understand what these metrics mean, here is a useful link:
    /// https://freetype.sourceforge.net/freetype2/docs/tutorial/step2.html
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getGlyphMetrics(
        self: Font,
        ch: u32,
    ) !struct { minx: c_int, maxx: c_int, miny: c_int, maxy: c_int, advance: c_int } {
        var minx: c_int = undefined;
        var maxx: c_int = undefined;
        var miny: c_int = undefined;
        var maxy: c_int = undefined;
        var advance: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetGlyphMetrics(
            self.value,
            ch,
            &minx,
            &maxx,
            &miny,
            &maxy,
            &advance,
        ));
        return .{ .minx = minx, .maxx = maxx, .miny = miny, .maxy = maxy, .advance = advance };
    }

    /// Query the kerning size between the glyphs of two UNICODE codepoints.
    ///
    /// ## Function Parameters
    /// * `previous_ch`: The previous codepoint.
    /// * `ch`: The current codepoint.
    ///
    /// ## Return Value
    /// Returns the kerning size between the two glyphs, in pixels.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getGlyphKerning(
        self: Font,
        previous_ch: u32,
        ch: u32,
    ) !c_int {
        var kerning: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetGlyphKerning(
            self.value,
            previous_ch,
            ch,
            &kerning,
        ));
        return kerning;
    }

    /// Calculate the dimensions of a rendered string of UTF-8 text.
    ///
    /// ## Function Parameters
    /// * `text`: Text to calculate, in UTF-8 encoding.
    ///
    /// ## Return Value
    /// Returns a struct with the width and height, in pixels, of the space that the
    /// specified string will take to fully render.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getStringSize(
        self: Font,
        text: []const u8,
    ) !struct { w: c_int, h: c_int } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetStringSize(
            self.value,
            text.ptr,
            text.len,
            &w,
            &h,
        ));
        return .{ .w = w, .h = h };
    }

    /// Calculate the dimensions of a rendered string of UTF-8 text.
    ///
    /// ## Function Parameters
    /// * `text`: Text to calculate, in UTF-8 encoding.
    /// * `wrap_width`: The maximum width or 0 to wrap on newline characters.
    ///
    /// ## Return Value
    /// Returns a struct with the width and height, in pixels, of the space that the
    /// specified string will take to fully render.
    ///
    /// ## Remarks
    /// Text is wrapped to multiple lines on line endings and on word boundaries if
    /// it extends beyond `wrap_width` in pixels.
    ///
    /// If `wrap_width` is 0, this function will only wrap on newline characters.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getStringSizeWrapped(
        self: Font,
        text: []const u8,
        wrap_width: c_int,
    ) !struct { w: c_int, h: c_int } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetStringSizeWrapped(
            self.value,
            text.ptr,
            text.len,
            wrap_width,
            &w,
            &h,
        ));
        return .{ .w = w, .h = h };
    }

    /// Calculate how much of a UTF-8 string will fit in a given width.
    ///
    /// ## Function Parameters
    /// * `text`: Text to calculate, in UTF-8 encoding.
    /// * `max_width`: Maximum width, in pixels, available for the string, or 0 for unbounded width.
    ///
    /// ## Return Value
    /// Returns a struct with the width, in pixels, of the string that will fit, and the length, in bytes, of the string that will fit.
    ///
    /// ## Remarks
    /// This reports the number of characters that can be rendered before reaching `max_width`.
    /// This does not need to render the string to do this calculation.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn measureString(
        self: Font,
        text: []const u8,
        max_width: c_int,
    ) !struct { measured_width: c_int, measured_length: usize } {
        var measured_width: c_int = undefined;
        var measured_length: usize = undefined;
        try errors.wrapCallBool(c.TTF_MeasureString(
            self.value,
            text.ptr,
            text.len,
            max_width,
            &measured_width,
            &measured_length,
        ));
        return .{ .measured_width = measured_width, .measured_length = measured_length };
    }

    /// Render UTF-8 text at fast quality to a new 8-bit surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    ///
    /// ## Return Value
    /// Returns a new 8-bit, palettized surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 8-bit, palettized surface. The surface's
    /// 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
    /// will be set to the text color.
    ///
    /// This will not word-wrap the string; you'll get a surface with a single line
    /// of text, as long as the string requires. You can use
    /// `renderTextSolidWrapped()` instead if you need to wrap the output to
    /// multiple lines.
    ///
    /// This will not wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextShaded`,
    /// `renderTextBlended`, and `renderTextLcd`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextSolid(
        self: Font,
        text: []const u8,
        fg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_Solid(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
            )),
        };
    }

    /// Render word-wrapped UTF-8 text at fast quality to a new 8-bit surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    /// * `wrap_length`: The maximum width of the text surface or 0 to wrap on newline characters.
    ///
    /// ## Return Value
    /// Returns a new 8-bit, palettized surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 8-bit, palettized surface. The surface's
    /// 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
    /// will be set to the text color.
    ///
    /// Text is wrapped to multiple lines on line endings and on word boundaries if
    /// it extends beyond `wrap_length` in pixels.
    ///
    /// If `wrap_length` is 0, this function will only wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextShadedWrapped`,
    /// `renderTextBlendedWrapped`, and `renderTextLcdWrapped`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextSolidWrapped(
        self: Font,
        text: []const u8,
        fg: Color,
        wrap_length: c_int,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_Solid_Wrapped(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
                wrap_length,
            )),
        };
    }

    /// Render a single 32-bit glyph at fast quality to a new 8-bit surface.
    ///
    /// ## Function Parameters
    /// * `ch`: The character to render.
    /// * `fg`: The foreground color for the text.
    ///
    /// ## Return Value
    /// Returns a new 8-bit, palettized surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 8-bit, palettized surface. The surface's
    /// 0 pixel will be the colorkey, giving a transparent background. The 1 pixel
    /// will be set to the text color.
    ///
    /// The glyph is rendered without any padding or centering in the X direction,
    /// and aligned normally in the Y direction.
    ///
    /// You can render at other quality levels with `renderGlyphShaded`,
    /// `renderGlyphBlended`, and `renderGlyphLcd`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderGlyphSolid(
        self: Font,
        ch: u32,
        fg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderGlyph_Solid(
                self.value,
                ch,
                fg.toSdl(),
            )),
        };
    }

    /// Render UTF-8 text at high quality to a new 8-bit surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    /// * `bg`: The background color for the text.
    ///
    /// ## Return Value
    /// Returns a new 8-bit, palettized surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 8-bit, palettized surface. The surface's
    /// 0 pixel will be the specified background color, while other pixels have
    /// varying degrees of the foreground color.
    ///
    /// This will not word-wrap the string; you'll get a surface with a single line
    /// of text, as long as the string requires. You can use
    /// `renderTextShadedWrapped()` instead if you need to wrap the output to
    /// multiple lines.
    ///
    /// This will not wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextSolid`,
    /// `renderTextBlended`, and `renderTextLcd`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextShaded(
        self: Font,
        text: []const u8,
        fg: Color,
        bg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_Shaded(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
                bg.toSdl(),
            )),
        };
    }

    /// Render word-wrapped UTF-8 text at high quality to a new 8-bit surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    /// * `bg`: The background color for the text.
    /// * `wrap_width`: The maximum width of the text surface or 0 to wrap on newline characters.
    ///
    /// ## Return Value
    /// Returns a new 8-bit, palettized surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 8-bit, palettized surface. The surface's
    /// 0 pixel will be the specified background color, while other pixels have
    /// varying degrees of the foreground color.
    ///
    /// Text is wrapped to multiple lines on line endings and on word boundaries if
    /// it extends beyond `wrap_width` in pixels.
    ///
    /// If `wrap_width` is 0, this function will only wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextSolidWrapped`,
    /// `renderTextBlendedWrapped`, and `renderTextLcdWrapped`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextShadedWrapped(
        self: Font,
        text: []const u8,
        fg: Color,
        bg: Color,
        wrap_width: c_int,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_Shaded_Wrapped(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
                bg.toSdl(),
                wrap_width,
            )),
        };
    }

    /// Render a single UNICODE codepoint at high quality to a new 8-bit surface.
    ///
    /// ## Function Parameters
    /// * `ch`: The codepoint to render.
    /// * `fg`: The foreground color for the text.
    /// * `bg`: The background color for the text.
    ///
    /// ## Return Value
    /// Returns a new 8-bit, palettized surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 8-bit, palettized surface. The surface's
    /// 0 pixel will be the specified background color, while other pixels have
    /// varying degrees of the foreground color.
    ///
    /// The glyph is rendered without any padding or centering in the X direction,
    /// and aligned normally in the Y direction.
    ///
    /// You can render at other quality levels with `renderGlyphSolid`,
    /// `renderGlyphBlended`, and `renderGlyphLcd`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderGlyphShaded(
        self: Font,
        ch: u32,
        fg: Color,
        bg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderGlyph_Shaded(
                self.value,
                ch,
                fg.toSdl(),
                bg.toSdl(),
            )),
        };
    }

    /// Render UTF-8 text at high quality to a new ARGB surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    ///
    /// ## Return Value
    /// Returns a new 32-bit, ARGB surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 32-bit, ARGB surface, using alpha
    /// blending to dither the font with the given color.
    ///
    /// This will not word-wrap the string; you'll get a surface with a single line
    /// of text, as long as the string requires. You can use
    /// `renderTextBlendedWrapped()` instead if you need to wrap the output to
    /// multiple lines.
    ///
    /// This will not wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextSolid`,
    /// `renderTextShaded`, and `renderTextLcd`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextBlended(
        self: Font,
        text: []const u8,
        fg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_Blended(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
            )),
        };
    }

    /// Render word-wrapped UTF-8 text at high quality to a new ARGB surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    /// * `wrap_width`: The maximum width of the text surface or 0 to wrap on newline characters.
    ///
    /// ## Return Value
    /// Returns a new 32-bit, ARGB surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 32-bit, ARGB surface, using alpha
    /// blending to dither the font with the given color.
    ///
    /// Text is wrapped to multiple lines on line endings and on word boundaries if
    /// it extends beyond `wrap_width` in pixels.
    ///
    /// If `wrap_width` is 0, this function will only wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextSolidWrapped`,
    /// `renderTextShadedWrapped`, and `renderTextLcdWrapped`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextBlendedWrapped(
        self: Font,
        text: []const u8,
        fg: Color,
        wrap_width: c_int,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_Blended_Wrapped(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
                wrap_width,
            )),
        };
    }

    /// Render a single UNICODE codepoint at high quality to a new ARGB surface.
    ///
    /// ## Function Parameters
    /// * `ch`: The codepoint to render.
    /// * `fg`: The foreground color for the text.
    ///
    /// ## Return Value
    /// Returns a new 32-bit, ARGB surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 32-bit, ARGB surface, using alpha
    /// blending to dither the font with the given color.
    ///
    /// The glyph is rendered without any padding or centering in the X direction,
    /// and aligned normally in the Y direction.
    ///
    /// You can render at other quality levels with `renderGlyphSolid`,
    /// `renderGlyphShaded`, and `renderGlyphLcd`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderGlyphBlended(
        self: Font,
        ch: u32,
        fg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderGlyph_Blended(
                self.value,
                ch,
                fg.toSdl(),
            )),
        };
    }

    /// Render UTF-8 text at LCD subpixel quality to a new ARGB surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    /// * `bg`: The background color for the text.
    ///
    /// ## Return Value
    /// Returns a new 32-bit, ARGB surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 32-bit, ARGB surface, and render
    /// alpha-blended text using FreeType's LCD subpixel rendering.
    ///
    /// This will not word-wrap the string; you'll get a surface with a single line
    /// of text, as long as the string requires. You can use
    /// `renderTextLcdWrapped()` instead if you need to wrap the output to
    /// multiple lines.
    ///
    /// This will not wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextSolid`,
    /// `renderTextShaded`, and `renderTextBlended`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextLcd(
        self: Font,
        text: []const u8,
        fg: Color,
        bg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_LCD(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
                bg.toSdl(),
            )),
        };
    }

    /// Render word-wrapped UTF-8 text at LCD subpixel quality to a new ARGB surface.
    ///
    /// ## Function Parameters
    /// * `text`: Text to render, in UTF-8 encoding.
    /// * `fg`: The foreground color for the text.
    /// * `bg`: The background color for the text.
    /// * `wrap_width`: The maximum width of the text surface or 0 to wrap on newline characters.
    ///
    /// ## Return Value
    /// Returns a new 32-bit, ARGB surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 32-bit, ARGB surface, and render
    /// alpha-blended text using FreeType's LCD subpixel rendering.
    ///
    /// Text is wrapped to multiple lines on line endings and on word boundaries if
    /// it extends beyond `wrap_width` in pixels.
    ///
    /// If `wrap_width` is 0, this function will only wrap on newline characters.
    ///
    /// You can render at other quality levels with `renderTextSolidWrapped`,
    /// `renderTextShadedWrapped`, and `renderTextBlendedWrapped`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderTextLcdWrapped(
        self: Font,
        text: []const u8,
        fg: Color,
        bg: Color,
        wrap_width: c_int,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderText_LCD_Wrapped(
                self.value,
                text.ptr,
                text.len,
                fg.toSdl(),
                bg.toSdl(),
                wrap_width,
            )),
        };
    }

    /// Render a single UNICODE codepoint at LCD subpixel quality to a new ARGB surface.
    ///
    /// ## Function Parameters
    /// * `ch`: The codepoint to render.
    /// * `fg`: The foreground color for the text.
    /// * `bg`: The background color for the text.
    ///
    /// ## Return Value
    /// Returns a new 32-bit, ARGB surface.
    ///
    /// ## Remarks
    /// This function will allocate a new 32-bit, ARGB surface, and render
    /// alpha-blended text using FreeType's LCD subpixel rendering.
    ///
    /// The glyph is rendered without any padding or centering in the X direction,
    /// and aligned normally in the Y direction.
    ///
    /// You can render at other quality levels with `renderGlyphSolid`,
    /// `renderGlyphShaded`, and `renderGlyphBlended`.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn renderGlyphLcd(
        self: Font,
        ch: u32,
        fg: Color,
        bg: Color,
    ) !surface.Surface {
        return .{
            .value = try errors.wrapCallNull(*c.SDL_Surface, c.TTF_RenderGlyph_LCD(
                self.value,
                ch,
                fg.toSdl(),
                bg.toSdl(),
            )),
        };
    }
};

/// A text engine used to create text objects.
///
/// ## Remarks
/// This is a public interface that can be used by applications and libraries
/// to perform customize rendering with text objects.
///
/// There are three text engines provided with the library:
///
/// * Drawing to an `surface.Surface`, created with `SurfaceTextEngine.init()`
/// * Drawing with an `renderer.Renderer`, created with `RendererTextEngine.init()`
/// * Drawing with the SDL GPU API, created with `GpuTextEngine.init()`
///
/// ## Version
/// This struct is available since SDL_ttf 3.0.0.
pub const TextEngine = struct {
    value: *c.TTF_TextEngine,
};

/// A text engine for drawing text on SDL surfaces.
pub const SurfaceTextEngine = struct {
    value: *c.TTF_TextEngine,

    /// Create a text engine for drawing text on SDL surfaces.
    ///
    /// ## Return Value
    /// Returns a `SurfaceTextEngine` object.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn init() !SurfaceTextEngine {
        return .{ .value = try errors.wrapCallNull(
            *c.TTF_TextEngine,
            c.TTF_CreateSurfaceTextEngine(),
        ) };
    }

    /// Destroy a text engine created for drawing text on SDL surfaces.
    ///
    /// ## Remarks
    /// All text created by this engine should be destroyed before calling this function.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the engine.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn deinit(
        self: SurfaceTextEngine,
    ) void {
        c.TTF_DestroySurfaceTextEngine(
            self.value,
        );
    }
};

/// A text engine for drawing text on an SDL renderer.
pub const RendererTextEngine = struct {
    value: *c.TTF_TextEngine,

    /// Create a text engine for drawing text on an SDL renderer.
    ///
    /// ## Function Parameters
    /// * `renderer`: The renderer to use for creating textures and drawing text.
    ///
    /// ## Return Value
    /// Returns a `RendererTextEngine` object.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the renderer.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn init(
        r: render.Renderer,
    ) !RendererTextEngine {
        return .{ .value = try errors.wrapCallNull(*c.TTF_TextEngine, c.TTF_CreateRendererTextEngine(
            r.value,
        )) };
    }

    /// Properties to use for renderer text engine creation.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    pub const CreateProperties = struct {
        /// The renderer to use for creating textures and drawing text.
        renderer: render.Renderer,
        /// The size of the texture atlas.
        atlas_texture_size: ?i64 = null,

        /// Convert to an SDL properties group.
        ///
        /// ## Remarks
        /// The returned group must be freed with `properties.Group.deinit()`.
        pub fn toProperties(
            self: CreateProperties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            try ret.set(
                c.TTF_PROP_RENDERER_TEXT_ENGINE_RENDERER,
                .{ .pointer = self.renderer.value },
            );
            if (self.atlas_texture_size) |val| try ret.set(
                c.TTF_PROP_RENDERER_TEXT_ENGINE_ATLAS_TEXTURE_SIZE,
                .{ .number = val },
            );
            return ret;
        }
    };

    /// Create a text engine for drawing text on an SDL renderer, with the specified properties.
    ///
    /// ## Function Parameters
    /// * `props`: The properties to use.
    ///
    /// ## Return Value
    /// Returns a `RendererTextEngine` object.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the renderer.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn initWithProperties(
        props: CreateProperties,
    ) !RendererTextEngine {
        const group = try props.toProperties();
        defer group.deinit();
        return .{ .value = try errors.wrapCallNull(*c.TTF_TextEngine, c.TTF_CreateRendererTextEngineWithProperties(
            group.value,
        )) };
    }

    /// Destroy a text engine created for drawing text on an SDL renderer.
    ///
    /// ## Remarks
    /// All text created by this engine should be destroyed before calling this function.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the engine.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn deinit(
        self: RendererTextEngine,
    ) void {
        c.TTF_DestroyRendererTextEngine(
            self.value,
        );
    }
};

/// A text engine for drawing text with the SDL GPU API.
pub const GpuTextEngine = struct {
    value: *c.TTF_TextEngine,

    /// Create a text engine for drawing text with the SDL GPU API.
    ///
    /// ## Function Parameters
    /// * `device`: The `gpu.Device` to use for creating textures and drawing text.
    ///
    /// ## Return Value
    /// Returns a `GpuTextEngine` object.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the device.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn init(
        device: gpu.Device,
    ) !GpuTextEngine {
        return .{ .value = try errors.wrapCallNull(*c.TTF_TextEngine, c.TTF_CreateGPUTextEngine(
            device.value,
        )) };
    }

    /// Properties to use for GPU text engine creation.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    pub const CreateProperties = struct {
        /// The `gpu.Device` to use for creating textures and drawing text.
        device: gpu.Device,
        /// The size of the texture atlas.
        atlas_texture_size: ?i64 = null,

        /// Convert to an SDL properties group.
        ///
        /// ## Remarks
        /// The returned group must be freed with `properties.Group.deinit()`.
        pub fn toProperties(
            self: CreateProperties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            try ret.set(
                c.TTF_PROP_GPU_TEXT_ENGINE_DEVICE,
                .{ .pointer = self.device.value },
            );
            if (self.atlas_texture_size) |val| try ret.set(
                c.TTF_PROP_GPU_TEXT_ENGINE_ATLAS_TEXTURE_SIZE,
                .{ .number = val },
            );
            return ret;
        }
    };

    /// Create a text engine for drawing text with the SDL GPU API, with the specified properties.
    ///
    /// ## Function Parameters
    /// * `props`: The properties to use.
    ///
    /// ## Return Value
    /// Returns a `GpuTextEngine` object.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the device.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn initWithProperties(
        props: CreateProperties,
    ) !GpuTextEngine {
        const group = try props.toProperties();
        defer group.deinit();
        return .{ .value = try errors.wrapCallNull(*c.TTF_TextEngine, c.TTF_CreateGPUTextEngineWithProperties(
            group.value,
        )) };
    }

    /// Destroy a text engine created for drawing text with the SDL GPU API.
    ///
    /// ## Remarks
    /// All text created by this engine should be destroyed before calling this function.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the engine.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn deinit(
        self: GpuTextEngine,
    ) void {
        c.TTF_DestroyGPUTextEngine(
            self.value,
        );
    }

    /// Sets the winding order of the vertices returned by `getGpuTextDrawData` for a particular GPU text engine.
    ///
    /// ## Function Parameters
    /// * `winding`: The new winding order option.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the engine.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setWinding(
        self: GpuTextEngine,
        winding: GpuTextEngineWinding,
    ) void {
        c.TTF_SetGPUTextEngineWinding(self.value, @intFromEnum(
            winding,
        ));
    }

    /// Get the winding order of the vertices returned by `getGpuTextDrawData` for a particular GPU text engine.
    ///
    /// ## Return Value
    /// Returns the winding order used by the GPU text engine.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the engine.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getWinding(
        self: GpuTextEngine,
    ) !GpuTextEngineWinding {
        const winding = try errors.wrapCall(
            c.TTF_GPUTextEngineWinding,
            c.TTF_GetGPUTextEngineWinding(
                self.value,
            ),
            c.TTF_GPU_TEXTENGINE_WINDING_INVALID,
        );
        return @enumFromInt(
            winding,
        );
    }
};

/// Draw text to an SDL surface.
///
/// ## Function Parameters
/// * `text`: The text to draw.
/// * `x`: The x coordinate in pixels, positive from the left edge towards the right.
/// * `y`: The y coordinate in pixels, positive from the top edge towards the bottom.
/// * `surface`: The surface to draw on.
///
/// ## Remarks
/// `text` must have been created using a `SurfaceTextEngine`.
///
/// ## Thread Safety
/// This function should be called on the thread that created the text.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn drawSurfaceText(
    text: Text,
    x: c_int,
    y: c_int,
    surf: surface.Surface,
) !void {
    return errors.wrapCallBool(c.TTF_DrawSurfaceText(
        text.value,
        x,
        y,
        surf.value,
    ));
}

/// Draw text to an SDL renderer.
///
/// ## Function Parameters
/// * `text`: The text to draw.
/// * `x`: The x coordinate in pixels, positive from the left edge towards the right.
/// * `y`: The y coordinate in pixels, positive from the top edge towards the bottom.
///
/// ## Remarks
/// `text` must have been created using a `RendererTextEngine`, and will draw using the renderer passed to that function.
///
/// ## Thread Safety
/// This function should be called on the thread that created the text.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn drawRendererText(
    text: Text,
    x: f32,
    y: f32,
) !void {
    return errors.wrapCallBool(c.TTF_DrawRendererText(
        text.value,
        x,
        y,
    ));
}

/// Draw sequence returned by `getGpuTextDrawData`
///
/// ## Version
/// This struct is available since SDL_ttf 3.0.0.
pub const GpuAtlasDrawSequence = struct {
    /// Texture atlas that stores the glyphs
    atlas_texture: gpu.Texture,
    /// An array of vertex positions
    xy: []const c.SDL_FPoint,
    /// An array of normalized texture coordinates for each vertex
    uv: []const c.SDL_FPoint,
    /// An array of indices into the 'vertices' arrays
    indices: []const c_int,
    /// The image type of this draw sequence
    image_type: ImageType,

    pub fn fromSdl(
        sdl_seq: *const c.TTF_GPUAtlasDrawSequence,
    ) GpuAtlasDrawSequence {
        return .{
            .atlas_texture = .{ .value = sdl_seq.atlas_texture },
            .xy = sdl_seq.xy[0..@intCast(
                sdl_seq.num_vertices,
            )],
            .uv = sdl_seq.uv[0..@intCast(
                sdl_seq.num_vertices,
            )],
            .indices = sdl_seq.indices[0..@intCast(
                sdl_seq.num_indices,
            )],
            .image_type = @enumFromInt(
                sdl_seq.image_type,
            ),
        };
    }
};

/// Get the geometry data needed for drawing the text.
///
/// ## Function Parameters
/// * `text`: The text to draw.
///
/// ## Return Value
/// Returns a `null` terminated linked list of `c.TTF_GPUAtlasDrawSequence` objects.
/// You can use `GpuAtlasDrawSequence.fromSdl` to convert each node to a more idiomatic Zig struct.
///
/// ## Remarks
/// `text` must have been created using a `GpuTextEngine`.
///
/// The positive X-axis is taken towards the right and the positive Y-axis is
/// taken upwards for both the vertex and the texture coordinates, i.e, it
/// follows the same convention used by the SDL_GPU API. If you want to use a
/// different coordinate system you will need to transform the vertices
/// yourself.
///
/// If the text looks blocky use linear filtering.
///
/// ## Thread Safety
/// This function should be called on the thread that created the text.
///
/// ## Version
/// This function is available since SDL_ttf 3.0.0.
pub fn getGpuTextDrawData(
    text: Text,
) ?*c.TTF_GPUAtlasDrawSequence {
    return c.TTF_GetGPUTextDrawData(
        text.value,
    );
}

/// Text created with `Text.init()`
///
/// ## Version
/// This struct is available since SDL_ttf 3.0.0.
pub const Text = struct {
    value: *c.TTF_Text,

    /// A copy of the UTF-8 string that this text object represents, useful for layout, debugging and retrieving substring text. This is updated when the text object is modified and will be freed automatically when the object is destroyed.
    pub fn getText(
        self: Text,
    ) [:0]const u8 {
        return std.mem.sliceTo(
            self.value.text,
            0,
        );
    }

    /// The number of lines in the text, 0 if it's empty
    pub fn getNumLines(
        self: Text,
    ) c_int {
        return self.value.num_lines;
    }

    /// Create a text object from UTF-8 text and a text engine.
    ///
    /// ## Function Parameters
    /// * `engine`: The text engine to use when creating the text object, may be `null`.
    /// * `font`: The font to render with.
    /// * `text`: The text to use, in UTF-8 encoding.
    ///
    /// ## Return Value
    /// Returns a `Text` object.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the font and text engine.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn init(
        engine: ?TextEngine,
        font: Font,
        text: []const u8,
    ) !Text {
        return .{
            .value = try errors.wrapCallNull(*c.TTF_Text, c.TTF_CreateText(
                if (engine) |e| e.value else null,
                font.value,
                text.ptr,
                text.len,
            )),
        };
    }

    /// Destroy a text object created by a text engine.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn deinit(
        self: Text,
    ) void {
        c.TTF_DestroyText(
            self.value,
        );
    }

    /// Get the properties associated with a text object.
    ///
    /// ## Return Value
    /// Returns a valid property group.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getProperties(
        self: Text,
    ) !properties.Group {
        return .{
            .value = try errors.wrapCall(
                c.SDL_PropertiesID,
                c.TTF_GetTextProperties(
                    self.value,
                ),
                0,
            ),
        };
    }

    /// Set the text engine used by a text object.
    ///
    /// ## Function Parameters
    /// * `engine`: The text engine to use for drawing.
    ///
    /// ## Remarks
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setEngine(
        self: Text,
        engine: TextEngine,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextEngine(
            self.value,
            engine.value,
        ));
    }

    /// Get the text engine used by a text object.
    ///
    /// ## Return Value
    /// Returns the `TextEngine` used by the text.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getEngine(
        self: Text,
    ) !TextEngine {
        return .{
            .value = try errors.wrapCallNull(*c.TTF_TextEngine, c.TTF_GetTextEngine(
                self.value,
            )),
        };
    }

    /// Set the font used by a text object.
    ///
    /// ## Function Parameters
    /// * `font`: The font to use, may be `null`.
    ///
    /// ## Remarks
    /// When a text object has a font, any changes to the font will automatically
    /// regenerate the text. If you set the font to `null`, the text will continue to
    /// render but changes to the font will no longer affect the text.
    ///
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setFont(
        self: Text,
        font: ?Font,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextFont(
            self.value,
            if (font) |f| f.value else null,
        ));
    }

    /// Get the font used by a text object.
    ///
    /// ## Return Value
    /// Returns the `Font` used by the text.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getFont(
        self: Text,
    ) !Font {
        return .{
            .value = try errors.wrapCallNull(*c.TTF_Font, c.TTF_GetTextFont(
                self.value,
            )),
        };
    }

    /// Set the direction to be used for text shaping a text object.
    ///
    /// ## Function Parameters
    /// * `direction`: The new direction for text to flow.
    ///
    /// ## Remarks
    /// This function only supports left-to-right text shaping if SDL_ttf was not
    /// built with HarfBuzz support.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setDirection(
        self: Text,
        direction: Direction,
    ) !void {
        return errors.wrapCallBool(
            c.TTF_SetTextDirection(self.value, @intFromEnum(
                direction,
            )),
        );
    }

    /// Get the direction to be used for text shaping a text object.
    ///
    /// ## Return Value
    /// Returns the direction to be used for text shaping.
    ///
    /// ## Remarks
    /// This defaults to the direction of the font used by the text object.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getDirection(
        self: Text,
    ) Direction {
        return @enumFromInt(c.TTF_GetTextDirection(
            self.value,
        ));
    }

    /// Set the script to be used for text shaping a text object.
    ///
    /// ## Function Parameters
    /// * `script`: An ISO 15924 code.
    ///
    /// ## Remarks
    /// This returns `error.SdlError` if SDL_ttf isn't built with HarfBuzz support.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setScript(
        self: Text,
        script: u32,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextScript(
            self.value,
            script,
        ));
    }

    /// Get the script used for text shaping a text object.
    ///
    /// ## Return Value
    /// Returns an ISO 15924 code or 0 if a script hasn't been set on either the text object or the font.
    ///
    /// ## Remarks
    /// This defaults to the script of the font used by the text object.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getScript(
        self: Text,
    ) u32 {
        return c.TTF_GetTextScript(
            self.value,
        );
    }

    /// Set the color of a text object.
    ///
    /// ## Function Parameters
    /// * `r`: The red color value in the range of 0-255.
    /// * `g`: The green color value in the range of 0-255.
    /// * `b`: The blue color value in the range of 0-255.
    /// * `a`: The alpha value in the range of 0-255.
    ///
    /// ## Remarks
    /// The default text color is white (255, 255, 255, 255,).
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setColor(
        self: Text,
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextColor(
            self.value,
            r,
            g,
            b,
            a,
        ));
    }

    /// Set the color of a text object.
    ///
    /// ## Function Parameters
    /// * `r`: The red color value, normally in the range of 0-1.
    /// * `g`: The green color value, normally in the range of 0-1.
    /// * `b`: The blue color value, normally in the range of 0-1.
    /// * `a`: The alpha value in the range of 0-1.
    ///
    /// ## Remarks
    /// The default text color is white (1.0f, 1.0f, 1.0f, 1.0f,).
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setColorFloat(
        self: Text,
        r: f32,
        g: f32,
        b: f32,
        a: f32,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextColorFloat(
            self.value,
            r,
            g,
            b,
            a,
        ));
    }

    /// Get the color of a text object.
    ///
    /// ## Return Value
    /// Returns a struct with the red, green, blue, and alpha color values in the range of 0-255.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getColor(
        self: Text,
    ) !struct { r: u8, g: u8, b: u8, a: u8 } {
        var r: u8 = undefined;
        var g: u8 = undefined;
        var b: u8 = undefined;
        var a: u8 = undefined;
        try errors.wrapCallBool(c.TTF_GetTextColor(
            self.value,
            &r,
            &g,
            &b,
            &a,
        ));
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Get the color of a text object.
    ///
    /// ## Return Value
    /// Returns a struct with the red, green, blue, and alpha color values, normally in the range of 0-1.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getColorFloat(
        self: Text,
    ) !struct { r: f32, g: f32, b: f32, a: f32 } {
        var r: f32 = undefined;
        var g: f32 = undefined;
        var b: f32 = undefined;
        var a: f32 = undefined;
        try errors.wrapCallBool(c.TTF_GetTextColorFloat(
            self.value,
            &r,
            &g,
            &b,
            &a,
        ));
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Set the position of a text object.
    ///
    /// ## Function Parameters
    /// * `x`: The x offset of the upper left corner of this text in pixels.
    /// * `y`: The y offset of the upper left corner of this text in pixels.
    ///
    /// ## Remarks
    /// This can be used to position multiple text objects within a single wrapping text area.
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setPosition(
        self: Text,
        x: c_int,
        y: c_int,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextPosition(
            self.value,
            x,
            y,
        ));
    }

    /// Get the position of a text object.
    ///
    /// ## Return Value
    /// Returns a struct with the x and y offset of the upper left corner of this text in pixels.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getPosition(
        self: Text,
    ) !struct { x: c_int, y: c_int } {
        var x: c_int = undefined;
        var y: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetTextPosition(
            self.value,
            &x,
            &y,
        ));
        return .{ .x = x, .y = y };
    }

    /// Set whether wrapping is enabled on a text object.
    ///
    /// ## Function Parameters
    /// * `wrap_width`: The maximum width in pixels, 0 to wrap on newline characters.
    ///
    /// ## Remarks
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setWrapWidth(
        self: Text,
        wrap_width: c_int,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextWrapWidth(
            self.value,
            wrap_width,
        ));
    }

    /// Get whether wrapping is enabled on a text object.
    ///
    /// ## Return Value
    /// Returns the maximum width in pixels or 0 if the text is being wrapped on newline characters.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getWrapWidth(
        self: Text,
    ) !c_int {
        var wrap_width: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetTextWrapWidth(
            self.value,
            &wrap_width,
        ));
        return wrap_width;
    }

    /// Set whether whitespace should be visible when wrapping a text object.
    ///
    /// ## Function Parameters
    /// * `visible`: `true` to show whitespace when wrapping text, `false` to hide it.
    ///
    /// ## Remarks
    /// If the whitespace is visible, it will take up space for purposes of
    /// alignment and wrapping. This is good for editing, but looks better when
    /// centered or aligned if whitespace around line wrapping is hidden. This
    /// defaults `false`.
    ///
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setWrapWhitespaceVisible(
        self: Text,
        visible: bool,
    ) !void {
        return errors.wrapCallBool(c.TTF_SetTextWrapWhitespaceVisible(
            self.value,
            visible,
        ));
    }

    /// Return whether whitespace is shown when wrapping a text object.
    ///
    /// ## Return Value
    /// Returns `true` if whitespace is shown when wrapping text, or `false` otherwise.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn wrapWhitespaceVisible(
        self: Text,
    ) bool {
        return c.TTF_TextWrapWhitespaceVisible(
            self.value,
        );
    }

    /// Set the UTF-8 text used by a text object.
    ///
    /// ## Function Parameters
    /// * `string`: The UTF-8 text to use, may be `null`.
    ///
    /// ## Remarks
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn setString(
        self: Text,
        string: ?[]const u8,
    ) !void {
        if (string) |s| {
            return errors.wrapCallBool(c.TTF_SetTextString(
                self.value,
                s.ptr,
                s.len,
            ));
        } else {
            return errors.wrapCallBool(c.TTF_SetTextString(
                self.value,
                null,
                0,
            ));
        }
    }

    /// Insert UTF-8 text into a text object.
    ///
    /// ## Function Parameters
    /// * `offset`: The offset, in bytes, from the beginning of the string if >= 0, the offset from the end of the string if < 0. Note that this does not do UTF-8 validation, so you should only insert at UTF-8 sequence boundaries.
    /// * `string`: The UTF-8 text to insert.
    ///
    /// ## Remarks
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn insertString(
        self: Text,
        offset: c_int,
        string: []const u8,
    ) !void {
        return errors.wrapCallBool(c.TTF_InsertTextString(
            self.value,
            offset,
            string.ptr,
            string.len,
        ));
    }

    /// Append UTF-8 text to a text object.
    ///
    /// ## Function Parameters
    /// * `string`: The UTF-8 text to insert.
    ///
    /// ## Remarks
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn appendString(
        self: Text,
        string: []const u8,
    ) !void {
        return errors.wrapCallBool(c.TTF_AppendTextString(
            self.value,
            string.ptr,
            string.len,
        ));
    }

    /// Delete UTF-8 text from a text object.
    ///
    /// ## Function Parameters
    /// * `offset`: The offset, in bytes, from the beginning of the string if >= 0, the offset from the end of the string if < 0. Note that this does not do UTF-8 validation, so you should only delete at UTF-8 sequence boundaries.
    /// * `length`: The length of text to delete, in bytes, or -1 for the remainder of the string.
    ///
    /// ## Remarks
    /// This function may cause the internal text representation to be rebuilt.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn deleteString(
        self: Text,
        offset: c_int,
        length: c_int,
    ) !void {
        return errors.wrapCallBool(c.TTF_DeleteTextString(
            self.value,
            offset,
            length,
        ));
    }

    /// Get the size of a text object.
    ///
    /// ## Return Value
    /// Returns a struct with the width and height of the text, in pixels.
    ///
    /// ## Remarks
    /// The size of the text may change when the font or font style and size change.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getSize(
        self: Text,
    ) !struct { w: c_int, h: c_int } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        try errors.wrapCallBool(c.TTF_GetTextSize(
            self.value,
            &w,
            &h,
        ));
        return .{ .w = w, .h = h };
    }

    /// Get the substring of a text object that surrounds a text offset.
    ///
    /// ## Function Parameters
    /// * `offset`: A byte offset into the text string.
    ///
    /// ## Return Value
    /// Returns the substring containing the offset.
    ///
    /// ## Remarks
    /// If `offset` is less than 0, this will return a zero length substring at the
    /// beginning of the text with the `SubStringFlags.text_start` flag set. If
    /// `offset` is greater than or equal to the length of the text string, this
    /// will return a zero length substring at the end of the text with the
    /// `SubStringFlags.text_end` flag set.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getSubString(
        self: Text,
        offset: c_int,
    ) !SubString {
        var substring: c.TTF_SubString = undefined;
        try errors.wrapCallBool(c.TTF_GetTextSubString(
            self.value,
            offset,
            &substring,
        ));
        return SubString.fromSdl(
            substring,
        );
    }

    /// Get the substring of a text object that contains the given line.
    ///
    /// ## Function Parameters
    /// * `line`: A zero-based line index, in the range [0 .. text->num_lines-1].
    ///
    /// ## Return Value
    /// Returns the substring containing the offset.
    ///
    /// ## Remarks
    /// If `line` is less than 0, this will return a zero length substring at the
    /// beginning of the text with the `SubStringFlags.text_start` flag set. If `line`
    /// is greater than or equal to `text->num_lines` this will return a zero
    /// length substring at the end of the text with the `SubStringFlags.text_end`
    /// flag set.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getSubStringForLine(
        self: Text,
        line: c_int,
    ) !SubString {
        var substring: c.TTF_SubString = undefined;
        try errors.wrapCallBool(c.TTF_GetTextSubStringForLine(
            self.value,
            line,
            &substring,
        ));
        return SubString.fromSdl(
            substring,
        );
    }

    /// Get the substrings of a text object that contain a range of text.
    ///
    /// ## Function Parameters
    /// * `offset`: A byte offset into the text string.
    /// * `length`: The length of the range being queried, in bytes, or -1 for the remainder of the string.
    /// * `allocator`: The allocator to use for the returned slice.
    ///
    /// ## Return Value
    /// Returns a slice of substrings. The caller owns the memory and should free it.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getSubStringsForRange(
        self: Text,
        offset: c_int,
        length: c_int,
        allocator: std.mem.Allocator,
    ) ![]SubString {
        var count: c_int = undefined;
        const c_substrings_ptr = try errors.wrapCallNull(**c.TTF_SubString, c.TTF_GetTextSubStringsForRange(
            self.value,
            offset,
            length,
            &count,
        ));
        const c_substrings = c_substrings_ptr[0..@intCast(
            count,
        )];
        defer {
            for (c_substrings) |s| {
                c.SDL_free(
                    s,
                );
            }
            c.SDL_free(
                c_substrings_ptr,
            );
        }

        const result = try allocator.alloc(
            SubString,
            c_substrings.len,
        );
        errdefer allocator.free(
            result,
        );
        for (c_substrings, 0..) |c_sub_ptr, i| {
            result[i] = SubString.fromSdl(
                c_sub_ptr.*,
            );
        }
        return result;
    }

    /// Get the portion of a text string that is closest to a point.
    ///
    /// ## Function Parameters
    /// * `x`: The x coordinate relative to the left side of the text, may be outside the bounds of the text area.
    /// * `y`: The y coordinate relative to the top side of the text, may be outside the bounds of the text area.
    ///
    /// ## Return Value
    /// Returns the closest substring of text to the given point.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getSubStringForPoint(
        self: Text,
        x: c_int,
        y: c_int,
    ) !SubString {
        var substring: c.TTF_SubString = undefined;
        try errors.wrapCallBool(c.TTF_GetTextSubStringForPoint(
            self.value,
            x,
            y,
            &substring,
        ));
        return SubString.fromSdl(
            substring,
        );
    }

    /// Get the previous substring in a text object
    ///
    /// ## Function Parameters
    /// * `substring`: The `SubString` to query.
    ///
    /// ## Return Value
    /// Returns the previous substring.
    ///
    /// ## Remarks
    /// If called at the start of the text, this will return a zero length
    /// substring with the `SubStringFlags.text_start` flag set.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getPreviousSubString(
        self: Text,
        substring: SubString,
    ) !SubString {
        var c_substring = try substring.toSdl();
        var previous: c.TTF_SubString = undefined;
        try errors.wrapCallBool(c.TTF_GetPreviousTextSubString(
            self.value,
            &c_substring,
            &previous,
        ));
        return SubString.fromSdl(
            previous,
        );
    }

    /// Get the next substring in a text object
    ///
    /// ## Function Parameters
    /// * `substring`: The `SubString` to query.
    ///
    /// ## Return Value
    /// Returns the next substring.
    ///
    /// ## Remarks
    /// If called at the end of the text, this will return a zero length substring
    /// with the `SubStringFlags.text_end` flag set.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn getNextSubString(
        self: Text,
        substring: SubString,
    ) !SubString {
        var c_substring = try substring.toSdl();
        var next: c.TTF_SubString = undefined;
        try errors.wrapCallBool(c.TTF_GetNextTextSubString(
            self.value,
            &c_substring,
            &next,
        ));
        return SubString.fromSdl(
            next,
        );
    }

    /// Update the layout of a text object.
    ///
    /// ## Remarks
    /// This is automatically done when the layout is requested or the text is
    /// rendered, but you can call this if you need more control over the timing of
    /// when the layout and text engine representation are updated.
    ///
    /// ## Thread Safety
    /// This function should be called on the thread that created the text.
    ///
    /// ## Version
    /// This function is available since SDL_ttf 3.0.0.
    pub fn update(
        self: Text,
    ) !void {
        return errors.wrapCallBool(c.TTF_UpdateText(
            self.value,
        ));
    }
};

/// The representation of a substring within text.
///
/// ## Version
/// This struct is available since SDL_ttf 3.0.0.
pub const SubString = struct {
    /// The flags for this substring
    flags: SubStringFlags,
    /// The byte offset from the beginning of the text
    offset: usize,
    /// The byte length starting at the offset
    length: usize,
    /// The index of the line that contains this substring
    line_index: c_int,
    /// The internal cluster index, used for quickly iterating
    cluster_index: c_int,
    /// The rectangle, relative to the top left of the text, containing the substring
    rect: rect.Rect,

    pub fn fromSdl(
        sdl_substring: c.TTF_SubString,
    ) SubString {
        std.debug.assert(
            sdl_substring.offset >= 0,
        );
        std.debug.assert(
            sdl_substring.length >= 0,
        );
        return .{
            .flags = SubStringFlags.fromSdl(
                sdl_substring.flags,
            ),
            .offset = @intCast(
                sdl_substring.offset,
            ),
            .length = @intCast(
                sdl_substring.length,
            ),
            .line_index = sdl_substring.line_index,
            .cluster_index = sdl_substring.cluster_index,
            .rect = .{ .value = sdl_substring.rect },
        };
    }

    pub fn toSdl(
        self: SubString,
    ) !c.TTF_SubString {
        const offset = std.math.cast(
            c_int,
            self.offset,
        ) orelse return error.Overflow;
        const length = std.math.cast(
            c_int,
            self.length,
        ) orelse return error.Overflow;
        return .{
            .flags = self.flags.toSdl(),
            .offset = offset,
            .length = length,
            .line_index = self.line_index,
            .cluster_index = self.cluster_index,
            .rect = self.rect.value,
        };
    }
};
