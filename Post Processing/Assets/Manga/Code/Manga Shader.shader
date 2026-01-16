Shader "Burnobad/Manga Shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    CGINCLUDE
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
            float2 hatchUV : TEXCOORD1;
        };

        sampler2D _MainTex, _LuminanceTex;
        float4 _MainTex_ST, _MainTex_TexelSize;
        float3 _LuminanceThresholds;
        float4 _BackgroundColor, _ShadowColor, _ShadowedAreaColor;

        float  _HighThreshold, _LowThreshold;
        sampler2D _PaperTex, _HatchTex;
        float4 _HatchTex_ST;
        float2 _HatchTiling;
        float _HatchRotation, _SecondaryHatchRotation;

        static const float PI = 3.14159265f;

        v2f vert (appdata v)
        {
            v2f o;

            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = TRANSFORM_TEX(v.uv, _MainTex);
            o.hatchUV = TRANSFORM_TEX(v.uv, _HatchTex);

            return o;
        }
        
        float4 SampleTexture(float2 uv, float uOffset, float vOffset) 
        {
			uv += _MainTex_TexelSize * float2(uOffset, vOffset);
			return tex2D(_MainTex, uv);
		} 
        float2 RotateUV(float2 _uv, float _deg)
        {
            float rad = radians(_deg);
            float cosine = cos(rad);
            float sine = sin(rad);

            float rotatedX = _uv.x * cosine - _uv.y * sine;
            float rotatedY = _uv.x * sine + _uv.y * cosine;

            return float2(rotatedX, rotatedY);
        }

    ENDCG

    SubShader
    {
        // it's a post processing effect
        // so no point: culling, writing to depth or not showing it
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Blur Pass"

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile __ GAUSSIAN_BLUR BOX_BLUR

            static const int gaussianKernel[5][5] =
            {
                {2, 4, 5, 4, 2},
                {4, 9, 12, 9, 4},
                {5, 12, 15, 12, 5},
                {4, 9, 12, 9, 4},
                {2, 4, 5, 4, 2}
            };
            static const int3x3 boxBlur =
            {
                1, 1, 1,
                1, 1, 1,
                1, 1, 1
            };

            fixed4 frag (v2f i) : SV_Target
            {
                float4 finalTex = 0;
                #if defined(GAUSSIAN_BLUR)
                    for(int x = 0; x < 5; x++)
                    {
                        for(int y = 0; y < 5; y++)
                        {
                            int uOffset = y - 2;
                            // this makes vOffset go from top to bottom
                            int vOffset = -(x - 2);

                            finalTex += SampleTexture(i.uv, uOffset, vOffset) * gaussianKernel[x][y];
                        }
                    }
                    
                    return finalTex / 159.0f;

                #elif defined(BOX_BLUR)
                    for(int x = 0; x < 3; x++)
                    {
                        for(int y = 0; y < 3; y++)
                        {
                            int uOffset = y - 1;
                            // this makes vOffset go from top to bottom
                            int vOffset = -(x - 1);

                            finalTex += SampleTexture(i.uv, uOffset, vOffset) * boxBlur[x][y];
                        }
                    }

                    return finalTex / 9.0f;

                #endif

                return tex2D(_MainTex, i.uv);
            }
            ENDCG
        }
        Pass
        {
            Name "Luminance Pass"

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag     

            fixed4 frag (v2f i) : SV_Target
            {
                float4 mainTex = tex2D(_MainTex, i.uv);
                
                //return 1;
                //return 0.2126 * mainTex.r + 0.7152 * mainTex.g + 0.0722 * mainTex.b;
                return LinearRgbToLuminance(mainTex);
            }
            ENDCG
        }
        Pass
        {
            Name "Calculate Intensity Pass"

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile __ PREWITT SCHARR
            
            // Wikipedia explains why i flipped them
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
            static const int3x3 PrewittX = 
            {
                1, 0, -1,
                1, 0, -1,
                1, 0, -1
            };      
            static const int3x3 PrewittY = 
            {
                1, 1, 1,
                0, 0, 0,
                -1, -1, -1
            };
            static const int3x3 ScharrX = 
            {
                3, 0, -3,
                10, 0, -10,
                3, 0, -3
            };      
            static const int3x3 ScharrY = 
            {
                3, 10, 3,
                0, 0, 0,
                -3, -10, -3
            };

            #if defined(PREWITT)
                #define KERNEL_X PrewittX
                #define KERNEL_Y PrewittY
            #elif defined(SCHARR)
                #define KERNEL_X ScharrX
                #define KERNEL_Y ScharrY
            #else
                #define KERNEL_X SobelX
                #define KERNEL_Y SobelY
            #endif

            fixed4 frag (v2f i) : SV_Target
            {
                float Gx = 0.0f;
                float Gy = 0.0f;

                for(int x = 0; x < 3; x++)
                {
                    for(int y = 0; y < 3; y++)
                    {
                        int uOffset = y - 1;
                        int vOffset = x - 1;
                        half l = SampleTexture(i.uv, uOffset, vOffset).a;

                        Gx += KERNEL_X[x][y] * l;
                        Gy += KERNEL_Y[x][y] * l;
                    }
                }

                float Mag = sqrt(Gx * Gx + Gy * Gy);
                float theta = abs(atan2(Gy, Gx));
                
                return float4(Gx, Gy, theta, Mag);
            }
            ENDCG
        }
        Pass
        {
            Name "Magnitude Thresholding Pass"

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag     

            // i discovered that using only alpha produces outlines that are too thin
            // but using the X gradient(r component) works way better, for artistic purposes
            // but if you combine in with Y gradient, it sort of starts immitating
            // the different thickness outlines in art have

            fixed4 frag (v2f i) : SV_Target
            {
                float4 canny = tex2D(_MainTex, i.uv);

                float theta = degrees(canny.b);
                float Mag = canny.a;

                float4 sampledGradient = 0;
                if ((0.0f <= theta && theta <= 36.0f) || (144.0f <= theta && theta <= 180.0f)) 
                {
                    float2 leftGradient = SampleTexture(i.uv, -1, 0).rb;
                    float2 rightGradient = SampleTexture(i.uv, 1, 0).rb;

                    sampledGradient = float4(leftGradient, rightGradient);
                }
                else  if ((72.0f <= theta && theta <= 36.0f)) 
                {
                    float2 topRightGradient = SampleTexture(i.uv, 1, 1).rb;
                    float2 bottomLeftGradient = SampleTexture(i.uv, -1, -1).rb;

                    sampledGradient = float4(topRightGradient, bottomLeftGradient);
                }
                else  if ((108.0f <= theta && theta <= 72.0f)) 
                {
                    float2 topGradient = SampleTexture(i.uv, 0, 1).rb;
                    float2 bottomGradient = SampleTexture(i.uv, 0, -1).rb;

                    sampledGradient = float4(topGradient, bottomGradient);
                }
                else
                {
                    float2 topLefttGradient = SampleTexture(i.uv, -1, 1).rb;
                    float2 bottomRightGradient = SampleTexture(i.uv, 1, -1).rb;

                    sampledGradient = float4(topLefttGradient, bottomRightGradient);
                }

                float canny1 = Mag >= sampledGradient.x && Mag >= sampledGradient.z ? canny : 0.0f;
                float canny2 = Mag >= sampledGradient.y && Mag >= sampledGradient.w ? canny : 0.0f;

                canny = saturate(canny1 + canny2);

                return canny;
            }
            ENDCG
        }
        Pass
        {
            Name "Double Threshold"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float4 frag(v2f i) : SV_Target 
            {
                float Mag = tex2D(_MainTex, i.uv).a;

                float4 result = 0.0f;

                if (Mag > _HighThreshold)
                    result = 1.0f;
                else if (Mag > _LowThreshold)
                    result = 0.5f;

                return result;
            }

            ENDCG
        }
        Pass
        {
            Name "Hysteresis"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float GetStrenght(v2f i)
            {
                for(int x = 0; x < 3; x++)
                {
                    for(int y = 0; y < 3; y++)
                    {
                        if (x == 0 && y == 0) 
                            continue;

                        half neighborStrength = SampleTexture(i.uv, x - 1, y - 1);  
                        if(neighborStrength == 1)
                            return 1;
                    }
                }

                return 0;
            }

            float4 frag(v2f i) : SV_Target 
            {
                float finalEdge = tex2D(_MainTex, i.uv).a;

                if(finalEdge > 0 && finalEdge < 1)
                {
                    finalEdge = GetStrenght(i);
                }

                //return abs(finalEdge - 1);
                return finalEdge;
            }

            ENDCG
        }     
        Pass
        {
            Name "Color"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag           

            #define HATCH_MULtIPLIER 3

            float4 frag(v2f i) : SV_Target 
            {
                float edges = tex2D(_MainTex, i.uv).a;
                float luminance = tex2D(_LuminanceTex, i.uv).a;

                float4 paperTex = tex2D(_PaperTex, i.uv);
                paperTex = lerp(paperTex, float4(_BackgroundColor.rgb, 1), _BackgroundColor.a);

                float2 hatchUV = float2(i.hatchUV.x * _HatchTiling.x, i.hatchUV.y * _HatchTiling.y);
                hatchUV = RotateUV(hatchUV, _HatchRotation);
                float4 hatchTex = tex2D(_HatchTex, hatchUV);
                hatchTex = 1 - hatchTex;

                float2 rotatedHatchUV = RotateUV(hatchUV, _SecondaryHatchRotation);
                float4 rotatedHatchTex = tex2D(_HatchTex, rotatedHatchUV);
                rotatedHatchTex = 1 - rotatedHatchTex;
                rotatedHatchTex += hatchTex;
                //rotatedHatchTex *= 0.5;
                rotatedHatchTex = saturate(rotatedHatchTex);

                float4 selectedTex = 0;
                float modifiedLumiance;
                if(luminance > _LuminanceThresholds.x)
                {
                    selectedTex = paperTex;
                    modifiedLumiance = 1;
                }
                else if(luminance < _LuminanceThresholds.z)
                {
                    selectedTex = _ShadowColor;
                    modifiedLumiance = 0;
                }
                else if(luminance > _LuminanceThresholds.y)
                {
                    selectedTex = lerp(paperTex, _ShadowedAreaColor, hatchTex.a * HATCH_MULtIPLIER);
                    modifiedLumiance = 0.75;
                }
                else
                {
                    selectedTex = lerp(paperTex, _ShadowedAreaColor, rotatedHatchTex.a * HATCH_MULtIPLIER);
                    modifiedLumiance = 0.25;
                }

                float4 finalOutput = lerp(selectedTex, _ShadowColor, edges);

                return finalOutput;
                //return modifiedLumiance;
            }

            ENDCG
        }  
    }
}
