Shader "Burnobad/Outliner/Normal + Depth Outline Shader"
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
            float4 _MainTex_ST, _MainTex_TexelSize, _CameraDepthTexture_TexelSize;

            float4 _OutlineColor;
            int _SampleDistance;
            float2 _SampleThresholds;

            sampler2D _DistortionTex;
            float _DistortionPower;

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

            #define SAMPLES_COUNT 8

            float sobelSamples[SAMPLES_COUNT];
            
            float SampleLinearDepth(float2 _uv, float _uOffset = 0, float _vOffset = 0)
            {
                _uv += _CameraDepthTexture_TexelSize.xy  * float2(_uOffset, _vOffset);
                float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, _uv));
                return Linear01Depth(depth);
            }
            
            float SampleEyeDepth(float2 _uv, float _uOffset = 0, float _vOffset = 0)
            {
                _uv += _CameraDepthTexture_TexelSize.xy  * float2(_uOffset, _vOffset);
                float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, _uv));
                return LinearEyeDepth(depth);
            }
            float3 ViewSpacePos(float2 _uv, float _uOffset = 0, float _vOffset = 0)
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
            float3 SampleNormals(float2 _uv, float _uOffset = 0, float _vOffset = 0)
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
                        float3 normal = SampleNormals(_uv, offsetUV.x, offsetUV.y);

                        _sobelSamples[0] += SobelX[x][y] * depth;
                        _sobelSamples[1] += SobelY[x][y] * depth;

                        _sobelSamples[2] += SobelX[x][y] * normal.x;
                        _sobelSamples[3] += SobelY[x][y] * normal.x;
                        _sobelSamples[4] += SobelX[x][y] * normal.y;
                        _sobelSamples[5] += SobelY[x][y] * normal.y;
                        // i think without z it looks better
                        //_sobelSamples[6] += SobelX[x][y] * normal.z;
                        //_sobelSamples[7] += SobelY[x][y] * normal.z;
                    }
                }          
            }

            float CheckThreshold(float _toCheck, float _threshold)
            {
                if(_toCheck > _threshold)
                    return 1;
                else
                    return 0;
            }
            float GetMagnitude(float2 _Samples, float _threshold)
            {
                float Mag = sqrt(_Samples.x * _Samples.x + _Samples.y * _Samples.y);
                Mag = saturate(Mag);
                Mag = CheckThreshold(Mag, _threshold);
                return Mag;
            }

            float GetDistortion(float2 _uv)
            {
                float scalerX = _MainTex_TexelSize.y / _MainTex_TexelSize.x;
                float2 disUV = float2(_uv.x * scalerX, _uv.y);
                float distortion = tex2D(_DistortionTex, disUV).a;

                distortion -= 0.5;
                distortion *= 2;

                return distortion;
            }

            fixed4 frag (v2f i) : SV_Target
            {

                fixed4 col = tex2D(_MainTex, i.uv);
                float2 distortion = GetDistortion(i.uv) * _MainTex_TexelSize * _DistortionPower;
                float2 testUV = i.uv + distortion;
                GetSobelSamples(testUV, sobelSamples);

                float2 depthSamples = float2(sobelSamples[0], sobelSamples[1]);
                float MagDepth = GetMagnitude(depthSamples, _SampleThresholds.x);

                float2 normalSampleX = float2(sobelSamples[2], sobelSamples[3]);
                float2 normalSampleY = float2(sobelSamples[4], sobelSamples[5]);
                float2 normalSampleZ = float2(sobelSamples[6], sobelSamples[7]);

                float MagNormalX = GetMagnitude(normalSampleX, _SampleThresholds.y);
                float MagNormalY = GetMagnitude(normalSampleY, _SampleThresholds.y);
                // i think without z it looks better
                //float MagNormalZ = GetMagnitude(normalSampleZ, _SampleThresholds.y);

                float MagNormal;
                // i think without z it looks better
                //MagNormal = max(max(MagNormalX, MagNormalY), MagNormalZ);
                MagNormal = max(MagNormalX, MagNormalY);

                float Mag = MagDepth + MagNormal;
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
