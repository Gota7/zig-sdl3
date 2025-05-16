// This file was generated using `zig build bindings`. Do not manually edit!

const C = @import("c.zig").C;
const std = @import("std");

/// The access pattern allowed for a texture.
pub const TextureAccess = enum(c_uint) {
    /// Changes rarely, not lockable.
    Static = C.SDL_TEXTUREACCESS_STATIC,
    /// Changes frequently, lockable.
    Streaming = C.SDL_TEXTUREACCESS_STREAMING,
    /// Texture can be used as a render target.
    Target = C.SDL_TEXTUREACCESS_TARGET,
};

/// How the logical size is mapped to the output.
pub const LogicalPresentation = enum(c_uint) {
    /// The rendered content is stretched to the output resolution.
    Stretch = C.SDL_LOGICAL_PRESENTATION_STRETCH,
    /// The rendered content is fit to the largest dimension and the other dimension is letterboxed with black bars.
    LetterBox = C.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    /// The rendered content is fit to the smallest dimension and the other dimension extends beyond the output bounds.
    Overscan = C.SDL_LOGICAL_PRESENTATION_OVERSCAN,
    /// The rendered content is scaled up by integer multiples to fit the output resolution.
    IntegerScale = C.SDL_LOGICAL_PRESENTATION_INTEGER_SCALE,
};

