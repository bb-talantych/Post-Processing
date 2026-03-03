Shader "_BB/Height Fog"
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
            float _Half_FOV_Tan;
            float4 _FogColor;

            float _StartPos, _EndPos, _Density;

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                return o;
            }

            float GetLinearFogFactor(float _yPos, float _start, float _end)
            {
                float end = min(_start, _end);

                float dif = end - _start;
                float endMinusDepth = end - _yPos;
                if(dif == 0)
                {
                    return endMinusDepth > 0 ? 1 : 0; 
                }

                float fogFactor = saturate(endMinusDepth / dif);
                return 1 - fogFactor;
            }
            float GetExponentialFogFactor(float _yPos, float _start, float _density)
            {
                float adjustedYPos = _start -_yPos;
                if(adjustedYPos <= 0)
                {
                    return 0;
                }

                float exponent = adjustedYPos * _density;
                return 1 - pow(2, -exponent);
            }
            float GetExponentialSquaredFogFactor(float _yPos, float _start, float _density)
            {
                float adjustedYPos = _start -_yPos;
                if(adjustedYPos <= 0)
                {
                    return 0;
                }

                float exponent = adjustedYPos * _density;
                exponent = pow(exponent, 2);
                return 1 - pow(2, -exponent);
            }

            float3 ConstructRay(v2f i)
            {
                float3 ray;

                float2 ndc = i.uv * 2 - 1;
                float screenAspect = _ScreenParams.x / _ScreenParams.y;

                ray.x = ndc.x * _Half_FOV_Tan;
                ray.x *= screenAspect;
                ray.y = ndc.y * _Half_FOV_Tan;
                ray.z = 1;

                return ray;
            }
            float4 GetViewPos(v2f i)
            {
                float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
                depth = Linear01Depth(depth) * _ProjectionParams.z;

                float3 ray = ConstructRay(i);
                return float4(ray * depth, 1); 
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 srcColor = tex2D(_MainTex, i.uv);           

                float4 viewPos = GetViewPos(i);
                float3 worldPos = mul(unity_CameraToWorld, viewPos);

                float fogFactor = 0;
                #if defined(ExponentialFactor)
                    fogFactor = GetExponentialFogFactor(worldPos.y, _StartPos, _Density);
                #elif defined(ExponentialSquaredFactor)
                    fogFactor = GetExponentialSquaredFogFactor(worldPos.y, _StartPos, _Density);
                #else
                    fogFactor = GetLinearFogFactor(worldPos.y, _StartPos, _EndPos);
                #endif

                float3 finalColor = lerp(srcColor, _FogColor, fogFactor);
                return float4(finalColor, 1);
            }
            ENDCG
        }
    }
}

