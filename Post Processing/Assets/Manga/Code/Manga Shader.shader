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

        float  _HighThreshold, _LowThreshold;
        float4 _OutlineColor;

        float4 _LuminanceThresholds;
        float4 _BackgroundColor, _ShadowColor;
        sampler2D _PaperTex;

        sampler2D _HatchTex;
        float4 _HatchTex_ST;
        float2 _HatchTiling;
        float _HatchRotation, _SecondaryHatchRotation;
        float4 _MainHatchColor, _SecondaryHatchColor;
        float _HatchBlendingTreshold, _SecondaryHatchBlendingTreshold;

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
            
            #pragma multi_compile __ GX GX_N_GY

            // i discovered that using only alpha produces outlines that are too thin
            // but using the X gradient(r component) works way better, for artistic purposes
            // but if you combine in with Y gradient, it sort of starts immitating
            // the different thickness outlines in art have

            fixed4 frag (v2f i) : SV_Target
            {
                float4 canny = tex2D(_MainTex, i.uv);

                float theta = degrees(canny.b);
                float Mag = canny.a;

                float3 firstGradient = 0;
                float3 secondGradient = 0;
                if ((0.0f <= theta && theta <= 36.0f) || (144.0f <= theta && theta <= 180.0f)) 
                {
                    firstGradient = SampleTexture(i.uv, -1, 0).rba;
                    secondGradient = SampleTexture(i.uv, 1, 0).rba;
                }
                else  if ((72.0f <= theta && theta <= 36.0f)) 
                {
                    firstGradient = SampleTexture(i.uv, 1, 1).rba;
                    secondGradient = SampleTexture(i.uv, -1, -1).rba;
                }
                else  if ((108.0f <= theta && theta <= 72.0f)) 
                {
                    firstGradient = SampleTexture(i.uv, 0, 1).rba;
                    secondGradient = SampleTexture(i.uv, 0, -1).rba;
                }
                else
                {
                    firstGradient = SampleTexture(i.uv, -1, 1).rba;
                    secondGradient = SampleTexture(i.uv, 1, -1).rba;
                }

                #if defined(GX) || defined(GX_N_GY)
                    float cannyX = Mag >= firstGradient.x && Mag >= secondGradient.x ? canny : 0.0f;
                    canny = cannyX;

                    #if defined(GX_N_GY)
                    float cannyY = Mag >= firstGradient.y && Mag >= secondGradient.y ? canny : 0.0f;
                    canny += cannyY;

                    #endif
                #else
                    float cannyA = Mag >= firstGradient.z && Mag >= secondGradient.z ? canny : 0.0f;
                    canny = cannyA;
                #endif

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

            float4 LerpTexColorA(float4 _paperTex, float4 _color)
            {
                return lerp(_paperTex, _color, _color.a);
            }

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

                // i add 90, so that at 0 for both hatches, the separation would still be visible
                float2 rotatedHatchUV = RotateUV(hatchUV, _SecondaryHatchRotation + 90);
                float4 rotatedHatchTex = tex2D(_HatchTex, rotatedHatchUV);
                rotatedHatchTex = 1 - rotatedHatchTex;
                rotatedHatchTex += hatchTex;
                rotatedHatchTex *= 0.5;
                rotatedHatchTex = saturate(rotatedHatchTex);

                float4 selectedTex = 0;
                if(luminance > _LuminanceThresholds.x)
                {
                    selectedTex = paperTex;
                }
                else if(luminance < _LuminanceThresholds.a)
                {
                    selectedTex = LerpTexColorA(paperTex, _ShadowColor);
                }
                else
                {   
                    float4 finalHatch = lerp(paperTex,  LerpTexColorA(paperTex, _MainHatchColor),
                        hatchTex.a * HATCH_MULtIPLIER);  
                    float4 finalSecondaryHatch = lerp(paperTex,  LerpTexColorA(paperTex, _SecondaryHatchColor),
                        rotatedHatchTex.a * HATCH_MULtIPLIER);

                    float start = _LuminanceThresholds.a;
                    float end = _LuminanceThresholds.x;

                    float mainHatchStart = lerp(start, end, _LuminanceThresholds.y);
                    _LuminanceThresholds.z = min(_LuminanceThresholds.z, _LuminanceThresholds.y);
                    float secondaryHatchEnd = lerp(start, end, _LuminanceThresholds.z);

                    if(luminance > mainHatchStart)
                    {
                        // blending hatsh and paper
                        float dif = end - mainHatchStart;
                        float t = (luminance - mainHatchStart) / dif;
                        selectedTex = lerp(finalHatch, paperTex, t);
                    }
                    else if(luminance <= secondaryHatchEnd)
                    {
                        // blending shadow and secondary hatch
                        float dif = secondaryHatchEnd - start;
                        float t = (luminance - start) / dif;
                        selectedTex = lerp(_ShadowColor, finalSecondaryHatch, t);
                    }
                    else
                    {
                        // blending hatches
                        float mainHatchEnd =  lerp(secondaryHatchEnd, mainHatchStart, _HatchBlendingTreshold);
                        float secondaryHatchStart = lerp(secondaryHatchEnd, mainHatchStart, _SecondaryHatchBlendingTreshold);

                        if(luminance > mainHatchEnd)
                        {
                            //selectedTex = float4(1,0,0,1);
                            selectedTex = finalHatch;
                        }
                        else if(luminance < secondaryHatchStart)
                        {
                            //selectedTex = float4(0,0,1,1);
                            selectedTex = finalSecondaryHatch;
                        }
                        else
                        {
                            float dif = mainHatchEnd - secondaryHatchStart;

                            float t;
                            if(dif > 0)
                            {
                                t = (luminance - secondaryHatchStart) / dif;
                            }
                            else
                            {
                                float oneMinusStart = 1 - _SecondaryHatchBlendingTreshold;

                                if(_HatchBlendingTreshold > oneMinusStart)
                                    t = 0;
                                else
                                    t = 1;
                            }
                            //selectedTex = float4(0, 1, 0, 1);
                            //selectedTex = lerp(float4(0,0,1,1), float4(1,0,0,1), t);
                            selectedTex = lerp(finalSecondaryHatch, finalHatch, t);
                        }
                    }
                }

                float4 finalOutput = lerp(selectedTex, LerpTexColorA(paperTex, _OutlineColor), edges);

                return finalOutput;
            }

            ENDCG
        }  
    }
}
