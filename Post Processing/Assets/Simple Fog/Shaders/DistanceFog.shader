Shader "_BB/Distance Fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile __ ExponentialFactor ExponentialSquaredFactor

            #include "UnityCG.cginc"

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

            sampler2D _MainTex, _CameraDepthTexture;
            float4 _FogColor;

            float _StartPos, _EndPos, _Density;

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                return o;
            }

            float GetLinearFogFactor(float _depth, float _start, float _end)
            {
                float end = max(0, _end);
                float start = min(_start, end);

                float dif = end - start;
                float endMinusDepth = end - _depth;
                if(dif == 0)
                {
                    return endMinusDepth > 0 ? 0 : 1; 
                }

                float fogFactor = saturate(endMinusDepth / dif);
                return 1 - fogFactor;
            }
            float GetExponentialFogFactor(float _depth, float _start, float _density)
            {
                float adjustedDepth = _depth - _start;
                if(adjustedDepth <= 0)
                {
                    return 0;
                }

                float exponent = adjustedDepth * _density;
                return 1 - pow(2, -exponent);
            }
            float GetExponentialSquaredFogFactor(float _depth, float _start, float _density)
            {
                float adjustedDepth = _depth - _start;
                if(adjustedDepth <= 0)
                {
                    return 0;
                }

                float exponent = adjustedDepth * _density;
                exponent = pow(exponent, 2);
                return 1 - pow(2, -exponent);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 srcColor = tex2D(_MainTex, i.uv);
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                depth = Linear01Depth(depth) * _ProjectionParams.z;

                float fogFactor = 0;
                #if defined(ExponentialFactor)
                    fogFactor = GetExponentialFogFactor(depth, _StartPos, _Density);
                #elif defined(ExponentialSquaredFactor)
                    fogFactor = GetExponentialSquaredFogFactor(depth, _StartPos, _Density);
                #else
                    fogFactor = GetLinearFogFactor(depth, _StartPos, _EndPos);
                #endif

                float3 finalColor = lerp(srcColor, _FogColor, fogFactor);
                return float4(finalColor, 1);
            }
            ENDCG
        }
    }
}
