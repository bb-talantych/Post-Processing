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
        };

        sampler2D _MainTex;
        float4 _MainTex_ST, _MainTex_TexelSize;
        float  _HighThreshold, _LowThreshold;

        float4 _PaperTex;
        float4 _PaperTex_ST;

        v2f vert (appdata v)
        {
            v2f o;

            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = TRANSFORM_TEX(v.uv, _MainTex);

            return o;
        }
        
        float4 SampleTexture(float2 uv, float uOffset, float vOffset) 
        {
			uv += _MainTex_TexelSize * float2(uOffset, vOffset);
			return tex2D(_MainTex, uv);
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
                        // this makes vOffset go from top to bottom
                        int vOffset = -(x - 1);
                        half l = SampleTexture(i.uv, uOffset, vOffset).a;

                        Gx += KERNEL_X[x][y] * l;
                        Gy += KERNEL_Y[x][y] * l;
                    }
                }

                float Mag = sqrt(Gx * Gx + Gy * Gy);
                
                return Mag;
            }
            ENDCG
        }
        Pass
        {
            Name "Calculate Intensity Pass Full"

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
                        // this makes vOffset go from top to bottom
                        int vOffset = -(x - 1);
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

            // i originally copied this from Acerola
            // but rereading the wiki, I think he made a mistake
            // "(e.g., a pixel that is pointing in the y-direction will be compared to the pixel above
            // and below it in the vertical axis)"
            // the implementation now is mine
            fixed4 frag (v2f i) : SV_Target
            {
                float4 canny = tex2D(_MainTex, i.uv);

                float Mag = canny.a;
                float theta = degrees(canny.b);

                if ((0.0f <= theta && theta <= 45.0f) || (135.0f <= theta && theta <= 180.0f)) 
                {
                    float westMag = SampleTexture(i.uv, -1, 0).a;
                    float eastMag = SampleTexture(i.uv, 1, 0).a;

                    canny = Mag >= westMag && Mag >= eastMag ? canny : 0.0f;
                } 
                else if (45.0f <= theta && theta <= 135.0f) 
                {
                    float northMag = SampleTexture(i.uv, 0, -1).a;
                    float southMag = SampleTexture(i.uv, 0, 1).a;

                    canny = Mag >= northMag && Mag >= southMag ? canny : 0.0f;
                }

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
    }
}
