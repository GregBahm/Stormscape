using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.Linq;

public class MainScript : MonoBehaviour
{
    struct StormBufferDatum
    {
        public Vector3 Position;
        public Vector3 StrokeNormal;
        public float StrokeProgression;
        public float WindPower;
    }

    public Material LineMat;
    private ComputeBuffer _pointsBuffer;
    private const int BufferStride = sizeof(float) * 3 + sizeof(float) * 3 + sizeof(float) + sizeof(float);
    private int dataPointCount;

    private static bool StormQualifies(StormData data)
    {
        if(data.DataPoints.Count < 3)
        {
            return false;
        }
        if(data.DataPoints[0].Year < 1900)
        {
            return false;
        }
        return true;
    }

    private void Start()
    {
        string dataSourcePath = Application.dataPath + "\\StormData.csv";
        List<StormData> storms = StormDataLoader.LoadStormData(dataSourcePath).Where(StormQualifies).ToList();
        dataPointCount = GetDataPointCount(storms);
        _pointsBuffer = GetComputeBuffer(storms);
    }

    private ComputeBuffer GetComputeBuffer(List<StormData> storms)
    {
        StormBufferDatum[] data = GetComputeBufferData(storms);
        ComputeBuffer ret = new ComputeBuffer(dataPointCount, BufferStride);
        ret.SetData(data);
        return ret;
    }

    private StormBufferDatum[] GetComputeBufferData(List<StormData> storms)
    {
        int index = 0;
        StormBufferDatum[] ret = new StormBufferDatum[dataPointCount];
        foreach (StormData storm in storms)
        {
            int startingIndex = index;
            int subIndex = 0;
            int lastPointIndex = storm.DataPoints.Count - 1;
            foreach (StormDataPoint dataPoint in storm.DataPoints)
            {
                StormBufferDatum newDatum = GetStormBufferDatum(dataPoint, subIndex, lastPointIndex);
                ret[index] = newDatum;
                subIndex++;
                index++;
            }

            ret[startingIndex].StrokeNormal = GetFirstStrokeNormal(ret[startingIndex].Position, ret[startingIndex + 1].Position);
            for (int i = 1; i < storm.DataPoints.Count - 1; i++)
            {
                int thisIndex = startingIndex + i;
                ret[thisIndex].StrokeNormal = GetStrokeNormal(ret[thisIndex - 1].StrokeNormal, ret[thisIndex].Position, ret[thisIndex + 1].Position);
            }
            ret[startingIndex + storm.DataPoints.Count - 1].StrokeNormal = ret[startingIndex + storm.DataPoints.Count - 2].StrokeNormal;
            
        }
        return ret;
    }

    private Vector3 GetStrokeNormal(Vector3 lastNormal, Vector3 thisPosition, Vector3 nextPosition)
    {
        Vector3 potentialRet = Vector3.Cross(thisPosition - nextPosition, Vector3.up).normalized;
        if(Vector3.Dot(potentialRet, lastNormal) < 0)
        {
            return potentialRet * -1;
        }
        return potentialRet;
    }

    private Vector3 GetFirstStrokeNormal(Vector3 startPosition, Vector3 nextPosition)
    {
        return Vector3.Cross(startPosition - nextPosition, Vector3.up).normalized;
    }

    private StormBufferDatum GetStormBufferDatum(StormDataPoint dataSource, int strokeIndex, int strokeLength)
    {
        float adjustedLongitude = GetAdjustedLongitude(dataSource.Longitude);
        float adjustedYear = (float)(dataSource.Year - 1848) / (2016 - 1848);
        Vector3 position = new Vector3(dataSource.Latitude, adjustedYear, adjustedLongitude);
        float strokeProgression = (float)strokeIndex / strokeLength;
        float windPower = Mathf.Max(0, dataSource.WindSpeed);
        return new StormBufferDatum() { Position = position, StrokeProgression = strokeProgression , WindPower = windPower};
    }

    private float GetAdjustedLongitude(float longitude)
    {
        return (longitude + 360) % 360;
    }

    private void Update()
    {
        LineMat.SetBuffer("_PointsBuffer", _pointsBuffer);
        LineMat.SetMatrix("_Transform", transform.localToWorldMatrix);
    }
    
    private int GetDataPointCount(List<StormData> storms)
    {
        int ret = 0;
        foreach (StormData datum in storms)
        {
            ret += datum.DataPoints.Count;
        }
        return ret;
    }

    private void OnRenderObject()
    {
        LineMat.SetPass(0);
        Graphics.DrawProcedural(MeshTopology.Points, 1, dataPointCount);
    }

    private void OnDestroy()
    {
        _pointsBuffer.Release();
    }
}
