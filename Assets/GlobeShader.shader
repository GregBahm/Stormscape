Shader "Unlit/GlobeShader"
{
	Properties
	{
		_Color("Color", Color) = (1,1,1,1)
		_Polar("Polar", Range(0, 1)) = 1
		_MainTex ("Texture", 2D) = "white" {}
		_GlobeRadius("Globe Radius", Float) = 1
		_XCoordinatesAdjuster("X Adjuster", Range(0.6, 0.7)) = 45
		_YCoordinatesAdjuster("Y Adjuster", Range(0.2, 0.4)) = 45
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		Cull Off
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
			float _GlobeRadius;
			float _XCoordinatesAdjuster;
			float _YCoordinatesAdjuster;
			float _Polar;
			float4 _Color;
			
			v2f vert (appdata v)
			{
				float4 originalVert = v.vertex;
				originalVert.xyz = originalVert.yzx;
				originalVert.yz *= -1;
				originalVert.x *= 2;
				v.vertex.x /= _XCoordinatesAdjuster;
				v.vertex.y /= _YCoordinatesAdjuster;
				float sphericalX = _GlobeRadius * cos(v.vertex.x) * cos(v.vertex.y);
				float sphericalY = _GlobeRadius * cos(v.vertex.x) * sin(v.vertex.y);
				float sphericalZ = _GlobeRadius *sin(v.vertex.x);

				float4 sphereVert = float4(sphericalX, sphericalY, sphericalZ, 1);
				float4 finalVert = lerp(originalVert, sphereVert, _Polar);
				v2f o;
				o.vertex = UnityObjectToClipPos(finalVert);
				o.uv = v.uv;
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target
			{
				float4 rawTexture = tex2D(_MainTex, i.uv);
				clip(rawTexture.x - .1);
				return rawTexture.xxxx * _Color;
			}
			ENDCG
		}
	}
}
