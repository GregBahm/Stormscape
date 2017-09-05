using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class StormDataLoader
{
    public static List<StormData> LoadStormData(string dataSourcePath)
    {
        List<StormData> ret = new List<StormData>();

        System.IO.StreamReader file = new System.IO.StreamReader(dataSourcePath);
        string line;
        string currentStormName = null;
        List<StormDataPoint> stormInProgress = new List<StormDataPoint>();
        file.ReadLine(); // Skipping the header stuff
        file.ReadLine();
        file.ReadLine();

        while ((line = file.ReadLine()) != null)
        {
            string[] splitString = line.Split(',');
            if (splitString[0] != currentStormName) // New Line
            {
                currentStormName = splitString[0];
                ret.Add(new StormData(stormInProgress));
                stormInProgress = new List<StormDataPoint>();
            }
            stormInProgress.Add(LoadDataFromLine(splitString));
        }

        file.Close();
        return ret;
    }

    private static StormDataPoint LoadDataFromLine(string[] splitString)
    {
        string rawLatitude = splitString[8];
        string rawLongitude = splitString[9];
        string rawWindSpeed = splitString[10];
        string rawYear = splitString[1];
        string rawFullDate = splitString[6];

        float latitude = Convert.ToSingle(rawLatitude);
        float longitude = Convert.ToSingle(rawLongitude);
        float windSpeed = Convert.ToSingle(rawWindSpeed);
        int year = Convert.ToInt32(rawYear);
        float day = GetDayFromString(rawFullDate);

        return new StormDataPoint(latitude, longitude, windSpeed, year, day);
    }

    private static float GetDayFromString(string rawFullDate)
    {
        string[] splitBySpace = rawFullDate.Split(' ');
        string dayPart = splitBySpace[0];
        string timePart = splitBySpace[1];

        string[] splitDayPart = dayPart.Split('-');
        string rawMonth = splitDayPart[1];
        string rawDayDate = splitDayPart[2];

        int month = Convert.ToInt32(rawMonth);
        int dayDate = Convert.ToInt32(rawDayDate);

        float totalDays = month * 30 + dayDate;

        string[] splitTimePart = timePart.Split(':');
        string rawHour = splitTimePart[0];
        int hour = Convert.ToInt32(rawHour);
        float hourFraction = (float)hour / 24;
        totalDays += hourFraction;

        return totalDays / 366;
    }
}

public struct StormData
{
    public readonly List<StormDataPoint> DataPoints;

    public StormData(List<StormDataPoint> dataPoints)
    {
        DataPoints = dataPoints;
    }
}

public struct StormDataPoint
{
    public readonly float Latitude;
    public readonly float Longitude;
    public readonly float WindSpeed;
    public readonly int Year;
    public readonly float Day; // 0 to 1 for its point in the year

    public StormDataPoint(float latitude,
        float longitude,
        float windspeed,
        int year,
        float day)
    {
        Latitude = latitude;
        Longitude = longitude;
        WindSpeed = windspeed;
        Year = year;
        Day = day;
    }
}