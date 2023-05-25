Bike Case Study
================

### 1. Task

#### Bike-share Case Study

Cyclistic launched their bike-share service in 2016. Since then, the
program has grown to a fleet of 5,824 bicycles that are geo-tracked and
locked into a network of 692 stations across Chicago. The bike can be
unlocked from one station and returned to any other station in the
system anytime.

Cyclistic offers flexible pricing plans including single-ride passes,
full-day passes, and annual memberships. Customers who purchase
single-ride or full-day passes are referred to as casual riders.
Customers who purchases annual memberships are Cyclistic members.

#### Task

The company wants to design a marketing strategy that aimed at
converting casual riders into annual members. In order to do that, they
want to understand:

-   How do annual members and casual riders use Cyclistic bikes
    differently?
-   Why would casual riders buy Cyclistic annual memberships?
-   How can Cyclistic use digital media to influence casual riders to
    become members?

This report is to answer how annual members and casual riders differ.

### 2. Data Description

Data source: Google Data Analytics Certificate on Cousera

#### Trip Data

Before 2020, the trip data was stored using the following metadata:

<table>
<thead>
<tr>
<th style="text-align:left;">
Variables
</th>
<th style="text-align:left;">
Descriptions
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
trip_id
</td>
<td style="text-align:left;">
ID attached to each trip taken
</td>
</tr>
<tr>
<td style="text-align:left;">
start_time
</td>
<td style="text-align:left;">
day and time trip started, in CST
</td>
</tr>
<tr>
<td style="text-align:left;">
stop_time
</td>
<td style="text-align:left;">
day and time trip ended, in CST
</td>
</tr>
<tr>
<td style="text-align:left;">
bikeid
</td>
<td style="text-align:left;">
ID attached to each bike
</td>
</tr>
<tr>
<td style="text-align:left;">
tripduration
</td>
<td style="text-align:left;">
time of trip in seconds
</td>
</tr>
<tr>
<td style="text-align:left;">
from_station_name
</td>
<td style="text-align:left;">
name of station where trip originated
</td>
</tr>
<tr>
<td style="text-align:left;">
to_station_name
</td>
<td style="text-align:left;">
name of station where trip terminated
</td>
</tr>
<tr>
<td style="text-align:left;">
from_station_id
</td>
<td style="text-align:left;">
ID of station where trip originated
</td>
</tr>
<tr>
<td style="text-align:left;">
to_station_id
</td>
<td style="text-align:left;">
ID of station where trip terminated
</td>
</tr>
<tr>
<td style="text-align:left;">
usertype
</td>
<td style="text-align:left;">
"Customer" is a rider who purchased a 24-Hour Pass; "Subscriber" is a
rider who purchased an Annual Membership
</td>
</tr>
<tr>
<td style="text-align:left;">
gender
</td>
<td style="text-align:left;">
gender of rider
</td>
</tr>
<tr>
<td style="text-align:left;">
birthyear
</td>
<td style="text-align:left;">
birth year of rider
</td>
</tr>
</tbody>
</table>

**Notes:**

-   Trips that did not include a start or end date are excluded
-   Trips less than 1 minute in duration are excluded
-   Trips greater than 24 hours in duration are excluded
-   Gender and birthday are only available for Subscribers

Since 2020, the data structure changed to:

