Shader "Helliaca/Glass_3"
{
    Properties
    {
        [Header(Physical Properties)]
        _NormalMap ("Normalmap", 2D) = "bump" {}
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        _Smoothness ("Smoothness", Range(0.0, 1.0)) = 1.0
        _Glass ("Glass Factor", Range(0.0, 1.0)) = 1.0
        _SmoothnessMetallicGlassMap ("Smoothness/Metallic/Glass Map", 2D) = "magenta" {}

        [Header(Color Properties)]
        _ColorTint ("Color Tint", Color) = (1.0, 1.0, 1.0, 0.0)
        _ColorMap ("Color Map", 2D) = "white" {}

        [Header(Refraction Properties)]
        _RefractionStrength ("RefractionStrength", Range (0.0,1.0)) = 0.5
        _RefrGeomNrmContrib ("NormalMap Refraction Contribution", Range(0.0, 1.0)) = 0.5
        _EmissiveStr ("Emissive Strength", Range(0.0, 1.0)) = 0.5
        _FresnelExponent ("Fresnel Exponent", Range(2, 20)) = 8

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
            float2 uv_ColorMap;
        };

        uniform sampler2D _NormalMap;
        uniform sampler2D _ColorMap;
        uniform sampler2D _SmoothnessMetallicGlassMap;
        uniform float _RefractionStrength;
        uniform float _RefractionBlur;
        uniform float _RefractionBlurEps;
        uniform float _RefrGeomNrmContrib;
        uniform float _Metallic;
        uniform float _Smoothness;
        uniform float _Glass;
        uniform float _EmissiveStr;
        uniform float4 _ColorTint;
        uniform float _FresnelExponent;
 
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
            //SET NORMAL
            o.Normal = normalize(UnpackNormal (tex2D (_NormalMap, IN.uv_ColorMap)));

            // Base Color
            float3 baseColor = _ColorTint*tex2D(_ColorMap, IN.uv_ColorMap).rgb;

            // transparency / glass
            float glass = (tex2D(_SmoothnessMetallicGlassMap, IN.uv_ColorMap)).b * _Glass;

            // Some necessary values:
            float3 viewSpaceNormal = normalize(mul(UNITY_MATRIX_MV, float4(o.Normal, 0.0)).xyz); // Normal vector from nrm texture inv iew space

            //IF GLASS -> DO REFRACTION
            float3 refr = float3(1,1,1); //default values
            float fresnel = 0.0f;
            if(glass > 0.1) {
                // These are the coordinates that would correspond to "directly behind" the current pixel
                float2 coords = IN.grabUV.xy/IN.grabUV.w;
                // Get an offset that we change coords by
                float2 offset = (IN.viewD - lerp(IN.viewD, -lerp(IN.nrmD, viewSpaceNormal, _RefrGeomNrmContrib), _RefractionStrength)).xy;

                // REFRACTION
                coords += offset;
                refr = tex2D(_GrabTexture, coords);

                // blur refraction if necessary
                if(_RefractionBlur>0.0) {
                    coords += _RefractionBlurEps*hash(coords);
                    refr = 
                        refr + 
                        // un-comment these lines if the blur quality is low:
                        //tex2D(_GrabTexture, coords+float2( _RefractionBlurEps, _RefractionBlurEps )) + 
                        //tex2D(_GrabTexture, coords+float2(-_RefractionBlurEps, _RefractionBlurEps )) +
                        //tex2D(_GrabTexture, coords+float2( _RefractionBlurEps,-_RefractionBlurEps )) +
                        //tex2D(_GrabTexture, coords+float2(-_RefractionBlurEps,-_RefractionBlurEps )) +
                        tex2D(_GrabTexture, coords+float2( _RefractionBlurEps, 0.0 )) +
                        tex2D(_GrabTexture, coords+float2( 0.0, _RefractionBlurEps )) +
                        tex2D(_GrabTexture, coords+float2(-_RefractionBlurEps, 0.0 )) +
                        tex2D(_GrabTexture, coords+float2( 0.0,-_RefractionBlurEps ));

                    refr /= 5.0f;
                }

                //FRESNEL
                fresnel = 1.0f-dot(IN.viewD, IN.nrmD);
                fresnel = min(1, 100.0f*pow(fresnel, _FresnelExponent));
            }

            // Remove transparency from non-glass surfaces glass
            refr = lerp(refr, float3(1,1,1), 1.0f-glass);

            // Apply frensel on glass
            refr = lerp(refr, baseColor, fresnel);

            o.Albedo = baseColor*refr*(1.0 - _EmissiveStr);
            o.Emission = baseColor*refr*_EmissiveStr;
            o.Metallic = tex2D(_SmoothnessMetallicGlassMap, IN.uv_ColorMap).g * _Metallic;
            o.Smoothness = tex2D(_SmoothnessMetallicGlassMap, IN.uv_ColorMap).r * _Smoothness;
            o.Alpha = 1.0f;
        }
        ENDCG
    }
}