/// A structure representing rendering state.
pub const Renderer = struct {
    value: *C.SDL_Renderer,

    /// Get the number of 2D rendering drivers available for the current display.
    pub fn numDrivers() usize {
        const ret = C.SDL_GetNumRenderDrivers();
        return @intCast(ret);
    }

    /// Use this function to get the name of a built in 2D rendering driver.
    pub fn getDriverName(
        index: usize,
    ) ?[:0]const u8 {
        const ret = C.SDL_GetRenderDriver(
            @intCast(index),
        );
        if (ret == null)
            return null;
        return std.mem.span(ret);
    }

    /// Create a window and default renderer.
    pub fn initWithWindow(
        title: [:0]const u8,
        width: usize,
        height: usize,
        window_flags: video.WindowFlags,
    ) !struct { window: video.Window, renderer: Renderer } {
        var window: ?*C.SDL_Window = undefined;
        var renderer: ?*C.SDL_Renderer = undefined;
        const ret = C.SDL_CreateWindowAndRenderer(
            title,
            @intCast(width),
            @intCast(height),
            window_flags.toSdl(),
            &window,
            &renderer,
        );
        if (!ret)
            return error.SdlError;
        return .{ .window = .{ .value = window orelse return error.SdlError }, .renderer = .{ .value = renderer orelse return error.SdlError } };
    }

    /// Create a 2D rendering context for a window.
    pub fn init(
        window: video.Window,
        renderer_name: ?[:0]const u8,
    ) !Renderer {
        const ret = C.SDL_CreateRenderer(
            window.value,
            if (renderer_name) |str_capture| str_capture.ptr else null,
        );
        if (ret == null)
            return error.SdlError;
        return Renderer{ .value = ret.? };
    }

    /// Create a 2D rendering context for a window, with the specified properties.
    pub fn initWithProperties(
        props: properties.Group,
    ) !Renderer {
        const ret = C.SDL_CreateRendererWithProperties(
            props.value,
        );
        if (ret == null)
            return error.SdlError;
        return Renderer{ .value = ret.? };
    }

    /// Create a 2D software rendering context for a surface.
    pub fn initSoftwareRenderer(
        target_surface: surface.Surface,
    ) !Renderer {
        const ret = C.SDL_CreateSoftwareRenderer(
            target_surface.value,
        );
        if (ret == null)
            return error.SdlError;
        return Renderer{ .value = ret.? };
    }

    /// Get the renderer associated with a window.
    pub fn getRenderer(
        window: video.Window,
    ) !Renderer {
        const ret = C.SDL_GetRenderer(
            window.value,
        );
        if (ret == null)
            return error.SdlError;
        return Renderer{ .value = ret.? };
    }

    /// Get the window associated with a renderer.
    pub fn getWindow(
        self: Renderer,
    ) !video.Window {
        const ret = C.SDL_GetRenderWindow(
            self.value,
        );
        if (ret == null)
            return error.SdlError;
        return video.Window{ .value = ret.? };
    }

    /// Get the name of a renderer.
    pub fn getName(
        self: Renderer,
    ) ![:0]const u8 {
        const ret = C.SDL_GetRendererName(
            self.value,
        );
        if (ret == null)
            return error.SdlError;
        return std.mem.span(ret);
    }

    /// Get the properties associated with a renderer.
    pub fn getProperties(
        self: Renderer,
    ) ![]properties.Group {
        const ret = C.SDL_GetRendererProperties(
            self.value,
        );
        if (ret == 0)
            return error.SdlError;
        return properties.Group{ .value = ret };
    }

    /// Get the output size in pixels of a rendering context.
    pub fn getOutputSize(
        self: Renderer,
    ) !struct { width: usize, height: usize } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        const ret = C.SDL_GetRenderOutputSize(
            self.value,
            &w,
            &h,
        );
        if (!ret)
            return error.SdlError;
        return .{ .width = @intCast(w), .height = @intCast(h) };
    }

    /// Get the current output size in pixels of a rendering context.
    pub fn getCurrentOutputSize(
        self: Renderer,
    ) !struct { width: usize, height: usize } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        const ret = C.SDL_GetCurrentRenderOutputSize(
            self.value,
            &w,
            &h,
        );
        if (!ret)
            return error.SdlError;
        return .{ .width = @intCast(w), .height = @intCast(h) };
    }

    /// Create a texture for a rendering context.
    pub fn createTexture(
        self: Renderer,
        format: pixels.Format,
        texture_access: TextureAccess,
        width: usize,
        height: usize,
    ) !Texture {
        const ret = C.SDL_CreateTexture(
            self.value,
            format.value,
            @intFromEnum(texture_access),
            @intCast(width),
            @intCast(height),
        );
        if (ret == null)
            return error.SdlError;
        return Texture{ .value = ret };
    }

    /// Create a texture from an existing surface.
    pub fn createTextureFromSurface(
        self: Renderer,
        surface_to_copy: surface.Surface,
    ) !Texture {
        const ret = C.SDL_CreateTextureFromSurface(
            self.value,
            surface_to_copy.value,
        );
        if (ret == null)
            return error.SdlError;
        return Texture{ .value = ret };
    }

    /// Create a texture for a rendering context with the specified properties.
    pub fn createTextureWithProperties(
        self: Renderer,
        props: properties.Group,
    ) !Texture {
        const ret = C.SDL_CreateTextureWithProperties(
            self.value,
            props.value,
        );
        if (ret == null)
            return error.SdlError;
        return Texture{ .value = ret };
    }

    /// Set a texture as the current rendering target.
    pub fn setTarget(
        self: Renderer,
        target: ?Texture,
    ) !void {
        const ret = C.SDL_SetRenderTarget(
            self.value,
            if (target) |target_val| target_val.value else null,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the current render target.
    pub fn getTarget(
        self: Renderer,
    ) ?Texture {
        const ret = C.SDL_GetRenderTarget(
            self.value,
        );
        if (ret == null)
            return null;
        return Texture{ .value = ret };
    }

    /// Set a device independent resolution and presentation mode for rendering.
    pub fn setLogicalPresentation(
        self: Renderer,
        width: usize,
        height: usize,
        presentation_mode: ?LogicalPresentation,
    ) !void {
        const ret = C.SDL_SetRenderLogicalPresentation(
            self.value,
            @intCast(width),
            @intCast(height),
            if (presentation_mode) |val| @intFromEnum(val) else C.SDL_LOGICAL_PRESENTATION_DISABLED,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get device independent resolution and presentation mode for rendering.
    pub fn getLogicalPresentation(
        self: Renderer,
    ) !struct { width: usize, height: usize, presentation_mode: ?LogicalPresentation } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var presentation_mode: C.SDL_RendererLogicalPresentation = undefined;
        const ret = C.SDL_GetRenderLogicalPresentation(
            self.value,
            &w,
            &h,
            &presentation_mode,
        );
        if (!ret)
            return error.SdlError;
        return .{ .width = @intCast(w), .height = @intCast(h), .presentation_mode = if (presentation_mode == C.SDL_LOGICAL_PRESENTATION_DISABLED) null else @enumFromInt(presentation_mode) };
    }

    /// Get the final presentation rectangle for rendering.
    pub fn getLogicalPresentationRect(
        self: Renderer,
    ) !rect.FRect {
        var presentation_rect: C.SDL_FRect = undefined;
        const ret = C.SDL_GetRenderLogicalPresentationRect(
            self.value,
            &presentation_rect,
        );
        if (!ret)
            return error.SdlError;
        return rect.FRect.fromSdl(presentation_rect);
    }

    /// Get a point in render coordinates when given a point in window coordinates.
    pub fn renderCoordinatesFromWindowCoordinates(
        self: Renderer,
        x: f32,
        y: f32,
    ) !struct { x: f32, y: f32 } {
        var render_x: f32 = undefined;
        var render_y: f32 = undefined;
        const ret = C.SDL_RenderCoordinatesFromWindow(
            self.value,
            @floatCast(x),
            @floatCast(y),
            &render_x,
            &render_y,
        );
        if (!ret)
            return error.SdlError;
        return .{ .x = render_x, .y = render_y };
    }

    /// Get a point in window coordinates when given a point in render coordinates.
    pub fn renderCoordinatesToWindowCoordinates(
        self: Renderer,
        x: f32,
        y: f32,
    ) !struct { x: f32, y: f32 } {
        var window_x: f32 = undefined;
        var window_y: f32 = undefined;
        const ret = C.SDL_RenderCoordinatesToWindow(
            self.value,
            @floatCast(x),
            @floatCast(y),
            &window_x,
            &window_y,
        );
        if (!ret)
            return error.SdlError;
        return .{ .x = window_x, .y = window_y };
    }

    /// Set the drawing area for rendering on the current target.
    pub fn setViewport(
        self: Renderer,
        viewport: ?rect.IRect,
    ) !void {
        const viewport_sdl: ?C.SDL_Rect = if (viewport == null) null else viewport.?.toSdl();
        const ret = C.SDL_SetRenderViewport(
            self.value,
            if (viewport_sdl == null) null else &(viewport_sdl.?),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the drawing area for the current target.
    pub fn getViewport(
        self: Renderer,
    ) !rect.IRect {
        var viewport: C.SDL_Rect = undefined;
        const ret = C.SDL_GetRenderViewport(
            self.value,
            &viewport,
        );
        if (!ret)
            return error.SdlError;
        return rect.IRect.fromSdl(viewport);
    }

    /// Return whether an explicit rectangle was set as the viewport.
    pub fn viewportSet(
        self: Renderer,
    ) bool {
        const ret = C.SDL_RenderViewportSet(
            self.value,
        );
        return ret;
    }

    /// Get the safe area for rendering within the current viewport.
    pub fn getSafeArea(
        self: Renderer,
    ) ?rect.Rect {
        var area: C.SDL_Rect = undefined;
        const ret = C.SDL_GetRenderSafeArea(
            self.value,
            &area,
        );
        if (!ret)
            return error.SdlError;
        return rect.Rect.fromSdl(area);
    }

    /// Set the clip rectangle for rendering on the specified target.
    pub fn setClipRect(
        self: Renderer,
        clipping: ?rect.IRect,
    ) !void {
        const clipping_sdl: ?C.SDL_Rect = if (clipping == null) null else clipping.?.toSdl();
        const ret = C.SDL_SetRenderClipRect(
            self.value,
            if (clipping_sdl == null) null else &(clipping_sdl.?),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the clip rectangle for the current target.
    pub fn getClipRect(
        self: Renderer,
    ) ?rect.Rect {
        var clipping: C.SDL_Rect = undefined;
        const ret = C.SDL_GetRenderClipRect(
            self.value,
            &clipping,
        );
        if (!ret)
            return error.SdlError;
        if (clipping.empty())
            return null;
        return rect.Rect.fromSdl(clipping);
    }

    /// Get whether clipping is enabled on the given renderer.
    pub fn clipEnabled(
        self: Renderer,
    ) bool {
        const ret = C.SDL_RenderClipEnabled(
            self.value,
        );
        return ret;
    }

    /// Set the drawing scale for rendering on the current target.
    pub fn setScale(
        self: Renderer,
        x: f32,
        y: f32,
    ) !void {
        const ret = C.SDL_SetRenderScale(
            self.value,
            @floatCast(x),
            @floatCast(y),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the drawing scale for the current target.
    pub fn getScale(
        self: Renderer,
    ) !struct { x: f32, y: f32 } {
        var x: f32 = undefined;
        var y: f32 = undefined;
        const ret = C.SDL_GetRenderScale(
            self.value,
            &x,
            &y,
        );
        if (!ret)
            return error.SdlError;
        return .{ .x = x, .y = y };
    }

    /// Set the color used for drawing operations (Rect, Line and Clear).
    pub fn setDrawColor(
        self: Renderer,
        color: pixels.Color,
    ) !void {
        const ret = C.SDL_SetRenderDrawColor(
            self.value,
            color.r,
            color.g,
            color.b,
            color.a,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Set the color used for drawing operations (Rect, Line and Clear).
    pub fn setDrawColorFloat(
        self: Renderer,
        color: pixels.FColor,
    ) !void {
        const ret = C.SDL_SetRenderDrawColorFloat(
            self.value,
            color.r,
            color.g,
            color.b,
            color.a,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the color used for drawing operations (Rect, Line and Clear).
    pub fn getDrawColor(
        self: Renderer,
    ) !pixels.Color {
        var r: u8 = undefined;
        var g: u8 = undefined;
        var b: u8 = undefined;
        var a: u8 = undefined;
        const ret = C.SDL_GetRenderDrawColor(
            self.value,
            &r,
            &g,
            &b,
            &a,
        );
        if (!ret)
            return error.SdlError;
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Get the color used for drawing operations (Rect, Line and Clear).
    pub fn getDrawColorFloat(
        self: Renderer,
    ) !pixels.FColor {
        var r: f32 = undefined;
        var g: f32 = undefined;
        var b: f32 = undefined;
        var a: f32 = undefined;
        const ret = C.SDL_GetRenderDrawColorFloat(
            self.value,
            &r,
            &g,
            &b,
            &a,
        );
        if (!ret)
            return error.SdlError;
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Set the color scale used for render operations.
    pub fn setColorScale(
        self: Renderer,
        scale: f32,
    ) !void {
        const ret = C.SDL_SetRenderColorScale(
            self.value,
            @floatCast(scale),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the color scale used for render operations.
    pub fn getColorScale(
        self: Renderer,
    ) !f32 {
        var scale: f32 = undefined;
        const ret = C.SDL_GetRenderColorScale(
            self.value,
            &scale,
        );
        if (!ret)
            return error.SdlError;
        return scale;
    }

    /// Set the blend mode used for drawing operations (Fill and Line).
    pub fn setDrawBlendMode(
        self: Renderer,
        mode: ?blend_mode.Mode,
    ) !void {
        const ret = C.SDL_SetRenderDrawBlendMode(
            self.value,
            if (mode) |mode_val| mode_val.value else C.SDL_BLENDMODE_NONE,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the blend mode used for drawing operations.
    pub fn getDrawBlendMode(
        self: Renderer,
    ) !?blend_mode.Mode {
        var mode: C.SDL_BlendMode = undefined;
        const ret = C.SDL_GetRenderDrawBlendMode(
            self.value,
            &mode,
        );
        if (!ret)
            return error.SdlError;
        if (mode == C.SDL_BLENDMODE_NONE)
            return null;
        return .{ .value = mode };
    }

    /// Clear the current rendering target with the drawing color.
    pub fn clear(
        self: Renderer,
    ) !void {
        const ret = C.SDL_RenderClear(
            self.value,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Draw a point on the current rendering target at subpixel precision.
    pub fn renderPoint(
        self: Renderer,
        p1: rect.FPoint,
    ) !void {
        const ret = C.SDL_RenderPoint(
            self.value,
            p1.x,
            p1.y,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Draw multiple points on the current rendering target at subpixel precision.
    pub fn renderPoints(
        self: Renderer,
        points: []const rect.FPoint,
    ) !void {
        const ret = C.SDL_RenderPoints(
            self.value,
            @ptrCast(points.ptr),
            @intCast(points.len),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Draw a line on the current rendering target at subpixel precision.
    pub fn renderLine(
        self: Renderer,
        p1: rect.FPoint,
        p2: rect.FPoint,
    ) !void {
        const ret = C.SDL_RenderLine(
            self.value,
            p1.x,
            p1.y,
            p2.x,
            p2.y,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Draw a series of connected lines on the current rendering target at subpixel precision.
    pub fn renderLines(
        self: Renderer,
        points: []const rect.FPoint,
    ) !void {
        const ret = C.SDL_RenderLines(
            self.value,
            @ptrCast(points.ptr),
            @intCast(points.len),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Draw a rectangle on the current rendering target at subpixel precision.
    pub fn renderRect(
        self: Renderer,
        dst: ?rect.FRect,
    ) !void {
        const dst_sdl: ?C.SDL_FRect = if (dst == null) null else dst.?.toSdl();
        const ret = C.SDL_RenderRect(
            self.value,
            if (dst_sdl == null) null else &(dst_sdl.?),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Draw some number of rectangles on the current rendering target at subpixel precision.
    pub fn renderRects(
        self: Renderer,
        rects: []const rect.FRect,
    ) !void {
        const ret = C.SDL_RenderRects(
            self.value,
            @ptrCast(rects.ptr),
            @intCast(rects.len),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Fill a rectangle on the current rendering target with the drawing color at subpixel precision.
    pub fn renderFillRect(
        self: Renderer,
        dst: ?rect.FRect,
    ) !void {
        const dst_sdl: ?C.SDL_FRect = if (dst == null) null else dst.?.toSdl();
        const ret = C.SDL_RenderFillRect(
            self.value,
            if (dst_sdl == null) null else &(dst_sdl.?),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Fill some number of rectangles on the current rendering target with the drawing color at subpixel precision.
    pub fn renderFillRects(
        self: Renderer,
        rects: []const rect.FRect,
    ) !void {
        const ret = C.SDL_RenderFillRects(
            self.value,
            @ptrCast(rects.ptr),
            @intCast(rects.len),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Copy a portion of the texture to the current rendering target at subpixel precision.
    pub fn renderTexture(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        dst_rect: ?rect.FRect,
    ) !void {
        const src_rect_sdl: ?C.SDL_FRect = if (src_rect == null) null else src_rect.?.toSdl();
        const dst_rect_sdl: ?C.SDL_FRect = if (dst_rect == null) null else dst_rect.?.toSdl();
        const ret = C.SDL_RenderTexture(
            self.value,
            texture.value,
            if (src_rect_sdl == null) null else &(src_rect_sdl.?),
            if (dst_rect_sdl == null) null else &(dst_rect_sdl.?),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Copy a portion of the source texture to the current rendering target, with rotation and flipping, at subpixel precision.
    pub fn renderTextureRotated(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        dst_rect: ?rect.FRect,
        angle: f64,
        center: ?rect.FPoint,
        flip_mode: ?surface.FlipMode,
    ) !void {
        const src_rect_sdl: ?C.SDL_FRect = if (src_rect == null) null else src_rect.?.toSdl();
        const dst_rect_sdl: ?C.SDL_FRect = if (dst_rect == null) null else dst_rect.?.toSdl();
        const center_sdl: ?C.SDL_FPoint = if (center == null) null else center.?.toSdl();
        const ret = C.SDL_RenderTextureRotated(
            self.value,
            texture.value,
            if (src_rect_sdl == null) null else &(src_rect_sdl.?),
            if (dst_rect_sdl == null) null else &(dst_rect_sdl.?),
            @floatCast(angle),
            if (center_sdl == null) null else &(center_sdl.?),
            if (flip_mode) |val| @intFromEnum(val) else C.SDL_FLIP_NONE,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Tile a portion of the texture to the current rendering target at subpixel precision.
    pub fn renderTextureTiled(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        scale: f32,
        dst_rect: ?rect.FRect,
    ) !void {
        const src_rect_sdl: ?C.SDL_FRect = if (src_rect == null) null else src_rect.?.toSdl();
        const dst_rect_sdl: ?C.SDL_FRect = if (dst_rect == null) null else dst_rect.?.toSdl();
        const ret = C.SDL_RenderTextureTiled(
            self.value,
            texture.value,
            if (src_rect_sdl == null) null else &(src_rect_sdl.?),
            @floatCast(scale),
            if (dst_rect_sdl == null) null else &(dst_rect_sdl.?),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Perform a scaled copy using the 9-grid algorithm to the current rendering target at subpixel precision.
    pub fn renderTexture9Grid(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        left_width: f32,
        right_width: f32,
        top_height: f32,
        bottom_height: f32,
        scale: f32,
        dst_rect: ?rect.FRect,
    ) !void {
        const src_rect_sdl: ?C.SDL_FRect = if (src_rect == null) null else src_rect.?.toSdl();
        const dst_rect_sdl: ?C.SDL_FRect = if (dst_rect == null) null else dst_rect.?.toSdl();
        const ret = C.SDL_RenderTexture9Grid(
            self.value,
            texture.value,
            if (src_rect_sdl == null) null else &(src_rect_sdl.?),
            @floatCast(left_width),
            @floatCast(right_width),
            @floatCast(top_height),
            @floatCast(bottom_height),
            @floatCast(scale),
            if (dst_rect_sdl == null) null else &(dst_rect_sdl.?),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Render a list of triangles, optionally using a texture and indices into the vertex arrays Color and alpha modulation is done per vertex.
    pub fn renderGeometry(
        self: Renderer,
        texture: ?Texture,
        vertices: [*]const Vertex,
        num_vertices: usize,
        indices: ?[*]const c_int,
        num_indices: usize,
    ) !void {
        const ret = C.SDL_RenderGeometry(
            self.value,
            if (texture) |texture_val| texture_val.value else null,
            vertices,
            @intCast(num_vertices),
            if (indices) |val| val else null,
            @intCast(num_indices),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Render a list of triangles, optionally using a texture and indices into the vertex arrays Color and alpha modulation is done per vertex.
    pub fn renderGeometryRaw(
        self: Renderer,
        texture: ?Texture,
        xy_positions: [*]const f32,
        xy_positions_stride: usize,
        colors: [*]const pixels.FColor,
        colors_stride: usize,
        uv_coords: [*]const f32,
        uv_coords_stride: usize,
        num_vertices: usize,
        indices: ?*const anyopaque,
        num_indices: usize,
        bytes_per_index: usize,
    ) !void {
        const ret = C.SDL_RenderGeometryRaw(
            self.value,
            if (texture) |texture_val| texture_val.value else null,
            xy_positions,
            @intCast(xy_positions_stride),
            colors,
            @intCast(colors_stride),
            uv_coords,
            @intCast(uv_coords_stride),
            @intCast(num_vertices),
            indices,
            @intCast(num_indices),
            @intCast(bytes_per_index),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Read pixels from the current rendering target.
    pub fn readPixels(
        self: Renderer,
        capture_area: ?rect.IRect,
    ) !surface.Surface {
        const capture_area_sdl: ?C.SDL_Rect = if (capture_area == null) null else capture_area.?.toSdl();
        const ret = C.SDL_RenderReadPixels(
            self.value,
            if (capture_area_sdl == null) null else &(capture_area_sdl.?),
        );
        if (ret == null)
            return error.SdlError;
        return surface.Surface{ .value = ret };
    }

    /// Update the screen with any rendering performed since the previous call.
    pub fn present(
        self: Renderer,
    ) !void {
        const ret = C.SDL_RenderPresent(
            self.value,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Destroy the rendering context for a window and free all associated textures.
    pub fn deinit(
        self: Renderer,
    ) void {
        const ret = C.SDL_DestroyRenderer(
            self.value,
        );
        _ = ret;
    }

    /// Force the rendering context to flush any pending commands and state.
    pub fn flush(
        self: Renderer,
    ) !void {
        const ret = C.SDL_FlushRenderer(
            self.value,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the CAMetalLayer associated with the given Metal renderer.
    pub fn getMetalLayer(
        self: Renderer,
    ) ?*anyopaque {
        const ret = C.SDL_GetRenderMetalLayer(
            self.value,
        );
        return ret;
    }

    /// Get the Metal command encoder for the current frame.
    pub fn getMetalCommandEncoder(
        self: Renderer,
    ) ?*anyopaque {
        const ret = C.SDL_GetRenderMetalCommandEncoder(
            self.value,
        );
        return ret;
    }

    /// Add a set of synchronization semaphores for the current frame.
    pub fn addVulkanSemaphores(
        self: Renderer,
        wait_stage_mask: u32,
        wait_semaphore: i64,
        signal_semaphore: i64,
    ) !void {
        const ret = C.SDL_AddVulkanRenderSemaphores(
            self.value,
            @intCast(wait_stage_mask),
            @intCast(wait_semaphore),
            @intCast(signal_semaphore),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Set VSync of the given renderer.
    pub fn setVSync(
        self: Renderer,
        vsync: ?VSync,
    ) !void {
        const ret = C.SDL_SetRenderVSync(self.value, VSync.toSdl(vsync));
        if (!ret)
            return error.SdlError;
    }

    /// Get VSync of the given renderer.
    pub fn getVSync(
        self: Renderer,
    ) !?VSync {
        var vsync: c_int = undefined;
        const ret = C.SDL_GetRenderVSync(self.value, &vsync);
        if (!ret)
            return error.SdlError;
        return VSync.fromSdl(vsync);
    }
};

/// An efficient driver-specific representation of pixel data.
pub const Texture = struct {
    value: *C.SDL_Texture,

    /// Get the properties associated with a texture.
    pub fn getProperties(
        self: Texture,
    ) !properties.Group {
        const ret = C.SDL_GetTextureProperties(
            self.value,
        );
        if (ret == 0)
            return error.SdlError;
        return properties.Group{ .value = ret };
    }

    /// Get the renderer that created an SDL_Texture.
    pub fn getRenderer(
        self: Texture,
    ) !Renderer {
        const ret = C.SDL_GetRendererFromTexture(
            self.value,
        );
        if (ret == null)
            return error.SdlError;
        return Renderer{ .value = ret.? };
    }

    /// Get the size of a texture, as floating point values.
    pub fn getSize(
        self: Texture,
    ) !struct { width: f32, height: f32 } {
        var w: f32 = undefined;
        var h: f32 = undefined;
        const ret = C.SDL_GetTextureSize(
            self.value,
            &w,
            &h,
        );
        if (!ret)
            return error.SdlError;
        return .{ .width = @floatCast(w), .height = @floatCast(h) };
    }

    /// Set an additional color value multiplied into render copy operations.
    pub fn setColorMod(
        self: Texture,
        r: u8,
        g: u8,
        b: u8,
    ) !void {
        const ret = C.SDL_SetTextureColorMod(
            self.value,
            @intCast(r),
            @intCast(g),
            @intCast(b),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Set an additional color value multiplied into render copy operations.
    pub fn setColorModFloat(
        self: Texture,
        r: f32,
        g: f32,
        b: f32,
    ) !void {
        const ret = C.SDL_SetTextureColorModFloat(
            self.value,
            @floatCast(r),
            @floatCast(g),
            @floatCast(b),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the additional color value multiplied into render copy operations.
    pub fn getColorMod(
        self: Texture,
    ) !struct { r: u8, g: u8, b: u8 } {
        var r: u8 = undefined;
        var g: u8 = undefined;
        var b: u8 = undefined;
        const ret = C.SDL_GetTextureColorMod(
            self.value,
            &r,
            &g,
            &b,
        );
        if (!ret)
            return error.SdlError;
        return .{ .r = r, .g = g, .b = b };
    }

    /// Get the additional color value multiplied into render copy operations.
    pub fn getColorModFloat(
        self: Texture,
    ) !struct { r: f32, g: f32, b: f32 } {
        var r: f32 = undefined;
        var g: f32 = undefined;
        var b: f32 = undefined;
        const ret = C.SDL_GetTextureColorModFloat(
            self.value,
            &r,
            &g,
            &b,
        );
        if (!ret)
            return error.SdlError;
        return .{ .r = r, .g = g, .b = b };
    }

    /// Set an additional alpha value multiplied into render copy operations.
    pub fn setAlphaMod(
        self: Texture,
        alpha: u8,
    ) !void {
        const ret = C.SDL_SetTextureAlphaMod(
            self.value,
            @intCast(alpha),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Set an additional alpha value multiplied into render copy operations.
    pub fn setAlphaModFloat(
        self: Texture,
        alpha: f32,
    ) !void {
        const ret = C.SDL_SetTextureAlphaModFloat(
            self.value,
            @floatCast(alpha),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the additional alpha value multiplied into render copy operations.
    pub fn getAlphaMod(
        self: Texture,
    ) !u8 {
        var alpha: u8 = undefined;
        const ret = C.SDL_GetTextureAlphaMod(
            self.value,
            &alpha,
        );
        if (!ret)
            return error.SdlError;
        return alpha;
    }

    /// Get the additional alpha value multiplied into render copy operations.
    pub fn getAlphaModFloat(
        self: Texture,
    ) !f32 {
        var alpha: f32 = undefined;
        const ret = C.SDL_GetTextureAlphaModFloat(
            self.value,
            &alpha,
        );
        if (!ret)
            return error.SdlError;
        return alpha;
    }

    /// Set the blend mode for a texture, used by `renderer.renderTexture`.
    pub fn setBlendMode(
        self: Texture,
        mode: blend_mode.Mode,
    ) !void {
        const ret = C.SDL_SetTextureBlendMode(
            self.value,
            mode.value,
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the blend mode used for texture copy operations.
    pub fn getBlendMode(
        self: Texture,
    ) !?blend_mode.Mode {
        var mode: C.SDL_BlendMode = undefined;
        const ret = C.SDL_GetTextureBlendMode(
            self.value,
            &mode,
        );
        if (!ret)
            return error.SdlError;
        if (mode == C.SDL_BLENDMODE_INVALID)
            return null;
        return .{ .value = mode };
    }

    /// Set the scale mode used for texture scale operations.
    pub fn setScaleMode(
        self: Texture,
        mode: surface.ScaleMode,
    ) !void {
        const ret = C.SDL_SetTextureScaleMode(
            self.value,
            @intFromEnum(mode),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Get the scale mode used for texture scale operations.
    pub fn getScaleMode(
        self: Texture,
    ) !surface.ScaleMode {
        var mode: C.SDL_ScaleMode = undefined;
        const ret = C.SDL_GetTextureScaleMode(
            self.value,
            &mode,
        );
        if (!ret)
            return error.SdlError;
        return @enumFromInt(mode);
    }

    /// Update the given texture rectangle with new pixel data.
    pub fn update(
        self: Texture,
        update_area: ?rect.IRect,
        data: []const u8,
    ) !void {
        const update_area_sdl: ?C.SDL_Rect = if (update_area == null) null else update_area.?.toSdl();
        const ret = C.SDL_UpdateTexture(
            self.value,
            if (update_area_sdl == null) null else &(update_area_sdl.?),
            data.ptr,
            @intCast(data.len / (if (update_area_sdl) |val| @as(usize, @intCast(val.h)) else self.getHeight())),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Update a rectangle within a planar YV12 or IYUV texture with new pixel data.
    pub fn updateYUV(
        self: Texture,
        update_area: ?rect.IRect,
        y_data: []const u8,
        u_data: []const u8,
        v_data: []const u8,
    ) !void {
        const update_area_sdl: ?C.SDL_Rect = if (update_area == null) null else update_area.?.toSdl();
        const ret = C.SDL_UpdateYUVTexture(
            self.value,
            if (update_area_sdl == null) null else &(update_area_sdl.?),
            y_data.ptr,
            @intCast(y_data.len / (if (update_area_sdl) |val| @as(usize, @intCast(val.h)) else self.getHeight())),
            u_data.ptr,
            @intCast(u_data.len / (if (update_area_sdl) |val| @as(usize, @intCast(val.h)) else self.getHeight())),
            v_data.ptr,
            @intCast(v_data.len / (if (update_area_sdl) |val| @as(usize, @intCast(val.h)) else self.getHeight())),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Update a rectangle within a planar NV12 or NV21 texture with new pixels.
    pub fn updateNV(
        self: Texture,
        update_area: ?rect.IRect,
        y_data: []const u8,
        uv_data: []const u8,
    ) !void {
        const update_area_sdl: ?C.SDL_Rect = if (update_area == null) null else update_area.?.toSdl();
        const ret = C.SDL_UpdateNVTexture(
            self.value,
            if (update_area_sdl == null) null else &(update_area_sdl.?),
            y_data.ptr,
            @intCast(y_data.len / (if (update_area_sdl) |val| @as(usize, @intCast(val.h)) else self.getHeight())),
            uv_data.ptr,
            @intCast(uv_data.len / (if (update_area_sdl) |val| @as(usize, @intCast(val.h)) else self.getHeight())),
        );
        if (!ret)
            return error.SdlError;
    }

    /// Lock a portion of the texture for write-only pixel access.
    pub fn lock(
        self: Texture,
        update_area: ?rect.IRect,
    ) ![]u8 {
        const update_area_sdl: ?C.SDL_Rect = if (update_area == null) null else update_area.?.toSdl();
        var data: ?*anyopaque = undefined;
        var pitch: c_int = undefined;
        const ret = C.SDL_LockTexture(
            self.value,
            if (update_area_sdl == null) null else &(update_area_sdl.?),
            &data,
            &pitch,
        );
        if (!ret)
            return error.SdlError;
        return .{ .ptr = @ptrCast(@alignCast(pixels)), .len = self.getHeight() * @as(usize, @intCast(pitch)) };
    }

    /// Lock a portion of the texture for write-only pixel access, and expose it as a SDL surface.
    pub fn lockToSurface(
        self: Texture,
        update_area: ?rect.IRect,
    ) !surface.Surface {
        const update_area_sdl: ?C.SDL_Rect = if (update_area == null) null else update_area.?.toSdl();
        var target_surface: C.SDL_Surface = undefined;
        const ret = C.SDL_LockTextureToSurface(
            self.value,
            if (update_area_sdl == null) null else &(update_area_sdl.?),
            &target_surface,
        );
        if (!ret)
            return error.SdlError;
        return target_surface;
    }

    /// Unlock a texture, uploading the changes to video memory, if needed.
    pub fn unlock(
        self: Texture,
    ) void {
        const ret = C.SDL_UnlockTexture(
            self.value,
        );
        _ = ret;
    }

    /// Destroy the specified texture.
    pub fn deinit(
        self: Texture,
    ) void {
        const ret = C.SDL_DestroyTexture(
            self.value,
        );
        _ = ret;
    }

    /// Get the pixel format for the texture.
    pub fn getPixelFormat(self: Texture) ?pixels.Format {
        return if (self.value.format == C.SDL_PIXELFORMAT_UNKNOWN) null else @enumFromInt(self.value.format);
    }

    /// Get the width of the texture.
    pub fn getWidth(self: Texture) usize {
        return @intCast(self.value.w);
    }

    /// Get the height of the texture.
    pub fn getHeight(self: Texture) usize {
        return @intCast(self.value.h);
    }

    /// Get the reference count of the texture.
    pub fn getRefCount(self: Texture) usize {
        return @intCast(self.value.refcount);
    }
};

/// Vertex for rendering.
pub const Vertex = extern struct {
    /// Position in SDL renderer coordinates.
    position: rect.FPoint,
    /// Vertex color.
    color: pixels.FColor,
    /// Normalize texture coordinates.
    tex_coord: rect.FPoint,
};

/// VSync mode.
pub const VSync = union(enum) {
    on_each_num_refresh: usize,
    adaptive: void,
    pub fn fromSdl(val: c_int) ?VSync {
        return if (val == 0) null else if (val == -1) .apdative else .on_each_num_refresh(@intCast(val));
    }
    /// Convert to an SDL value.
    pub fn toSdl(self: ?VSync) c_int {
        return if (self) |sync|
            switch (sync) {
                .OnEachNumRefresh => |val| @intCast(val),
                .adaptive => -1,
            }
        else
            0;
    }
};

/// The name of the software renderer.
pub const software_renderer_name = C.SDL_SOFTWARE_RENDERER;

const blend_mode = @import("blend_mode.zig");
const video = @import("video.zig");
const properties = @import("properties.zig");
const rect = @import("rect.zig");
const surface = @import("surface.zig");
const pixels = @import("pixels.zig");
