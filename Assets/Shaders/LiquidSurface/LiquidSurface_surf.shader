Shader "Helliaca/LiquidSurface_surf"
{
    Properties
    {
        _HashSeed ("Hash Function Seed", Float) = 1.0
        _Seed ("Seed", Float) = 1.0
        _Frequency ("Frequency", Range (0.0,0.5)) = 0.16
        _Amplitude ("Amplitude", Range (-2.0, 2.0)) = 0.6
        _Choppiness ("Choppiness", Range (-0.75, 20.0)) = 4.0
        _Wave_iter ("Geometry Iterations", Range(0, 5)) = 3
        _Detail_iter ("Detail Iterations", Range(0, 10)) = 5

        _SkyColor ("SkyColor", Color) = (0.788, 0.871, 1.0, 1.0)

        _SeaAmbientColor ("Sea Ambient", Color) = (0.0, 0.09, 0.18, 1.0)
        _SeaDiffuseColor ("Sea Diffuse", Color) = (0.058, 0.065, 0.043, 1.0)
        _SeaDiffuseExponent ("Sea Diffuse Exponent", Float) = 30
        _SeaSpecularColor ("Sea Specular", Color) = (1.0, 1.0, 1.0, 1.0)
        _SeaSpecularExponent ("Sea Specular Exponent", Float) = 60
        _SeaSurfaceColor ("Sea Surface", Color) = (0.48, 0.54, 0.36, 1.0)
        _SeaSurfaceHeight ("Sea Surface Height", Float) = 0.6
        _SeaSurfaceDepthAttentuationFactor ("Sea Surface Attenuation Factor by Depth", Float) = 0.18
        _SeaSurfaceDistanceAttentuationFactor ("Sea Surface Attenuation Factor by Distance", Float) = 0.001

        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows Lambert vertex:vert
        

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
            float3 worldPos;
            float3 worldNormal;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        uniform float _Seed;
        uniform float _HashSeed;
        uniform float _Frequency;
        uniform float _Amplitude;
        uniform float _Choppiness;
        uniform int _Wave_iter;
        uniform int _Detail_iter;

        uniform float4 _SkyColor;
        uniform float4 _SeaAmbientColor;
        uniform float4 _SeaDiffuseColor;
        uniform float _SeaDiffuseExponent;
        uniform float4 _SeaSpecularColor;
        uniform float _SeaSpecularExponent;
        uniform float4 _SeaSurfaceColor;
        uniform float _SeaSurfaceHeight;
        uniform float _SeaSurfaceDepthAttentuationFactor;
        uniform float _SeaSurfaceDistanceAttentuationFactor;

        // >>> Helper functions

        #define PI 3.1415927f
        #define f2_00 float2(0.0f, 0.0f)
        #define f2_10 float2(1.0f, 0.0f)
        #define f2_01 float2(0.0f, 1.0f)
        #define f2_11 float2(1.0f, 1.0f)

        // Provides random hash based on floating point seed
        float hash(float f) {
            return frac(sin(f)*_HashSeed);
        }

        // Provides random hash based on 2d vector as seed
        float hash(float2 v) {
            // dot product with some random, constant vector
            return hash( dot(v, float2(_Seed, hash(_Seed))) );
        }

        // Provides noise texture with each integer having a value in [-1,1] and values inbetween being bi-linearly interpolated
        float int_noise(float2 v) {
            // Get integer position of v as well as fractional (v % 1)
            float2 p = floor(v);
            float2 fr = frac(v);

            // Smoothstep the fractional part to avoid jagged edges inbetween values
            fr = smoothstep(f2_00, f2_11, fr);
            // Get inverse vector, we need this in the next step
            float2 fm = f2_11 - fr;

            // Perform a linear square-interpolation between p, p+(1,0), p+(0,1) and p+(1,1). See: https://en.wikipedia.org/wiki/Bilinear_interpolation#Unit_square
            float k = hash(p) * fm.x*fm.y + 
                hash(p+f2_10) * fr.x*fm.y + 
                hash(p+f2_01) * fm.x*fr.y + 
                hash(p+f2_11) * fr.x*fr.y;

            // Transform to values between -1 and 1
            return -1.0 + 2.0 * k;
        }

        // Provides a semi-random random texture with smooth waves. Example: https://i.imgur.com/VFP54aQ.png
        float wave(float2 uv, float choppy) {
            // Distort UV map with noise
            uv.x += int_noise(uv);
            uv.y += int_noise(uv);
            // Sine function in [0,1] with 2x the frequency
            // The lines below provide a smooth, regular grid of waves moving back-and-forth. The distortion step above provides the necessary randomness.
            float2 wv = 0.5 * ( sin(2.0f*uv) + 1.0f ); 
            return pow(1.0-pow(wv.x * wv.y,0.65),choppy);
        }

        // overlay of multiple maps or smth?
        float map2(float2 uv) {
            float freq = _Frequency;
            float amp = _Amplitude;
            float choppy = _Choppiness;

            float2x2 octave_m = float2x2(1.6,-1.2,1.2,1.6);

            float d, h = 0.0f;

            for(int i=0; i < _Wave_iter; i++) {
                d = wave( _Frequency*(_Time[1]+uv), choppy);  // get base wave value
                d += wave( _Frequency*(_Time[1]-uv), choppy); // For some additional randomness?
                h += d*amp;                             // Add this value to the height based on amplitude

                uv = mul(octave_m, uv);                 // Spiral the UV somewhere else for next sample
                freq*= 1.9f;                           // Increase frequency of wave-map (higher detail)
                amp *= 0.22f;                           // Decrease amplitude (add detail waves that are smaller)

                choppy = lerp(choppy, 1.0f, 0.2f);      // Increase choppiness, as bigger waves are smoother and smaller ones are choppier
            }
            return -h;
        }
        float map2_detailed(float2 uv) {
            float freq = _Frequency;
            float amp = _Amplitude;
            float choppy = _Choppiness;

            float2x2 octave_m = float2x2(1.6,-1.2,1.2,1.6);

            float d, h = 0.0f;

            for(int i=0; i < _Detail_iter; i++) {
                d = wave( freq*(_Time[1]+uv), choppy);
                d += wave( freq*(_Time[1]-uv), choppy);
                h += d*amp;

                uv = mul(octave_m, uv);
                freq *= 1.9f;
                amp *= 0.22f;

                choppy = lerp(choppy, 1.0f, 0.2f);
            }
            return -h;
        }

        float3 getNormal(float2 uv, float eps) {
            // Derive Surface normal from difference in height based on x+eps and z+eps
            float3 n;
            n.y = map2_detailed(uv);    // Get height at current position
            n.x = map2_detailed(float2(uv.x+eps, uv.y)) - n.y;
            n.z = map2_detailed(float2(uv.x, uv.y+eps)) - n.y;
            n.y = eps;
            return normalize(n);
        }
        float fresnel (float3 normal, float3 viewDir) {
            return pow( clamp(1.0 - dot(normal, -viewDir), 0.0, 1.0), 3.0 ) * 0.5;
        }
        float3 phong(float3 ambient, float3 diffuse, float3 spec, float3 n, float3 l, float3 viewDir) {
            float diff_str = 1.0f;//pow(dot(n,l), _SeaDiffuseExponent);
            float spec_str = 0.0f;//pow(max(dot(l, reflect(viewDir, n)), 0.0), _SeaSpecularExponent);
            return ambient + diff_str * diffuse + spec_str * spec;
        }
        //Old
        float3 getSeaColor_old(float3 p, float3 n, float3 l, float3 eye, float3 dist) {  
            // We perform regular phong shading
            float3 ph = phong(_SeaAmbientColor, _SeaDiffuseColor, _SeaSpecularColor, n, l, eye);
            // Apply a frensel effect with sky color
            float3 color = lerp(ph, _SkyColor, fresnel(n, eye));
            
            // Attenuate towards a differen color on the surface
            float atten = max(1.0 - dot(dist,dist) * _SeaSurfaceDistanceAttentuationFactor, 0.0);
            color += _SeaSurfaceColor * (p.y - _SeaSurfaceHeight) * _SeaSurfaceDepthAttentuationFactor * atten;
            
            return color;
        }

        float3 getSeaColor(float3 dist) {  
            // We perform regular phong shading
            //float3 ph = phong(_SeaAmbientColor, _SeaDiffuseColor, _SeaSpecularColor, n, l, eye);
            // Apply a frensel effect with sky color
            //float3 color = lerp(ph, _SkyColor, fresnel(n, eye));
            float3 color = _SeaDiffuseColor;
            // Attenuate towards a differen color on the surface
            float atten = max(1.0 - dot(dist,dist) * _SeaSurfaceDistanceAttentuationFactor, 0.0);
            color += _SeaSurfaceColor * (0.0 - _SeaSurfaceHeight) * _SeaSurfaceDepthAttentuationFactor * atten;
            
            return color;
        }

        void vert (inout appdata_full v) {
            //float h = map2(v.uv);
            //v.vertex.xyz += v.normal * 0.1;
        }

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            float2 uv = IN.uv_MainTex;
        
            float3 origin = _WorldSpaceCameraPos;
            float3 dir = normalize(IN.worldPos.xyz - origin);

            // Distance to fragment
            float3 dist = IN.worldPos - origin;

            // Surface normal
            float3 n;
            n = getNormal(uv, dot(dist,dist) * 0.0001f);

            // Light stuff
            float3 light = normalize(float3(0.0,1.0,0.8)); 
            
            // color
            float3 c = getSeaColor(dist);
            
            
            fixed4 col = fixed4(c.r, c.g, c.b, 1.0f);


            o.Albedo = c.rgb;
            // Metallic and smoothness come from slider variables
            //o.Metallic = _Metallic;
            //o.Smoothness = _Glossiness;
            //o.Alpha = c.a;
            //o.Smoothness = 0.0f;
            //o.Metallic = 1.0f;
            o.Normal = n.xzy;
            
        }
        ENDCG
    }
    FallBack "Diffuse"
}
