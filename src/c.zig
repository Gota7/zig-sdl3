const extension_options = @import("extension_options");

pub const c = @cImport({
    @cInclude("SDL3/SDL.h");
    if (!extension_options.main) {
        @cDefine("SDL_MAIN_NOIMPL", {});
    }
    @cInclude("SDL3/SDL_main.h");
    @cInclude("SDL3/SDL_vulkan.h");
    const ext_image = extension_options.image; // Optional include.
    if (ext_image) {
        @cInclude("SDL3_image/SDL_image.h");
    }
    const ext_net = extension_options.net;
    if (ext_net) {
        @cInclude("SDL3_net/SDL_net.h");
    }
    const ext_ttf = extension_options.ttf;
    if (ext_ttf) {
        @cInclude("SDL3_ttf/SDL_ttf.h");
        @cInclude("SDL3_ttf/SDL_textengine.h");
    }
});
