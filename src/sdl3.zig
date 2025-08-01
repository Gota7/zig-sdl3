/// Not recommended for usage unless absolutely needed.
///
/// SDL's macros are not compatible with zig, use zig when appropriate.
///
/// However, setting callbacks should work fine.
pub const assert = @import("assert.zig");

/// SDL offers a way to perform I/O asynchronously.
/// This allows an app to read or write files without waiting for data to actually transfer; the functions that request I/O never block while the request is fulfilled.
///
/// Instead, the data moves in the background and the app can check for results at their leisure.
///
/// This is more complicated than just reading and writing files in a synchronous way, but it can allow for more efficiency,
/// and never having framerate drops as the hard drive catches up, etc.
///
/// The general usage pattern for async I/O is:
/// * Create one or more `async_io.Queue` objects.
/// * Open files with `async_io.File.init()`.
/// * Start I/O tasks to the files with `async_io.Queue.readFile()` or `async_io.Queue.writeFile()`, putting those tasks into one of the queues.
/// * Later on, use `async_io.Queue.getResult()` on a queue to see if any task is finished without blocking. Tasks might finish in any order with success or failure.
/// * When all your tasks are done, close the file with `async_io.Queue.CloseFile()`. This also generates a task, since it might flush data to disk!
///
/// This all works, without blocking, in a single thread, but one can also wait on a queue in a background thread, sleeping until new results have arrived:
/// * Call `async_io.Queue.waitResult()` from one or more threads to efficiently block until new tasks complete.
/// * When shutting down, call `async_io.Queue.signal()` to unblock any sleeping threads despite there being no new tasks completed.
///
/// And, of course, to match the synchronous `io_stream.loadFile()`, we offer `async_io.Queue.loadFile()` as a convenience function.
/// This will handle allocating a buffer, slurping in the file data, and null-terminating it; you still check for results later.
///
/// Behind the scenes, SDL will use newer, efficient APIs on platforms that support them: Linux's `io_uring` and Windows 11's `IoRing`, for example.
/// If those technologies aren't available, SDL will offload the work to a thread pool that will manage otherwise-synchronous loads without blocking the app.
///
/// ## Best Practices
/// Simple non-blocking I/O--for an app that just wants to pick up data whenever it's ready without losing framerate waiting on disks to spin--can use whatever pattern
/// works well for the program.
/// In this case, simply call `async_io.Queue.readFile()`, or maybe `async_io.Queue.loadFile()`, as needed.
/// Once a frame, call SDL_GetAsyncIOResult to check for any completed tasks and deal with the data as it arrives.
///
/// If two separate pieces of the same program need their own I/O, it is legal for each to create their own queue.
/// This will prevent either piece from accidentally consuming the other's completed tasks. Each queue does require some amount of resources, but it is not an overwhelming cost.
/// Do not make a queue for each task, however.
/// It is better to put many tasks into a single queue.
/// They will be reported in order of completion, not in the order they were submitted, so it doesn't generally matter what order tasks are started.
///
/// One async I/O queue can be shared by multiple threads, or one thread can have more than one queue, but the most efficient way--if ruthless efficiency is the goal--is to
/// have one queue per thread, with multiple threads working in parallel,
/// and attempt to keep each queue loaded with tasks that are both started by and consumed by the same thread.
/// On modern platforms that can use newer interfaces, this can keep data flowing as efficiently as possible all the way from storage hardware to the app,
/// with no contention between threads for access to the same queue.
///
/// Written data is not guaranteed to make it to physical media by the time a closing task is completed, unless `async_io.closeFile()` is called with its `flush` parameter set to true,
/// which is to say that a successful result here can still result in lost data during an unfortunately-timed power outage if not flushed.
/// However, flushing will take longer and may be unnecessary, depending on the app's needs.
pub const async_io = @import("async_io.zig");

/// Atomic operations.
///
/// IMPORTANT: If you are not an expert in concurrent lockless programming, you should not be using any functions in this file.
/// You should be protecting your data structures with full mutexes instead.
///
/// Seriously, here be dragons!
///
/// You can find out a little more about lockless programming and the subtle issues that can arise here:
/// https://learn.microsoft.com/en-us/windows/win32/dxtecharts/lockless-programming
///
/// There's also lots of good information here:
/// * https://www.1024cores.net/home/lock-free-algorithms
/// * https://preshing.com/
///
/// These operations may or may not actually be implemented using processor specific atomic operations.
/// When possible they are implemented as true processor specific atomic operations.
/// When that is not possible the are implemented using locks that do use the available atomic operations.
///
/// All of the atomic operations that modify memory are full memory barriers.
pub const atomic = @import("atomic.zig");

/// Audio functionality for the SDL library.
///
/// All audio in SDL3 revolves around `audio.Stream`.
/// Whether you want to play or record audio, convert it, stream it, buffer it, or mix it, you're going to be passing it through an audio stream.
///
/// Audio streams are quite flexible; they can accept any amount of data at a time, in any supported format, and output it as needed in any other format,
/// even if the data format changes on either side halfway through.
///
/// An app opens an audio device and binds any number of audio streams to it, feeding more data to the streams as available.
/// When the device needs more data, it will pull it from all bound streams and mix them together for playback.
///
/// Audio streams can also use an app-provided callback to supply data on-demand, which maps pretty closely to the SDL2 audio model.
///
/// SDL also provides a simple .WAV loader in `audio.loadWav()` (and `audio.loadWavIo()` if you aren't reading from a file) as a basic means to load sound data into your program.
///
/// ## Logical audio devices
/// In SDL3, opening a physical device (like a SoundBlaster 16 Pro) gives you a logical device ID that you can bind audio streams to.
/// In almost all cases, logical devices can be used anywhere in the API that a physical device is normally used.
/// However, since each device opening generates a new logical device, different parts of the program (say, a VoIP library, or text-to-speech framework,
/// or maybe some other sort of mixer on top of SDL) can have their own device opens that do not interfere with each other;
/// each logical device will mix its separate audio down to a single buffer, fed to the physical device, behind the scenes.
/// As many logical devices as you like can come and go; SDL will only have to open the physical device at the OS level once,
/// and will manage all the logical devices on top of it internally.
///
/// One other benefit of logical devices: if you don't open a specific physical device, instead opting for the default,
/// SDL can automatically migrate those logical devices to different hardware as circumstances change: a user plugged in headphones?
/// The system default changed?
/// SDL can transparently migrate the logical devices to the correct physical device seamlessly and keep playing;
/// the app doesn't even have to know it happened if it doesn't want to.
///
/// ## Simplified Audio
/// As a simplified model for when a single source of audio is all that's needed, an app can use `audio.Device.openStream()`, which is a single function to open an audio device,
/// create an audio stream, bind that stream to the newly-opened device, and (optionally) provide a callback for obtaining audio data.
/// When using this function, the primary interface is the `audio.Stream` and the device handle is mostly hidden away;
/// destroying a stream created through this function will also close the device, stream bindings cannot be changed, etc.
/// One other quirk of this is that the device is started in a paused state and must be explicitly resumed;
/// this is partially to offer a clean migration for SDL2 apps and partially because the app might have to do more setup before playback begins;
/// in the non-simplified form, nothing will play until a stream is bound to a device, so they start unpaused.
///
/// ## Channel Layouts
/// Audio data passing through SDL is uncompressed PCM data, interleaved. One can provide their own decompression through an MP3, etc, decoder,
/// but SDL does not provide this directly.
/// Each interleaved channel of data is meant to be in a specific order.
///
/// Abbreviations:
/// * FRONT = Single mono speaker.
/// * FL = Front left speaker.
/// * FR = Front right speaker.
/// * FC = Front center speaker.
/// * BL = Back left speaker.
/// * BR = Back right speaker.
/// * SR = Surround right speaker.
/// * SL = Surround left speaker.
/// * BC = Back center speaker.
/// * LFE = Low-frequency speaker.
///
/// These are listed in the order they are laid out in memory, so "FL, FR" means "the front left speaker is laid out in memory first, then the front right,
/// then it repeats for the next audio frame":
/// * 1 channel (mono) layout: FRONT
/// * 2 channels (stereo) layout: FL, FR
/// * 3 channels (2.1) layout: FL, FR, LFE
/// * 4 channels (quad) layout: FL, FR, BL, BR
/// * 5 channels (4.1) layout: FL, FR, LFE, BL, BR
/// * 6 channels (5.1) layout: FL, FR, FC, LFE, BL, BR (last two can also be SL, SR)
/// * 7 channels (6.1) layout: FL, FR, FC, LFE, BC, SL, SR
/// * 8 channels (7.1) layout: FL, FR, FC, LFE, BL, BR, SL, SR
///
/// This is the same order as DirectSound expects, but applied to all platforms; SDL will swizzle the channels as necessary if a platform expects something different.
///
/// `audio.Stream` can also be provided channel maps to change this ordering to whatever is necessary, in other audio processing scenarios.
pub const audio = @import("audio.zig");

/// Functions for fiddling with bits and bitmasks.
pub const bits = @import("bits.zig");

/// Blend modes decide how two colors will mix together.
/// There are both standard modes for basic needs and a means to create custom modes, dictating what sort of math to do on what color components.
pub const blend_mode = @import("blend_mode.zig");

/// Provide raw access to SDL3's C API.
///
/// Under most circumstances, you will never need to use this.
/// This should only really be used for functions not yet implemented in zig-sdl3.
pub const c = @import("c.zig").c;

/// CPU feature detection for SDL.
///
/// These functions are largely concerned with reporting if the system has access to various SIMD instruction sets,
/// but also has other important info to share, such as system RAM size and number of logical CPU cores.
///
/// CPU instruction set checks, like `cpu_info.hasSse()` and `cpu_info.hasNeon()`, are available on all platforms,
/// even if they don't make sense (an ARM processor will never have SSE and an x86 processor will never have NEON,
/// for example, but these functions still exist and will simply return false in these cases).
pub const cpu_info = @import("cpu_info.zig");

