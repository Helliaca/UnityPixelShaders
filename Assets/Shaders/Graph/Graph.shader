Shader "Helliaca/Graph"
{
    Properties
    {
        _YPadding ("Y Padding", Float) = 1.0
        _Thickness ("Thickness", Float) = 0.1
        _FalloffExponent ("Falloff Exponent", Range(0.1, 8.0)) = 1.0
        _BaseColor ("Base Color", Color) = (0.0, 0.0, 0.0, 1.0)
        _LineColor ("Line Color", Color) = (1.0, 0.0, 0.0, 1.0)
        _DataCount ("Data Count", Int) = 25
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

            #define data_len 100
            #define inf 9999.0f

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float2 _Data[data_len];
            float _YPadding;
            float _Thickness;
            float _FalloffExponent;
            float4 _BaseColor;
            float4 _LineColor;
            int _DataCount;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float seg_point_dist(float2 v, float2 w, float2 p) {
                float l2 = dot(w-v, w-v);
                if (l2 == 0.0) return distance(v, p);
                float t = max(0, min(1, dot(p - v, w - v) / l2));
                return distance(p, v + t * (w - v));
            }

            float4 getMinMax() {
                float minX = inf;
                float minY = inf;
                float maxX = -inf;
                float maxY = -inf;

                for(int i=0; i<_DataCount; i++) {
                    minX = min(_Data[i].x, minX);
                    minY = min(_Data[i].y, minY);
                    maxX = max(_Data[i].x, maxX);
                    maxY = max(_Data[i].y, maxY);
                }
                return float4(minX, minY-_YPadding, maxX, maxY+_YPadding);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                fixed4 col = _BaseColor;

                float4 minmax = getMinMax();

                float2 coord = minmax.xy + i.uv*(minmax.zw - minmax.xy);

                int j = 0;
                for(; j<_DataCount-1; j++) {
                    if(_Data[j].x>coord.x) break;
                }

                float dist = seg_point_dist(_Data[j], _Data[j+1], coord);

                if(j-1>-1) dist = min(dist, seg_point_dist(_Data[j-1], _Data[j], coord));
                if(j-2>-1) dist = min(dist, seg_point_dist(_Data[j-2], _Data[j-1], coord));

                dist = pow(dist/_Thickness, _FalloffExponent);
                float mul = smoothstep(1.0, 0.0, dist);
                col = mul * _LineColor;

                return col;
            }
            ENDCG
        }
    }
}
