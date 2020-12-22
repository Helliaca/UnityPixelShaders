Shader "Helliaca/Glass_2"
{
    Properties
    {
        [Header(Basic Properties)]
        _NormalMap ("Normalmap", 2D) = "bump" {}
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 1.0

        [Header(Color Properties)]
        _ColorTint ("Color Tint", Color) = (1.0, 1.0, 1.0)
        _ColorMap ("Color Map", 2D) = "white" {}

        [Header(Refraction Properties)]
        _RefractionStrength ("RefractionStrength", Range (0.0,1.0)) = 0.5
        _RefrGeomNrmContrib ("NormalMap Refraction Contribution", Range(0.0, 1.0)) = 0.5
        _EmissiveStr ("Emissive Strength", Range(0.0, 1.0)) = 0.5

        [Header(Refraction Blur)]
        [MaterialToggle] _RefractionBlur ("RefractionBlur", Float) = 0
        _RefractionBlurEps ("RefractionBlurEps", Range (0.0001, 0.1)) = 0.01
    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        LOD 100

        GrabPass
        {                            
            "_GrabTexture"
        }

        Pass
        {
            SetTexture [_GrabTexture] { combine texture }
        }


        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard vertex:vert fullforwardshadows alpha

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 4.0

        sampler2D _GrabTexture;
 
        struct Input
        {
            float4 grabUV;
            float3 viewD;   // view direction but in VIEW SPACE (!)
            float3 nrmD;    // normal vector in VIEW SPACE (!)
            float2 uv_NormalMap;
        };

        uniform sampler2D _NormalMap;
        uniform sampler2D _ColorMap;
        uniform sampler2D _RefractionMap;
        uniform float _RefractionStrength;
        uniform float _RefractionBlur;
        uniform float _RefractionBlurEps;
        uniform float _RefrGeomNrmContrib;
        uniform float _Metallic;
        uniform float _Smoothness;
        uniform float _EmissiveStr;
        uniform float3 _ColorTint;
 
        void vert (inout appdata_full v, out Input o)
        {
            UNITY_INITIALIZE_OUTPUT(Input,o);
            o.grabUV = ComputeGrabScreenPos(UnityObjectToClipPos(v.vertex));
            o.nrmD = normalize(mul(UNITY_MATRIX_MV, float4(v.normal, 0.0)).xyz);
            o.viewD = normalize(mul(UNITY_MATRIX_MV, float4(ObjSpaceViewDir(v.vertex), 0.0)).xyz);
        }

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)

        float hash (float2 uv)
        {
            return frac(sin(dot(uv,float2(12.9898,78.233)))*43758.5453123);
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            //// NORMAL
            o.Normal = normalize(UnpackNormal (tex2D (_NormalMap, IN.uv_NormalMap)));
            float3 viewSpaceNormal = normalize(mul(UNITY_MATRIX_MV, float4(o.Normal, 0.0)).xyz);

            //// REFRACTION
            // These are the coordinates that would correspond to "directly behind" the current pixel
            float2 coords = IN.grabUV.xy/IN.grabUV.w;
            // Get an offset that we change coords by
            float2 offset = (IN.viewD - lerp(IN.viewD, -lerp(IN.nrmD, viewSpaceNormal, _RefrGeomNrmContrib), _RefractionStrength)).xy;

            // Refractive component/color
            coords += offset;
            float4 refr = tex2D(_GrabTexture, coords);

            if(_RefractionBlur>0.0) {
                coords += _RefractionBlurEps*hash(coords);
                refr = 
                    refr + 
                    tex2D(_GrabTexture, coords+float2( _RefractionBlurEps, _RefractionBlurEps )) + 
                    tex2D(_GrabTexture, coords+float2(-_RefractionBlurEps, _RefractionBlurEps )) +
                    tex2D(_GrabTexture, coords+float2( _RefractionBlurEps,-_RefractionBlurEps )) +
                    tex2D(_GrabTexture, coords+float2(-_RefractionBlurEps,-_RefractionBlurEps )) +
                    tex2D(_GrabTexture, coords+float2( _RefractionBlurEps, 0.0 )) +
                    tex2D(_GrabTexture, coords+float2( 0.0, _RefractionBlurEps )) +
                    tex2D(_GrabTexture, coords+float2(-_RefractionBlurEps, 0.0 )) +
                    tex2D(_GrabTexture, coords+float2( 0.0,-_RefractionBlurEps ));

                refr /= 9.0f;
            }

            float3 baseColor = _ColorTint*tex2D(_ColorMap, IN.uv_NormalMap);

            o.Albedo = baseColor*refr*(1.0 - _EmissiveStr);
            o.Emission = baseColor*refr*_EmissiveStr;
            o.Metallic = _Metallic;
            o.Smoothness = _Smoothness;
            o.Alpha = 1.0f;
        }
        ENDCG
    }
}