/// Video capture for the SDL library.
///
/// This API lets apps read input from video sources, like webcams.
/// Camera devices can be enumerated, queried, and opened.
/// Once opened, it will provide `surface.Surface` objects as new frames of video come in.
/// These surfaces can be uploaded to an `render.Texture` or processed as pixels in memory.
///
/// Several platforms will alert the user if an app tries to access a camera,
/// and some will present a UI asking the user if your application should be allowed to obtain images at all, which they can deny.
/// A successfully opened camera will not provide images until permission is granted.
/// Applications, after opening a camera device, can see if they were granted access by either polling with the `camera.Camera.getPermissionState()` function,
/// or waiting for an `event.Type.camera_device_approved` or `event.Type.camera_device_denied` event.
/// Platforms that don't have any user approval process will report approval immediately.
///
/// Note that SDL cameras only provide video as individual frames; they will not provide full-motion video encoded in a movie file format,
/// although an app is free to encode the acquired frames into any format it likes.
/// It also does not provide audio from the camera hardware through this API; not only do many webcams not have microphones at all,
/// many people--from streamers to people on Zoom calls--will want to use a separate microphone regardless of the camera.
/// In any case, recorded audio will be available through SDL's audio API no matter what hardware provides the microphone.
///
/// ## Camera Gotchas
/// Consumer-level camera hardware tends to take a little while to warm up, once the device has been opened.
/// Generally most camera apps have some sort of UI to take a picture (a button to snap a pic while a preview is showing,
/// some sort of multi-second countdown for the user to pose, like a photo booth), which puts control in the users' hands,
/// or they are intended to stay on for long times (Pokemon Go, etc).
///
/// It's not uncommon that a newly-opened camera will provide a couple of completely black frames, maybe followed by some under-exposed images.
/// If taking a single frame automatically, or recording video from a camera's input without the user initiating it from a preview,
/// it could be wise to drop the first several frames (if not the first several seconds worth of frames!) before using images from a camera.
pub const camera = @import("camera.zig");

/// SDL provides access to the system clipboard, both for reading information from other processes and publishing information of its own.
///
/// This is not just text! SDL apps can access and publish data by mimetype.
///
/// ## Basic Use (Text)
/// Obtaining and publishing simple text to the system clipboard is as easy as calling `clipboard.getText()` and `clipboard.setText()`, respectively.
/// These deal with C strings in UTF-8 encoding. Data transmission and encoding conversion is completely managed by SDL.
///
/// ## Clipboard Callbacks (Non-Text)
/// Things get more complicated when the clipboard contains something other than text.
/// Not only can the system clipboard contain data of any type, in some cases it can contain the same data in different formats!
/// For example, an image painting app might let the user copy a graphic to the clipboard, and offers it in .BMP, .JPG, or .PNG format for other apps to consume.
///
/// Obtaining clipboard data ("pasting") like this is a matter of calling `clipboard.getData()` and telling it the mimetype of the data you want.
/// But how does one know if that format is available?
/// `hasData()` can report if a specific mimetype is offered, and `clipboard.getMimeTypes()` can provide the entire list of mimetypes available,
/// so the app can decide what to do with the data and what formats it can support.
///
/// Setting the clipboard ("copying") to arbitrary data is done with `clipboard.setData()`.
/// The app does not provide the data in this call, but rather the mimetypes it is willing to provide and a callback function.
/// During the callback, the app will generate the data.
/// This allows massive data sets to be provided to the clipboard, without any data being copied before it is explicitly requested.
/// More specifically, it allows an app to offer data in multiple formats without providing a copy of all of them upfront.
/// If the app has an image that it could provide in PNG or JPG format, it doesn't have to encode it to either of those unless and until something tries to paste it.
///
/// ## Primary Selection
/// The X11 and Wayland video targets have a concept of the "primary selection" in addition to the usual clipboard.
/// This is generally highlighted (but not explicitly copied) text from various apps.
/// SDL offers APIs for this through `clipboard.getPrimarySelectionText()` and `clipboard.setPrimarySelectionText()`.
/// SDL offers these APIs on platforms without this concept, too, but only so far that it will keep a copy of a string that the app sets for later retrieval;
/// the operating system will not ever attempt to change the string externally if it doesn't support a primary selection.
pub const clipboard = @import("clipboard.zig");

/// File dialog support.
///
/// SDL offers file dialogs, to let users select files with native GUI interfaces.
/// There are "open" dialogs, "save" dialogs, and folder selection dialogs.
/// The app can control some details, such as filtering to specific files,
/// or whether multiple files can be selected by the user.
///
/// Note that launching a file dialog is a non-blocking operation; control returns to the app immediately,
/// and a callback is called later (possibly in another thread) when the user makes a choice.
pub const dialog = @import("dialog.zig");

/// Functions converting endian-specific values to different byte orders.
///
/// These functions either unconditionally swap byte order (`endian.swap16()`, `endian.swap32()`, `endian.swap64()`, `endian.swapFloat()`),
/// or they swap to/from the system's native byte order
/// (`endian.swap16Le()`, `endian.swap16Be()`, `endian.swap32Le()`, `endian.swap32Be()`, `endian.swapFloatLe()`, `endian.swapfloatBe()`).
/// In the latter case, the functionality is provided by macros that become no-ops if a swap isn't necessary: on an x86 (littleendian) processor,
/// `endian.swap32Le()` does nothing, but `endian.swap32Be()` reverses the bytes of the data.
/// On a PowerPC processor (bigendian), the macros behavior is reversed.
///
/// The swap routines are inline functions, and attempt to use compiler intrinsics,
/// inline assembly, and other magic to make byteswapping efficient.
pub const endian = @import("endian.zig");

/// Simple error message routines for SDL.
///
/// Most apps will interface with these APIs in exactly one function:
/// when almost any SDL function call reports failure, you can get a human-readable string of the problem from `errors.get()`.
///
/// These strings are maintained per-thread, and apps are welcome to set their own errors, which is popular when building libraries on top of SDL for other apps to consume.
/// These strings are set by calling `errors.set()`.
pub const errors = @import("errors.zig");

/// Event queue management.
///
/// It's extremely common--often required--that an app deal with SDL's event queue.
/// Almost all useful information about interactions with the real world flow through here: the user interacting with the computer and app, hardware coming and going,
/// the system changing in some way, etc.
///
/// An app generally takes a moment, perhaps at the start of a new frame, to examine any events that have occured since the last time and process or ignore them.
/// This is generally done by calling `events.poll()` in a loop until it returns `null` (or, if using the main callbacks,
/// events are provided one at a time in calls to `SDL_AppEvent()` before the next call to `SDL_AppIterate()`; in this scenario, the app does not call `events.poll()` at all).
///
/// There is other forms of control, too: `events.peep()` has more functionality at the cost of more complexity,
/// and `events.wait()`/`events.waitAndPop()` can block the process until something interesting happens, which might be beneficial for certain types of programs on low-power hardware.
/// One may also call `events.addWatch()` to set a callback when new events arrive.
///
/// The app is free to generate their own events, too: `events.push()` allows the app to put events onto the queue for later retrieval;
/// `events.register()` can guarantee that these events have a type that isn't in use by other parts of the system.
pub const events = @import("events.zig");

/// Extra utilities provided by zig-sdl3 for convenience.
pub const extras = @import("extras.zig");

/// SDL offers an API for examining and manipulating the system's filesystem.
/// This covers most things one would need to do with directories, except for actual file I/O (which is covered by `io_stream` and `async_io` instead).
///
/// There are functions to answer necessary path questions:
/// * Where is my app's data? `filesystem.getBasePath()`.
/// * Where can I safely write files? `filesystem.getPrefPath()`.
/// * Where are paths like Downloads, Desktop, Music? `filesystem.getUserFolder()`.
/// * What is this thing at this location? `filesystem.getPathInfo()`.
/// * What items live in this folder? `filesystem.enumerateDirectory()`.
/// * What items live in this folder by wildcard? `filesystem.globDirectory()`.
/// * What is my current working directory? `filesystem.getCurrentDirectory()`.
///
/// SDL also offers functions to manipulate the directory tree: renaming, removing, copying files.
pub const filesystem = @import("filesystem.zig");

/// SDL provides a low-level joystick API, which just treats joysticks as an arbitrary pile of buttons, axes, and hat switches.
/// If you're planning to write your own control configuration screen, this can give you a lot of flexibility, but that's a lot of work,
/// and most things that we consider "joysticks" now are actually console-style gamepads.
/// So SDL provides the gamepad API on top of the lower-level joystick functionality.
///
/// The difference between a joystick and a gamepad is that a gamepad tells you where a button or axis is on the device.
/// You don't speak to gamepads in terms of arbitrary numbers like "button 3" or "axis 2" but in standard locations: the d-pad,
/// the shoulder buttons, triggers, A/B/X/Y (or X/O/Square/Triangle, if you will).
///
/// One turns a joystick into a gamepad by providing a magic configuration string,
/// which tells SDL the details of a specific device: when you see this specific hardware, if button 2 gets pressed, this is actually D-Pad Up, etc.
///
/// SDL has many popular controllers configured out of the box, and users can add their own controller details through an environment variable if it's otherwise unknown to SDL.
///
/// In order to use these functions, `init()` must have been called with the `InitFlags.gamepad` flag.
/// This causes SDL to scan the system for gamepads, and load appropriate drivers.
///
/// If you would like to receive gamepad updates while the application is in the background,
/// you should set the following hint before calling `init()`: `hints.Type.joystick_allow_background_events`.
///
/// Gamepads support various optional features such as rumble, color LEDs, touchpad, gyro, etc.
/// The support for these features varies depending on the controller and OS support available.
/// You can check for LED and rumble capabilities at runtime by calling `gamepad.Gamepad.getProperties()` and checking the various capability properties.
/// You can check for touchpad by calling `gamepad.Gamepad.getNumTouchpads()` and check for gyro and accelerometer by calling `gamepad.Gamepad.hasSensor()`.
///
/// By default SDL will try to use the most capable driver available, but you can tune which OS drivers to use with the various joystick hints in `hints`.
///
/// Your application should always support gamepad hotplugging.
/// On some platforms like Xbox, Steam Deck, etc., this is a requirement for certification.
/// On other platforms, like macOS and Windows when using `Windows.Gaming.Input`,
/// controllers may not be available at startup and will come in at some point after you've started processing events.
pub const gamepad = @import("gamepad.zig");

/// The GPU API offers a cross-platform way for apps to talk to modern graphics hardware.
/// It offers both 3D graphics and compute support, in the style of Metal, Vulkan, and Direct3D 12.
///
/// This is a very complex category, and so it is recommended to read over https://wiki.libsdl.org/SDL3/CategoryGPU.
pub const gpu = @import("gpu.zig");

/// A GUID is a 128-bit value that represents something that is uniquely identifiable by this value: "globally unique."
///
/// SDL provides functions to convert a GUID to/from a stri
pub const Guid = @import("guid.zig").Guid;

