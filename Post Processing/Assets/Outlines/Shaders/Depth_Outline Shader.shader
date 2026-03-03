Shader "Burnobad/Outliner/Depth Outline Shader"
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

            sampler2D _MainTex, _CameraDepthTexture, _Source;
            float4 _MainTex_ST, _MainTex_TexelSize, _CameraDepthTexture_TexelSize;

            float4 _OutlineColor;
            int _SampleDistance;
            float _DepthThreshold;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 SampleTexture(float2 uv, float uOffset = 0, float vOffset = 0) 
            {
			    uv += _MainTex_TexelSize * float2(uOffset, vOffset);
			    return tex2D(_MainTex, uv);
		    } 

        ENDCG

        Pass
        {
            Name "Sobel"

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

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

            float SampleLinearDepth(float2 _uv, float _uOffset = 0, float _vOffset = 0)
            {
                _uv += _CameraDepthTexture_TexelSize.xy  * float2(_uOffset, _vOffset);
                float depth = UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, _uv));
                return Linear01Depth(depth);
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

            fixed4 frag (v2f i) : SV_Target
            {
                float Gx = 0;
                float Gy = 0;

                for(int x = 0; x < 3; x++)
                {
                    for(int y = 0; y < 3; y++)
                    {
                        float2 offsetUV = float2(x - 1, y - 1);

                        float depth = SampleLinearDepth(i.uv, offsetUV.x, offsetUV.y);

                        Gx += SobelX[x][y] * depth;
                        Gy += SobelY[x][y] * depth;
                    }
                }

                float theta = atan2(Gy, Gx);
                float Mag = GetMagnitude(float2(Gx,Gy), _DepthThreshold);

                return float4(Gx, Gy, theta, Mag);
            }
            ENDCG
        }

        Pass
        {
            Name "Line Width"
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            float GetAngle(float _theha)
            {
                float angle = degrees(_theha);
                if(angle < 0)
                {
                    float t = abs(angle) / 180;
                    angle = lerp(360, 180, t);
                }

                return angle;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float4 source = tex2D(_Source, i.uv);
                float4 sampledMag = 0; 

                for(int j = 1; j <= _SampleDistance; j++)
                {
                    float2 uvOffset = float2(1, 1) * j;
                    float2 diagonalUVOffset = uvOffset * 0.707; 

                    float2 sw = SampleTexture(i.uv, diagonalUVOffset.x, diagonalUVOffset.y).ba;
                    float2 se = SampleTexture(i.uv, -diagonalUVOffset.x, diagonalUVOffset.y).ba;
                    float2 nw = SampleTexture(i.uv, diagonalUVOffset.x, -diagonalUVOffset.y).ba;
                    float2 ne = SampleTexture(i.uv, -diagonalUVOffset.x, -diagonalUVOffset.y).ba;

                    float southWestAngle = GetAngle(sw.x);
                    float southEastAngle = GetAngle(se.x);
                    float northWestAngle = GetAngle(nw.x);
                    float northEastAngle = GetAngle(ne.x);

                    float2 s = SampleTexture(i.uv, 0, uvOffset.y).ba;
                    float2 n = SampleTexture(i.uv, 0, -uvOffset.y).ba;
                    float2 w = SampleTexture(i.uv, uvOffset.x, 0).ba;
                    float2 e = SampleTexture(i.uv, -uvOffset.x, 0).ba;

                    float northAngle = GetAngle(n.x);
                    float southAngle = GetAngle(s.x);
                    float eastAngle = GetAngle(e.x);
                    float westAngle = GetAngle(w.x);

                    if(45 >= southAngle || southAngle >= 315)
                    {
                        sampledMag += float4(1, 0, 0, 1) * s.y;
                    }
                    else if(135 >= westAngle && westAngle >= 45)
                    {
                        sampledMag += float4(0, 1, 0, 1) * w.y;
                    }
                    else if(225 >= northAngle && northAngle >= 135)
                    {
                        sampledMag += float4(0, 0, 1, 1) * n.y;
                    }
                    else if (315 >= eastAngle && eastAngle >= 225) 
                    {
                        sampledMag += float4(1, 1, 0, 1) * e.y;
                    }

                
                    if(67.5 >= southWestAngle && southWestAngle >= 22.5)
                    {
                        sampledMag += float4(1, 0, 1, 1) * sw.y;
                    }
                    else if(157.5 >= northWestAngle && northWestAngle >= 112.5)
                    {
                        sampledMag += float4(0, 1, 1, 1) * nw.y;
                    }
                    else if(247.5 >= northEastAngle && northEastAngle >= 202.5)
                    {
                        sampledMag += float4(1, 0, 1, 1) * ne.y;
                    }
                    else if(337.5 >= southEastAngle && southEastAngle >= 292.5)
                    {
                        sampledMag += float4(0, 1, 1, 1) * se.y;
                    }                
                }

                sampledMag = saturate(sampledMag);
                

                return lerp(source, _OutlineColor, sampledMag.a);
            }
            ENDCG
        }
    }
}
