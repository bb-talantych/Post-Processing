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
            //#include "UnityShaderVariables.cginc"

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
            float4 _MainTex_ST, _MainTex_TexelSize, _CameraDepthTexture_TexelSize;

            float4 _OutlineColor;
            float _SampleDistance;
            float3 _SampleStrenght;

            float4 _BackgroundColor;

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            static const int3x3 SobelX = 
            {
                1, 0, -1,
                2, 0, -2,
                1, 0, -1
            };      
            static const int3x3 SobelY = 
            {
                1, 2, 1,
                0, 0, 0,
                -1, -2, -1
            };

            #define SAMPLES_COUNT 7

            float sobelSamples[SAMPLES_COUNT];
          
            float SampleLuminance(float2 _uv, float _uOffset, float _vOffset)
            {
                _uv += _MainTex_TexelSize.xy * float2(_uOffset, _vOffset);
                return LinearRgbToLuminance(tex2D(_MainTex, _uv));
            }
            float SampleLinearDepth(float2 _uv, float _uOffset, float _vOffset)
            {
                _uv += _CameraDepthTexture_TexelSize.xy * float2(_uOffset, _vOffset);
                float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, _uv));
                return Linear01Depth(depth);
            }
            
            float SampleEyeDepth(float2 _uv, float _uOffset, float _vOffset)
            {
                _uv += _CameraDepthTexture_TexelSize.xy * float2(_uOffset, _vOffset);
                float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, _uv));
                return LinearEyeDepth(depth);
            }
            float3 ViewSpacePos(float2 _uv, float _uOffset, float _vOffset)
            {
                float2 offsetUV = _uv + _MainTex_TexelSize.xy * float2(_uOffset, _vOffset);

                float2 ndc =  offsetUV * 2 - 1;
                float depth = SampleEyeDepth(_uv, _uOffset, _vOffset);

                float4 clipPos = float4(ndc, 1, 1);

                float4 viewPosH = mul(unity_CameraInvProjection, clipPos); 
                float3 viewPos = viewPosH.xyz / viewPosH.w;
                viewPos *= depth;

                return viewPos;
            }
            float3 SampleNormals(float2 _uv, float _uOffset, float _vOffset)
            {
                float3 centerP = ViewSpacePos(_uv, _uOffset, _vOffset);
                float3 rightP = ViewSpacePos(_uv, 1 + _uOffset, _vOffset);
                float3 topP = ViewSpacePos(_uv, _uOffset, 1 + _vOffset);
               
                float3 tangentX = rightP - centerP;
                float3 tangentY = topP - centerP;

                float3 normal = normalize(cross(tangentY, tangentX));
                normal *= 0.5;
                normal += 0.5;
                return normal;
            }

            void GetSobelSamples(float2 _uv, inout float _sobelSamples[SAMPLES_COUNT])
            {
                for(int x = 0; x < 3; x++)
                {
                    for(int y = 0; y < 3; y++)
                    {
                        float2 offsetUV = float2(x - 1, y - 1) * _SampleDistance;
                        float depth = SampleLinearDepth(_uv, offsetUV.x, offsetUV.y);
                        float lum = SampleLuminance(_uv, offsetUV.x, offsetUV.y);
                        float3 normal = SampleNormals(_uv, offsetUV.x, offsetUV.y);

                        _sobelSamples[0] += SobelX[x][y] * depth;
                        _sobelSamples[1] += SobelY[x][y] * depth;
                        _sobelSamples[2] += SobelX[x][y] * lum;
                        _sobelSamples[3] += SobelY[x][y] * lum;
                        _sobelSamples[4] += SobelY[x][y] * normal.x;
                        _sobelSamples[5] += SobelX[x][y] * normal.y;
                        _sobelSamples[6] += SobelY[x][y] * normal.z;
                    }
                }
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);
                GetSobelSamples(i.uv, sobelSamples);

                float2 sampleDepth = float2(sobelSamples[0], sobelSamples[1]);
                float MagDepth = sqrt(sampleDepth.x * sampleDepth.x + sampleDepth.y * sampleDepth.y);
                MagDepth *= _SampleStrenght.x;

                float2 sampleLum = float2(sobelSamples[2], sobelSamples[3]);
                float MagLum = sqrt(sampleLum.x * sampleLum.x + sampleLum.y * sampleLum.y);
                MagLum *= _SampleStrenght.y;

                float3 sampleNormal = float3(sobelSamples[4], sobelSamples[5], sobelSamples[6]);
                //float MagNormal = (sampleNormal.x + sampleNormal.y + sampleNormal.z) / 3;
                float MagNormal = max(max(sampleNormal.x, sampleNormal.y), sampleNormal.z);
                MagNormal *= _SampleStrenght.z;

                float Mag = MagDepth + MagLum + MagNormal;
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