/// The SDL haptic subsystem manages haptic (force feedback) devices.
///
/// The basic usage is as follows:
/// * Initialize the subsystem `init.InitFlags.haptic`.
/// * Open a haptic device.
/// * `haptic.Haptic.init()` to open from index.
/// * `haptic.Haptic.initFromJoystick()` to open from an existing joystick.
/// * Create an effect (`haptic.Effect`).
/// * Upload the effect with `haptic.Haptic.createEffect()`.
/// * Run the effect with `haptic.Haptic.runEffect()`.
/// * (Optional) Free the effect with `haptic.Haptic.destroyEffect()`.
/// * Close the haptic device with `haptic.Haptic.deinit()`.
///
/// TODO: CODE EXAMPLE!
///
/// Note that the SDL haptic subsystem is not thread-safe.
pub const haptic = @import("haptic.zig");

/// File for SDL HID API functions.
///
/// This is an adaptation of the original HIDAPI interface by Alan Ott, and includes source code licensed under the following license:
/// ```
/// HIDAPI - Multi-Platform library for
/// communication with HID devices.
///
/// Copyright 2009, Alan Ott, Signal 11 Software.
/// All Rights Reserved.
///
/// This software may be used by anyone for any reason so
/// long as the copyright notice in the source files
/// remains intact.
/// ```
/// (Note that this license is the same as item three of SDL's zlib license, so it adds no new requirements on the user.)
///
/// If you would like a version of SDL without this code, you can build SDL with `SDL_HIDAPI_DISABLED` defined to `1`.
/// You might want to do this for example on iOS or tvOS to avoid a dependency on the CoreBluetooth framework.
pub const hid_api = @import("hid_api.zig");

/// This file contains functions to set and get configuration hints, as well as listing each of them alphabetically.
///
/// The convention for naming hints is "xy_z", where "XY_Z" is the environment variable that can be used to override the default.
///
/// In general these hints are just that - they may or may not be supported or applicable on any given platform,
/// but they provide a way for an application or user to give the library a hint as to how they would like the library to work.
pub const hints = @import("hints.zig");

/// This is a simple library to load images of various formats as SDL surfaces.
/// It can load BMP, GIF, JPEG, LBM, PCX, PNG, PNM (PPM/PGM/PBM), QOI, TGA, XCF, XPM, and simple SVG format images.
/// It can also load AVIF, JPEG-XL, TIFF, and WebP images, depending on build options.
pub const image = if (extension_options.image) @import("image.zig") else void;

/// SDL does some preprocessor gymnastics to determine if any CPU-specific compiler intrinsics are available,
/// as this is not necessarily an easy thing to calculate, and sometimes depends on quirks of a system, versions of build tools, and other external forces.
///
/// Apps including SDL's headers will be able to check consistent preprocessor definitions to decide if it's safe to use compiler intrinsics for a specific CPU architecture.
/// This check only tells you that the compiler is capable of using those intrinsics; at runtime,
/// you should still check if they are available on the current system with the CPU info functions, such as `cpu_info.hasSse()` or `cpu_info.hasNeon()`.
/// Otherwise, the process might crash for using an unsupported CPU instruction.
///
/// SDL only sets preprocessor defines for CPU intrinsics if they are supported, so apps should check the constants.
///
/// SDL will also include the appropriate instruction-set-specific support headers, so if SDL decides to set `intrin.sse2` to true,
/// it will also `#include <emmintrin.h>` as well.
pub const intrin = @import("intrin.zig");

/// SDL provides an abstract interface for reading and writing data streams.
/// It offers implementations for files, memory, etc, and the app can provide their own implementations, too.
///
/// `io_stream.Stream` is not related to the standard C++ iostream class, other than both are abstract interfaces to read/write data.
pub const io_stream = @import("io_stream.zig");

/// SDL joystick support.
///
/// This is the lower-level joystick handling.
/// If you want the simpler option, where what each button does is well-defined, you should use the `gamepad` API instead.
///
/// The term "instance_id" is the current instantiation of a joystick device in the system, if the joystick is removed and then re-inserted then it will get a new `instance_id`,
/// `instance_id`'s are monotonically increasing identifiers of a joystick plugged in.
///
/// The term "player_index" is the number assigned to a player on a specific controller.
/// For XInput controllers this returns the XInput user index.
/// Many joysticks will not be able to supply this information.
///
/// The `Guid` is used as a stable 128-bit identifier for a joystick device that does not change over time.
/// It identifies class of the device (a X360 wired controller for example).
/// This identifier is platform dependent.
///
/// In order to use these functions, `init.init()` must have been called with the `init.Flags.joystick` flag.
/// This causes SDL to scan the system for joysticks, and load appropriate drivers.
///
/// If you would like to receive joystick updates while the application is in the background,
/// you should set the following hint before calling `init.init()`: `hints.Type.joystick_allow_background_events`.
pub const joystick = @import("joystick.zig");

/// SDL keyboard management.
///
/// Please refer to the Best Keyboard Practices document for details on how best to accept keyboard input in various types of programs:
/// https://wiki.libsdl.org/SDL3/BestKeyboardPractices
pub const keyboard = @import("keyboard.zig");

/// Defines constants which identify keyboard keys and modifiers.
///
/// Please refer to the Best Keyboard Practices document for details on what this information means and how best to use it.
///
/// https://wiki.libsdl.org/SDL3/BestKeyboardPractices
pub const keycode = @import("keycode.zig");

/// System-dependent library loading routines.
///
/// Shared objects are code that is programmatically loadable at runtime.
/// Windows calls these "DLLs", Linux calls them "shared libraries", etc.
///
/// To use them, build such a library, then call `SharedObject.load()` on it.
/// Once loaded, you can use `SharedObject.loadFunction()` on that object to find the address of its exported symbols.
/// When done with the object, call `SharedObject.unload()` to dispose of it.
///
/// Some things to keep in mind:
///
/// These functions only work on C function names.
/// Other languages may have name mangling and intrinsic language support that varies from compiler to compiler.
/// Make sure you declare your function pointers with the same calling convention as the actual library function.
/// Your code will crash mysteriously if you do not do this.
/// Avoid namespace collisions. If you load a symbol from the library, it is not defined whether or not it goes into the global symbol namespace for the application.
/// If it does and it conflicts with symbols in your code or other shared libraries, you will not get the results you expect. :)
/// Once a library is unloaded, all pointers into it obtained through `SharedObject.loadFunction()` become invalid, even if the library is later reloaded.
/// Don't unload a library if you plan to use these pointers in the future.
/// Notably: beware of giving one of these pointers to `atexit()`, since it may call that pointer after the library unloads.
pub const SharedObject = @import("loadso.zig").SharedObject;

/// SDL locale services.
///
/// This provides a way to get a list of preferred locales (language plus country) for the user.
/// There is exactly one function: `Locale.getPreferred()`, which handles all the heavy lifting,
/// and offers documentation on all the strange ways humans might have configured their language settings.
pub const Locale = @import("locale.zig").Locale;

/// Simple log messages with priorities and categories.
/// A message's `log.Priority` signifies how important the message is.
/// A message's `log.Category` signifies from what domain it belongs to.
/// Every category has a minimum priority specified: when a message belongs to that category, it will only be sent out if it has that minimum priority or higher.
///
/// SDL's own logs are sent below the default priority threshold, so they are quiet by default.
///
/// You can change the log verbosity programmatically using `log.Category.setPriority()` or with `hints.set(.Logging, ...)`, or with the "SDL_LOGGING" environment variable.
/// This variable is a comma separated set of category=level tokens that define the default logging levels for SDL applications.
///
/// The category can be a numeric category, one of "app", "error", "assert", "system", "audio", "video", "render", "input", "test", or * for any unspecified category.
///
/// The level can be a numeric level, one of "verbose", "debug", "info", "warn", "error", "critical", or "quiet" to disable that category.
///
/// You can omit the category if you want to set the logging level for all categories.
///
/// If this hint isn't set, the default log levels are equivalent to:
///
/// app=info,assert=warn,test=verbose,*=error
///
/// Here's where the messages go on different platforms:
///
/// * Windows: debug output stream
/// * Android: log output
/// * Others: standard error output (stderr)
///
/// You don't need to have a newline (\n) on the end of messages, the functions will do that for you.
/// For consistent behavior cross-platform, you shouldn't have any newlines in messages,
/// such as to log multiple lines in one call; unusual platform-specific behavior can be observed in such usage.
/// Do one log call per line instead, with no newlines in messages.
///
/// Each log call is atomic, so you won't see log messages cut off one another when logging from multiple threads.
pub const log = @import("log.zig");

/// Main callback functions when desired.
pub const main_callbacks = if (extension_options.callbacks) @import("main_callbacks.zig") else void;

/// Ability to call other main functions.
///
/// SDL will take care of platform specific details on how it gets called.
///
/// You most likely don't want to touch this and instead deal with the `.callbacks` setting to enable main callbacks in `build.zig`.
/// See the template project for an example on how to set this up.
///
/// For more information, see:
/// [https://wiki.libsdl.org/SDL3/README/main-functions](https://wiki.libsdl.org/SDL3/README/main-functions).
pub const main_funcs = @import("main.zig");

/// SDL offers a simple message box API, which is useful for simple alerts,
/// such as informing the user when something fatal happens at startup without the need to build a UI for it (or informing the user before your UI is ready).
///
/// These message boxes are native system dialogs where possible.
///
/// There is both a customizable function (`message_box.show()`) that offers lots of options for what to display and reports on what choice the user made,
/// and also a much-simplified version (`message_box.showSimple()`), merely takes a text message and title,
/// and waits until the user presses a single "OK" UI button.
/// Often, this is all that is necessary.
pub const message_box = @import("message_box.zig");

/// Functions to creating Metal layers and views on SDL windows.
///
/// This provides some platform-specific glue for Apple platforms.
/// Most macOS and iOS apps can use SDL without these functions, but this API they can be useful for specific OS-level integration tasks.
pub const MetalView = @import("metal.zig").View;

/// Any GUI application has to deal with the mouse, and SDL provides functions to manage mouse input and the displayed cursor.
///
/// Most interactions with the mouse will come through the event subsystem.
/// Moving a mouse generates an `event.Type.mouse_motion` event, pushing a button generates `event.Type.mouse_button_down`, etc,
/// but one can also query the current state of the mouse at any time with `mouse.getState()`.
///
/// For certain games, it's useful to disassociate the mouse cursor from mouse input.
/// An FPS, for example, would not want the player's motion to stop as the mouse hits the edge of the window.
/// For these scenarios, use `mouse.setWindowRelativeMode()`, which hides the cursor, grabs mouse input to the window, and reads mouse input no matter how far it moves.
///
/// Games that want the system to track the mouse but want to draw their own cursor can use `moues.hide()` and `mouse.show()`.
/// It might be more efficient to let the system manage the cursor, if possible, using `mouse.set()` with a custom image made through `mouse.Cursor.initColor()`,
/// or perhaps just a specific system cursor from `mouse.Cursor.initSystem()`.
///
/// SDL can, on many platforms, differentiate between multiple connected mice, allowing for interesting input scenarios and multiplayer games.
/// They can be enumerated with `mouse.getMice()`, and SDL will send `event.Type.mouse_added` and `event.Type.mouse_removed` events as they are connected and unplugged.
///
/// Since many apps only care about basic mouse input, SDL offers a virtual mouse device for touch and pen input,
/// which often can make a desktop application work on a touchscreen phone without any code changes.
/// Apps that care about touch/pen separately from mouse input should filter out events with a which field of `mouse.ID.touch` and `mouse.ID.pen`.
pub const mouse = @import("mouse.zig");

