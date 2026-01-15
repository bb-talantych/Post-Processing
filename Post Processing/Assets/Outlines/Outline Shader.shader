Shader "Burnobad/Outline Shader"
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

            #pragma multi_compile __ EDGE_CHECKER

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
            float4 _MainTex_ST, _MainTex_TexelSize;

            float4 _OutlineColor;
            float _SampleDistance;
            float4 _BackgroundColor;

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            static const int2x2 robertsCrossV =
            {
                1, 0,
                0, -1
            };
            static const int2x2 robertsCrossH =
            {
                0, 1,
                -1, 0
            };

            float4 SampleLuminance(float2 _uv, float _uOffset, float _vOffset)
            {
                _uv += _MainTex_TexelSize * float2(_uOffset, _vOffset);
                return LinearRgbToLuminance(tex2D(_MainTex, _uv));
            }
            float4 SampleDepth(float2 _uv, float _uOffset, float _vOffset)
            {
                _uv += _MainTex_TexelSize * float2(_uOffset, _vOffset);
                float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, _uv));
                return Linear01Depth(depth);
            }
            float GetRoberts(float2 _uv, int2x2 _robertsKernel)
            {
                float robertsOutput = 0;
                for(int x = 0; x < 2; x++)
                {
                    for(int y = 0; y < 2; y++)
                    {
                        int roberts = _robertsKernel[x][y];
                        if(roberts != 0)
                        {
                            float2 offsetUV = float2(x, y) * _SampleDistance;
                            offsetUV -= _SampleDistance * 0.5;
                            robertsOutput += SampleDepth(_uv, offsetUV.x, offsetUV.y).a * roberts;
                        }
                    }
                }
                return robertsOutput;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                float robertsV = GetRoberts(i.uv, robertsCrossV);
                float robertsH = GetRoberts(i.uv, robertsCrossH);

                float Mag = sqrt(robertsV * robertsV + robertsH * robertsH);
                Mag = saturate(Mag);

                float4 finalOutput = 0;
                #if defined(EDGE_CHECKER)
                    finalOutput = lerp(_BackgroundColor, _OutlineColor, Mag);
                #else
                    finalOutput = lerp(col, _OutlineColor, Mag);
                #endif

                return finalOutput;
            }
            ENDCG
        }
    }
}
