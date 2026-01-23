Shader "Burnobad/Sobel Angle Visualizer Shader"
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

            sampler2D _MainTex, _CameraDepthTexture;
            float4 _MainTex_ST, _CameraDepthTexture_TexelSize;

            float4 _UpCol, _DownCol, _RightCol, _LeftCol;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
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
                float Mag = sqrt(Gx * Gx + Gy * Gy);

                return float4(Gx, Gy, theta, Mag);
            }
            ENDCG
        }

        Pass
        {
            Name "Visualizer"
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
                float4 sobel = tex2D(_MainTex, i.uv);

                float Mag = sobel.a;
                
                float4 sampledMag = 0;              
                float angle = GetAngle(sobel.b);

                // turns out atan2 returns with:
                // 0 == down
                // 90 == left
                // 180 == up
                // 270 == right

                // Down
                if(45 >= angle || angle >= 315)
                {
                    sampledMag = _DownCol;
                }
                // Left
                else if(135 >= angle && angle >= 45)
                {
                    sampledMag = _LeftCol;
                }
                // Up
                else if(225 >= angle && angle >= 135)
                {
                    sampledMag = _UpCol;
                }
                // Right
                else if (315 >= angle && angle >= 225) 
                {
                    sampledMag = _RightCol;
                }

                return sampledMag;
            }
            ENDCG
        }
    }
}
