// DISSOLVE — the noise-threshold trick as a minimal ShaderLab shader.
// Per pixel: sample noise; if noise < threshold, discard the pixel.
// Raising the threshold from 0→1 eats the sprite away in noise-shaped
// islands. Pair with DissolveDriver.cs. Chapter 03 of the book.
Shader "SparksAndSprites/Dissolve"
{
    Properties
    {
        _MainTex ("Sprite", 2D) = "white" {}
        _NoiseTex ("Noise", 2D) = "white" {}
        _Threshold ("Threshold", Range(0, 1)) = 0
        _EdgeColor ("Edge glow", Color) = (1, 0.6, 0.2, 1)
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off ZWrite Off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _MainTex, _NoiseTex;
            float _Threshold;
            fixed4 _EdgeColor;

            fixed4 frag (v2f_img i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                float noise = tex2D(_NoiseTex, i.uv).r;
                if (noise < _Threshold) discard;          // ← the whole trick
                // a thin burning edge just above the threshold
                if (noise < _Threshold + 0.05) col.rgb = _EdgeColor.rgb;
                return col;
            }
            ENDCG
        }
    }
}