/// SDL offers several thread synchronization primitives.
/// This document can't cover the complicated topic of thread safety, but reading up on what each of these primitives are, why they are useful,
/// and how to correctly use them is vital to writing correct and safe multithreaded programs.
///
/// * Mutexes: `mutex.Mutex.init()`.
/// * Read/Write locks: `mutex.RwLock.init()`.
/// * Semaphores: `mutex.Semaphore.init()`.
/// * Condition variables: `mutex.Condition.init()`.
///
/// SDL also offers a datatype, `mutex.InitState`, which can be used to make sure only one thread initializes/deinitializes some resource
/// that several threads might try to use for the first time simultaneously.
pub const mutex = @import("mutex.zig");

/// TODO documentation.
pub const net = if (extension_options.net) @import("net.zig") else void;

/// SDL API functions that don't fit elsewhere.
pub const openURL = @import("misc.zig").openURL;

/// SDL pen event handling.
///
/// SDL provides an API for pressure-sensitive pen (stylus and/or eraser) handling, e.g., for input and drawing tablets or suitably equipped mobile / tablet devices.
///
/// To get started with pens, simply handle pen events.
/// When a pen starts providing input, SDL will assign it a unique `pen.ID`, which will remain for the life of the process, as long as the pen stays connected.
///
/// Pens may provide more than simple touch input; they might have other axes, such as pressure, tilt, rotation, etc.
pub const pen = @import("pen.zig");

/// SDL offers facilities for pixel management.
///
/// Largely these facilities deal with pixel format: what does this set of bits represent?
///
/// If you mostly want to think of a pixel as some combination of red, green, blue, and maybe alpha intensities, this is all pretty straightforward,
/// and in many cases, is enough information to build a perfectly fine game.
///
/// However, the actual definition of a pixel is more complex than that:
///
/// Pixels are a representation of a color in a particular color space.
///
/// The first characteristic of a color space is the color type.
/// SDL understands two different color types, RGB and YCbCr, or in SDL also referred to as YUV.
///
/// RGB colors consist of red, green, and blue channels of color that are added together to represent the colors we see on the screen.
///
/// https://en.wikipedia.org/wiki/RGB_color_model
///
/// YCbCr colors represent colors as a Y luma brightness component and red and blue chroma color offsets.
/// This color representation takes advantage of the fact that the human eye is more sensitive to brightness than the color in an image.
/// The Cb and Cr components are often compressed and have lower resolution than the luma component.
///
/// https://en.wikipedia.org/wiki/YCbCr
///
/// When the color information in YCbCr is compressed, the Y pixels are left at full resolution and each Cr and Cb pixel represents an average of the
/// color information in a block of Y pixels.
/// The chroma location determines where in that block of pixels the color information is coming from.
///
/// The color range defines how much of the pixel to use when converting a pixel into a color on the display.
/// When the full color range is used, the entire numeric range of the pixel bits is significant.
/// When narrow color range is used, for historical reasons, the pixel uses only a portion of the numeric range to represent colors.
///
/// The color primaries and white point are a definition of the colors in the color space relative to the standard XYZ color space.
///
/// https://en.wikipedia.org/wiki/CIE_1931_color_space
///
/// The transfer characteristic, or opto-electrical transfer function (OETF), is the way a color is converted from mathematically linear space into a non-linear output signals.
///
/// https://en.wikipedia.org/wiki/Rec._709#Transfer_characteristics
///
/// The matrix coefficients are used to convert between YCbCr and RGB colors.
pub const pixels = @import("pixels.zig");

/// SDL provides a means to identify the app's platform, both at compile time and runtime.
pub const platform = @import("platform.zig");

/// SDL power management routines.
///
/// There is a single function in this category: `PowerState.get()`.
///
/// This function is useful for games on the go.
/// This allows an app to know if it's running on a draining battery, which can be useful if the app wants to reduce processing, or perhaps framerate,
/// to extend the duration of the battery's charge.
/// Perhaps the app just wants to show a battery meter when fullscreen, or alert the user when the power is getting extremely low, so they can save their game.
pub const PowerState = @import("power.zig").PowerState;

/// Process control support.
///
/// These functions provide a cross-platform way to spawn and manage OS-level processes.
///
/// You can create a new subprocess with `Process.init()` and optionally read and write to it using `Process.read()` or `Process.getInput()` and `Process.getOutput()`.
/// If more advanced functionality like chaining input between processes is necessary, you can use `Process.initWithProperties()`.
///
/// You can get the status of a created process with `Process.wait()`, or terminate the process with `Process.kill()`.
///
/// Don't forget to call `Process.deinit()` to clean up, whether the process process was killed, terminated on its own, or is still running!
pub const Process = @import("process.zig").Process;

/// A property is a variable that can be created and retrieved by name at runtime.
///
/// All properties are part of a property group `properties.Group`.
/// A property group can be created with the `properties.Group.init()` function and destroyed with the `properties.Group.deinit()` function.
///
/// Properties can be added to and retrieved from a property group through `properties.Group.set()` and `properties.Group.get()`.
///
/// Properties can be removed from a group by using `properties.Group.clear()`.
pub const properties = @import("properties.zig");

/// Some helper functions for managing rectangles and 2D points, in both integer and floating point versions.
pub const rect = @import("rect.zig");

/// Header file for SDL 2D rendering functions.
///
/// This API supports the following features:
/// * Single pixel points.
/// * Single pixel lines.
/// * Filled rectangles.
/// * Texture images.
/// * 2D polygons.
///
/// The primitives may be drawn in opaque, blended, or additive modes.
///
/// The texture images may be drawn in opaque, blended, or additive modes.
/// They can have an additional color tint or alpha modulation applied to them, and may also be stretched with linear interpolation.
///
/// This API is designed to accelerate simple 2D operations.
/// You may want more functionality such as polygons and particle effects and in that case you should use SDL's OpenGL/Direct3D support, the SDL3 GPU API,
/// or one of the many good 3D engines.
///
/// These functions must be called from the main thread.
/// See this bug for details: https://github.com/libsdl-org/SDL/issues/986
pub const render = @import("render.zig");

/// Defines keyboard scancodes.
///
/// Please refer to the Best Keyboard Practices document for details on what this information means and how best to use it.
///
/// https://wiki.libsdl.org/SDL3/BestKeyboardPractices
pub const Scancode = @import("scancode.zig").Scancode;

/// SDL sensor management.
///
/// These APIs grant access to gyros and accelerometers on various platforms.
///
/// In order to use these functions, `init.init()` must have been called with the `sensor` flag.
/// This causes SDL to scan the system for sensors, and load appropriate drivers.
pub const sensor = @import("sensor.zig");

/// The storage API is a high-level API designed to abstract away the portability issues that come up when using something lower-level.
///
/// See https://wiki.libsdl.org/SDL3/CategoryStorage for more details.
pub const storage = @import("storage.zig");

/// SDL surfaces are buffers of pixels in system RAM.
/// These are useful for passing around and manipulating images that are not stored in GPU memory.
///
/// `surface.Surface` makes serious efforts to manage images in various formats, and provides a reasonable toolbox for transforming the data,
/// including copying between surfaces, filling rectangles in the image data, etc.
///
/// There is also a simple .bmp loader, `surface.loadBmp()`.
/// SDL itself does not provide loaders for various other file formats, but there are several excellent external libraries that do, including its own satellite library,
/// SDL_image:
/// https://github.com/libsdl-org/SDL_image
pub const surface = @import("surface.zig");

/// Platform-specific SDL API functions. These are functions that deal with needs of specific operating systems,
/// that didn't make sense to offer as platform-independent, generic APIs.
///
/// Most apps can make do without these functions, but they can be useful for integrating with other parts of a specific system,
/// adding platform-specific polish to an app, or solving problems that only affect one target.
pub const system = @import("system.zig");

/// SDL offers cross-platform thread management functions.
/// These are mostly concerned with starting threads, setting their priority, and dealing with their termination.
///
/// In addition, there is support for Thread Local Storage (data that is unique to each thread, but accessed from a single key).
///
/// On platforms without thread support (such as Emscripten when built without pthreads),
/// these functions still exist, but things like `thread.Thread.init()` will report failure without doing anything.
///
/// If you're going to work with threads, you almost certainly need to have a good understanding of `mutex` as well.
///
/// This part of the SDL API handles management of threads, but an app also will need locks to manage thread safety.
/// Those pieces are in `mutex`.
pub const thread = @import("thread.zig");

/// SDL realtime clock and date/time routines.
///
/// There are two data types that are used in this category: `time.Time`, which represents the nanoseconds since a specific moment (an "epoch"),
/// and `time.DateTime`, which breaks time down into human-understandable components: years, months, days, hours, etc.
///
/// Much of the functionality is involved in converting those two types to other useful forms.
pub const time = @import("time.zig");

/// TODO documentation.
pub const ttf = if (extension_options.ttf) @import("ttf.zig") else void;

/// SDL provides time management functionality.
/// It is useful for dealing with (usually) small durations of time.
///
/// This is not to be confused with calendar time management, which is provided by `time`.
///
/// This category covers measuring time elapsed (`timer.getMillisecondsSinceInit()`, `timer.getPerformanceCounter()`),
/// putting a thread to sleep for a certain amount of time (`timer.delayMilliseconds()`, `timer.delayNanoseconds()`, `timer.delayNanosecondsPrecise()`),
/// and firing a callback function after a certain amount of time has elasped (`timer.Timer.initMilliseconds()`, etc).
///
/// There are also useful functions to convert between time units, like `timer.secondsToNanoseconds()` and such.
pub const timer = @import("timer.zig");

/// SDL offers a way to add items to the "system tray" (more correctly called the "notification area" on Windows).
/// On platforms that offer this concept, an SDL app can add a tray icon, submenus, checkboxes, and clickable entries,
/// and register a callback that is fired when the user clicks on these pieces.
pub const tray = @import("tray.zig");

