Shader "Helliaca/Artifact"
{
    //Shader adapted from: https://www.shadertoy.com/view/WlfXW4
    Properties
    {
        [Header(Transform)]
        _Translation("World Position", Vector) = (0, 0, 0)
        _Rotation("World Rotation", Vector) = (0, 0, 0)

        [Header(Geometry)]
        _Scale("Scale", Float) = 4.5
        _MinHitDist("Solid Distance", Range(0, 0.1)) = 0.001
        [IntRange] _DetailIterations("Subdivisions", Range(0, 32)) = 6 // Keep this low for better performance
        [IntRange] _RaymarchIterations("Raymarch Resolution", Range(0, 128)) = 32 // Keep reasonably this low for better performance
        _SubdivisionScale("Subdivision Scale", Range(0.1, 1.0)) = 0.5

        [Header(Base Material)]
        _BaseColor("Base Color", Color) = (0.05, 0.05, 0.05, 0.0)
        _BaseBrightness("Highlight Base Brightness", Range(0.0, 1.0)) = 0.1 //Values above 1.0 also work, but look dodgy in most cases
        _SolidRadius("Solid Radius", Float) = 0.06

        [Header(Highlight Material)]
        _HighlightColor("Highlight Color", Color) = (0.0, 0.7, 0.3, 1.0)
        _HighlightDelay("Highlight Latency", Range(0.0, 1.0)) = 0.3 // Some values above 1.0 can also work
        _HighlightRadius("Highlight Radius", Float) = 0.01
        [Space(20)]
        _CAtt("Highlight Const Attenuation Factor", Range(0.0, 10.0)) = 0.3
        _LAtt("Highlight Linear Attenuation Factor", Range(0.0, 10.0)) = 0.0
        _QAtt("Highlight Quadratic Attenuation Factor", Range(0.0, 10.0)) = 10.0

        [Header(Movement)]
        _MovementFreq("Movement Frequency", Vector) = (0.8, 0.8, 0.8)
        _MovementDist("Movement Distortion Frequency", Vector) = (0.3, 0.3, 0.3)
        _MovementAmplitude("Movement Amplitdue", Vector) = (2.0, 0.0, 2.0)

    }
    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 worldSpacePos : TEXCOORD1;
            };


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldSpacePos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            float3 _Rotation;
            float3 _Translation;
            float _Scale;
            float _MinHitDist;
            float _CubeScale;
            int _DetailIterations;
            int _RaymarchIterations;
            float _SubdivisionScale;
            fixed4 _BaseColor;
            fixed4 _HighlightColor;
            float _HighlightDelay;
            float _BaseBrightness;
            float _CAtt;
            float _LAtt;
            float _QAtt;
            float _SolidRadius;
            float _HighlightRadius;
            float3 _MovementAmplitude;
            float3 _MovementDist;
            float3 _MovementFreq;


            float2x2 rot(float angle) {
                return float2x2(cos(angle), sin(angle), -sin(angle), cos(angle));
            }

            float3 rotate_x(float3 v, float angle) {
                v.yz = mul(rot(angle), v.yz);
                return v;
            }

            float3 rotate_y(float3 v, float angle) {
                v.xz = mul(rot(angle), v.xz);
                return v;
            }

            float3 rotate_z(float3 v, float angle) {
                v.xy = mul(rot(angle), v.xy);
                return v;
            }

            //Helper Functions
            // p: point in space
            // s: scale of first cube and as a result the whole structure
            // r: width of the lines
            // t: time parameter
            float shape(float3 p, float r, float t)
            {    
                float3 s = float3(_Scale,_Scale,_Scale); // The 'world position' of our cube corner vertex.
                
                //Each axis will have 2^_DetailIterations cubes along it
                for (int i=0; i<_DetailIterations; i++){
                    
                    p = abs(p); // We mirror cube at s along each axis (one cube in +xyz -> 4 cubes)
                    p = p-s;	// Turn p intro coords relative to cube center (s)
                    
                    // Rotate p
                    p = rotate_x(p, sin(t*_MovementFreq.x + _MovementDist.x*sin(t))*_MovementAmplitude.x);
                    p = rotate_y(p, sin(t*_MovementFreq.y + _MovementDist.x*sin(t))*_MovementAmplitude.y);
                    p = rotate_z(p, sin(t*_MovementFreq.z + _MovementDist.x*sin(t))*_MovementAmplitude.z);

                    //float2x2 m = rotate(sin(t*0.8+0.3*sin(t))*2.0+0.8);
                    //p.xy = mul(m, p.xy);
                    //p.yz = mul(m, p.yz);
                    
                    // Move cube closer to origin and make smaller by factor of 2
                    s *= _SubdivisionScale;
                }
                
                p = abs(p)-s; // apply mirror and turn p to coords relative to s
                // p is now the vector from s to p. s Represents the corner vertex of a cube.
                // The abs() mirrors this vertex along each axis, giving us 4 vertices of a cube
                // This means, for length(p)<r we are withing one of such corner vertices
                
                // To go from 4 corner verts to a complete cube we sort the axes of p in ascending order
                // Then we clamp the smallest coordiante to 0
                // Clamping the coord to zero means all negative ones go to zero and are thus within the smallest distance
                if (p.x < p.z) p.xz = p.zx;
                if (p.y < p.z) p.yz = p.zy;
                p.z = max(0.0,p.z);
                
                // We return the distance of p to a cube (minus radius)
                return length(p)-r;
            }

            void map(float3 p, inout float g, inout float q)
            {
                // Distance to a flower with very thin lines (0.01)
                float de = shape(p, _HighlightRadius, _Time.y-_HighlightDelay);
                
                g += _BaseBrightness / (_CAtt + _LAtt*de + _QAtt*de*de);
                
                q = shape(p, _SolidRadius, _Time.y);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // We will march a ray from the Camera to the worldposition of this fragment
                float3 ori = _WorldSpaceCameraPos;
                float3 dir = normalize(i.worldSpacePos - ori);

                // We need to apply the model matrix of our shape. But since we don't have any vertices to work with, 
                // we will bring the vectors ori and dir into Model space by applying the inverse operations:
                ori = rotate_x(ori, -_Rotation.x);
                ori = rotate_y(ori, -_Rotation.y);
                ori = rotate_z(ori, -_Rotation.z);

                dir = rotate_x(dir, -_Rotation.x);
                dir = rotate_y(dir, -_Rotation.y);
                dir = rotate_z(dir, -_Rotation.z);

                ori -= _Translation;
                dir = normalize(dir); // should technically not be necessary
                
                // Base color: faint grey
                fixed4 col = _BaseColor;
                
                float g = 0.0;
                float t = 0.0;
                float d;

                bool hit = false;
                
                // raymarch form or
                for(int i = 0; i < _RaymarchIterations; i++)
                {
                    map(ori + dir * t, g, d);	//g -> add color based on distance. Gives us a nice glow effect and stuff
                                            //d -> distance of our sampled point to the flower. we will advance by thid distance along our ray
                    t += d;
                    if(d < _MinHitDist) {
                        hit = true;
                        break;
                    }
                }
                
                col += _HighlightColor*g*0.25;
                col = clamp(col,0.0,1.0);
                if(hit) col.a = 1.0f;

                return col;
            }
            ENDCG
        }
    }
}
