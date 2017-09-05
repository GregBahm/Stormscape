Shader "Unlit/LinesShader"
{
	Properties
	{
		_Polar("Polar", Range(0, 1)) = 1
		_StrokeThickness("Stroke Thickness", Range(0, 0.05)) = 1
		_WindlessThickness("Windless Thickness", Float) = 1
		_WindPowerWeight("Wind Power Weight", Range(0, 1)) = 1
		_GlobeRadius("Globe Radius", Float) = 1
		_DataHeight("Data Height", Float) = 1
		_CoordinatesAdjuster("Adjuster", Float) = 45
		_NormalizedTimeParam("Normalized Time Param", Range(0,1)) = 0
		_YearParam("Year Param", Range(0,1)) = 0
		_ColorA("Color A", Color) = (1,1,1,1)
		_ColorB("Color B", Color) = (1,1,1,1)
		_RampA("Ramp A", Float) = 1
		_RampB("Ramp B", Float) = 1
		_LineYThickness("Line Y Thickness", Range(0, 0.05)) = 1
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		//BlendOp Max
		//ZWrite Off
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma geometry geo
			#pragma fragment frag
			#pragma target 5.0 
			
			#include "UnityCG.cginc"

			float4x4 _Transform;
			float _StrokeThickness;
			float _CoordinatesAdjuster;
			float _GlobeRadius;
			float _DataHeight;
			float _WindlessThickness;
			float _WindPowerWeight;
			float _Polar;
			float _NormalizedTimeParam;
			float _YearParam;
			float4 _ColorA;
			float4 _ColorB;
			float _RampA;
			float _RampB;
			float _LineYThickness;

			struct StormBufferDatum
			{
				float3 Position;
				float3 StrokeNormal;
				float StrokeProgression;
				float WindPower;
			};

			struct g2f
			{
				float4 vertex : SV_POSITION;
				float strokeTime : TEXCOORD0;
				float year : TEXCOORD1;
			};

			StructuredBuffer<StormBufferDatum> _PointsBuffer;

			struct v2g
			{
				StormBufferDatum start : Normal;
				StormBufferDatum end : TEXCOORD2;
			};

			v2g vert(uint meshId : SV_VertexID, uint instanceId : SV_InstanceID)
			{
				StormBufferDatum start = _PointsBuffer[instanceId];
				StormBufferDatum end = _PointsBuffer[instanceId + 1];

				v2g o;
				o.start = start;
				o.end = end;
				return o; 
			}

			float4 ConvertToOutputSpace(float3 pointWorldPos)
			{
				pointWorldPos.xz /= _CoordinatesAdjuster;
				pointWorldPos.y = _GlobeRadius + _DataHeight * pointWorldPos.y;
				float sphericalX = pointWorldPos.y * cos(pointWorldPos.x) * cos(pointWorldPos.z);
				float sphericalY = pointWorldPos.y * cos(pointWorldPos.x) * sin(pointWorldPos.z);
				float sphericalZ = pointWorldPos.y *sin(pointWorldPos.x);
				float3 sphericalPos = float3(sphericalX, sphericalZ, sphericalY);
				float3 finalBase = lerp(sphericalPos, pointWorldPos, _Polar);
				float4 transformSpace = mul(_Transform, float4(finalBase, 1));
				return UnityObjectToClipPos(transformSpace);
			}

			float GetWeight(StormBufferDatum datum)
			{
				float year = datum.Position.y;
				float yearParam = _YearParam > year;
				yearParam *= 1 - (_YearParam - year);
				float timeFactor = 1 - abs(datum.StrokeProgression - _NormalizedTimeParam);

				float windyTarget = datum.WindPower * _StrokeThickness;
				return lerp(windyTarget, _WindlessThickness, _WindPowerWeight);
			}

			void AppendSide(inout TriangleStream<g2f> triStream, 
				float3 startPointA, 
				float3 startPointB, 
				float3 endPointA, 
				float3 endPointB, 
				v2g sourceData)
			{
				g2f o;
				o.year = sourceData.start.Position.y;
				o.strokeTime = sourceData.start.StrokeProgression;
				o.vertex = ConvertToOutputSpace(startPointA);
				triStream.Append(o);
				o.vertex = ConvertToOutputSpace(startPointB);
				triStream.Append(o);

				o.strokeTime = sourceData.end.StrokeProgression;
				o.vertex = ConvertToOutputSpace(endPointA);
				triStream.Append(o);
				o.vertex = ConvertToOutputSpace(endPointB);
				triStream.Append(o);
				triStream.RestartStrip();
			}

			[maxvertexcount(8)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream)
			{
				bool notEnd = p[0].start.StrokeProgression < 1;
				bool notMeridian = p[0].start.Position.z - p[0].end.Position.z < 180;
				if (notEnd && notMeridian)
				{
					g2f o;
					float startWeight = GetWeight(p[0].start);
					float endWeight = GetWeight(p[0].end);

					float3 chainStart = p[0].start.Position;
					float3 startNormal = normalize(p[0].start.StrokeNormal) * startWeight;
					float3 chainEnd = p[0].end.Position;
					float3 endNormal = normalize(p[0].end.StrokeNormal) * endWeight;

					float3 pointA = chainStart - startNormal;
					float3 pointB = chainStart + startNormal;
					float3 pointC = chainEnd - endNormal;
					float3 pointD = chainEnd + endNormal;

					float3 pointADropped = pointA + float3(0, -_LineYThickness, 0);
					float3 pointBDropped = pointB + float3(0, -_LineYThickness, 0);
					float3 pointCDropped = pointC + float3(0, -_LineYThickness, 0);
					float3 pointDDropped = pointD + float3(0, -_LineYThickness, 0);

					AppendSide(triStream, pointADropped, pointA, pointCDropped, pointC, p[0]);
					AppendSide(triStream, pointA, pointB, pointC, pointD, p[0]);
					//o.strokeTime = p[0].start.StrokeProgression;
					//o.vertex = ConvertToOutputSpace(pointA);
					//triStream.Append(o);
					//o.vertex = ConvertToOutputSpace(pointB);
					//triStream.Append(o);
					//
					//o.strokeTime = p[0].end.StrokeProgression;
					//o.vertex = ConvertToOutputSpace(pointC);
					//triStream.Append(o);
					//o.vertex = ConvertToOutputSpace(pointD);
					//triStream.Append(o);
				}
			}
			
			fixed4 frag (g2f i) : SV_Target
			{
				return lerp(_ColorA, _ColorB, pow(saturate(i.year), _RampA));
				//return lerp(_ColorA, _ColorB, pow(saturate(yearParam), _RampA)) * pow(saturate(yearParam), _RampB);
				//return (_YearParam < i.year) * (1 - abs(_YearParam - i.year) * 10);
			}
			ENDCG
		}
	}
}