/// SDL offers touch input, on platforms that support it.
/// It can manage multiple touch devices and track multiple fingers on those devices.
///
/// Touches are mostly dealt with through the event system, in the `event.Type.finger_down`, `event.Type.finger_motion`, and `event.Type.finger_up` events,
/// but there are also functions to query for hardware details, etc.
///
/// The touch system, by default, will also send virtual mouse events; this can be useful for making a some desktop apps work on a phone without significant changes.
/// For apps that care about mouse and touch input separately, they should ignore mouse events that have a which field of `touch.ID.mouse`.
pub const touch = @import("touch.zig");

/// Functionality to query the current SDL version, both as headers the app was compiled against, and a library the app is linked to.
pub const Version = @import("version.zig").Version;

/// SDL's video subsystem is largely interested in abstracting window management from the underlying operating system.
/// You can create windows, manage them in various ways, set them fullscreen, and get events when interesting things happen with them,
/// such as the mouse or keyboard interacting with a window.
///
/// The video subsystem is also interested in abstracting away some platform-specific differences in OpenGL: context creation, swapping buffers, etc.
/// This may be crucial to your app, but also you are not required to use OpenGL at all.
/// In fact, SDL can provide rendering to those windows as well, either with an easy-to-use 2D API or with a more-powerful GPU API.
/// Of course, it can simply get out of your way and give you the window handles you need to use Vulkan, Direct3D, Metal, or whatever else you like directly, too.
///
/// The video subsystem covers a lot of functionality, out of necessity, so it is worth perusing the list of functions just to see what's available,
/// but most apps can get by with simply creating a window and listening for events, so start with `video.Window.init()` and `events.poll()`.
pub const video = @import("video.zig");

/// Functions for creating Vulkan surfaces on SDL windows.
///
/// For the most part, Vulkan operates independent of SDL, but it benefits from a little support during setup.
///
/// Use `vulkan.getInstanceExtensions()` to get platform-specific bits for creating a `vulkan.Instance`,
/// then `vulkan.getVkGetInstanceProcAddr()` to get the appropriate function for querying Vulkan entry points.
/// Then `vulkan.Surface.init()` will get you the final pieces you need to prepare for rendering into a `video.Window` with Vulkan.
///
/// Unlike OpenGL, most of the details of "context" creation and window buffer swapping are handled by the Vulkan API directly,
/// so SDL doesn't provide Vulkan equivalents of `video.gl.swapWindow()`, etc; they aren't necessary.
pub const vulkan = @import("vulkan.zig");

// Others.
const extension_options = @import("extension_options");
const std = @import("std");

//
// Init stuff below.
//

/// Return values for optional main callbacks.
///
/// Returning Success or Failure from `SDL_AppInit(), `SDL_AppEvent()`,
/// or `SDL_AppIterate()` will terminate the program and report success/failure to the operating system.
/// What that means is platform-dependent.
/// On Unix, for example, on success, the process error code will be zero, and on failure it will be 1.
/// This interface doesn't allow you to return specific exit codes, just whether there was an error generally or not.
///
/// Returning Continue from these functions will let the app continue to run.
///
/// See Main callbacks in SDL3 for complete details.
///
/// This enum is available since SDL 3.2.0.
pub const AppResult = enum(c.SDL_AppResult) {
    /// Value that requests that the app continue from the main callbacks.
    run = c.SDL_APP_CONTINUE,
    /// Value that requests termination with success from the main callbacks.
    success = c.SDL_APP_SUCCESS,
    /// Value that requests termination with error from the main callbacks.
    failure = c.SDL_APP_FAILURE,
};

/// Function pointer for event callback.
///
/// ## Function Parameters
/// * `app_state`: An optional pointer, provided by the app in `SDL_AppInit()`.
/// * `event`: The new event for the app to examine.
///
/// ## Return Value
/// Returns `AppResult.failure` to terminate with an error, `AppResult.success` to terminate with success, `AppResult.run` to continue.
///
/// ## Remarks
/// These are used by `main.enterAppMainCallbacks()`.
/// This mechanism operates behind the scenes for apps using the optional main callbacks.
/// Apps that want to use this should just implement `SDL_AppEvent()` directly.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub fn AppEventCallback(
    comptime UserData: type,
) type {
    return *const fn (
        app_state: *UserData,
        event: events.Event,
    ) anyerror!AppResult;
}

/// Function pointer typedef for init.
///
/// ## Function Parameters
/// * `app_state`: A place where the app can optionally store a pointer for future use.
/// * `args`: Command line arguments for the app.
///
/// ## Return Value
/// Returns `AppResult.failure` to terminate with an error, `AppResult.success` to terminate with success, `AppResult.run` to continue.
///
/// ## Remarks
/// These are used by `main.enterAppMainCallbacks()`.
/// This mechanism operates behind the scenes for apps using the optional main callbacks.
/// Apps that want to use this should just implement `SDL_AppInit()` directly.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub fn AppInitCallback(
    comptime UserData: type,
) type {
    return *const fn (
        app_state: *?*UserData,
        args: [][*:0]u8,
    ) anyerror!AppResult;
}

/// Function pointer typedef for an update loop.
///
/// ## Function Parameters
/// * `app_state`: An optional pointer, provided by the app in `SDL_AppInit()`.
///
/// ## Return Value
/// Returns `AppResult.failure` to terminate with an error, `AppResult.success` to terminate with success, `AppResult.run` to continue.
///
/// ## Remarks
/// These are used by `main.enterAppMainCallbacks()`.
/// This mechanism operates behind the scenes for apps using the optional main callbacks.
/// Apps that want to use this should just implement `SDL_AppIterate()` directly.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub fn AppIterateCallback(comptime UserData: type) type {
    return *const fn (
        app_state: *UserData,
    ) anyerror!AppResult;
}

/// Function pointer typedef for quitting.
///
/// ## Function Parameters
/// * `app_state`: An optional pointer, provided by the app in `SDL_AppInit()`.
/// * `result`: The result code that terminated the app (success or failure).
///
/// ## Remarks
/// These are used by `main.enterAppMainCallbacks()`.
/// This mechanism operates behind the scenes for apps using the optional main callbacks.
/// Apps that want to use this should just implement `SDL_AppEvent()` directly.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub fn AppQuitCallback(
    comptime UserData: type,
) type {
    return *const fn (app_state: ?*UserData, result: AppResult) void;
}

/// Callback run on the main thread.
///
/// ## Function Parameters
/// * `user_data`: An app-controlled pointer that is passed to the callback.
///
/// ## Versions
/// This datatype is available since SDL 3.2.0.
pub fn MainThreadCallback(
    comptime UserData: type,
) type {
    return *const fn (
        user_data: ?*UserData,
    ) void;
}

/// An app's metadata property to get or set.
///
/// ## Version
/// This is provided by zig-sdl3.
pub const AppMetadataProperty = enum {
    /// The human-readable name of the application, like "My Game 2: Bad Guy's Revenge!".
    /// This will show up anywhere the OS shows the name of the application separately from window titles, such as volume control applets, etc.
    /// This defaults to "SDL Application".
    name,
    /// The version of the app that is running; there are no rules on format, so "1.0.3beta2" and "April 22nd, 2024" and a git hash are all valid options.
    /// This has no default.
    version,
    /// A unique string that identifies this app.
    /// This must be in reverse-domain format, like "com.example.mygame2".
    /// This string is used by desktop compositors to identify and group windows together, as well as match applications with associated desktop settings and icons.
    /// If you plan to package your application in a container such as Flatpak, the app ID should match the name of your Flatpak container as well.
    /// This has no default.
    identifier,
    /// The human-readable name of the creator/developer/maker of this app, like "MojoWorkshop, LLC"
    creator,
    /// The human-readable copyright notice, like "Copyright (c) 2024 MojoWorkshop, LLC" or whatnot.
    /// Keep this to one line, don't paste a copy of a whole software license in here.
    /// This has no default.
    copyright,
    /// A URL to the app on the web.
    /// Maybe a product page, or a storefront, or even a GitHub repository, for user's further information.
    /// This has no default.
    url,
    /// The type of application this is.
    /// Currently this string can be "game" for a video game, "mediaplayer" for a media player, or generically "application" if nothing else applies.
    /// Future versions of SDL might add new types.
    /// This defaults to "application".
    program_type,

    /// Convert from an SDL string.
    pub fn fromSdl(val: [:0]const u8) AppMetadataProperty {
        if (std.mem.eql(u8, c.SDL_PROP_APP_METADATA_NAME_STRING, val))
            return .name;
        if (std.mem.eql(u8, c.SDL_PROP_APP_METADATA_VERSION_STRING, val))
            return .version;
        if (std.mem.eql(u8, c.SDL_PROP_APP_METADATA_IDENTIFIER_STRING, val))
            return .identifier;
        if (std.mem.eql(u8, c.SDL_PROP_APP_METADATA_CREATOR_STRING, val))
            return .creator;
        if (std.mem.eql(u8, c.SDL_PROP_APP_METADATA_COPYRIGHT_STRING, val))
            return .copyright;
        if (std.mem.eql(u8, c.SDL_PROP_APP_METADATA_URL_STRING, val))
            return .url;
        if (std.mem.eql(u8, c.SDL_PROP_APP_METADATA_TYPE_STRING, val))
            return .program_type;
        return .name;
    }

    /// Convert to an SDL string.
    pub fn toSdl(self: AppMetadataProperty) [:0]const u8 {
        return switch (self) {
            .name => c.SDL_PROP_APP_METADATA_NAME_STRING,
            .version => c.SDL_PROP_APP_METADATA_VERSION_STRING,
            .identifier => c.SDL_PROP_APP_METADATA_IDENTIFIER_STRING,
            .creator => c.SDL_PROP_APP_METADATA_CREATOR_STRING,
            .copyright => c.SDL_PROP_APP_METADATA_COPYRIGHT_STRING,
            .url => c.SDL_PROP_APP_METADATA_URL_STRING,
            .program_type => c.SDL_PROP_APP_METADATA_TYPE_STRING,
        };
    }
};

