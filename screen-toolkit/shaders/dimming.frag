#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 selectionRect;
    float dimOpacity;
    vec2 screenSize;
    float borderRadius;
    float outlineThickness;
    vec4 outlineColor;
};

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 halfSize = selectionRect.zw * 0.5;
    vec2 center   = selectionRect.xy + halfSize;
    vec2 p        = qt_TexCoord0 * screenSize - center;

    float dist          = sdRoundedBox(p, halfSize, borderRadius);
    float aa            = max(fwidth(dist), 0.0001);
    float safeThickness = max(outlineThickness, aa * 2.0);

    float outerStep  = smoothstep(-aa, aa, dist);
    float outlineEnd = smoothstep(safeThickness - aa, safeThickness + aa, dist);

    float outlineMask = outerStep * (1.0 - outlineEnd);
    float dimMask     = outlineEnd;

    vec4 finalOutlineColor = vec4(outlineColor.rgb, outlineColor.a * qt_Opacity);
    vec4 dimColor          = vec4(0.0, 0.0, 0.0, dimOpacity * qt_Opacity);

    fragColor = outlineMask * finalOutlineColor + dimMask * dimColor;
}

