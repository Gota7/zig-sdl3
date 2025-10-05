#version 450

struct SpriteComputeData
{
    vec3 position;
    float rotation;
    vec2 scale;
    vec4 texture;
    vec4 color;
};

struct SpriteVertex
{
    vec4 position;
    vec2 tex_coord;
    vec4 color;
};

layout(local_size_x = 64) in;
layout(set = 0, binding = 0, std140) buffer computeBuffer {
    SpriteComputeData sprites[];
};

layout(set = 1, binding = 0, std140) buffer vertexBuffer {
    SpriteVertex vertices[];
};

void main() {
    uint sprite_ind = gl_GlobalInvocationID.x;
    SpriteComputeData sprite = sprites[sprite_ind];

    mat4 scale = mat4(
            vec4(sprite.scale.x, 0.0f, 0.0f, 0.0f),
            vec4(0.0f, sprite.scale.y, 0.0f, 0.0f),
            vec4(0.0f, 0.0f, 1.0f, 0.0f),
            vec4(0.0f, 0.0f, 0.0f, 1.0f)
        );

    float c = cos(sprite.rotation);
    float s = sin(sprite.rotation);

    mat4 rotation = mat4(
            vec4(c, s, 0.0f, 0.0f),
            vec4(-s, c, 0.0f, 0.0f),
            vec4(0.0f, 0.0f, 1.0f, 0.0f),
            vec4(0.0f, 0.0f, 0.0f, 1.0f)
        );

    mat4 translation = mat4(
            vec4(1.0f, 0.0f, 0.0f, 0.0f),
            vec4(0.0f, 1.0f, 0.0f, 0.0f),
            vec4(0.0f, 0.0f, 1.0f, 0.0f),
            vec4(sprite.position.x, sprite.position.y, sprite.position.z, 1.0f)
        );

    mat4 model = translation * rotation * scale;

    vec4 top_left = vec4(0.0f, 0.0f, 0.0f, 1.0f);
    vec4 top_right = vec4(1.0f, 0.0f, 0.0f, 1.0f);
    vec4 bottom_left = vec4(0.0f, 1.0f, 0.0f, 1.0f);
    vec4 bottom_right = vec4(1.0f, 1.0f, 0.0f, 1.0f);

    vertices[sprite_ind * 4u].position = model * top_left;
    vertices[sprite_ind * 4u + 1].position = model * top_right;
    vertices[sprite_ind * 4u + 2].position = model * bottom_left;
    vertices[sprite_ind * 4u + 3].position = model * bottom_right;

    vertices[sprite_ind * 4u].tex_coord = vec2(sprite.texture.x, sprite.texture.y);
    vertices[sprite_ind * 4u + 1].tex_coord = vec2(sprite.texture.x + sprite.texture.z, sprite.texture.y);
    vertices[sprite_ind * 4u + 2].tex_coord = vec2(sprite.texture.x, sprite.texture.y + sprite.texture.w);
    vertices[sprite_ind * 4u + 3].tex_coord = vec2(sprite.texture.x + sprite.texture.z, sprite.texture.y + sprite.texture.w);

    vertices[sprite_ind * 4u].color = sprite.color;
    vertices[sprite_ind * 4u + 1].color = sprite.color;
    vertices[sprite_ind * 4u + 2].color = sprite.color;
    vertices[sprite_ind * 4u + 3].color = sprite.color;
}