/// These are the flags which may be passed to `init()`.
///
/// ## Remarks
/// You should specify the subsystems which you will be using in your application.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const InitFlags = struct {
    /// Implies `events`.
    audio: bool = false,
    /// Implies `events`, should be initialized on the main thread.
    video: bool = false,
    /// Implies `events`, should be initialized on the same thread as `video` on Windows if you don't set the `joystick_thread` hint.
    joystick: bool = false,
    haptic: bool = false,
    /// Implies `joystick`.
    gamepad: bool = false,
    events: bool = false,
    /// Implies `events`.
    sensor: bool = false,
    /// Implies `events`.
    camera: bool = false,
    /// Initializes all subsystems.
    pub const everything = InitFlags{
        .audio = true,
        .video = true,
        .joystick = true,
        .haptic = true,
        .gamepad = true,
        .events = true,
        .sensor = true,
        .camera = true,
    };

    /// Convert from an SDL value.
    pub fn fromSdl(flags: c.SDL_InitFlags) InitFlags {
        return .{
            .audio = (flags & c.SDL_INIT_AUDIO) != 0,
            .video = (flags & c.SDL_INIT_VIDEO) != 0,
            .joystick = (flags & c.SDL_INIT_JOYSTICK) != 0,
            .haptic = (flags & c.SDL_INIT_HAPTIC) != 0,
            .gamepad = (flags & c.SDL_INIT_GAMEPAD) != 0,
            .events = (flags & c.SDL_INIT_EVENTS) != 0,
            .sensor = (flags & c.SDL_INIT_SENSOR) != 0,
            .camera = (flags & c.SDL_INIT_CAMERA) != 0,
        };
    }

    /// Convert to an SDL value.
    pub fn toSdl(self: InitFlags) c.SDL_InitFlags {
        return (if (self.audio) @as(c.SDL_InitFlags, c.SDL_INIT_AUDIO) else 0) |
            (if (self.video) @as(c.SDL_InitFlags, c.SDL_INIT_VIDEO) else 0) |
            (if (self.joystick) @as(c.SDL_InitFlags, c.SDL_INIT_JOYSTICK) else 0) |
            (if (self.haptic) @as(c.SDL_InitFlags, c.SDL_INIT_HAPTIC) else 0) |
            (if (self.gamepad) @as(c.SDL_InitFlags, c.SDL_INIT_GAMEPAD) else 0) |
            (if (self.events) @as(c.SDL_InitFlags, c.SDL_INIT_EVENTS) else 0) |
            (if (self.sensor) @as(c.SDL_InitFlags, c.SDL_INIT_SENSOR) else 0) |
            (if (self.camera) @as(c.SDL_InitFlags, c.SDL_INIT_CAMERA) else 0) |
            0;
    }
};

/// Initialize the SDL library.
///
/// ## Function Parameters
/// * `flags`: Subsystem initialization flags.
///
/// ## Remarks
/// The file I/O (for example: `io.fromFile()`) and threading (`thread.create()`) subsystems are initialized by default.
/// Message boxes (`message_box.showSimpleMessageBox()`) also attempt to work without initializing the video subsystem,
/// in hopes of being useful in showing an error dialog when `init.init()` fails.
/// You must specifically initialize other subsystems if you use them in your application.
///
/// Logging (such as `log`) works without initialization, too.
///
/// Subsystem initialization is ref-counted, you must call `init.quit()` for each `init.init()` to correctly shutdown a subsystem manually (or call `init.quit()` to force shutdown).
/// If a subsystem is already loaded then this call will increase the ref-count and return.
///
/// Consider reporting some basic metadata about your application before calling `init.init()`, using either `init.setAppMetadata()` or `init.setAppMetadataProperty()`.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn init(
    flags: InitFlags,
) !void {
    const ret = c.SDL_Init(
        flags.toSdl(),
    );
    return errors.wrapCallBool(ret);
}

/// Return whether this is the main thread.
///
/// ## Return Value
/// Returns true if this thread is the main thread, or false otherwise.
///
/// ## Remarks
/// On Apple platforms, the main thread is the thread that runs your program's main() entry point. On other platforms, the main thread is the one that calls SDL_Init(SDL_INIT_VIDEO), which should usually be the one that runs your program's main() entry point. If you are using the main callbacks, SDL_AppInit(), SDL_AppIterate(), and SDL_AppQuit() are all called on the main thread.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn isMainThread() bool {
    return c.SDL_IsMainThread();
}

/// Shut down specific SDL subsystems.
///
/// ## Function Parameters
/// * `flags`: Flags used by the `init.init()` function.
///
/// ## Remarks
/// You still need to call `init.shutdown()` even if you close all open subsystems with `sdl.quit()`.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn quit(
    flags: InitFlags,
) void {
    c.SDL_QuitSubSystem(
        flags.toSdl(),
    );
}

/// Call a function on the main thread during event processing.
///
/// ## Function Parameters
/// * `UserData`: Type of user data.
/// * `callback`: The callback to call on the main thread.
/// * `user_data`: A pointer that is passed to callback.
/// * `wait_complete`: True to wait for the callback to complete, false to return immediately.
///
/// ## Remarks
/// If this is called on the main thread, the callback is executed immediately.
/// If this is called on another thread, this callback is queued for execution on the main thread during event processing.
///
/// Be careful of deadlocks when using this functionality.
/// ou should not have the main thread wait for the current thread while this function is being called with `wait_complete` true.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn runOnMainThread(
    comptime UserData: type,
    comptime callback: MainThreadCallback(UserData),
    user_data: ?*UserData,
    wait_complete: bool,
) !void {
    const Cb = struct {
        fn run(user_data_c: ?*anyopaque) callconv(.c) void {
            callback(@alignCast(@ptrCast(user_data_c)));
        }
    };
    const ret = c.SDL_RunOnMainThread(Cb.run, user_data, wait_complete);
    return errors.wrapCallBool(ret);
}

/// Clean up all initialized subsystems.
///
/// ## Remarks
/// You should call this function even if you have already shutdown each initialized subsystem with `init.quit()`.
/// It is safe to call this function even in the case of errors in initialization.
///
/// You can use this function with `atexit()` to ensure that it is run when your application is shutdown,
/// but it is not wise to do this from a library or other dynamically loaded code.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn shutdown() void {
    c.SDL_Quit();
}

/// Specify basic metadata about your app.
///
/// ## Function Parameters
/// * `app_name`: The name of the application ("My Game 2: Bad Guy's Revenge!").
/// * `app_version`: The version of the application ("1.0.0beta5" or a git hash, or whatever makes sense).
/// * `app_identifier`: A unique string in reverse-domain format that identifies this app ("com.example.mygame2").
///
/// ## Remarks
/// You can optionally provide metadata about your app to SDL.
/// This is not required, but strongly encouraged.
///
/// There are several locations where SDL can make use of metadata (an "About" box in the macOS menu bar, the name of the app can be shown on some audio mixers, etc).
/// Any piece of metadata can be left as null, if a specific detail doesn't make sense for the app.
///
/// This function should be called as early as possible, before `init.init()`.
/// Multiple calls to this function are allowed, but various state might not change once it has been set up with a previous call to this function.
///
/// Passing a null removes any previous metadata.
///
/// This is a simplified interface for the most important information.
/// You can supply significantly more detailed metadata with `init.SetAppMetadataProperty()`.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn setAppMetadata(
    app_name: ?[:0]const u8,
    app_version: ?[:0]const u8,
    app_identifier: ?[:0]const u8,
) !void {
    const ret = c.SDL_SetAppMetadata(
        if (app_name) |str_capture| str_capture.ptr else null,
        if (app_version) |str_capture| str_capture.ptr else null,
        if (app_identifier) |str_capture| str_capture.ptr else null,
    );
    return errors.wrapCallBool(ret);
}

/// Specify metadata about your app through a set of properties.
///
/// ## Function Parameters
/// * `property`: Property to set.
/// * `value`: Value to set the property to. This may be null to clear it.
///
/// ## Remarks
/// You can optionally provide metadata about your app to SDL.
/// This is not required, but strongly encouraged.
///
/// There are several locations where SDL can make use of metadata (an "About" box in the macOS menu bar, the name of the app can be shown on some audio mixers, etc).
/// Any piece of metadata can be left out, if a specific detail doesn't make sense for the app.
///
/// This function should be called as early as possible, before `init.init()`.
/// Multiple calls to this function are allowed, but various state might not change once it has been set up with a previous call to this function.
///
/// Once set, this metadata can be read using `init.getAppMetadataProperty()`.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn setAppMetadataProperty(
    property: AppMetadataProperty,
    value: ?[:0]const u8,
) !void {
    const ret = c.SDL_SetAppMetadataProperty(
        property.toSdl(),
        if (value) |str_capture| str_capture.ptr else null,
    );
    return errors.wrapCallBool(ret);
}

/// Get metadata about your app.
///
/// ## Function Parameters
/// * `property`: The metadata property to get.
///
/// ## Return Value
/// Returns the current value of the metadata property, or the default if it is not set, `null` for properties with no default.
///
/// ## Remarks
/// This returns metadata previously set using `init.setAppMetadata()` or `init.setAppMetadataProperty()`.
/// See `init.setAppMetadataProperty()` for the list of available properties and their meanings.
///
/// ## Thread Safety
/// It is safe to call this function from any thread,
/// although the string returned is not protected and could potentially be freed if you call `init.setAppMetadataProperty()` to set that property from another thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getAppMetadataProperty(
    property: AppMetadataProperty,
) ?[:0]const u8 {
    const ret = c.SDL_GetAppMetadataProperty(
        property.toSdl(),
    );
    if (ret == null)
        return null;
    return std.mem.span(ret);
}

/// Get which given systems have been initialized.
///
/// ## Function Parameters
/// * `flags`: Flags to mask the result with.
///
/// ## Return Value
/// Returns the mask of the argument with flags that have been initialized.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn wasInit(
    flags: InitFlags,
) InitFlags {
    const ret = c.SDL_WasInit(
        flags.toSdl(),
    );
    return InitFlags.fromSdl(ret);
}

//
// Stdinc stuff below.
//

/// A callback used to implement `calloc()`.
///
/// ## Function Parameters
/// * `num_members`: The number of elements in the array.
/// * `size`: The size of each element of the array.
///
/// ## Return Value
/// Returns a pointer to the allocated array, or `null` if allocation failed.
///
/// ## Remarks
/// SDL will always ensure that the passed `num_members` and `size` are both greater than `0`.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const CallocFunc = *const fn (
    num_members: usize,
    size: usize,
) ?[*]u8;

/// A callback used to implement `calloc()`.
///
/// ## Function Parameters
/// * `num_members`: The number of elements in the array.
/// * `size`: The size of each element of the array.
///
/// ## Return Value
/// Returns a pointer to the allocated array, or `null` if allocation failed.
///
/// ## Remarks
/// SDL will always ensure that the passed `num_members` and `size` are both greater than `0`.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const CallocFuncC = *const fn (
    num_members: usize,
    size: usize,
) callconv(.c) ?*anyopaque;

