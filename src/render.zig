const c = @import("c");
const blend_mode = @import("blend_mode.zig");
const errors = @import("errors.zig");
const events = @import("events.zig");
const gpu = @import("gpu.zig");
const options = @import("options");
const pixels = @import("pixels.zig");
const properties = @import("properties.zig");
const rect = @import("rect.zig");
const sdl3 = @import("sdl3.zig");
const std = @import("std");
const surface = @import("surface.zig");
const video = @import("video.zig");

/// The size, in pixels, of a single `render.Renderer.renderDebugText()` character.
///
/// ## Remarks
/// The font is monospaced and square, so this applies to all characters.
///
/// ## Version
/// This macro is available since SDL 3.2.0.
pub const debug_text_font_character_size: usize = @intCast(c.SDL_DEBUG_TEXT_FONT_CHARACTER_SIZE);

/// The name of the software renderer.
///
/// ## Version
/// This macro is available since SDL 3.2.0.
pub const software_renderer_name = c.SDL_SOFTWARE_RENDERER;

// GPU render state added in 3.4.0.

// GPU render state description added in 3.4.0.

/// A structure representing rendering state
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Renderer = struct {
    value: *c.SDL_Renderer,

    /// Properties for a 2d rendering context.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    pub const CreateProperties = struct {
        /// The name of the rendering driver to use, if a specific one is desired.
        name: ?[:0]const u8 = null,
        /// The window where rendering is displayed, required if this isn't a software renderer using a surface.
        window: ?struct { value: ?video.Window } = null,
        /// The surface where rendering is displayed, if you want a software renderer without a window.
        render_surface: ?struct { value: ?surface.Surface } = null,
        /// An SDL_Colorspace value describing the colorspace for output to the display, defaults to `pixels.Colorspace.srgb`.
        /// The direct3d11, direct3d12, and metal renderers support `pixels.Colorspace.srgb_linear`, which is a linear color space and supports HDR output.
        /// If you select `pixels.Colorspace.srgb_linear`, drawing still uses the sRGB colorspace, but values can go beyond `1` and float (linear) format textures can be used for HDR content.
        output_colorspace: ?pixels.Colorspace = null,
        /// Optional vsync option.
        present_vsync: ?struct { value: ?video.VSync } = null,
        // gpu_shaders_spirv: ?bool = null,
        // gpu_shaders_dxil: ?bool = null,
        // gpu_shaders_msl: ?bool = null,
        /// The `VkInstance` to use with the renderer, optional.
        vulkan_instance: ?struct { value: ?*anyopaque } = null,
        /// The `VkSurfaceKHR` to use with the renderer, optional.
        vulkan_surface: ?i64 = null,
        /// The `VkPhysicalDevice` to use with the renderer, optional.
        vulkan_physical_device: ?struct { value: ?*anyopaque } = null,
        /// The `VkDevice` to use with the renderer, optional.
        vulkan_device: ?struct { value: ?*anyopaque } = null,
        /// The queue family index used for rendering.
        vulkan_graphics_queue_family_index: ?i64 = null,
        /// The queue family index used for presentation.
        vulkan_present_queue_family_index: ?i64 = null,

        /// Convert to SDL.
        pub fn toProperties(
            self: CreateProperties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            if (self.name) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_NAME_STRING, .{ .string = val });
            if (self.window) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_WINDOW_POINTER, .{ .pointer = if (val.value) |val2| val2.value else null });
            if (self.render_surface) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_SURFACE_POINTER, .{ .pointer = if (val.value) |val2| val2.value else null });
            if (self.output_colorspace) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_OUTPUT_COLORSPACE_NUMBER, .{ .number = @intFromEnum(val) });
            if (self.present_vsync) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_PRESENT_VSYNC_NUMBER, .{ .number = @intCast(video.VSync.toSdl(val.value)) });
            // GPU properties exist in later SDL version.

            if (self.vulkan_instance) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_VULKAN_INSTANCE_POINTER, .{ .pointer = val.value });
            if (self.vulkan_surface) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_VULKAN_SURFACE_NUMBER, .{ .number = val });
            if (self.vulkan_physical_device) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_VULKAN_PHYSICAL_DEVICE_POINTER, .{ .pointer = val.value });
            if (self.vulkan_device) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_VULKAN_DEVICE_POINTER, .{ .pointer = val.value });
            if (self.vulkan_graphics_queue_family_index) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER, .{ .number = val });
            if (self.vulkan_present_queue_family_index) |val|
                try ret.set(c.SDL_PROP_RENDERER_CREATE_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER, .{ .number = val });
            return ret;
        }
    };

    /// Get the properties associated with a renderer.
    ///
    /// ## Version
    /// This struct is provided by zig-sdl3.
    pub const Properties = struct {
        /// The name of the rendering driver.
        name: ?[:0]const u8,
        /// The window where rendering is displayed, if any.
        window: ?struct { value: ?video.Window },
        /// The surface where rendering is displayed, if this is a software renderer without a window.
        render_surface: ?struct { value: ?surface.Surface },
        /// The current vsync setting.
        vsync: ?struct { value: ?video.VSync },
        /// The maximum texture width and height.
        max_texture_size: ?usize,
        /// Array representing the available texture formats for this renderer.
        formats: ?struct { value: ?[*:c.SDL_PIXELFORMAT_UNKNOWN]const c.SDL_PixelFormat },
        /// Value describing the colorspace for output to the display, defaults to `pixels.Colorspace.srgb`.
        output_colorspace: ?pixels.Colorspace,
        /// True if the output colorspace is `pixels.Colorspace.srgb_linear` and the renderer is showing on a display with HDR enabled.
        /// This property can change dynamically when `events.Type.window_hdr_state_changed` is sent.
        hdr_enabled: ?bool,
        /// The value of SDR white in the `pixels.Colorspace.srgb_linear` colorspace.
        /// When HDR is enabled, this value is automatically multiplied into the color scale.
        /// This property can change dynamically when `events.Type.window_hdr_state_changed` is sent.
        sdr_white_point: ?f32,
        /// The additional high dynamic range that can be displayed, in terms of the SDR white point.
        /// When HDR is not enabled, this will be `1`.
        /// This property can change dynamically when `events.Type.window_hdr_state_changed` is sent.
        hdr_headroom: ?f32,
        /// The `IDirect3DDevice9` associated with the renderer.
        d3d9_device: ?struct { value: ?*anyopaque },
        /// The `ID3D11Device` associated with the renderer.
        d3d11_device: ?struct { value: ?*anyopaque },
        /// The `IDXGISwapChain1` associated with the renderer.
        /// This may change when the window is resized.
        d3d11_swapchain: ?struct { value: ?*anyopaque },
        /// The `ID3D12Device` associated with the renderer.
        d3d12_device: ?struct { value: ?*anyopaque },
        /// The `IDXGISwapChain4` associated with the renderer.
        d3d12_swapchain: ?struct { value: ?*anyopaque },
        /// The `ID3D12CommandQueue` associated with the renderer.
        d3d12_command_queue: ?struct { value: ?*anyopaque },
        /// The `VkInstance` associated with the renderer.
        vulkan_instance: ?struct { value: ?*anyopaque },
        /// The `VkSurfaceKHR` associated with the renderer.
        vulkan_surface: ?i64,
        /// The `VkPhysicalDevice` associated with the renderer.
        vulkan_physical_device: ?struct { value: ?*anyopaque },
        /// The `VkDevice` associated with the renderer.
        vulkan_device: ?struct { value: ?*anyopaque },
        /// The queue family index used for rendering.
        vulkan_graphics_queue_family_index: ?i64,
        /// The queue family index used for presentation.
        vulkan_present_queue_family_index: ?i64,
        /// The number of swapchain images, or potential frames in flight, used by the Vulkan renderer.
        vulkan_swapchain_image_count: ?i64,
        /// The GPU device associated with the renderer.
        gpu_device: ?struct { value: ?gpu.Device },

        /// Convert from SDL.
        pub fn fromProperties(
            props: properties.Group,
        ) Properties {
            return .{
                .name = if (props.get(c.SDL_PROP_RENDERER_NAME_STRING)) |val| val.string else null,
                .window = if (props.get(c.SDL_PROP_RENDERER_WINDOW_POINTER)) |val| (.{ .value = if (val.pointer) |val2| .{ .value = @ptrCast(@alignCast(val2)) } else null }) else null,
                .render_surface = if (props.get(c.SDL_PROP_RENDERER_SURFACE_POINTER)) |val| (.{ .value = if (val.pointer) |val2| .{ .value = @ptrCast(@alignCast(val2)) } else null }) else null,
                .vsync = if (props.get(c.SDL_PROP_RENDERER_VSYNC_NUMBER)) |val| .{ .value = video.VSync.fromSdl(@intCast(val.number)) } else null,
                .max_texture_size = if (props.get(c.SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER)) |val| @intCast(val.number) else null,
                .formats = if (props.get(c.SDL_PROP_RENDERER_TEXTURE_FORMATS_POINTER)) |val| .{ .value = @ptrCast(@alignCast(val.pointer)) } else null,
                .output_colorspace = if (props.get(c.SDL_PROP_RENDERER_OUTPUT_COLORSPACE_NUMBER)) |val| pixels.Colorspace.fromSdl(@intCast(val.number)) else null,
                .hdr_enabled = if (props.get(c.SDL_PROP_RENDERER_HDR_ENABLED_BOOLEAN)) |val| val.boolean else null,
                .sdr_white_point = if (props.get(c.SDL_PROP_RENDERER_SDR_WHITE_POINT_FLOAT)) |val| val.float else null,
                .hdr_headroom = if (props.get(c.SDL_PROP_RENDERER_HDR_HEADROOM_FLOAT)) |val| val.float else null,
                .d3d9_device = if (props.get(c.SDL_PROP_RENDERER_D3D9_DEVICE_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d11_device = if (props.get(c.SDL_PROP_RENDERER_D3D11_DEVICE_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d11_swapchain = if (props.get(c.SDL_PROP_RENDERER_D3D11_SWAPCHAIN_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d12_device = if (props.get(c.SDL_PROP_RENDERER_D3D12_DEVICE_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d12_swapchain = if (props.get(c.SDL_PROP_RENDERER_D3D12_SWAPCHAIN_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d12_command_queue = if (props.get(c.SDL_PROP_RENDERER_D3D12_COMMAND_QUEUE_POINTER)) |val| .{ .value = val.pointer } else null,
                .vulkan_instance = if (props.get(c.SDL_PROP_RENDERER_VULKAN_INSTANCE_POINTER)) |val| .{ .value = val.pointer } else null,
                .vulkan_surface = if (props.get(c.SDL_PROP_RENDERER_VULKAN_SURFACE_NUMBER)) |val| val.number else null,
                .vulkan_physical_device = if (props.get(c.SDL_PROP_RENDERER_VULKAN_PHYSICAL_DEVICE_POINTER)) |val| .{ .value = val.pointer } else null,
                .vulkan_device = if (props.get(c.SDL_PROP_RENDERER_VULKAN_DEVICE_POINTER)) |val| .{ .value = val.pointer } else null,
                .vulkan_graphics_queue_family_index = if (props.get(c.SDL_PROP_RENDERER_VULKAN_GRAPHICS_QUEUE_FAMILY_INDEX_NUMBER)) |val| val.number else null,
                .vulkan_present_queue_family_index = if (props.get(c.SDL_PROP_RENDERER_VULKAN_PRESENT_QUEUE_FAMILY_INDEX_NUMBER)) |val| val.number else null,
                .vulkan_swapchain_image_count = if (props.get(c.SDL_PROP_RENDERER_VULKAN_SWAPCHAIN_IMAGE_COUNT_NUMBER)) |val| val.number else null,
                .gpu_device = if (props.get(c.SDL_PROP_RENDERER_GPU_DEVICE_POINTER)) |val| (.{ .value = if (val.pointer) |val2| .{ .value = @ptrCast(@alignCast(val2)) } else null }) else null,
            };
        }
    };

    /// Add a set of synchronization semaphores for the current frame.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `wait_stage_mask`: The `VkPipelineStageFlags` for the wait.
    /// * `wait_semaphore`: A `VkSempahore` to wait on before rendering the current frame, or `null` if not needed.
    /// * `signal_semaphore`: A `VkSempahore` that SDL will signal when rendering for the current frame is complete, or `null` if not needed.
    ///
    /// ## Remarks
    /// The Vulkan renderer will wait for `wait_semaphore` before submitting rendering commands and signal `signal_semaphore` after rendering commands
    /// are complete for this frame.
    ///
    /// This should be called each frame that you want semaphore synchronization.
    /// The Vulkan renderer may have multiple frames in flight on the GPU, so you should have multiple semaphores that are used for synchronization.
    /// Querying `render.Renderer.getProperties().vulkan_swapchain_image_count` will give you the maximum number of semaphores you'll need.
    ///
    /// Thread Safety
    /// It is NOT safe to call this function from two threads at once.
    ///
    /// Version
    /// This function is available since SDL 3.2.0.
    pub fn addVulkanSemaphores(
        self: Renderer,
        wait_stage_mask: u32,
        wait_semaphore: ?i64,
        signal_semaphore: ?i64,
    ) !void {
        const ret = c.SDL_AddVulkanRenderSemaphores(
            self.value,
            wait_stage_mask,
            if (wait_semaphore) |val| val else 0,
            if (signal_semaphore) |val| val else 0,
        );
        return errors.wrapCallBool(ret);
    }

    /// Clear the current rendering target with the drawing color.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Remarks
    /// This function clears the entire rendering target, ignoring the viewport and the clip rectangle.
    /// Note, that clearing will also set/fill all pixels of the rendering target to current renderer draw color,
    /// so make sure to invoke `render.Renderer.setDrawColor()` when needed.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn clear(
        self: Renderer,
    ) !void {
        const ret = c.SDL_RenderClear(
            self.value,
        );
        return errors.wrapCallBool(ret);
    }

    /// Convert the coordinates in an event to render coordinates.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `event`: The event to modify.
    ///
    /// ## Remarks
    /// This takes into account several states:
    /// * The window dimensions.
    /// * The logical presentation settings (`render.Renderer.setLogicalPresentation()`).
    /// * The scale (`render.Renderer.setScale()`).
    /// * The viewport (`render.Renderer.setViewport()`).
    ///
    /// Various event types are converted with this function: mouse, touch, pen, etc.
    ///
    /// Touch coordinates are converted from normalized coordinates in the window to non-normalized rendering coordinates.
    ///
    /// Relative mouse coordinates (`x_rel` and `y_rel` event fields) are also converted.
    /// Applications that do not want these fields converted should use `render.Renderer.coordinatesFromWindow()` on the specific event fields instead of
    /// converting the entire event structure.
    ///
    /// Once converted, coordinates may be outside the rendering area.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn convertEventToRenderCoordinates(
        self: Renderer,
        event: *events.Event,
    ) !void {
        var event_sdl = event.toSdl();
        try errors.wrapCallBool(c.SDL_ConvertEventToRenderCoordinates(self.value, &event_sdl));
        event.* = events.Event.fromSdl(event_sdl);
    }

    // CreateGPURenderer added in 3.4.0.

    // CreateGPURenderState added in 3.4.0.

    /// Create a texture from an existing surface.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `surface_to_copy`: Surface containing pixel data used to fill the texture.
    ///
    /// ## Return Value
    /// Returns the created texture.
    ///
    /// ## Remarks
    /// The surface is not modified or freed by this function.
    ///
    /// The `render.Texture.Access` hint for the created texture is `render.Texture.Access.static`.
    ///
    /// The pixel format of the created texture may be different from the pixel format of the surface,
    /// and can be queried using the `render.Texture.getProperties().format` property.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// TODO!!!
    pub fn createTextureFromSurface(
        self: Renderer,
        surface_to_copy: surface.Surface,
    ) !Texture {
        const ret = c.SDL_CreateTextureFromSurface(
            self.value,
            surface_to_copy.value,
        );
        return Texture{ .value = try errors.wrapCallNull(*c.SDL_Texture, ret) };
    }

    // SetGPURenderStateFragmentUniforms for render state is added in 3.4.0.
    // SDL_DestroyGPURenderState is added in 3.4.0.

    /// Destroy the rendering context for a window and free all associated textures.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Remarks
    /// This should be called before destroying the associated window.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn deinit(
        self: Renderer,
    ) void {
        c.SDL_DestroyRenderer(
            self.value,
        );
    }

    /// Force the rendering context to flush any pending commands and state.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Remarks
    /// You do not need to (and in fact, shouldn't) call this function unless you are planning to call into OpenGL/Direct3D/Metal/whatever directly,
    /// in addition to using a renderer.
    ///
    /// This is for a very-specific case: if you are using SDL's render API, and you plan to make OpenGL/D3D/whatever calls in addition to SDL render API calls.
    /// If this applies, you should call this function between calls to SDL's render API and the low-level API you're using in cooperation.
    ///
    /// In all other cases, you can ignore this function.
    ///
    /// This call makes SDL flush any pending rendering work it was queueing up to do later in a single batch, and marks any internal cached state as invalid,
    /// so it'll prepare all its state again later, from scratch.
    ///
    /// This means you do not need to save state in your rendering code to protect the SDL renderer.
    /// However, there lots of arbitrary pieces of Direct3D and OpenGL state that can confuse things;
    /// you should use your best judgment and be prepared to make changes if specific state needs to be protected.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn flush(
        self: Renderer,
    ) !void {
        const ret = c.SDL_FlushRenderer(
            self.value,
        );
        return errors.wrapCallBool(ret);
    }

    /// Get whether clipping is enabled on the given render target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// Returns true if clipping is enabled or not.
    ///
    /// ## Remarks
    /// Each render target has its own clip rectangle.
    /// This function checks the clip rect for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getClipEnabled(
        self: Renderer,
    ) bool {
        const ret = c.SDL_RenderClipEnabled(
            self.value,
        );
        return ret;
    }

    /// Get the clip rectangle for the current target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The current clipping area or `null` if disabled.
    ///
    /// ## Remarks
    /// Each render target has its own clip rectangle.
    /// This function gets the clip rect for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getClipRect(
        self: Renderer,
    ) !?rect.IRect {
        var clipping: c.SDL_Rect = undefined;
        const ret = c.SDL_GetRenderClipRect(
            self.value,
            &clipping,
        );
        try errors.wrapCallBool(ret);
        const conv = rect.IRect.fromSdl(clipping);
        if (conv.empty())
            return null;
        return conv;
    }

    /// Get the color scale used for render operations.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The current color scale value.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getColorScale(
        self: Renderer,
    ) !f32 {
        var scale: f32 = undefined;
        const ret = c.SDL_GetRenderColorScale(
            self.value,
            &scale,
        );
        try errors.wrapCallBool(ret);
        return scale;
    }

    /// Get the current output size in pixels of a rendering context.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The current output size in pixels of a rendering context.
    /// Width and height are provided in that order.
    ///
    /// ## Remarks
    /// If a rendering target is active, this will return the size of the rendering target in pixels, otherwise return the value of `render.Renderer.getOutputSize()`.
    ///
    /// Rendering target or not, the output will be adjusted by the current logical presentation state, dictated by `render.Renderer.setRenderLogicalPresentation()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getCurrentOutputSize(
        self: Renderer,
    ) !struct { usize, usize } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        const ret = c.SDL_GetCurrentRenderOutputSize(
            self.value,
            &w,
            &h,
        );
        try errors.wrapCallBool(ret);
        return .{ @intCast(w), @intCast(h) };
    }

    // getDefaultTextureScalMode() is in SDL 3.4.0.

    /// Get the blend mode used for drawing operations.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The current blend mode.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getDrawBlendMode(
        self: Renderer,
    ) !?blend_mode.Mode {
        var mode: c.SDL_BlendMode = undefined;
        const ret = c.SDL_GetRenderDrawBlendMode(
            self.value,
            &mode,
        );
        try errors.wrapCallBool(ret);
        return blend_mode.Mode.fromSdl(mode);
    }

    /// Get the color used for drawing operations (Rect, Line and Clear).
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The color used to draw on the rendering target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getDrawColor(
        self: Renderer,
    ) !pixels.Color {
        var r: u8 = undefined;
        var g: u8 = undefined;
        var b: u8 = undefined;
        var a: u8 = undefined;
        const ret = c.SDL_GetRenderDrawColor(
            self.value,
            &r,
            &g,
            &b,
            &a,
        );
        try errors.wrapCallBool(ret);
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Get the color used for drawing operations (Rect, Line and Clear).
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The color used to draw on the rendering target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getDrawColorFloat(
        self: Renderer,
    ) !pixels.FColor {
        var r: f32 = undefined;
        var g: f32 = undefined;
        var b: f32 = undefined;
        var a: f32 = undefined;
        const ret = c.SDL_GetRenderDrawColorFloat(
            self.value,
            &r,
            &g,
            &b,
            &a,
        );
        try errors.wrapCallBool(ret);
        return .{ .r = r, .g = g, .b = b, .a = a };
    }

    /// Get device independent resolution and presentation mode for rendering.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The width and height with the logical presentation output size along with the presentation mode used in that order.
    ///
    /// ## Remarks
    /// This function gets the width and height of the logical rendering output, or the output size in pixels if a logical resolution is not enabled.
    ///
    /// Each render target has its own logical presentation state.
    /// This function gets the state for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getLogicalPresentation(
        self: Renderer,
    ) !struct { usize, usize, ?LogicalPresentation } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        var presentation_mode: c.SDL_RendererLogicalPresentation = undefined;
        const ret = c.SDL_GetRenderLogicalPresentation(
            self.value,
            &w,
            &h,
            &presentation_mode,
        );
        try errors.wrapCallBool(ret);
        return .{ @intCast(w), @intCast(h), LogicalPresentation.fromSdl(presentation_mode) };
    }

    /// Get the final presentation rectangle for rendering.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The logical presentation rectangle.
    ///
    /// ## Remarks
    /// This function returns the calculated rectangle used for logical presentation, based on the presentation mode and output size.
    /// If logical presentation is disabled, it will fill the rectangle with the output size, in pixels.
    ///
    /// Each render target has its own logical presentation state.
    /// This function gets the rectangle for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getLogicalPresentationRect(
        self: Renderer,
    ) !rect.FRect {
        var presentation_rect: c.SDL_FRect = undefined;
        const ret = c.SDL_GetRenderLogicalPresentationRect(
            self.value,
            &presentation_rect,
        );
        try errors.wrapCallBool(ret);
        return rect.FRect.fromSdl(presentation_rect);
    }

    /// Get the Metal command encoder for the current frame.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The metal layer on success, or `null` if the renderer isn't a Metal renderer or there was an error.
    ///
    /// ## Remarks
    /// This will return `null` if Metal refuses to give SDL a drawable to render to, which might happen if the window is hidden/minimized/offscreen.
    /// This doesn't apply to command encoders for render targets, just the window's backbuffer.
    /// Check your return values!
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getMetalCommandEncoder(
        self: Renderer,
    ) ?*anyopaque {
        const ret = c.SDL_GetRenderMetalCommandEncoder(
            self.value,
        );
        return ret;
    }

    /// Get the `CAMetalLayer` associated with the given Metal renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The metal layer on success, or `null` if the renderer isn't a Metal renderer.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getMetalLayer(
        self: Renderer,
    ) ?*anyopaque {
        const ret = c.SDL_GetRenderMetalLayer(
            self.value,
        );
        return ret;
    }

    /// Get the name of a renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// Returns the name of the selected renderer.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getName(
        self: Renderer,
    ) ![:0]const u8 {
        const ret = c.SDL_GetRendererName(
            self.value,
        );
        return errors.wrapCallCString(ret);
    }

    /// Get the output size in pixels of a rendering context.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The output size in pixels.
    /// The width and height are provided in that order.
    ///
    /// ## Remarks
    /// This returns the true output size in pixels, ignoring any render targets or logical size and presentation.
    ///
    /// For the output size of the current rendering target, with logical size adjustments, use `render.Renderer.getCurrentOutputSize()` instead.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getOutputSize(
        self: Renderer,
    ) !struct { usize, usize } {
        var w: c_int = undefined;
        var h: c_int = undefined;
        const ret = c.SDL_GetRenderOutputSize(
            self.value,
            &w,
            &h,
        );
        try errors.wrapCallBool(ret);
        return .{ @intCast(w), @intCast(h) };
    }

    /// Get the properties associated with a renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// Returns the read-only properties of the renderer.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getProperties(
        self: Renderer,
    ) !Properties {
        const ret = c.SDL_GetRendererProperties(
            self.value,
        );
        return Properties.fromProperties(.{ .value = try errors.wrapCall(c.SDL_PropertiesID, ret, 0) });
    }

    /// Get the safe area for rendering within the current viewport.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// Area that is safe for interactive content.
    ///
    /// ## Remarks
    /// Some devices have portions of the screen which are partially obscured or not interactive, possibly due to on-screen controls, curved edges, camera notches, TV overscan, etc.
    /// This function provides the area of the current viewport which is safe to have interactible content.
    /// You should continue rendering into the rest of the render target, but it should not contain visually important or interactible content.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getSafeArea(
        self: Renderer,
    ) !rect.IRect {
        var area: c.SDL_Rect = undefined;
        const ret = c.SDL_GetRenderSafeArea(
            self.value,
            &area,
        );
        try errors.wrapCallBool(ret);
        return rect.IRect.fromSdl(area);
    }

    /// Get the drawing scale for the current target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// The scaling factors for x and y in that order.
    ///
    /// ## Remarks
    /// Each render target has its own scale.
    /// This function gets the scale for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getScale(
        self: Renderer,
    ) !struct { f32, f32 } {
        var x: f32 = undefined;
        var y: f32 = undefined;
        const ret = c.SDL_GetRenderScale(
            self.value,
            &x,
            &y,
        );
        try errors.wrapCallBool(ret);
        return .{ x, y };
    }

    /// Get the current render target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// Returns the current render target or `null` for the default target.
    ///
    /// ## Remarks
    /// The default render target is the window for which the renderer was created, and is reported a `null` here.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getTarget(
        self: Renderer,
    ) ?Texture {
        const ret = c.SDL_GetRenderTarget(
            self.value,
        );
        if (ret == null)
            return null;
        return Texture{ .value = ret };
    }

    // getTextureAddressMode added in SDL 3.4.0.

    /// Get the drawing area for the current target.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer to query.
    ///
    /// ## Return Value
    /// Returns the current drawing area.
    ///
    /// ## Remarks
    /// Each render target has its own viewport.
    /// This function gets the viewport for the current render target.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getViewport(
        self: Renderer,
    ) !rect.IRect {
        var viewport: c.SDL_Rect = undefined;
        const ret = c.SDL_GetRenderViewport(
            self.value,
            &viewport,
        );
        try errors.wrapCallBool(ret);
        return rect.IRect.fromSdl(viewport);
    }

    /// Get VSync of the given renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer to query.
    ///
    /// ## Return Value
    /// Returns the current vertical refresh sync interval.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getVSync(
        self: Renderer,
    ) !?video.VSync {
        var vsync: c_int = undefined;
        const ret = c.SDL_GetRenderVSync(self.value, &vsync);
        try errors.wrapCallBool(ret);
        return video.VSync.fromSdl(vsync);
    }

    /// Get the window associated with a renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer to query.
    ///
    /// ## Return Value
    /// Returns the window.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getWindow(
        self: Renderer,
    ) !video.Window {
        const ret = c.SDL_GetRenderWindow(
            self.value,
        );
        return video.Window{ .value = try errors.wrapCallNull(*c.SDL_Window, ret) };
    }

    /// Create a 2D rendering context for a window.
    ///
    /// ## Function Parameters
    /// * `window`: The window where rendering is displayed.
    /// * `renderer_name`: The name of the rendering driver to initialize, or `null` to let SDL choose one.
    ///
    /// ## Return Value
    /// Returns a valid rendering context.
    ///
    /// ## Remarks
    /// If you want a specific renderer, you can specify its name here.
    /// A list of available renderers can be obtained by calling `render.getDriverName()` multiple times, with indices from `0` to `render.getNumDrivers()`.
    /// If you don't need a specific renderer, specify `null` and SDL will attempt to choose the best option for you, based on what is available on the user's system.
    ///
    /// If name is a comma-separated list, SDL will try each name, in the order listed, until one succeeds or all of them fail.
    ///
    /// By default the rendering size matches the window size in pixels,
    /// but you can call `render.Renderer.setLogicalPresentation()` to change the content size and scaling options.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// TODO!!!
    pub fn init(
        window: video.Window,
        renderer_name: ?[:0]const u8,
    ) !Renderer {
        const ret = c.SDL_CreateRenderer(
            window.value,
            if (renderer_name) |str_capture| str_capture.ptr else null,
        );
        return Renderer{ .value = try errors.wrapCallNull(*c.SDL_Renderer, ret) };
    }

    /// Create a 2D rendering context for a window, with the specified properties.
    ///
    /// ## Function Parameters
    /// * `props`: The properties to use.
    ///
    /// ## Return Value
    /// Returns a valid rendering context.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn initWithProperties(
        props: CreateProperties,
    ) !Renderer {
        const props_sdl = try props.toProperties();
        defer props_sdl.deinit();
        const ret = c.SDL_CreateRendererWithProperties(
            props_sdl.value,
        );
        return Renderer{ .value = try errors.wrapCallNull(*c.SDL_Renderer, ret) };
    }

    /// Create a 2D software rendering context for a surface.
    ///
    /// ## Function Parameters
    /// * `target_surface`: The surface structure representing the surface where rendering is done.
    ///
    /// ## Return Value
    /// Returns a valid rendering context.
    ///
    /// ## Remarks
    /// Two other API which can be used to create SDL_Renderer: `render.Renderer.init()` and `render.Renderer.initWithWindow()`.
    /// These can also create a software renderer, but they are intended to be used with a `video.Window` as the final destination and not a `surface.Surface`.
    ///
    /// Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// TODO!!!
    pub fn initSoftwareRenderer(
        target_surface: surface.Surface,
    ) !Renderer {
        const ret = c.SDL_CreateSoftwareRenderer(
            target_surface.value,
        );
        return Renderer{ .value = try errors.wrapCallNull(*c.SDL_Renderer, ret) };
    }

    /// Create a window and default renderer.
    ///
    /// ## Function Parameters
    /// * `title`: The title of the window, in UTF-8 encoding.
    /// * `width`: The width of the window.
    /// * `height`: The height of the window.
    /// * `window_flags`: The flags used to create the window.
    ///
    /// ## Return Value
    /// Returns the created window and renderer.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// TODO!!!
    pub fn initWithWindow(
        title: [:0]const u8,
        width: usize,
        height: usize,
        window_flags: video.Window.Flags,
    ) !struct { video.Window, Renderer } {
        var window: ?*c.SDL_Window = undefined;
        var renderer: ?*c.SDL_Renderer = undefined;
        const ret = c.SDL_CreateWindowAndRenderer(
            title,
            @intCast(width),
            @intCast(height),
            window_flags.toSdl(),
            &window,
            &renderer,
        );
        try errors.wrapCallBool(ret);
        return .{ .{ .value = window.? }, .{ .value = renderer.? } };
    }

    /// Update the screen with any rendering performed since the previous call.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Remarks
    /// SDL's rendering functions operate on a backbuffer; that is
    /// calling a rendering function such as `render.Renderer.renderLine()` does not directly put a line on the screen, but rather updates the backbuffer.
    /// As such, you compose your entire scene and present the composed backbuffer to the screen as a complete picture.
    ///
    /// Therefore, when using SDL's rendering API, one does all drawing intended for the frame,
    /// and then calls this function once per frame to present the final drawing to the user.
    ///
    /// The backbuffer should be considered invalidated after each present; do not assume that previous contents will exist between frames.
    /// You are strongly encouraged to call `render.Renderer.clear()` to initialize the backbuffer before starting each new frame's drawing,
    /// even if you plan to overwrite every pixel.
    ///
    /// Please note, that in case of rendering to a texture - there is no need to call this after drawing needed objects to a texture,
    /// and should not be done; you are only required to change back the rendering target to default via `renderer.Renderer.setTarget(null)` afterwards,
    /// as textures by themselves do not have a concept of backbuffers.
    /// Calling `render.Renderer.present()` while rendering to a texture will fail.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn present(
        self: Renderer,
    ) !void {
        const ret = c.SDL_RenderPresent(
            self.value,
        );
        return errors.wrapCallBool(ret);
    }

    /// Read pixels from the current rendering target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `capture_area`: Rectangle representing the area to read, which will be clipped to the current viewport, or `null` for the entire viewport.
    ///
    /// ## Return Value
    /// Returns a new surface on success.
    ///
    /// ## Remarks
    /// The returned surface contains pixels inside the desired area clipped to the current viewport, and should be freed with `surface.Surface.deinit().
    ///
    /// Note that this returns the actual pixels on the screen, so if you are using logical presentation you should use `renderer.Renderer.getLogicalPresentationRect()` to get
    /// the area containing your content.
    ///
    /// WARNING: This is a very slow operation, and should not be used frequently.
    /// If you're using this on the main rendering target, it should be called after rendering and before `render.Renderer.present()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn readPixels(
        self: Renderer,
        capture_area: ?rect.IRect,
    ) !surface.Surface {
        const capture_area_sdl: c.SDL_Rect = if (capture_area) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderReadPixels(
            self.value,
            if (capture_area != null) &capture_area_sdl else null,
        );
        return surface.Surface{ .value = try errors.wrapCallNull(*c.SDL_Surface, ret) };
    }

    /// Get a point in render coordinates when given a point in window coordinates.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `point`: The point to convert to render coordinates.
    ///
    /// ## Return Value
    /// Returns the render coordinates.
    ///
    /// ## Remarks
    /// This takes into account several states:
    /// * The window dimensions.
    /// * The logical presentation settings (`render.Renderer.setLogicalPresentation()`).
    /// * The scale (`render.Renderer.setScale()`).
    /// * The viewport (`render.Renderer.setViewport()`).
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderCoordinatesFromWindowCoordinates(
        self: Renderer,
        point: rect.FPoint,
    ) !rect.FPoint {
        var render_x: f32 = undefined;
        var render_y: f32 = undefined;
        const ret = c.SDL_RenderCoordinatesFromWindow(
            self.value,
            point.x,
            point.y,
            &render_x,
            &render_y,
        );
        try errors.wrapCallBool(ret);
        return .{ .x = render_x, .y = render_y };
    }

    /// Get a point in window coordinates when given a point in render coordinates.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `point`: The point to convert to window coordinates.
    ///
    /// ## Return Value
    /// Returns the window coordinates.
    ///
    /// ## Remarks
    /// This takes into account several states:
    /// * The window dimensions.
    /// * The logical presentation settings (`render.Renderer.setLogicalPresentation()`).
    /// * The scale (`render.Renderer.setScale()`).
    /// * The viewport (`render.Renderer.setViewport()`).
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderCoordinatesToWindowCoordinates(
        self: Renderer,
        point: rect.FPoint,
    ) !rect.FPoint {
        var window_x: f32 = undefined;
        var window_y: f32 = undefined;
        const ret = c.SDL_RenderCoordinatesToWindow(
            self.value,
            point.x,
            point.y,
            &window_x,
            &window_y,
        );
        try errors.wrapCallBool(ret);
        return .{ .x = window_x, .y = window_y };
    }

    /// Draw debug text to a renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw the text.
    /// * `top_left`: The top-left corner of the text will draw.
    /// * `str`: The string to render.
    ///
    /// ## Remarks
    /// This function will render a string of text to a renderer.
    /// Note that this is a convenience function for debugging, with severe limitations, and not intended to be used for production apps and games.
    ///
    /// Among these limitations:
    /// * It accepts UTF-8 strings, but will only render ASCII characters.
    /// * It has a single, tiny size (8x8 pixels). One can use logical presentation or scaling to adjust it, but it will be blurry.
    /// * It uses a simple, hardcoded bitmap font. It does not allow different font selections and it does not support truetype, for proper scaling.
    /// * It does no word-wrapping and does not treat newline characters as a line break. If the text goes out of the window, it's gone.
    ///
    /// For serious text rendering, there are several good options, such as `SDL_ttf`, `stb_truetype`, or other external libraries.
    ///
    /// On first use, this will create an internal texture for rendering glyphs.
    /// This texture will live until the renderer is destroyed.
    ///
    /// The text is drawn in the color specified by `render.Renderer.setDrawColor()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderDebugText(
        self: Renderer,
        top_left: rect.FPoint,
        str: [:0]const u8,
    ) !void {
        const ret = c.SDL_RenderDebugText(
            self.value,
            top_left.x,
            top_left.y,
            str.ptr,
        );
        return errors.wrapCallBool(ret);
    }

    /// Draw debug text to a renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw the text.
    /// * `top_left`: The top-left corner of the text will draw.
    /// * `fmt`: Print format for the debug text.
    /// * `args`: Arguments to the debug text format.
    ///
    /// ## Remarks
    /// This function will render formatted text to the target.
    /// Note that this is a convinence function for debugging, with severe limitations, and is not intended to be used for production apps and games.
    ///
    /// For the full list of limitations and other useful information, see `render.renderDebugText()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderDebugTextFormat(
        self: Renderer,
        top_left: rect.FPoint,
        comptime fmt: []const u8,
        args: anytype,
    ) !void {
        var fallback = std.heap.stackFallback(options.renderer_debug_text_stack_size, sdl3.allocator);
        const allocator = fallback.get();
        const msg = try std.fmt.allocPrintSentinel(allocator, fmt, args, 0);
        defer allocator.free(msg);
        const ret = c.SDL_RenderDebugText(
            self.value,
            top_left.x,
            top_left.y,
            msg.ptr,
        );
        return errors.wrapCallBool(ret);
    }

    /// Fill a rectangle on the current rendering target with the drawing color at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should fill a rectangle.
    /// * `dst_rect`: The destination rectangles to draw or `null` for the entire target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderFillRect(
        self: Renderer,
        dst_rect: ?rect.FRect,
    ) !void {
        const dst_rect_sdl: c.SDL_FRect = if (dst_rect) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderFillRect(
            self.value,
            if (dst_rect != null) &dst_rect_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Fill some number of rectangles on the current rendering target with the drawing color at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should fill multiple rectangles.
    /// * `rects`: The rectangles to draw.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderFillRects(
        self: Renderer,
        rects: []const rect.FRect,
    ) !void {
        const ret = c.SDL_RenderFillRects(
            self.value,
            @ptrCast(rects.ptr),
            @intCast(rects.len),
        );
        return errors.wrapCallBool(ret);
    }

    /// Render a list of triangles, optionally using a texture and indices into the vertex arrays Color and alpha modulation is done per vertex (texture color and texture alpha mod are ignored).
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `texture`: The optional texture to use.
    /// * `vertices`: Vertex positions.
    /// * `xy_positions_stride`: Byte size to move from one element to the next element.
    /// * `colors`: Vertex colors.
    /// * `colors_stride`: Byte size to move from one element to the next element.
    /// * `uv_coords`: Vertex normalized texture coordinates.
    /// * `uv_coords_stride`: Byte size to move from one element to the next element.
    /// * `num_vertices`: Number of vertices.
    /// * `indices`: An optional array of indices into the 'vertices' arrays, if `null` all vertices will be rendered in sequential order.
    /// * `num_indices`: Number of indices.
    /// * `bytes_per_index`: Size of an index in bytes.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderGeometry(
        self: Renderer,
        texture: ?Texture,
        vertices: []const Vertex,
        indices: ?[]const c_int,
    ) !void {
        const ret = c.SDL_RenderGeometry(
            self.value,
            if (texture) |texture_val| texture_val.value else null,
            @ptrCast(vertices.ptr),
            @intCast(vertices.len),
            if (indices) |val| val.ptr else null,
            if (indices) |val| @intCast(val.len) else 0,
        );
        return errors.wrapCallBool(ret);
    }

    /// Render a list of triangles, optionally using a texture and indices into the vertex arrays Color and alpha modulation is done per vertex (texture color and texture alpha mod are ignored).
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `texture`: The optional texture to use.
    /// * `xy_positions`: Vertex positions.
    /// * `xy_positions_stride`: Byte size to move from one element to the next element.
    /// * `colors`: Vertex colors.
    /// * `colors_stride`: Byte size to move from one element to the next element.
    /// * `uv_coords`: Vertex normalized texture coordinates.
    /// * `uv_coords_stride`: Byte size to move from one element to the next element.
    /// * `num_vertices`: Number of vertices.
    /// * `indices`: An optional array of indices into the 'vertices' arrays, if `null` all vertices will be rendered in sequential order.
    /// * `num_indices`: Number of indices.
    /// * `bytes_per_index`: Size of an index in bytes.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
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
        const ret = c.SDL_RenderGeometryRaw(
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
        return errors.wrapCallBool(ret);
    }

    /// Draw a line on the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw a line.
    /// * `start`: The start point.
    /// * `end`: The end point.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderLine(
        self: Renderer,
        start: rect.FPoint,
        end: rect.FPoint,
    ) !void {
        const ret = c.SDL_RenderLine(
            self.value,
            start.x,
            start.y,
            end.x,
            end.y,
        );
        return errors.wrapCallBool(ret);
    }

    /// Draw a series of connected lines on the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw multiple points.
    /// * `points`: The points along the lines.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderLines(
        self: Renderer,
        points: []const rect.FPoint,
    ) !void {
        const ret = c.SDL_RenderLines(
            self.value,
            @ptrCast(points.ptr),
            @intCast(points.len),
        );
        return errors.wrapCallBool(ret);
    }

    /// Draw a point on the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw a point.
    /// * `point`: The point to render.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderPoint(
        self: Renderer,
        point: rect.FPoint,
    ) !void {
        const ret = c.SDL_RenderPoint(
            self.value,
            point.x,
            point.y,
        );
        return errors.wrapCallBool(ret);
    }

    /// Draw multiple points on the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw multiple points.
    /// * `points`: The points to draw.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderPoints(
        self: Renderer,
        points: []const rect.FPoint,
    ) !void {
        const ret = c.SDL_RenderPoints(
            self.value,
            @ptrCast(points.ptr),
            @intCast(points.len),
        );
        return errors.wrapCallBool(ret);
    }

    /// Draw a rectangle on the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw a rectangle.
    /// * `dst`: Destination rectangle, or `null` for the entire target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderRect(
        self: Renderer,
        dst: ?rect.FRect,
    ) !void {
        const dst_sdl: c.SDL_FRect = if (dst) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderRect(
            self.value,
            if (dst != null) &dst_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Draw some number of rectangles on the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should draw multiple rectangles.
    /// * `rects`: Slice of destination rectangles.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderRects(
        self: Renderer,
        rects: []const rect.FRect,
    ) !void {
        const ret = c.SDL_RenderRects(
            self.value,
            @ptrCast(rects.ptr),
            @intCast(rects.len),
        );
        return errors.wrapCallBool(ret);
    }

    /// Copy a portion of the texture to the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should copy parts of a texture.
    /// * `texture`: The source texture.
    /// * `src_rect`: The source rectangle, or `null` for the entire texture.
    /// * `dst_rect`: The destination rectangle, or `null` for the entire target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderTexture(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        dst_rect: ?rect.FRect,
    ) !void {
        const src_rect_sdl: c.SDL_FRect = if (src_rect) |val| val.toSdl() else undefined;
        const dst_rect_sdl: c.SDL_FRect = if (dst_rect) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderTexture(
            self.value,
            texture.value,
            if (src_rect != null) &src_rect_sdl else null,
            if (dst_rect != null) &dst_rect_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Copy a portion of the source texture to the current rendering target, with affine transform, at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should copy parts of a texture.
    /// * `texture`: The source texture.
    /// * `src_rect`: The source rectangle, or `null` for the entire texture.
    /// * `left_width`: The width, in pixels, of the left corners in `src_rect`.
    /// * `right_width`: The width, in pixels, of the right corners in `src_rect`.
    /// * `top_width`: The width, in pixels, of the top corners in `src_rect`.
    /// * `bottom_width`: The width, in pixels, of the bottom corners in `src_rect`.
    /// * `scale`: The scale used to transform the corner of `src_rect` into the corner of `dst_rect`, or `0.0` for an unscaled copy.
    /// * `dst_rect`: The destination rectangle, or `null` for the entire target.
    pub fn renderTexture9GridTiled(
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
        const src_rect_sdl: c.SDL_FRect = if (src_rect) |val| val.toSdl() else undefined;
        const dst_rect_sdl: c.SDL_FRect = if (dst_rect) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderTexture9Grid(
            self.value,
            texture.value,
            if (src_rect != null) &src_rect_sdl else null,
            left_width,
            right_width,
            top_height,
            bottom_height,
            scale,
            if (dst_rect != null) &dst_rect_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    // /// Copy a portion of the source texture to the current rendering target, with affine transform, at subpixel precision.
    // ///
    // /// ## Function Parameters
    // /// * `self`: The renderer which should copy parts of a texture.
    // /// * `texture`: The source texture.
    // /// * `src_rect`: The source rectangle, or `null` for the entire texture.
    // /// * `left_width`: The width, in pixels, of the left corners in `src_rect`.
    // /// * `right_width`: The width, in pixels, of the right corners in `src_rect`.
    // /// * `top_width`: The width, in pixels, of the top corners in `src_rect`.
    // /// * `bottom_width`: The width, in pixels, of the bottom corners in `src_rect`.
    // /// * `scale`: The scale used to transform the corner of `src_rect` into the corner of `dst_rect`, or `0.0` for an unscaled copy.
    // /// * `dst_rect`: The destination rectangle, or `null` for the entire target.
    // /// * `tile_scale`: The scale used to transform the borders and center of `src_rect` into the borders and middle of `dst_rect`, or `1` for an unscaled copy.
    // pub fn renderTexture9GridTiled(
    //     self: Renderer,
    //     texture: Texture,
    //     src_rect: ?rect.FRect,
    //     left_width: f32,
    //     right_width: f32,
    //     top_height: f32,
    //     bottom_height: f32,
    //     scale: f32,
    //     dst_rect: ?rect.FRect,
    //     tile_scale: f32,
    // ) !void {
    //     const src_rect_sdl: c.SDL_FRect = if (src_rect) |val| val.toSdl() else undefined;
    //     const dst_rect_sdl: c.SDL_FRect = if (dst_rect) |val| val.toSdl() else undefined;
    //     const ret = c.SDL_RenderTexture9GridTiled(
    //         self.value,
    //         texture.value,
    //         if (src_rect != null) &src_rect_sdl else null,
    //         if (dst_rect != null) &dst_rect_sdl else null,
    //         angle,
    //         if (center != null) &center_sdl else null,
    //         flip_mode.toSdl(),
    //     );
    //     return errors.wrapCallBool(ret);
    // }

    /// Copy a portion of the source texture to the current rendering target, with affine transform, at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should copy parts of a texture.
    /// * `texture`: The source texture.
    /// * `src_rect`: The source rectangle, or `null` for the entire texture.
    /// * `origin`: A point indicating where the top-left corner of `src_rect` should be mapped to, or `null` for the rendering target's origin.
    /// * `right`: A point indicating where the top-right corner of `src_rect` should be mapped to, or `null` for the rendering target's top-right corner.
    /// * `down`: A point indicating where the bottom-left corner of `src_rect` should be mapped to, or `null` for the rendering target's bottom-left corner.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderTextureAffine(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        origin: ?rect.FPoint,
        right: ?rect.FPoint,
        down: ?rect.FPoint,
    ) !void {
        const src_rect_sdl: c.SDL_FRect = if (src_rect) |val| val.toSdl() else undefined;
        const origin_sdl: c.SDL_FPoint = if (origin) |val| val.toSdl() else undefined;
        const right_sdl: c.SDL_FPoint = if (right) |val| val.toSdl() else undefined;
        const down_sdl: c.SDL_FPoint = if (down) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderTextureAffine(
            self.value,
            texture.value,
            if (src_rect != null) &src_rect_sdl else null,
            if (origin != null) &origin_sdl else null,
            if (right != null) &right_sdl else null,
            if (down != null) &down_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Copy a portion of the source texture to the current rendering target, with rotation and flipping, at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should copy parts of a texture.
    /// * `texture`: The source texture.
    /// * `src_rect`: The source rectangle, or `null` for the entire texture.
    /// * `dst_rect`: The destination rectangle, or `null` for the entire target.
    /// * `angle`: An angle in degrees that indicates the rotation that will be applied to `dst_rect`, rotating it in a clockwise direction.
    /// * `center`: A point indicating the point around which `dst_rect` will be rotated (if `null`, rotation will be done around `dst_rect.w / 2`, `dst_rect.h / 2`).
    /// * `flip`: Which flipping actions should be performed on the texture.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderTextureRotated(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        dst_rect: ?rect.FRect,
        angle: f64,
        center: ?rect.FPoint,
        flip_mode: surface.FlipMode,
    ) !void {
        const src_rect_sdl: c.SDL_FRect = if (src_rect) |val| val.toSdl() else undefined;
        const dst_rect_sdl: c.SDL_FRect = if (dst_rect) |val| val.toSdl() else undefined;
        const center_sdl: c.SDL_FPoint = if (center) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderTextureRotated(
            self.value,
            texture.value,
            if (src_rect != null) &src_rect_sdl else null,
            if (dst_rect != null) &dst_rect_sdl else null,
            angle,
            if (center != null) &center_sdl else null,
            flip_mode.toSdl(),
        );
        return errors.wrapCallBool(ret);
    }

    /// Tile a portion of the texture to the current rendering target at subpixel precision.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer which should copy parts of a texture.
    /// * `texture`: The source texture.
    /// * `src_rect`: The source rectangle, or `null` for the entire texture.
    /// * `scale`: The scale used to transform `src_rect` into the destination rectangle, e.g. a 32x32 texture with a scale of 2 would fill 64x64 tiles.
    /// * `dst_rect`: The destination rectangle, or `null` for the entire target.
    ///
    /// ## Remarks
    /// The pixels in `src_rect` will be repeated as many times as needed to completely fill `dst_rect`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn renderTextureTiled(
        self: Renderer,
        texture: Texture,
        src_rect: ?rect.FRect,
        scale: f32,
        dst_rect: ?rect.FRect,
    ) !void {
        const src_rect_sdl: c.SDL_FRect = if (src_rect) |val| val.toSdl() else undefined;
        const dst_rect_sdl: c.SDL_FRect = if (dst_rect) |val| val.toSdl() else undefined;
        const ret = c.SDL_RenderTextureTiled(
            self.value,
            texture.value,
            if (src_rect != null) &src_rect_sdl else null,
            scale,
            if (dst_rect != null) &dst_rect_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set the clip rectangle for rendering on the specified target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `clipping`: A rect structure representing the clip area, relative to the viewport, or `null` to disable clipping.
    ///
    /// ## Remarks
    /// Each render target has its own clip rectangle.
    /// This function sets the cliprect for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setClipRect(
        self: Renderer,
        clipping: ?rect.IRect,
    ) !void {
        const clipping_sdl: c.SDL_Rect = if (clipping) |val| val.toSdl() else undefined;
        const ret = c.SDL_SetRenderClipRect(
            self.value,
            if (clipping != null) &clipping_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set the color scale used for render operations.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `scale`: The color scale value.
    ///
    /// ## Remarks
    /// The color scale is an additional scale multiplied into the pixel color value while rendering.
    /// This can be used to adjust the brightness of colors during HDR rendering, or changing HDR video brightness when playing on an SDR display.
    ///
    /// The color scale does not affect the alpha channel, only the color brightness.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setColorScale(
        self: Renderer,
        scale: f32,
    ) !void {
        const ret = c.SDL_SetRenderColorScale(
            self.value,
            @floatCast(scale),
        );
        return errors.wrapCallBool(ret);
    }

    // This is added in SDL 3.4.0.
    // /// Set default scale mode for new textures for given renderer.
    // ///
    // /// ## Function Parameters
    // /// * `self`: The renderer to update.
    // /// * `scale_mode`: The scale mode to change to for new textures.
    // ///
    // /// ## Remarks
    // /// When a renderer is created, `scale_mode` defaults to `surface.ScaleMode.linear`.
    // ///
    // /// ## Thread Safety
    // /// This function should only be called on the main thread.
    // ///
    // /// ## Version
    // /// This function is available since SDL 3.4.0.
    // pub fn setDefaultTextureScaleMode(
    //     self: Renderer,
    //     scale_mode: surface.ScaleMode,
    // ) !void {
    //     return errors.wrapCallBool(C.setscalemode)
    // }

    /// Set the blend mode used for drawing operations (Fill and Line).
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `mode`: The mode to use for blending.
    ///
    /// ## Remarks
    /// If the blend mode is not supported, the closest supported mode is chosen.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setDrawBlendMode(
        self: Renderer,
        mode: blend_mode.Mode,
    ) !void {
        const ret = c.SDL_SetRenderDrawBlendMode(
            self.value,
            blend_mode.Mode.toSdl(mode),
        );
        return errors.wrapCallBool(ret);
    }

    /// Set the color used for drawing operations (Rect, Line and Clear).
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `color`: Color used to draw on the rendering target.
    ///
    /// ## Remarks
    /// Set the color for drawing or filling rectangles, lines, and points, and for `render.Renderer.clear()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setDrawColor(
        self: Renderer,
        color: pixels.Color,
    ) !void {
        const ret = c.SDL_SetRenderDrawColor(
            self.value,
            color.r,
            color.g,
            color.b,
            color.a,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set the color used for drawing operations (Rect, Line and Clear).
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `color`: Color used to draw on the rendering target.
    ///
    /// ## Remarks
    /// Set the color for drawing or filling rectangles, lines, and points, and for `render.Renderer.clear()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setDrawColorFloat(
        self: Renderer,
        color: pixels.FColor,
    ) !void {
        const ret = c.SDL_SetRenderDrawColorFloat(
            self.value,
            color.r,
            color.g,
            color.b,
            color.a,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set a device independent resolution and presentation mode for rendering.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `width`: The width of the logical resolution.
    /// * `height`: The height of the logical resolution.
    /// * `presentation_mode`: The presentation mode used.
    ///
    /// ## Remarks
    /// This function sets the width and height of the logical rendering output.
    /// The renderer will act as if the current render target is always the requested dimensions, scaling to the actual resolution as necessary.
    ///
    /// This can be useful for games that expect a fixed size, but would like to scale the output to whatever is available, regardless of how a user resizes a window,
    /// or if the display is high DPI.
    ///
    /// Logical presentation can be used with both render target textures and the renderer's window; the state is unique to each render target,
    /// and this function sets the state for the current render target.
    /// It might be useful to draw to a texture that matches the window dimensions with logical presentation enabled,
    /// and then draw that texture across the entire window with logical presentation disabled.
    /// Be careful not to render both with logical presentation enabled, however, as this could produce double-letterboxing, etc.
    ///
    /// You can disable logical coordinates by setting the mode to `null`, and in that case you get the full pixel resolution of the render target;
    /// it is safe to toggle logical presentation during the rendering of a frame: perhaps most of the rendering is done to specific dimensions but to make fonts look sharp,
    /// the app turns off logical presentation while drawing text, for example.
    ///
    /// For the renderer's window, letterboxing is drawn into the framebuffer if logical presentation is enabled during `render.Renderer.present()`;
    /// be sure to reenable it before presenting if you were toggling it,
    /// otherwise the letterbox areas might have artifacts from previous frames (or artifacts from external overlays, etc).
    /// Letterboxing is never drawn into texture render targets; be sure to call `render.Renderer.clear()` before drawing into the texture so the letterboxing areas are cleared,
    /// if appropriate.
    ///
    /// You can convert coordinates in an event into rendering coordinates using `render.Renderer.convertEventToRenderCoordinates()`.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setLogicalPresentation(
        self: Renderer,
        width: usize,
        height: usize,
        presentation_mode: ?LogicalPresentation,
    ) !void {
        const ret = c.SDL_SetRenderLogicalPresentation(
            self.value,
            @intCast(width),
            @intCast(height),
            if (presentation_mode) |val| @intFromEnum(val) else c.SDL_LOGICAL_PRESENTATION_DISABLED,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set the drawing scale for rendering on the current target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `x`: The horizontal scaling factor.
    /// * `y`: The vertical scaling factor.
    ///
    /// ## Remarks
    /// The drawing coordinates are scaled by the x/y scaling factors before they are used by the renderer.
    /// This allows resolution independent drawing with a single coordinate system.
    ///
    /// If this results in scaling or subpixel drawing by the rendering backend, it will be handled using the appropriate quality hints.
    /// For best results use integer scaling factors.
    ///
    /// Each render target has its own scale.
    /// This function sets the scale for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setScale(
        self: Renderer,
        x: f32,
        y: f32,
    ) !void {
        const ret = c.SDL_SetRenderScale(
            self.value,
            x,
            y,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set a texture as the current rendering target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `target`: The targeted texture, which must be created with the `render.TextureAccess.target` flag, or `null` to render to the window instead of a texture.
    ///
    /// ## Remarks
    /// The default render target is the window for which the renderer was created.
    /// To stop rendering to a texture and render to the window again, call this function with a `null` texture.
    ///
    /// Viewport, cliprect, scale, and logical presentation are unique to each render target.
    /// Get and set functions for these states apply to the current render target set by this function,
    /// and those states persist on each target when the current render target changes.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setTarget(
        self: Renderer,
        target: ?Texture,
    ) !void {
        const ret = c.SDL_SetRenderTarget(
            self.value,
            if (target) |target_val| target_val.value else null,
        );
        return errors.wrapCallBool(ret);
    }

    // SetRenderTextureAddressMode added in SDL 3.4.0.

    /// Set the drawing area for rendering on the current target.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    /// * `viewport`: The structure representing the drawing area, or `null` to set the viewport to the entire target.
    ///
    /// ## Remarks
    /// Drawing will clip to this area (separately from any clipping done with `render.Renderer.setClipRect()`),
    /// and the top left of the area will become coordinate `(0, 0)` for future drawing commands.
    ///
    /// The area's width and height must be `>= 0`.
    ///
    /// Each render target has its own viewport. This function sets the viewport for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setViewport(
        self: Renderer,
        viewport: ?rect.IRect,
    ) !void {
        const viewport_sdl: c.SDL_Rect = if (viewport) |val| val.toSdl() else undefined;
        const ret = c.SDL_SetRenderViewport(
            self.value,
            if (viewport != null) &viewport_sdl else null,
        );
        return errors.wrapCallBool(ret);
    }

    /// Toggle VSync of the given renderer.
    ///
    /// ## Function Parameters
    /// * `self`: The renderer to toggle.
    /// * `vsync`: The vertical refresh sync interval.
    ///
    /// ## Remarks
    /// When a renderer is created, vsync defaults to `render.Vsync.disabled`.
    ///
    /// Not every value is supported by every driver, so you should check for errors to see whether the requested setting is supported.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setVSync(
        self: Renderer,
        vsync: ?video.VSync,
    ) !void {
        const ret = c.SDL_SetRenderVSync(self.value, video.VSync.toSdl(vsync));
        return errors.wrapCallBool(ret);
    }

    /// Return whether an explicit rectangle was set as the viewport.
    ///
    /// ## Function Parameters
    /// * `self`: The rendering context.
    ///
    /// ## Return Value
    /// Returns true if the viewport was set to a specific rectangle, or false if it was set to `null` (the entire target).
    ///
    /// ## Remarks
    /// This is useful if you're saving and restoring the viewport and want to know whether you should restore a specific rectangle or `null`.
    ///
    /// Each render target has its own viewport. This function checks the viewport for the current render target.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn viewportSet(
        self: Renderer,
    ) bool {
        return c.SDL_RenderViewportSet(self.value);
    }

    // SetRenderGPUState is added in SDL 3.4.0.

};

/// How the logical size is mapped to the output.
///
/// ## Version
/// This enum is available since SDL 3.2.0.
pub const LogicalPresentation = enum(c.SDL_RendererLogicalPresentation) {
    /// The rendered content is stretched to the output resolution.
    stretch = c.SDL_LOGICAL_PRESENTATION_STRETCH,
    /// The rendered content is fit to the largest dimension and the other dimension is letterboxed with black bars.
    letter_box = c.SDL_LOGICAL_PRESENTATION_LETTERBOX,
    /// The rendered content is fit to the smallest dimension and the other dimension extends beyond the output bounds.
    overscan = c.SDL_LOGICAL_PRESENTATION_OVERSCAN,
    /// The rendered content is scaled up by integer multiples to fit the output resolution.
    integer_scale = c.SDL_LOGICAL_PRESENTATION_INTEGER_SCALE,

    /// Convert from an SDL.
    pub fn fromSdl(value: c.SDL_RendererLogicalPresentation) ?LogicalPresentation {
        if (value == c.SDL_LOGICAL_PRESENTATION_DISABLED)
            return null;
        return @enumFromInt(value);
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: ?LogicalPresentation) c.SDL_RendererLogicalPresentation {
        if (self) |val|
            return @intFromEnum(val);
        return c.SDL_LOGICAL_PRESENTATION_DISABLED;
    }
};

/// An efficient driver-specific representation of pixel data.
///
/// ## Remarks
/// Note that the reference count will be `1` when initialized, and decremented on each call to `render.Texture.deinit()`.
/// An application is free to increment the reference count when an additional uses is added, just be sure it has a corresponding deinit call.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Texture = struct {
    value: *c.SDL_Texture,

    /// The access pattern allowed for a texture.
    ///
    /// ## Version
    /// This enum is available since SDL 3.2.0.
    pub const Access = enum(c.SDL_TextureAccess) {
        /// Changes rarely, not lockable.
        static = c.SDL_TEXTUREACCESS_STATIC,
        /// Changes frequently, lockable.
        streaming = c.SDL_TEXTUREACCESS_STREAMING,
        /// Texture can be used as a render target.
        target = c.SDL_TEXTUREACCESS_TARGET,
    };

    /// Properties associated with a texture.
    ///
    /// ## Version
    /// Provided by zig-sdl3.
    pub const CreateProperties = struct {
        /// An colorspace value describing the texture colorspace, defaults to `pixels.Colorspace.srgb_linear` for floating point textures,
        /// `pixels.Colorspace.hdr10` for 10-bit textures, `pixels.Colorspace.srgb` for other RGB textures and `pixels.Colorspace.jpeg` for YUV textures.
        colorspace: ?pixels.Colorspace = null,
        /// Pixel format to use.
        format: ?struct { value: ?pixels.Format } = null,
        /// Texture access mode.
        access: ?Access = null,
        /// The width of the texture in pixels, required.
        width: ?usize = null,
        /// The height of the texture in pixels, required.
        height: ?usize = null,
        /// Tor HDR10 and floating point textures, this defines the value of 100% diffuse white, with higher values being displayed in the High Dynamic Range headroom.
        /// This defaults to `100` for HDR10 textures and `1` for floating point textures.
        sdr_white_point: ?f32 = null,
        /// For HDR10 and floating point textures, this defines the maximum dynamic range used by the content, in terms of the SDR white point.
        /// This would be equivalent to maxCLL / `render.Texture.CreateProperties.sdr_white_point` for HDR10 content.
        /// If this is defined, any values outside the range supported by the display will be scaled into the available HDR headroom, otherwise they are clipped.
        hdr_headroom: ?f32 = null,
        /// The `ID3D11Texture2D` associated with the texture, if you want to wrap an existing texture.
        d3d11_texture: ?struct { value: ?*anyopaque } = null,
        /// The `ID3D11Texture2D` associated with the U plane of a YUV texture, if you want to wrap an existing texture.
        d3d11_texture_u: ?struct { value: ?*anyopaque } = null,
        /// The `ID3D11Texture2D` associated with the V plane of a YUV texture, if you want to wrap an existing texture.
        d3d11_texture_v: ?struct { value: ?*anyopaque } = null,
        /// The `ID3D12Resource` associated with the texture, if you want to wrap an existing texture.
        d3d12_texture: ?struct { value: ?*anyopaque } = null,
        /// The `ID3D12Resource` associated with the U plane of a YUV texture, if you want to wrap an existing texture.
        d3d12_texture_u: ?struct { value: ?*anyopaque } = null,
        /// The `ID3D12Resource` associated with the V plane of a YUV texture, if you want to wrap an existing texture.
        d3d12_texture_v: ?struct { value: ?*anyopaque } = null,
        /// The `CVPixelBufferRef` associated with the texture, if you want to create a texture from an existing pixel buffer.
        metal_pixelbuffer: ?struct { value: ?*anyopaque } = null,
        /// The `GLuint` texture associated with the texture, if you want to wrap an existing texture.
        opengl_texture: ?i64 = null,
        /// The `GLuint` texture associated with the UV plane of an NV12 texture, if you want to wrap an existing texture.
        opengl_texture_uv: ?i64 = null,
        /// The `GLuint` texture associated with the U plane of a YUV texture, if you want to wrap an existing texture.
        opengl_texture_u: ?i64 = null,
        /// The `GLuint` texture associated with the V plane of a YUV texture, if you want to wrap an existing texture.
        opengl_texture_v: ?i64 = null,
        /// The `GLuint` texture associated with the texture, if you want to wrap an existing texture.
        opengles2_texture: ?i64 = null,
        /// The `GLuint` texture associated with the UV plane of an NV12 texture, if you want to wrap an existing texture.
        opengles2_texture_uv: ?i64 = null,
        /// The `GLuint` texture associated with the U plane of a YUV texture, if you want to wrap an existing texture.
        opengles2_texture_u: ?i64 = null,
        /// The `GLuint` texture associated with the V plane of a YUV texture, if you want to wrap an existing texture.
        opengles2_texture_v: ?i64 = null,
        /// The `VkImage` with layout `VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL` associated with the texture, if you want to wrap an existing texture.
        vulkan_texture: ?i64 = null,

        /// Convert to SDL.
        pub fn toProperties(
            self: CreateProperties,
        ) !properties.Group {
            const ret = try properties.Group.init();
            if (self.colorspace) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_COLORSPACE_NUMBER, .{ .number = @intFromEnum(val) });
            if (self.format) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_FORMAT_NUMBER, .{ .number = pixels.Format.toSdl(val.value) });
            if (self.access) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_ACCESS_NUMBER, .{ .number = @intFromEnum(val) });
            if (self.width) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_WIDTH_NUMBER, .{ .number = @intCast(val) });
            if (self.height) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_HEIGHT_NUMBER, .{ .number = @intCast(val) });
            if (self.sdr_white_point) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_SDR_WHITE_POINT_FLOAT, .{ .float = val });
            if (self.hdr_headroom) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_HDR_HEADROOM_FLOAT, .{ .float = val });
            if (self.d3d11_texture) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_POINTER, .{ .pointer = val.value });
            if (self.d3d11_texture_u) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_U_POINTER, .{ .pointer = val.value });
            if (self.d3d11_texture_v) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_D3D11_TEXTURE_V_POINTER, .{ .pointer = val.value });
            if (self.d3d12_texture) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_POINTER, .{ .pointer = val.value });
            if (self.d3d12_texture_u) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_U_POINTER, .{ .pointer = val.value });
            if (self.d3d12_texture_v) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_D3D12_TEXTURE_V_POINTER, .{ .pointer = val.value });
            if (self.metal_pixelbuffer) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_METAL_PIXELBUFFER_POINTER, .{ .pointer = val.value });
            if (self.opengl_texture) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_NUMBER, .{ .number = val });
            if (self.opengl_texture_uv) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_UV_NUMBER, .{ .number = val });
            if (self.opengl_texture_u) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_U_NUMBER, .{ .number = val });
            if (self.opengl_texture_v) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGL_TEXTURE_V_NUMBER, .{ .number = val });
            if (self.opengles2_texture) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_NUMBER, .{ .number = val });
            if (self.opengles2_texture_uv) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_UV_NUMBER, .{ .number = val });
            if (self.opengles2_texture_u) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_U_NUMBER, .{ .number = val });
            if (self.opengles2_texture_v) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_OPENGLES2_TEXTURE_V_NUMBER, .{ .number = val });
            if (self.vulkan_texture) |val|
                try ret.set(c.SDL_PROP_TEXTURE_CREATE_VULKAN_TEXTURE_NUMBER, .{ .number = val });
            return ret;
        }
    };

    /// Properties associated with a texture.
    ///
    /// ## Version
    /// Provided by zig-sdl3.
    pub const Properties = struct {
        /// Value describing texture colorspace.
        colorspace: ?pixels.Colorspace,
        /// Pixel format.
        format: ?struct { value: ?pixels.Format },
        /// Texture access.
        access: ?Access,
        /// The width of the texture in pixels.
        width: ?usize,
        /// The height of the texture in pixels.
        height: ?usize,
        /// For HDR10 and floating point textures, this defines the value of 100% diffuse white, with higher values being displayed in the High Dynamic Range headroom.
        /// This defaults to `100` for HDR10 textures and `1` for other textures.
        sdr_white_point: ?f32,
        /// Tor HDR10 and floating point textures, this defines the maximum dynamic range used by the content, in terms of the SDR white point.
        /// If this is defined, any values outside the range supported by the display will be scaled into the available HDR headroom, otherwise they are clipped.
        /// This defaults to `1` for SDR textures, `4` for HDR10 textures, and no default for floating point textures.
        hdr_headroom: ?f32,
        /// The `ID3D11Texture2D` associated with the texture.
        d3d11_texture: ?struct { value: ?*anyopaque },
        /// The `ID3D11Texture2D` associated with the U plane of a YUV texture.
        d3d11_texture_u: ?struct { value: ?*anyopaque },
        /// The `ID3D11Texture2D` associated with the V plane of a YUV texture.
        d3d11_texture_v: ?struct { value: ?*anyopaque },
        /// The `ID3D12Resource` associated with the texture.
        d3d12_texture: ?struct { value: ?*anyopaque },
        /// The `ID3D12Resource` associated with the U plane of a YUV texture.
        d3d12_texture_u: ?struct { value: ?*anyopaque },
        /// The `ID3D12Resource` associated with the V plane of a YUV texture.
        d3d12_texture_v: ?struct { value: ?*anyopaque },
        /// The `VkImage` associated with the texture.
        vulkan_texture: ?i64,
        /// The `GLuint` texture associated with the texture.
        opengl_texture: ?i64,
        /// The `GLuint` texture associated with the UV plane of an NV12 texture.
        opengl_texture_uv: ?i64,
        /// The `GLuint` texture associated with the U plane of a YUV texture.
        opengl_texture_u: ?i64,
        /// The `GLuint` texture associated with the V plane of a YUV texture.
        opengl_texture_v: ?i64,
        /// The `GLenum` for the texture target (`GL_TEXTURE_2D`, `GL_TEXTURE_RECTANGLE_ARB`, etc).
        opengl_texture_target: ?i64,
        /// The texture coordinate wdigth of the texture (`0` - `1`).
        opengl_tex_w: ?f32,
        /// The texture coordinate height of the texture (`0` - `1`).
        opengl_tex_h: ?f32,
        /// The `GLuint` texture associated with the texture.
        opengles2_texture: ?i64,
        /// The `GLuint` texture associated with the UV plane of an NV12 texture.
        opengles2_texture_uv: ?i64,
        /// The `GLuint` texture associated with the U plane of a YUV texture.
        opengles2_texture_u: ?i64,
        /// The `GLuint` texture associated with the V plane of a YUV texture.
        opengles2_texture_v: ?i64,
        /// The `GLenum` for the texture target (`GL_TEXTURE_2D`, `GL_TEXTURE_EXTERNAL_OES`, etc).
        opengles2_texture_target: ?i64,

        /// Create from SDL.
        pub fn fromProperties(
            props: properties.Group,
        ) Properties {
            return .{
                .colorspace = if (props.get(c.SDL_PROP_TEXTURE_COLORSPACE_NUMBER)) |val| @enumFromInt(val.number) else null,
                .format = if (props.get(c.SDL_PROP_TEXTURE_FORMAT_NUMBER)) |val| .{ .value = pixels.Format.fromSdl(@intCast(val.number)) } else null,
                .access = if (props.get(c.SDL_PROP_TEXTURE_ACCESS_NUMBER)) |val| @enumFromInt(val.number) else null,
                .width = if (props.get(c.SDL_PROP_TEXTURE_WIDTH_NUMBER)) |val| @intCast(val.number) else null,
                .height = if (props.get(c.SDL_PROP_TEXTURE_HEIGHT_NUMBER)) |val| @intCast(val.number) else null,
                .sdr_white_point = if (props.get(c.SDL_PROP_TEXTURE_SDR_WHITE_POINT_FLOAT)) |val| val.float else null,
                .hdr_headroom = if (props.get(c.SDL_PROP_TEXTURE_HDR_HEADROOM_FLOAT)) |val| val.float else null,
                .d3d11_texture = if (props.get(c.SDL_PROP_TEXTURE_D3D11_TEXTURE_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d11_texture_u = if (props.get(c.SDL_PROP_TEXTURE_D3D11_TEXTURE_U_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d11_texture_v = if (props.get(c.SDL_PROP_TEXTURE_D3D11_TEXTURE_V_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d12_texture = if (props.get(c.SDL_PROP_TEXTURE_D3D12_TEXTURE_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d12_texture_u = if (props.get(c.SDL_PROP_TEXTURE_D3D12_TEXTURE_U_POINTER)) |val| .{ .value = val.pointer } else null,
                .d3d12_texture_v = if (props.get(c.SDL_PROP_TEXTURE_D3D12_TEXTURE_V_POINTER)) |val| .{ .value = val.pointer } else null,
                .vulkan_texture = if (props.get(c.SDL_PROP_TEXTURE_VULKAN_TEXTURE_NUMBER)) |val| val.number else null,
                .opengl_texture = if (props.get(c.SDL_PROP_TEXTURE_OPENGL_TEXTURE_NUMBER)) |val| val.number else null,
                .opengl_texture_uv = if (props.get(c.SDL_PROP_TEXTURE_OPENGL_TEXTURE_UV_NUMBER)) |val| val.number else null,
                .opengl_texture_u = if (props.get(c.SDL_PROP_TEXTURE_OPENGL_TEXTURE_U_NUMBER)) |val| val.number else null,
                .opengl_texture_v = if (props.get(c.SDL_PROP_TEXTURE_OPENGL_TEXTURE_V_NUMBER)) |val| val.number else null,
                .opengl_texture_target = if (props.get(c.SDL_PROP_TEXTURE_OPENGL_TEXTURE_TARGET_NUMBER)) |val| val.number else null,
                .opengl_tex_w = if (props.get(c.SDL_PROP_TEXTURE_OPENGL_TEX_W_FLOAT)) |val| val.float else null,
                .opengl_tex_h = if (props.get(c.SDL_PROP_TEXTURE_OPENGL_TEX_H_FLOAT)) |val| val.float else null,
                .opengles2_texture = if (props.get(c.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_NUMBER)) |val| val.number else null,
                .opengles2_texture_uv = if (props.get(c.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_UV_NUMBER)) |val| val.number else null,
                .opengles2_texture_u = if (props.get(c.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_U_NUMBER)) |val| val.number else null,
                .opengles2_texture_v = if (props.get(c.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_V_NUMBER)) |val| val.number else null,
                .opengles2_texture_target = if (props.get(c.SDL_PROP_TEXTURE_OPENGLES2_TEXTURE_TARGET_NUMBER)) |val| val.number else null,
            };
        }
    };

    /// Destroy the specified texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to destroy.
    ///
    /// ## Remarks
    /// Passing an otherwise invalid texture will set the SDL error message to "Invalid texture".
    ///
    /// This will decrement the reference count of the texture, and only destroy it if the reference count is at 1.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn deinit(
        self: Texture,
    ) void {
        c.SDL_DestroyTexture(self.value);
    }

    /// Get the additional alpha value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The current alpha value.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getAlphaMod(
        self: Texture,
    ) !u8 {
        var alpha: u8 = undefined;
        const ret = c.SDL_GetTextureAlphaMod(
            self.value,
            &alpha,
        );
        try errors.wrapCallBool(ret);
        return alpha;
    }

    /// Get the additional alpha value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The current alpha value.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getAlphaModFloat(
        self: Texture,
    ) !f32 {
        var alpha: f32 = undefined;
        const ret = c.SDL_GetTextureAlphaModFloat(
            self.value,
            &alpha,
        );
        try errors.wrapCallBool(ret);
        return alpha;
    }

    /// Get the blend mode used for texture copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The current blend mode.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getBlendMode(
        self: Texture,
    ) !?blend_mode.Mode {
        var mode: c.SDL_BlendMode = undefined;
        const ret = c.SDL_GetTextureBlendMode(
            self.value,
            &mode,
        );
        try errors.wrapCallBool(ret);
        return blend_mode.Mode.fromSdl(mode);
    }

    /// Get the additional color value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The current color value.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getColorMod(
        self: Texture,
    ) !struct { r: u8, g: u8, b: u8 } {
        var r: u8 = undefined;
        var g: u8 = undefined;
        var b: u8 = undefined;
        const ret = c.SDL_GetTextureColorMod(
            self.value,
            &r,
            &g,
            &b,
        );
        try errors.wrapCallBool(ret);
        return .{ .r = r, .g = g, .b = b };
    }

    /// Get the additional color value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The current color value.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getColorModFloat(
        self: Texture,
    ) !struct { r: f32, g: f32, b: f32 } {
        var r: f32 = undefined;
        var g: f32 = undefined;
        var b: f32 = undefined;
        const ret = c.SDL_GetTextureColorModFloat(
            self.value,
            &r,
            &g,
            &b,
        );
        try errors.wrapCallBool(ret);
        return .{ .r = r, .g = g, .b = b };
    }

    /// Get the format of the texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture.
    ///
    /// ## Return Value
    /// The format of the texture.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getFormat(
        self: Texture,
    ) ?pixels.Format {
        return pixels.Format.fromSdl(self.value.format);
    }

    /// Get the height of the texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture.
    ///
    /// ## Return Value
    /// The height of the texture.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getHeight(
        self: Texture,
    ) usize {
        return @intCast(self.value.h);
    }

    /// Get the properties associated with a texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The read-only properties of the texture.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getProperties(
        self: Texture,
    ) !Properties {
        const ret = c.SDL_GetTextureProperties(
            self.value,
        );
        return Properties.fromProperties(.{ .value = try errors.wrapCall(c.SDL_PropertiesID, ret, 0) });
    }

    /// Get the reference count of the texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture.
    ///
    /// ## Return Value
    /// The reference count of the texture.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getRefCount(
        self: Texture,
    ) usize {
        return @intCast(self.value.refcount);
    }

    /// Get the renderer that created the texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The renderer that created this texture.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getRenderer(
        self: Texture,
    ) !Renderer {
        const ret = c.SDL_GetRendererFromTexture(
            self.value,
        );
        return Renderer{ .value = try errors.wrapCallNull(*c.SDL_Renderer, ret) };
    }

    /// Get the scale mode used for texture scale operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The current scale mode.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getScaleMode(
        self: Texture,
    ) !surface.ScaleMode {
        var mode: c.SDL_ScaleMode = undefined;
        const ret = c.SDL_GetTextureScaleMode(
            self.value,
            &mode,
        );
        try errors.wrapCallBool(ret);
        return @enumFromInt(mode);
    }

    /// Get the size of a texture, as floating point values.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to query.
    ///
    /// ## Return Value
    /// The width and height of the texture in pixels in that order.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getSize(
        self: Texture,
    ) !struct { f32, f32 } {
        var w: f32 = undefined;
        var h: f32 = undefined;
        const ret = c.SDL_GetTextureSize(
            self.value,
            &w,
            &h,
        );
        try errors.wrapCallBool(ret);
        return .{ w, h };
    }

    /// Get the width of the texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture.
    ///
    /// ## Return Value
    /// The width of the texture.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn getWidth(
        self: Texture,
    ) usize {
        return @intCast(self.value.w);
    }

    /// Increment the ref count of the texture.
    ///
    /// ## Function Parameters
    /// * `self`: The texture.
    ///
    /// ## Remarks
    /// All calls to this function must be matched with `render.Texture.deinit()`.
    ///
    /// ## Thread Safety
    /// This function is not thread safe.
    ///
    /// ## Version
    /// This function is provided by zig-sdl3.
    pub fn incrementRefCount(
        self: Texture,
    ) void {
        self.value.refcount += 1;
    }

    /// Create a texture for a rendering context.
    ///
    /// ## Function Parameters
    /// * `renderer`: The rendering context.
    /// * `format`: Pixel format of the texture.
    /// * `access`: Access method for the texture.
    /// * `width`: The width of the texture in pixels.
    /// * `height`: The height of the texture in pixels.
    ///
    /// ## Return Value
    /// Returns the created texture.
    ///
    /// ## Remarks
    /// The contents of a texture when first created are not defined.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    ///
    /// ## Code Examples
    /// TODO!!!
    pub fn init(
        renderer: Renderer,
        format: pixels.Format,
        access: Access,
        width: usize,
        height: usize,
    ) !Texture {
        return .{ .value = try errors.wrapCallNull(*c.SDL_Texture, c.SDL_CreateTexture(
            renderer.value,
            pixels.Format.toSdl(format),
            @intFromEnum(access),
            @intCast(width),
            @intCast(height),
        )) };
    }

    /// Create a texture for a rendering context with the specified properties.
    ///
    /// ## Function Parameters
    /// * `renderer`: The rendering context.
    /// * `props`: The properties to use.
    ///
    /// ## Return Value
    /// Returns the created texture.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn initWithProperties(
        renderer: Renderer,
        props: CreateProperties,
    ) !Texture {
        const props_sdl = try props.toProperties();
        defer props_sdl.deinit();
        const ret = c.SDL_CreateTextureWithProperties(
            renderer.value,
            props_sdl.value,
        );
        return Texture{ .value = try errors.wrapCallNull(*c.SDL_Texture, ret) };
    }

    /// Lock a portion of the texture for write-only pixel access.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `update_area`: The rectangle representing the area to lock for access, or `null` to lock the entire texture.
    ///
    /// ## Return Value
    /// Returns a pointer to the raw pixel data along with the pitch.
    /// The pitch is the length of one row in bytes.
    ///
    /// ## Remarks
    /// The texture must be created to allow streaming access in its `render.AccessMode`.
    /// As an optimization, the pixels made available for editing don't necessarily contain the old texture data.
    /// This is a write-only operation, and if you need to keep a copy of the texture data you should do that at the application level.
    ///
    /// You must use `render.Texture.unlock()` to unlock the pixels and apply any changes.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn lock(
        self: Texture,
        update_area: ?rect.IRect,
    ) !struct { [*]u8, usize } {
        const update_area_sdl: c.SDL_Rect = if (update_area) |val| val.toSdl() else undefined;
        var data: ?*anyopaque = undefined;
        var pitch: c_int = undefined;
        const ret = c.SDL_LockTexture(
            self.value,
            if (update_area != null) &update_area_sdl else null,
            &data,
            &pitch,
        );
        try errors.wrapCallBool(ret);
        return .{ @ptrCast(@alignCast(data)), @intCast(pitch) };
    }

    /// Lock a portion of the texture for write-only pixel access, and expose it as a SDL surface.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `update_area`: The rectangle representing the area to lock for access, or `null` to lock the entire texture.
    ///
    /// ## Return Value
    /// Returns an SDL surface of size `update_area`.
    /// Don't assume any specific pixel content.
    ///
    /// ## Remarks
    /// Besides providing a surface instead of raw pixel data, this function operates like `render.Texture.lock()`.
    ///
    /// As an optimization, the pixels made available for editing don't necessarily contain the old texture data.
    /// This is a write-only operation, and if you need to keep a copy of the texture data you should do that at the application level.
    ///
    /// You must use `render.Texture.unlock()` to unlock the pixels and apply any changes.
    ///
    /// The returned surface is freed internally after calling `render.Texture.unlock()` or `render.Texture.deinit()`.
    /// The caller should not free it.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn lockToSurface(
        self: Texture,
        update_area: ?rect.IRect,
    ) !surface.Surface {
        const update_area_sdl: c.SDL_Rect = if (update_area) |val| val.toSdl() else undefined;
        var data: [*c]c.SDL_Surface = undefined;
        const ret = c.SDL_LockTextureToSurface(
            self.value,
            if (update_area != null) &update_area_sdl else null,
            &data,
        );
        try errors.wrapCallBool(ret);
        return .{ .value = data };
    }

    /// Set an additional alpha value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `alpha`: The source alpha value multiplied into copy operations.
    ///
    /// ## Remarks
    /// When this texture is rendered, during the copy operation the source alpha value is modulated by this alpha value according to the following formula:
    /// `srcC = srcA * (alpha / 255)`
    ///
    /// Alpha modulation is not always supported by the renderer; it will error if alpha modulation is not supported.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setAlphaMod(
        self: Texture,
        alpha: u8,
    ) !void {
        const ret = c.SDL_SetTextureAlphaMod(
            self.value,
            alpha,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set an additional alpha value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `alpha`: The source alpha value multiplied into copy operations.
    ///
    /// ## Remarks
    /// When this texture is rendered, during the copy operation the source alpha value is modulated by this alpha value according to the following formula:
    /// `srcC = srcA * alpha`
    ///
    /// Alpha modulation is not always supported by the renderer; it will error if alpha modulation is not supported.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setAlphaModFloat(
        self: Texture,
        alpha: f32,
    ) !void {
        const ret = c.SDL_SetTextureAlphaModFloat(
            self.value,
            alpha,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set the blend mode for a texture, used by `renderer.renderTexture`.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `blend_mode`: The blend mode to use for texture blending.
    ///
    /// ## Remarks
    /// If the blend mode is not supported, the closest supported mode is chosen and this function returns an error.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setBlendMode(
        self: Texture,
        mode: blend_mode.Mode,
    ) !void {
        const ret = c.SDL_SetTextureBlendMode(
            self.value,
            blend_mode.Mode.toSdl(mode),
        );
        return errors.wrapCallBool(ret);
    }

    /// Set an additional color value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `r`: The red color value multiplied into copy operations.
    /// * `g`: The green color value multiplied into copy operations.
    /// * `b`: The blue color value multiplied into copy operations.
    ///
    /// ## Remarks
    /// When this texture is rendered, during the copy operation each source color channel is modulated by the appropriate color value according to the following formula:
    /// `srcC = srcC * (color / 255)`
    ///
    /// Color modulation is not always supported by the renderer; it will error if color modulation is not supported.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setColorMod(
        self: Texture,
        r: u8,
        g: u8,
        b: u8,
    ) !void {
        const ret = c.SDL_SetTextureColorMod(
            self.value,
            r,
            g,
            b,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set an additional color value multiplied into render copy operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `r`: The red color value multiplied into copy operations.
    /// * `g`: The green color value multiplied into copy operations.
    /// * `b`: The blue color value multiplied into copy operations.
    ///
    /// ## Remarks
    /// When this texture is rendered, during the copy operation each source color channel is modulated by the appropriate color value according to the following formula:
    /// `srcC = srcC * color`
    ///
    /// Color modulation is not always supported by the renderer; it will error if color modulation is not supported.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setColorModFloat(
        self: Texture,
        r: f32,
        g: f32,
        b: f32,
    ) !void {
        const ret = c.SDL_SetTextureColorModFloat(
            self.value,
            r,
            g,
            b,
        );
        return errors.wrapCallBool(ret);
    }

    /// Set the scale mode used for texture scale operations.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `mode`: The mode to use for texture scaling.
    ///
    /// ## Remarks
    /// The default texture scale mode is `surface.ScaleMode.linear`.
    ///
    /// If the scale mode is not supported, the closest supported mode is chosen.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setScaleMode(
        self: Texture,
        mode: surface.ScaleMode,
    ) !void {
        const ret = c.SDL_SetTextureScaleMode(
            self.value,
            @intCast(@intFromEnum(mode)),
        );
        return errors.wrapCallBool(ret);
    }

    /// Unlock a texture, uploading the changes to video memory, if needed.
    ///
    /// ## Function Parameters
    /// * `self`: The locked texture.
    ///
    /// ## Remarks
    /// Warning: Please note that `render.Texture.lock()` is intended to be write-only; it will not guarantee the previous contents of the texture will be provided.
    /// You must fully initialize any area of a texture that you lock before unlocking it, as the pixels might otherwise be uninitialized memory.
    ///
    /// Which is to say: locking and immediately unlocking a texture can result in corrupted textures, depending on the renderer in use.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn unlock(
        self: Texture,
    ) void {
        c.SDL_UnlockTexture(
            self.value,
        );
    }

    /// Update the given texture rectangle with new pixel data.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `update_area`: The rectangle of pixels to update, or `null` to update the entire texture.
    /// * `data`: The raw pixel data in the format of the texture.
    /// * `pitch`: The number of bytes in a row of pixel data, including padding between lines.
    ///
    /// ## Remarks
    /// The pixel data must be in the pixel format of the texture, which can be queried using the `format` property.
    ///
    /// This is a fairly slow function, intended for use with static textures that do not change often.
    ///
    /// If the texture is intended to be updated often, it is preferred to create the texture as streaming and use the locking functions referenced below.
    /// While this function will work with streaming textures, for optimization reasons you may not get the pixels back if you lock the texture afterward.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn update(
        self: Texture,
        update_area: ?rect.IRect,
        data: [*]const u8,
        pitch: usize,
    ) !void {
        const update_area_sdl: c.SDL_Rect = if (update_area) |val| val.toSdl() else undefined;
        const ret = c.SDL_UpdateTexture(
            self.value,
            if (update_area != null) &update_area_sdl else null,
            data,
            @intCast(pitch),
        );
        return errors.wrapCallBool(ret);
    }

    /// Update a rectangle within a planar NV12 or NV21 texture with new pixels.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `update_area`: The rectangle of pixels to update, or `null` to update the entire texture.
    /// * `y_data`: The raw pixel data for the Y plane.
    /// * `y_pitch`: The number of bytes between rows of pixel data for the Y plane.
    /// * `uv_data`: The raw pixel data for the UV plane.
    /// * `uv_pitch`: The number of bytes between rows of pixel data for the UV plane.
    ///
    /// ## Remarks
    /// You can use `render.Texture.update()` as long as your pixel data is a contiguous block of NV12/21 planes in the proper order,
    /// but this function is available if your pixel data is not contiguous.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn updateNV(
        self: Texture,
        update_area: ?rect.IRect,
        y_data: [*]const u8,
        y_pitch: usize,
        uv_data: [*]const u8,
        uv_pitch: usize,
    ) !void {
        const update_area_sdl: c.SDL_Rect = if (update_area) |val| val.toSdl() else undefined;
        const ret = c.SDL_UpdateNVTexture(
            self.value,
            if (update_area != null) &update_area_sdl else null,
            y_data,
            @intCast(y_pitch),
            uv_data,
            @intCast(uv_pitch),
        );
        return errors.wrapCallBool(ret);
    }

    /// Update a rectangle within a planar YV12 or IYUV texture with new pixel data.
    ///
    /// ## Function Parameters
    /// * `self`: The texture to update.
    /// * `update_area`: The rectangle of pixels to update, or `null` to update the entire texture.
    /// * `y_data`: The raw pixel data for the Y plane.
    /// * `y_pitch`: The number of bytes between rows of pixel data for the Y plane.
    /// * `u_data`: The raw pixel data for the U plane.
    /// * `u_pitch`: The number of bytes between rows of pixel data for the U plane.
    /// * `v_data`: The raw pixel data for the V plane.
    /// * `v_pitch`: The number of bytes between rows of pixel data for the V plane.
    ///
    /// ## Remarks
    /// You can use `render.Texture.update()` as long as your pixel data is a contiguous block of Y and U/V planes in the proper order,
    /// but this function is available if your pixel data is not contiguous.
    ///
    /// ## Thread Safety
    /// This function should only be called on the main thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn updateYUV(
        self: Texture,
        update_area: ?rect.IRect,
        y_data: [*]const u8,
        y_pitch: usize,
        u_data: [*]const u8,
        u_pitch: usize,
        v_data: [*]const u8,
        v_pitch: usize,
    ) !void {
        const update_area_sdl: c.SDL_Rect = if (update_area) |val| val.toSdl() else undefined;
        const ret = c.SDL_UpdateYUVTexture(
            self.value,
            if (update_area != null) &update_area_sdl else null,
            y_data,
            @intCast(y_pitch),
            u_data,
            @intCast(u_pitch),
            v_data,
            @intCast(v_pitch),
        );
        return errors.wrapCallBool(ret);
    }
};

