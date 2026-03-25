#version 460 core
#include <flutter/runtime_effect.glsl>

uniform sampler2D uCanvasTexture;
uniform float uAccretionDisk;
uniform vec2 uResolution;
uniform vec3 uCameraTranslate;
uniform float uPov;
uniform float uMaxIterations;
uniform float uStepSize;
uniform float uTime;

out vec4 fragColor;

#define SPEED_OF_LIGHT 1.0
#define EVENT_HORIZON_RADIUS 1.0
#define BACKGROUND_DISTANCE 1000.0
#define PI 3.14159265359

// ---------------------------
// -- FBM -> ACCRETION DISK---
// ---------------------------
float hash(float n) { return fract(sin(n) * 753.5453123); }
float noise(vec3 x) {
    vec3 p = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    float n = p.x + p.y * 157.0 + 113.0 * p.z;
    return mix(mix(mix(hash(n + 0.0), hash(n + 1.0), f.x),
                   mix(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
               mix(mix(hash(n + 113.0), hash(n + 114.0), f.x),
                   mix(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
}

float fbm(vec3 pos) {
    float t = noise(pos) * 1.0 + 0.5;
    for (int i = 1; i < 3; i++) {
        pos *= 3.0;
        t *= noise(pos) * 0.5 + 0.75;
    }
    return t;
}

vec3 geodesic_equation(vec3 position, float h2) {
    return -(1.5 * h2 * position) / pow(length(position), 5.0);
}

void main() {
    // 居中核心逻辑：在计算 UV 时应用偏移，而不是修改摄像机视角逻辑
    // 这样可以确保原作者的 1:1 投影和畸变逻辑完全不受干扰
    vec2 uv = (FlutterFragCoord().xy - 0.5 * uResolution) / min(uResolution.y, uResolution.x);
    
    // --- 恢复原作者 1:1 摄像机初始化 ---
    vec3 camera_pos = vec3(0.0, 0.05, 20.0);
    float camX = camera_pos.x + uCameraTranslate.x;
    float camY = camera_pos.y + uCameraTranslate.y;
    
    // 原版旋转矩阵
    mat3 rotY = mat3(cos(camX), 0, sin(camX), 0, 1, 0, -sin(camX), 0, cos(camX));
    mat3 rotX = mat3(1, 0, 0, 0, cos(camY), -sin(camY), 0, sin(camY), cos(camY));
    
    vec3 look_from = rotY * rotX * camera_pos;
    
    // 1:1 射线方向逻辑 (rd)
    vec3 rd = normalize(vec3(uv, -1.0)); 
    rd = rotY * rotX * rd;

    vec3 position = look_from;
    vec3 velocity = SPEED_OF_LIGHT * rd;
    float h2 = pow(length(cross(position, velocity)), 2.0);

    vec3 finalColor = vec3(0.0);
    bool hit = false;

    // --- 恢复原版 RK4 积分循环 ---
    for (int i = 0; i < 128; i++) {
        if (i >= int(uMaxIterations)) break;
        
        float dist = length(position);
        if (dist < EVENT_HORIZON_RADIUS) {
            finalColor = vec3(0.0);
            hit = true;
            break;
        }
        if (dist > BACKGROUND_DISTANCE) break;

        float step_size = dist * dist * uStepSize;
        vec3 rk_delta = velocity * step_size;

        // 1:1 RK-4 实现
        vec3 k1 = step_size * geodesic_equation(position, h2);
        vec3 k2 = step_size * geodesic_equation(position + 0.5 * rk_delta + 0.125 * k1 * step_size, h2);
        vec3 k3 = step_size * geodesic_equation(position + 0.5 * rk_delta + 0.125 * k2 * step_size, h2);
        vec3 k4 = step_size * geodesic_equation(position + rk_delta + 0.5 * k3 * step_size, h2);
        vec3 d = (k1 + 2.0 * (k2 + k3) + k4) / 6.0;

        vec3 next_p = position + rk_delta + d * uStepSize;
        
        // --- 恢复原版吸积盘逻辑 (包含正面穿过引力透镜看到下方的设定) ---
        if (uAccretionDisk > 0.5 && position.y * next_p.y < 0.0) {
            float r_disk = length(position.xz);
            if (r_disk > 2.0 && r_disk < 8.0) {
                float disk_intensity = 1.0 - length(position / vec3(8.0, 1.0, 8.0));
                disk_intensity *= smoothstep(2.0, 3.0, r_disk);
                
                vec3 uvw = vec3(atan(position.z, position.x) / (2.0 * PI), (r_disk - 2.0) / 6.0, position.y);
                float density = fbm(position + uvw * 2.0);
                disk_intensity *= inversesqrt(r_disk) * density;
                
                float dpth = step_size * (uMaxIterations / 10.0) * disk_intensity;
                
                // 1:1 红移计算
                float redshift = sqrt((1.0 - 2.0 / r_disk) / (1.0 - 2.0 / length(look_from)));
                finalColor += vec3(1.0, 0.65, 0.5) * redshift * dpth;
            }
        }

        position += rk_delta;
        velocity += d;
    }

    if (!hit) {
        // 1:1 背景映射
        vec3 positioned = normalize(position);
        float theta = atan(positioned.x, positioned.z);
        float phi = asin(positioned.y);
        vec2 new_coord = vec2(theta / PI + 0.5, phi / PI + 0.5);
        finalColor += texture(uCanvasTexture, new_coord).rgb;
    }

    // 1:1 光晕
    float glow = 0.01 / length(position - look_from);
    finalColor += vec3(1.0, 0.7, 0.5) * clamp(glow * 12.0, 0.0, 1.0);

    fragColor = vec4(finalColor, 1.0);
}