/// A callback used to implement `free()`.
///
/// ## Function Parameters
/// * `mem`: A pointer to allocated memory.
///
/// ## Remarks
/// SDL will ensure `mem` will never be null.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const FreeFunc = *const fn (
    mem: [*]u8,
) void;

/// A callback used to implement `free()`.
///
/// ## Function Parameters
/// * `mem`: A pointer to allocated memory.
///
/// ## Remarks
/// SDL will ensure `mem` will never be null.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const FreeFuncC = *const fn (
    mem: ?*anyopaque,
) callconv(.c) void;

/// A callback used to implement `malloc()`.
///
/// ## Function Parameters
/// * `size`: The size to allocate.
///
/// ## Return Value
/// Returns a pointer to the allocated memory, or `null` if allocation failed.
///
/// ## Remarks
/// SDL will always ensure that the passed `size` is greater than `0`.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const MallocFunc = *const fn (
    size: usize,
) ?[*]u8;

/// A callback used to implement `malloc()`.
///
/// ## Function Parameters
/// * `size`: The size to allocate.
///
/// ## Return Value
/// Returns a pointer to the allocated memory, or `null` if allocation failed.
///
/// ## Remarks
/// SDL will always ensure that the passed `size` is greater than `0`.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const MallocFuncC = *const fn (
    size: usize,
) callconv(.c) ?*anyopaque;

/// A callback used to implement `realloc()`.
///
/// ## Function Parameters
/// * `mem`: A pointer to allocated memory to reallocate, or `null`.
/// * `size`: The new size of the memory.
///
/// ## Return Value
/// Returns a pointer to the newly allocated memory, or `null` if allocation failed.
///
/// ## Remarks
/// SDL will always ensure that the passed `size` is greater than `0`.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const ReallocFunc = *const fn (
    mem: ?[*]u8,
    size: usize,
) ?[*]u8;

/// A callback used to implement `realloc()`.
///
/// ## Function Parameters
/// * `mem`: A pointer to allocated memory to reallocate, or `null`.
/// * `size`: The new size of the memory.
///
/// ## Return Value
/// Returns a pointer to the newly allocated memory, or `null` if allocation failed.
///
/// ## Remarks
/// SDL will always ensure that the passed `size` is greater than `0`.
///
/// ## Thread Safety
/// It should be safe to call this callback from any thread.
///
/// ## Version
/// This datatype is available since SDL 3.2.0.
pub const ReallocFuncC = *const fn (
    mem: ?*anyopaque,
    size: usize,
) callconv(.c) ?*anyopaque;

/// A thread-safe set of environment variables.
///
/// ## Version
/// This struct is available since SDL 3.2.0.
pub const Environment = packed struct {
    value: *c.SDL_Environment,

    /// Destroy a set of environment variables.
    ///
    /// ## Function Parameters
    /// * `self`: The environment to destroy.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread, as long as the environment is no longer in use.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn deinit(
        self: Environment,
    ) void {
        c.SDL_DestroyEnvironment(self.value);
    }

    /// Get the value of a variable in the environment.
    ///
    /// ## Function Parameters
    /// * `self`: The environment to query.
    /// * `name`: The name of the variable to get.
    ///
    /// ## Return Value
    /// Returns the environment variable, or `null` if it can't be found.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getVariable(
        self: Environment,
        name: [:0]const u8,
    ) ?[:0]const u8 {
        const ret = c.SDL_GetEnvironmentVariable(self.value, name.ptr);
        if (ret == null)
            return null;
        return std.mem.span(ret);
    }

    /// Get all variables in the environment.
    ///
    /// ## Function Parameters
    /// * `self`: The environment to query.
    ///
    /// ## Return Value
    /// Returns a `null` terminated array of pointers to environment variables in the form "variable=value".
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn getVariables(
        self: Environment,
    ) ![*:null][*c]u8 {
        return try errors.wrapCallNull([*:null][*c]u8, c.SDL_GetEnvironmentVariables(self.value));
    }

    /// Create a set of environment variables.
    ///
    /// ## Function Parameters
    /// * `populated`: True to initialize it from the C runtime environment, false to create an empty environment.
    ///
    /// ## Return Value
    /// Returns a new environment.
    ///
    /// ## Thread Safety
    /// If populated is false, it is safe to call this function from any thread, otherwise it is safe if no other threads are manipulating the enviroment variables.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn init(
        populated: bool,
    ) !Environment {
        return .{ .value = try errors.wrapCallNull(*c.SDL_Environment, c.SDL_CreateEnvironment(populated)) };
    }

    /// Set the value of a variable in the environment.
    ///
    /// ## Function Parameters
    /// * `self`: The environment to modify.
    /// * `name`: The name of the variable to set.
    /// * `value`: The value of the variable to set.
    /// * `overwrite`: True to overwrite the variable if it exists, false to return success without setting the variable if it already exists.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn setVariable(
        self: Environment,
        name: [:0]const u8,
        value: [:0]const u8,
        overwrite: bool,
    ) !void {
        return errors.wrapCallBool(c.SDL_SetEnvironmentVariable(self.value, name.ptr, value.ptr, overwrite));
    }

    /// Clear a variable from the environment.
    ///
    /// ## Function Parameters
    /// * `self`: The environment to modify.
    /// * `name`: The name of the variable to unset.
    ///
    /// ## Thread Safety
    /// It is safe to call this function from any thread.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn unsetVariable(
        self: Environment,
        name: [:0]const u8,
    ) !void {
        return errors.wrapCallBool(c.SDL_UnsetEnvironmentVariable(self.value, name.ptr));
    }

    // Size tests.
    comptime {
        std.debug.assert(@sizeOf(*c.SDL_Environment) == @sizeOf(Environment));
    }
};

/// Free allocated memory.
///
/// ## Function Parameters
/// * `mem`: A pointer to allocated memory, or `null`.
///
/// ## Remarks
/// The pointer is no longer valid after this call and cannot be dereferenced anymore.
///
/// If mem is `null`, this function does nothing.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn free(mem: anytype) void {
    switch (@typeInfo(@TypeOf(mem))) {
        .pointer => |pt| {
            if (pt.size == .slice) {
                c.SDL_free(@ptrCast(mem.ptr));
            } else {
                c.SDL_free(@ptrCast(mem));
            }
        },
        else => @compileError("Invalid argument to SDL free"),
    }
}

/// Get the process environment.
///
/// ## Return Value
/// Returns a pointer to the environment for the process.
///
/// ## Remarks
/// Use functions in the returned environment to manipulate it, use zig's environment functions to persist outside it.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getEnvironment() !Environment {
    return .{ .value = try errors.wrapCallNull(*c.SDL_Environment, c.SDL_GetEnvironment()) };
}

/// Get the current set of SDL memory functions.
///
/// ## Return Value
/// Returns the current memory functions.
///
/// ## Remarks
/// This is what `malloc()` and friends will use by default, if there has been no call to `setMemoryFunctions()`.
/// This is not necessarily using the C runtime's malloc functions behind the scenes!
/// Different platforms and build configurations might do any number of unexpected things.
///
/// ## Thread Safety
/// This does not hold a lock, so do not call this in the unlikely event of a background thread calling `setMemoryFunctions()` simultaneously.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getMemoryFunctions() struct { malloc: MallocFuncC, calloc: CallocFuncC, realloc: ReallocFuncC, free: FreeFuncC } {
    var malloc_fn: ?MallocFuncC = undefined;
    var calloc_fn: ?CallocFuncC = undefined;
    var realloc_fn: ?ReallocFuncC = undefined;
    var free_fn: ?FreeFuncC = undefined;
    c.SDL_GetMemoryFunctions(
        &malloc_fn,
        &calloc_fn,
        &realloc_fn,
        &free_fn,
    );
    return .{ .malloc = malloc_fn.?, .calloc = calloc_fn.?, .realloc = realloc_fn.?, .free = free_fn.? };
}

/// Get the number of outstanding (unfreed) allocations.
///
/// ## Return Value
/// Returns the number of allocations or `null` if allocation counting is disabled.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getNumAllocations() ?usize {
    const ret = c.SDL_GetNumAllocations();
    if (ret == -1)
        return null;
    return @intCast(ret);
}

/// Get the original set of SDL memory functions.
///
/// ## Return Value
/// Returns the original memory functions.
///
/// ## Remarks
/// This is what `malloc()` and friends will use by default, if there has been no call to `setMemoryFunctions()`.
/// This is not necessarily using the C runtime's malloc functions behind the scenes!
/// Different platforms and build configurations might do any number of unexpected things.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn getOriginalMemoryFunctions() struct { malloc: MallocFuncC, calloc: CallocFuncC, realloc: ReallocFuncC, free: FreeFuncC } {
    var malloc_fn: ?MallocFuncC = undefined;
    var calloc_fn: ?CallocFuncC = undefined;
    var realloc_fn: ?ReallocFuncC = undefined;
    var free_fn: ?FreeFuncC = undefined;
    c.SDL_GetOriginalMemoryFunctions(
        &malloc_fn,
        &calloc_fn,
        &realloc_fn,
        &free_fn,
    );
    return .{ .malloc = malloc_fn.?, .calloc = calloc_fn.?, .realloc = realloc_fn.?, .free = free_fn.? };
}

/// Convert a single Unicode codepoint to UTF-8.
///
/// ## Function Parameters
/// * `codepoint`: A Unicode codepoint to convert to UTF-8.
/// * `dst`: The location to write the encoded UTF-8. Must point to at least 4 bytes!
///
/// ## Return Value
/// Returns the address of the first byte past the newly-written UTF-8 sequence.
///
/// ## Remarks
/// If codepoint is an invalid value (outside the Unicode range, or a UTF-16 surrogate value, etc), this will use `U+FFFD (REPLACEMENT CHARACTER)`
/// for the codepoint instead, and not set an error.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn ucs4ToUtf8(codepoint: u32, dst: *[4]u8) [*]u8 {
    return c.SDL_UCS4ToUTF8(codepoint, dst);
}

/// Allocator that uses SDL's `malloc()` and `free()` functions.
pub const allocator = std.mem.Allocator{
    .ptr = undefined,
    .vtable = &.{
        .alloc = sdlAlloc,
        .resize = sdlResize,
        .remap = sdlRemap,
        .free = sdlFree,
    },
};

fn sdlAlloc(ptr: *anyopaque, len: usize, alignment: std.mem.Alignment, ret_addr: usize) ?[*]u8 {
    _ = ptr;
    _ = alignment;
    _ = ret_addr;
    const ret = c.SDL_malloc(len);
    if (ret) |val| {
        return @as([*]u8, @alignCast(@ptrCast(val)));
    }
    return null;
}

