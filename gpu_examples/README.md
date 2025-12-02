# SDL3 GPU Examples
Zig examples of using SDL3's GPU subsystem along with shadercross to run all provided shader formats on the target. SDL shadercross bridges the platform shader format gap such that the shaders "just work" everywhere.

## Build System
You can use `zig build examples` to build all of the example executables, and `zig build run -Dexample=example-zig-file-here` (Ex: `-Dexample=basic-triangle`) to run a particular example. You may also specify the shader format to use with `-Dshader_format`. Note that the default format is `zig`. You are free to use the build system as a reference for building your own project's, taking the shader format you like most.

Zig shaders use `spirv-opt` on the system to optimize the result of SPIR-V as zig does not optimize SPIR-V iirc? Also, you may not compile zig shaders on a Windows system at the moment [due to this issue](https://github.com/ziglang/zig/issues/23883). There is nothing stopping you from cross-compiling for a Windows system, but doing dev from a Windows environment would be unfun.

GLSL shaders use `glslang` on the system in order to compile GLSL into SPIR-V binaries.

HLSL shaders are compiled at runtime using SDL shadercross. Note that nothing is stopping you from pre-compiling HLSL into SPIR-V using `glslang` if runtime flexibility is not needed.

## Shader Formats
Each shader format has its own ups and downs.

### Zig
Pros:
* It's zig
* Tooling already installed with the compiler

Cons:
* Inline assembly required for more complex tasks
* External tool required at compile time to maximize performance
* No runtime recompilation support

### Compiled GLSL/HLSL
Pros:
* Normal shading language

Cons:
* Requires `glslang` or other shader compiler at build time
* No runtime recompilation support

### Runtime HLSL
Pros:
* Runtime recompilation support
* Normal shading language

Cons:
* Requires additional less-flexible dependencies for SDL shadercross
