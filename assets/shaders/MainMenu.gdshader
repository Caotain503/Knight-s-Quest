shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 30.0) = 12.0;
uniform int sample_count : hint_range(8, 64) = 32;
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.008;
uniform float distortion_speed : hint_range(0.0, 2.0) = 0.3;
uniform float distortion_scale : hint_range(1.0, 20.0) = 4.0;

const float GOLDEN_ANGLE = 2.3999632;

// Pseudo-random noise fonksiyonu
float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// Smooth value noise (gerçek duman/sis görünümü için)
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 pixel_size = TEXTURE_PIXEL_SIZE;
    
    // Zaman bazlı, akan bir noise üret. Bu UV'yi hafifçe iter, duman gibi salınım yaratır.
    float n1 = noise(UV * distortion_scale + TIME * distortion_speed);
    float n2 = noise(UV * distortion_scale - TIME * distortion_speed * 0.7);
    vec2 distorted_uv = UV + vec2(n1 - 0.5, n2 - 0.5) * distortion_strength;
    
    // Distorted UV üzerinden disk blur uygula
    vec4 color = texture(TEXTURE, distorted_uv);
    
    for (int i = 1; i < sample_count; i++) {
        float angle = float(i) * GOLDEN_ANGLE;
        float radius = sqrt(float(i) / float(sample_count));
        
        vec2 offset = vec2(cos(angle), sin(angle)) * radius * blur_amount;
        offset *= pixel_size;
        
        color += texture(TEXTURE, distorted_uv + offset);
    }
    
    COLOR = color / float(sample_count);
}