fn sdlResize(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) bool {
    _ = ptr;
    _ = memory;
    _ = alignment;
    _ = new_len;
    _ = ret_addr;
    return false;
}

fn sdlRemap(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, ret_addr: usize) ?[*]u8 {
    _ = ptr;
    _ = alignment;
    _ = ret_addr;
    const ret = c.SDL_realloc(memory.ptr, new_len);
    if (ret) |val| {
        return @as([*]u8, @alignCast(@ptrCast(val)));
    }
    return null;
}

fn sdlFree(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret_addr: usize) void {
    _ = ptr;
    _ = alignment;
    _ = ret_addr;
    c.SDL_free(memory.ptr);
}

/// Replace SDL's memory allocation functions with the original ones.
///
/// ## Version
/// This is provided by zig-sdl3.
pub fn restoreMemoryFunctions() !void {
    const originals = getOriginalMemoryFunctions();
    return errors.wrapCallBool(c.SDL_SetMemoryFunctions(
        originals.malloc,
        originals.calloc,
        originals.realloc,
        originals.free,
    ));
}

/// Replace SDL's memory allocation functions with a custom set.
///
/// ## Function Parameters
/// * `malloc`: Custom `malloc` function.
/// * `calloc`: Custom `calloc` function.
/// * `realloc`: Custom `realloc` function.
/// * `free`: Custom `free` function.
///
/// ## Return Value
/// Returns the addresses to the C final functions.
///
/// ## Remarks
/// It is not safe to call this function once any allocations have been made, as future calls to `free()` will use the new allocator,
/// even if they came from an `malloc()` made with the old one!
///
/// If used, usually this needs to be the first call made into the SDL library, if not the very first thing done at program startup time.
///
/// ## Thread Safety
/// It is safe to call this function from any thread, but one should not replace the memory functions once any allocations are made!
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn setMemoryFunctions(
    comptime malloc_fn: MallocFunc,
    comptime calloc_fn: CallocFunc,
    comptime realloc_fn: ReallocFunc,
    comptime free_fn: FreeFunc,
) !struct { malloc: MallocFuncC, calloc: CallocFuncC, realloc: ReallocFuncC, free: FreeFuncC } {
    const Cb = struct {
        pub fn malloc(
            size: usize,
        ) callconv(.c) ?*anyopaque {
            return malloc_fn(size);
        }
        pub fn calloc(
            num_members: usize,
            size: usize,
        ) callconv(.c) ?*anyopaque {
            return calloc_fn(num_members, size);
        }
        pub fn realloc(
            mem: ?*anyopaque,
            size: usize,
        ) callconv(.c) ?*anyopaque {
            return realloc_fn(@alignCast(@ptrCast(mem)), size);
        }
        pub fn free(
            mem: ?*anyopaque,
        ) callconv(.c) void {
            return free_fn(@alignCast(@ptrCast(mem.?)));
        }
    };
    const ret = c.SDL_SetMemoryFunctions(
        Cb.malloc,
        Cb.calloc,
        Cb.realloc,
        Cb.free,
    );
    try errors.wrapCallBool(ret);
    return .{ .malloc = Cb.malloc, .calloc = Cb.calloc, .realloc = Cb.realloc, .free = Cb.free };
}

/// Iterate over a UTF8 string in reverse.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const Utf8ReverseIterator = struct {
    str: [*c]const u8,
    start: [*c]const u8,

    /// Get the previous UTF-8 codepoint.
    ///
    /// ## Function Parameters
    /// * `self`: The UTF-8 iterator.
    ///
    /// ## Return Value
    /// Returns the previous unicode codepoint, or `null` if done.
    ///
    /// ## Thread Safety
    /// This function is not thread safe.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn prev(
        self: *Utf8ReverseIterator,
    ) ?u32 {
        const ret = c.SDL_StepBackUTF8(self.start, &self.str);
        if (ret == 0)
            return null;
        return ret;
    }
};

/// Decode a UTF-8 string in reverse, one Unicode codepoint at a time.
///
/// ## Function Parameters
/// * `str`: The UTF-8 string to decode.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn stepBackUtf8(
    str: []const u8,
) Utf8ReverseIterator {
    return .{
        .str = @ptrFromInt(@intFromPtr(str.ptr) + str.len),
        .start = str.ptr,
    };
}

/// Iterate over a UTF8 string.
///
/// ## Version
/// This struct is provided by zig-sdl3.
pub const Utf8Iterator = struct {
    str: [*c]const u8,
    len: usize,

    /// Get the next UTF-8 codepoint.
    ///
    /// ## Function Parameters
    /// * `self`: The UTF-8 iterator.
    ///
    /// ## Return Value
    /// Returns the next unicode codepoint, or `null` if done.
    ///
    /// ## Thread Safety
    /// This function is not thread safe.
    ///
    /// ## Version
    /// This function is available since SDL 3.2.0.
    pub fn next(
        self: *Utf8Iterator,
    ) ?u32 {
        const ret = c.SDL_StepUTF8(&self.str, &self.len);
        if (ret == 0)
            return null;
        return ret;
    }
};

/// Decode a UTF-8 string, one Unicode codepoint at a time.
///
/// ## Function Parameters
/// * `str`: The UTF-8 string to decode.
///
/// ## Thread Safety
/// It is safe to call this function from any thread.
///
/// ## Version
/// This function is available since SDL 3.2.0.
pub fn stepUtf8(
    str: []const u8,
) Utf8Iterator {
    return .{
        .str = str.ptr,
        .len = str.len,
    };
}

/// Custom allocator to use for `setMemoryFunctionsByAllocator()`.
var custom_allocator: std.mem.Allocator = undefined;

const Allocation = struct {
    size: usize,
};

fn allocationSize(request_size: usize) usize {
    var size: usize = request_size;
    while (size % @min(@sizeOf(@cImport(@cInclude("stddef.h")).max_align_t), @sizeOf(?*anyopaque) * 2) != 0) // TODO: Optimize this?
        size += 1;
    return size;
}

fn makeAllocation(total_size: usize, comptime memset: bool) ?[*]u8 {
    const total_buf = custom_allocator.alloc(u8, allocationSize(total_size) + @sizeOf(Allocation)) catch return null;
    if (memset)
        @memset(total_buf, 0);
    const allocation: *Allocation = @ptrCast(@alignCast(total_buf.ptr));
    allocation.size = total_buf.len;
    const data_ptr: [*]u8 = @ptrFromInt(@intFromPtr(total_buf.ptr) + @sizeOf(Allocation));
    // std.debug.print("MAKE PTR: {p}, {d}\n", .{ data_ptr, allocation.size });
    return data_ptr;
}

fn allocCalloc(num_members: usize, size: usize) ?[*]u8 {
    return makeAllocation(num_members * size, true);
}

fn allocFree(mem: [*]u8) void {
    const allocation: *Allocation = @ptrFromInt(@intFromPtr(mem) - @sizeOf(Allocation));
    // std.debug.print("CLEAR PTR: {p}, {d}\n", .{ raw_ptr, allocation.size });
    custom_allocator.free(@as([*]u8, @ptrCast(allocation))[0..allocation.size]);
}

fn allocMalloc(size: usize) ?[*]u8 {
    return makeAllocation(size, false);
}

fn allocRealloc(mem: ?[*]u8, size: usize) ?[*]u8 {
    const raw_ptr = mem orelse return allocMalloc(size);
    // const allocation: *Allocation = @alignCast(@fieldParentPtr("buf", @as(*void, @ptrCast(raw_ptr))));
    allocFree(raw_ptr);
    return allocMalloc(size);
    // const total_buf = custom_allocator.realloc(@as([*]u8, @ptrCast(raw_ptr))[0..allocation.size], allocationSize(size) + @sizeOf(Allocation)) catch return null;
    // allocation = @ptrCast(@alignCast(total_buf.ptr));
    // allocation.size = total_buf.len;
    // return &allocation.buf;
}

/// Replace SDL's memory allocation functions to use with an allocator.
/// This can be restored with `restoreMemoryFunctions()`.
///
/// ## Function Parameters
/// * `new_allocator`: The new allocator to use for allocations.
///
/// ## Return Value
/// Returns the addresses to the C final functions.
///
/// ## Remarks
/// It is not safe to call this function once any allocations have been made, as future calls to `free()` will use the new allocator,
/// even if they came from an `malloc()` made with the old one!
///
/// If used, usually this needs to be the first call made into the SDL library, if not the very first thing done at program startup time.
///
/// ## Version
/// This is provided by zig-sdl3.
pub fn setMemoryFunctionsByAllocator(
    new_allocator: std.mem.Allocator,
) !struct { malloc: MallocFuncC, calloc: CallocFuncC, realloc: ReallocFuncC, free: FreeFuncC } {
    custom_allocator = new_allocator;
    const ret = try setMemoryFunctions(
        allocMalloc,
        allocCalloc,
        allocRealloc,
        allocFree,
    );
    return .{ .malloc = ret.malloc, .calloc = ret.calloc, .realloc = ret.realloc, .free = ret.free };
}

fn testRunOnMainThreadCb(user_data: ?*i32) void {
    user_data.?.* = -1;
}

// Add all tests from subsystems.
test {
    std.testing.refAllDecls(@This());

    defer shutdown();
    const flags = InitFlags{
        .events = true,
        .camera = true,
    };
    try setAppMetadata("SDL3 Test", null, "!Testing");
    try init(flags);
    defer quit(flags);
    try std.testing.expect(isMainThread());
    var data: i32 = 1;
    try runOnMainThread(i32, testRunOnMainThreadCb, &data, true);
    try std.testing.expectEqual(-1, data);
    try std.testing.expectEqual(flags, wasInit(flags));
    try std.testing.expectEqualStrings("SDL3 Test", getAppMetadataProperty(.name).?);
    try std.testing.expectEqual(null, getAppMetadataProperty(.version));
    try std.testing.expectEqualStrings("!Testing", getAppMetadataProperty(.identifier).?);
    try setAppMetadataProperty(.creator, "Gota7");
    try std.testing.expectEqualStrings("Gota7", getAppMetadataProperty(.creator).?);
    try setAppMetadataProperty(.creator, null);
    try std.testing.expectEqual(null, getAppMetadataProperty(.creator));
    try std.testing.expectEqual(null, getAppMetadataProperty(.url));

    custom_allocator = std.testing.allocator;
    var ptr = allocMalloc(5).?;
    allocFree(ptr);
    ptr = allocCalloc(3, 5).?;
    ptr = allocRealloc(ptr, 303).?;
    allocFree(ptr);
}