<table>
<thead>
<tr>
<th style="text-align:left;">
Variables
</th>
<th style="text-align:left;">
Descriptions
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
ride_id
</td>
<td style="text-align:left;">
ID attached to each ride taken
</td>
</tr>
<tr>
<td style="text-align:left;">
rideable_type
</td>
<td style="text-align:left;">
docked_bike, electric_bike, classic_bike
</td>
</tr>
<tr>
<td style="text-align:left;">
started_at
</td>
<td style="text-align:left;">
day and time trip started
</td>
</tr>
<tr>
<td style="text-align:left;">
ended_at
</td>
<td style="text-align:left;">
day and time trip ended
</td>
</tr>
<tr>
<td style="text-align:left;">
start_station_name
</td>
<td style="text-align:left;">
name of station where trip originated
</td>
</tr>
<tr>
<td style="text-align:left;">
end_station_name
</td>
<td style="text-align:left;">
name of station where trip terminated
</td>
</tr>
<tr>
<td style="text-align:left;">
start_station_id
</td>
<td style="text-align:left;">
ID of station where trip originated
</td>
</tr>
<tr>
<td style="text-align:left;">
end_station_id
</td>
<td style="text-align:left;">
ID of station where trip terminated
</td>
</tr>
<tr>
<td style="text-align:left;">
start_lat
</td>
<td style="text-align:left;">
latitude of station where trip originated
</td>
</tr>
<tr>
<td style="text-align:left;">
end_lat
</td>
<td style="text-align:left;">
latitude of station where trip terminated
</td>
</tr>
<tr>
<td style="text-align:left;">
start_lng
</td>
<td style="text-align:left;">
longitude of station where trip originated
</td>
</tr>
<tr>
<td style="text-align:left;">
end_lng
</td>
<td style="text-align:left;">
longitude of station where trip terminated
</td>
</tr>
<tr>
<td style="text-align:left;">
member_casual
</td>
<td style="text-align:left;">
"casual" is a rider who purchased a 24-Hour Pass; "member" is a rider
who purchased an Annual Membership
</td>
</tr>
</tbody>
</table>

#### Station Data

Store all the data of stations in the system

<table>
<thead>
<tr>
<th style="text-align:left;">
Variables
</th>
<th style="text-align:left;">
Descriptions
</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align:left;">
id
</td>
<td style="text-align:left;">
ID attached to each station
</td>
</tr>
<tr>
<td style="text-align:left;">
name
</td>
<td style="text-align:left;">
station name
</td>
</tr>
<tr>
<td style="text-align:left;">
latitude
</td>
<td style="text-align:left;">
station latitude
</td>
</tr>
<tr>
<td style="text-align:left;">
longitude
</td>
<td style="text-align:left;">
station longitude
</td>
</tr>
<tr>
<td style="text-align:left;">
dpcapacity
</td>
<td style="text-align:left;">
number of total docks at each station
</td>
</tr>
<tr>
<td style="text-align:left;">
online_date
</td>
<td style="text-align:left;">
date the station was created in the system
</td>
</tr>
</tbody>
</table>

### 3. Data Cleaning

All steps of data import and cleaning are written in
[0_data_load.R](1_code\0_data_load.R):

-   Unzip and import data from csv from folder 2_data
-   As the data structure of trips before and after 2020 are different,
    data was imported into 2 different dataframes: trip_s2020,
    trips_b2020
-   Parse different date time formats for start time and end time of
    including: ymd_HMS, mdy_HMS, mdy_HM
-   Remove duplicated trips
-   Re-calculate trip length in seconds
-   After cleaning, data was exported in csv files, and uploaded to
    PostgreSQL, and SQLite server

The output data included:

-   Station data: 585 stations, data as of: 2017-12-31
-   Trip data before 2020: 21,243,283 trips from 2001-01-20 to
    2020-01-21
-   Trip data since 2020: 13,024,689 trips from 2020-01-01 to 2022-09-06

Table name / File name of output data:

| Data              | SQLite        | PostgreSQL    | CSV files        |
|-------------------|---------------|---------------|------------------|
| Station           | `D_Station`   | `d_station`   | station_data.csv |
| Trips before 2020 | `F_TripB2020` | `f_tripb2020` | trips20_data.csv |
| Trips after 2020  | `F_TripS2020` | `f_trips2020` | tripb20_data.csv |

### 4. Summary of Analysis

-   Annual members rode more trips than casual riders, but the trip
    length of casual rides are 2.3 times longer than that of annual
    members.
-   Average trip length of all members: 1180 seconds (or 19 minutes);
    casual riders: 1754 seconds (or 29 minutes); annual members: 770
    seconds (or 12 minutes)
-   The number of trips decreased during the winter season (November to
    February), and the trip length was also shorter.
-   Averagely, weekends had more rides than weekdays. The trend was
    opposite during winter months from November to February, when Monday
    to Thursday had more rides than other days.

Refer to [1_code/1_report.html](1_code/1_report.html) for the full analysis
