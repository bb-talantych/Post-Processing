Shader "Unlit/SimpleSharpness"
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

            float _Sharpness;

            v2f vert (appdata v)
            {
                v2f o;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                return o;
            }

            // Inspired by Acerola
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                float center = _Sharpness * 4 + 1;
                float neighbour = -_Sharpness;

                float4 n = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, 1));
                float4 s = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(0, -1));
                float4 e = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(1, 0));
                float4 w = tex2D(_MainTex, i.uv + _MainTex_TexelSize * float2(-1, 0));

                float4 finalNeighbours = (n + s + e + w) * neighbour;
                float4 output = (col * center) + finalNeighbours;

                return saturate(output);
            }
            ENDCG
        }
    }
}