// Texture address mode in SDL 3.4.0.

/// Vertex structure.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Vertex = extern struct {
    /// Position in SDL renderer coordinates.
    position: rect.FPoint,
    /// Vertex color.
    color: pixels.FColor,
    /// Normalized texture coordinates, if needed.
    tex_coord: rect.FPoint,

    // Size tests.
    comptime {
        errors.assertStructsEqual(c.SDL_Vertex, Vertex);
    }
};

/// Use this function to get the name of a built in 2D rendering driver.
///
/// ## Function Parameters
/// * `index`: The index of the rendering driver.
///
/// ## Return Value
/// Returns the name of the rendering driver at the requested index, or `null` if an invalid index was specified.
///
/// ## Remarks
/// The list of rendering drivers is given in the order that they are normally initialized by default; the drivers that seem more reasonable to choose first
/// (as far as the SDL developers believe) are earlier in the list.
///
/// The names of drivers are all simple, low-ASCII identifiers, like "opengl", "direct3d12" or "metal"
/// These never have Unicode characters, and are not meant to be proper names.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
///
/// ## Code Examples
/// TODO!!!
pub fn getDriverName(
    index: usize,
) ?[:0]const u8 {
    const ret = c.SDL_GetRenderDriver(
        @intCast(index),
    );
    if (ret == null)
        return null;
    return std.mem.span(ret);
}

/// Get the number of 2D rendering drivers available for the current display.
///
/// ## Return Value
/// Returns the number of built in render drivers.
///
/// ## Remarks
/// A render driver is a set of code that handles rendering and texture management on a particular display.
/// Normally there is only one, but some drivers may have several available with different capabilities.
///
/// There may be none if SDL was compiled without render support.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getNumDrivers() usize {
    const ret = c.SDL_GetNumRenderDrivers();
    return @intCast(ret);
}

/// Get the renderer associated with a window.
///
/// ## Function Parameters
/// * `window`: The window to query.
///
/// ## Return Value
/// Returns the rendering context.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getRenderer(
    window: video.Window,
) !Renderer {
    const ret = c.SDL_GetRenderer(
        window.value,
    );
    return Renderer{ .value = try errors.wrapCallNull(*c.SDL_Renderer, ret) };
}

// Render tests.
test "Render" {
    std.testing.refAllDeclsRecursive(@This());
}
