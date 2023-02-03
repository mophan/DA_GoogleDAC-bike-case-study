# Version 20221019


# set up ---------------------------------------------

# packages
library(tidyverse)
library(lubridate)
library(janitor)
library(readxl)
library(data.table)
library(hms)
library(sqldf)
library(RPostgres)
# library(RSQLite)
library(DBI)
library(keyring)


# folder 
folder_data <- '2_data'
folder_input <- '3_input'
folder_ouput <- '4_output'
# folder_db <- '5_dbsqlite'

folder_extractdata <-
  paste0(folder_data, '/extract_data')


# # create folder extract data
# PS: RUN ONLY ONCE
# dir.create(file.path(folder_data, 'extract_data'))


# connect SQLite
# PS: new database will be created if the bike db does not exist
# con_sqlite <- 
#   dbConnect(SQLite(), 
#             paste0(folder_db, '/bike.sqlite'))


# connect to PostgreSQL
con <- 
  dbConnect(
    Postgres(),
    dbname = "dac_bike",
    port = "5432",
    user = key_list("postgres")[1,2],
    password = key_get("postgres", key_list("postgres")[1,2])
  )



# 1. import trip since 2020 ------------------------------------------------------------

# list file name
trips20_files <-
  list.files(folder_data, pattern = '*data.zip')


# import trips20 data
trips20_data <-
  lapply(trips20_files, function(x) {
    read_csv(file.path(folder_data, x)) %>%
      mutate(
        across(c(start_station_id, end_station_id), ~ as.numeric(.)),
        filename = str_remove(basename(x), pattern = '.zip')
      )
  }) %>%
  bind_rows()


# check if all data are imported
table(trips20_data$filename, 
      !is.na(trips20_data$ride_id))



# 2. import trip before 2020 (header only)-------------------------------------
# PS: ONLY RUN THIS PART ONCE 

# # list files
# data_files <- 
#   list.files(folder_data, pattern = 'Divvy_*')
#
#
# # unzip files to folder extract data
# filename <-
#   lapply(data_files, function(x) {
#     unzip(file.path(folder_data, x), exdir = folder_extractdata)
#   }) %>%
#   unlist() %>%
#   as.data.frame() %>%
#   rename(FileName = '.') %>% 
#   mutate(
#     FileName = str_split(FileName, "/") %>% map_chr(~last(.))
#   ) %>% 
#   filter(str_detect(FileName, 'Divvy_'))
# 
# 
# # list unzip folders
# unzip_folders <- 
#   list.dirs(folder_extractdata)
#   
# 
# # filter unzipped folders
# unzip_folders <- 
#   unzip_folders[grepl("Divvy_", unzip_folders)]
# 
# 
# # function to copy files to folder extract data
# copyEverything <- function(from, to){
#   
#   # search all the files in from directories
#   files <- 
#     list.files(from, pattern = 'Divvy_')
# 
#   
#   # copy the files
#   file.copy(paste(from, files, sep = '/'), 
#             paste(to, files, sep = '/'))
# }
# 
# 
# # copy all files from sub folders to folder_extractdata
# for (i in 1:length(unzip_folders)) {
#     
#   copyEverything(unzip_folders[i], folder_extractdata)
#     
#   }


# check file header 
# PS: to mass import files that have same headers

# list file names 
tripb20_files <- 
  list.files(folder_extractdata, 
             pattern = 'Divvy_Trips_')


# list only csv files
tripb20_files <- 
  tripb20_files[grepl('*.csv', tripb20_files)]


# function to read headers of data files
read.header <- function(filename){
  
  data <- 
    colnames(read.csv2(file.path(folder_extractdata, filename))) %>%  # only import the column header in one column
    as.data.frame() %>% 
    rename(header = '.') %>% 
    mutate(filename = basename(filename))
  
  return(data)
  
}


# import data headers
tripb20_header <- 
  lapply(tripb20_files, 
         function(x) read.header(x)) %>% 
  bind_rows()


# count number of separator '.' to detect similar pattern
tripb20_header <- 
  tripb20_header %>% 
  mutate(
    num_separator = nchar(gsub("[^.]", "", header)),
    num_char = nchar(header),
    .before = 'filename'
  )


# check number separator "." in header
table(tripb20_header$num_separator,
      tripb20_header$num_char)



# 3. import trip before 2020 ---------------------------------------

# filter headers with same pattern
# PS: headers having the same num separator (11)
tripb20_same_header <- 
  tripb20_header %>% 
  filter(num_separator == 11)


# function to read data
read.quarter <- function(filename){
  
  # import data
  data <- 
    read_csv(file.path(folder_extractdata, filename)) %>% 
    mutate(filename = basename(filename)) %>% 
    rename_with(        # rename if col starttime and stoptime exist
      ~ case_when(
        . == 'starttime' ~ 'start_time',
        . == 'stoptime' ~ 'end_time',
        TRUE ~ .
      )
    )
  
  # convert time to character
  # PS: to align date types of all files to bind rows
    data <-
      data %>%
      mutate(across(c(start_time, end_time), 
                    ~ as.character(.)))
  
  # return data
    return(data)
    
}


# import data
tripb20_data <- 
  lapply(tripb20_same_header$filename, 
         function(x) read.quarter(x)) %>% 
  bind_rows()


# check if all data are imported
table(tripb20_data$filename,
      is.na(tripb20_data$trip_id))



# data cleansing ---

# check birthday and birthyear
table(is.na(tripb20_data$birthday), 
      is.na(tripb20_data$birthyear))


# combine 2 columns birthday, birthyear
tripb20_data <- 
  tripb20_data %>% 
  mutate(
    birthyear = case_when(is.na(birthyear) ~ birthday,
                          TRUE ~ birthyear)
  ) %>% 
  select(-birthday)


# check date format
tripb20_dateformat <- 
  tripb20_data %>% 
  select(filename, start_time) %>% 
  distinct() %>% 
  mutate(start_time_length = nchar(start_time)) %>% 
  group_by(start_time_length, filename)%>% 
  summarise(
    start_time_max = max(start_time)) 


# convert date format
tripb20_data <- 
  tripb20_data %>% 
  mutate(
    
    # convert multiple date time format
    across(c(start_time, end_time),
           ~ as_datetime(parse_date_time(., c('ymd_HMS',
                                              'mdy_HMS',
                                              'mdy_HM'))),
           .names = '{col}_adj'),
    
    # convert to year
    across(c(start_time_adj, end_time_adj), 
           year,
           .names = '{col}_year')
 
    
  )


# check data type
glimpse(tripb20_data)


# check if any NA
table(is.na(tripb20_data$start_time),
      is.na(tripb20_data$start_time_adj))

table(is.na(tripb20_data$end_time),
      is.na(tripb20_data$end_time_adj))


# check distribution by year
addmargins(table(tripb20_data$start_time_adj_year))
prop.table(table(tripb20_data$start_time_adj_year)) * 100

addmargins(table(tripb20_data$end_time_adj_year))
prop.table(table(tripb20_data$end_time_adj_year)) * 100


# rename columns
tripb20_data_adj <- 
  tripb20_data %>%
  select(-start_time, -end_time) %>% 
  rename(
    start_time = start_time_adj,
    end_time = end_time_adj,
    start_time_year = start_time_adj_year,
    end_time_year = end_time_adj_year)



# 4. import trip data with different header ---------------------------------------

# import Q1_2018
Q1_2018 <- 
  read_csv(file.path(folder_extractdata, 'Divvy_Trips_2018_Q1.csv')) %>% 
  clean_names()


# rename columns
Q1_2018 <- 
  Q1_2018 %>% 
  rename(
    trip_id = x01_rental_details_rental_id,
    start_time = x01_rental_details_local_start_time,
    end_time = x01_rental_details_local_end_time,
    bikeid = x01_rental_details_bike_id,
    tripduration = x01_rental_details_duration_in_seconds_uncapped,
    from_station_id = x03_rental_start_station_id,
    from_station_name = x03_rental_start_station_name,
    to_station_id = x02_rental_end_station_id,
    to_station_name = x02_rental_end_station_name,
    usertype = user_type,
    gender = member_gender,
    birthyear = x05_member_details_member_birthday_year
  ) %>% 
  mutate(
    filename = basename(file.path(folder_extractdata, 'Divvy_Trips_2018_Q1.csv')),
    across(c(start_time, end_time), year, .names = '{col}_year')
  )


# check date
min(Q1_2018$start_time)
max(Q1_2018$end_time)


# import Q2_2019
Q2_2019 <- 
  read_csv(file.path(folder_extractdata, 'Divvy_Trips_2019_Q2.csv')) %>% 
  clean_names()


# rename columns
Q2_2019 <- 
  Q2_2019 %>% 
  rename(
    trip_id = x01_rental_details_rental_id,
    start_time = x01_rental_details_local_start_time,
    end_time = x01_rental_details_local_end_time,
    bikeid = x01_rental_details_bike_id,
    tripduration = x01_rental_details_duration_in_seconds_uncapped,
    from_station_id = x03_rental_start_station_id,
    from_station_name = x03_rental_start_station_name,
    to_station_id = x02_rental_end_station_id,
    to_station_name = x02_rental_end_station_name,
    usertype = user_type,
    gender = member_gender,
    birthyear = x05_member_details_member_birthday_year
  ) %>% 
  mutate(
    filename = basename(file.path(folder_extractdata, 'Divvy_Trips_2019_Q2.csv')),
    across(c(start_time, end_time), year, .names = '{col}_year')
  )


# check date
min(Q2_2019$start_time)
max(Q2_2019$end_time)


# import Q1_2020 (same data frame as trips20 trip)
Q1_2020 <- 
  read_csv(file.path(folder_extractdata, 'Divvy_Trips_2020_Q1.csv')) %>% 
  clean_names() %>% 
  mutate(
    filename = basename(file.path(folder_extractdata, 'Divvy_Trips_2020_Q1.csv'))
  )


# check dates
min(Q1_2020$started_at)
max(Q1_2020$started_at) 



# 5. merge trip data ---------------------------------------

# trip since 2020 ---

# check minDate, maxDate of data trip since 2020
min(trips20_data$started_at)
max(trips20_data$ended_at)

# check col name before merge
glimpse(trips20_data)
glimpse(Q1_2020)


# merge trip data since 2020 
trips20_data <- 
  trips20_data %>% 
  rbind(Q1_2020 %>% 
          select(names(trips20_data))) %>% 
  distinct()



#  trip before 2020 ---

# check trip data before 2020 
glimpse(tripb20_data_adj)
glimpse(Q1_2018)
glimpse(Q2_2019)


# check dates
min(tripb20_data_adj$start_time)
max(tripb20_data_adj$end_time)

min(Q1_2018$start_time)
max(Q1_2018$end_time)

min(Q2_2019$start_time)
max(Q2_2019$end_time)


# merge trip data before 2020
tripb20_data_final <- 
  tripb20_data_adj %>% 
  rbind(
    Q1_2018 %>% select(names(tripb20_data_adj)),
    Q2_2019 %>% select(names(tripb20_data_adj))
  ) 


# remove duplicate
tripb20_data_final <- 
  tripb20_data_final %>% 
  distinct()



# 6. import stations ---------------------------------------------

# list station
station_files <- 
  list.files(folder_extractdata, 
             pattern = 'Divvy_Stations_')


# filter csv files
station_files_csv <- 
  station_files[grepl('*.csv', station_files)]


# import station data
station_data <-
  lapply(station_files_csv, function(x) {
    read_csv(file.path(folder_extractdata, x)) %>%
      mutate(filename = basename(x)) %>% 
      clean_names()
  }) %>%
  bind_rows()


# filter excel file
station_files_xlsx <- 
  station_files[grepl('*.xlsx', station_files)]


# import excel file
Q1Q2_2014_station <- 
  read_xlsx(file.path(folder_extractdata, 
                      station_files_xlsx)) %>% 
  clean_names() %>% 
  mutate(
    filename = basename(station_files_xlsx),
    online_date = as.character(online_date)
           )


# rbind station data
station_data <- 
  bind_rows(station_data, 
            Q1Q2_2014_station) %>% 
  distinct()


# check NA
table(station_data$filename, is.na(station_data$id))
table(station_data$filename, is.na(station_data$date_created))
table(station_data$filename, is.na(station_data$online_date))
table(station_data$filename, is.na(station_data$city))
table(station_data$filename, is.na(station_data$x8))  # empty 


# combine two columns online_date and date_created
station_data <- 
  station_data %>% 
  mutate(
    # merge online_date and date_created
    online_date = case_when(is.na(online_date) ~ date_created,
                            TRUE ~ online_date)
  ) %>% 
  select(-x8, -date_created)


# check NA again
table(station_data$filename, is.na(station_data$online_date))


# check date format
station_dateformat <- 
  station_data %>% 
  mutate(date_length = nchar(online_date)) %>% 
  group_by(date_length, filename) %>% 
  summarise(date_max = max(online_date))


# convert date format, separate date and time
station_data <- 
  station_data %>% 
  mutate(
    online_date = as_datetime(
      parse_date_time(online_date,
                      c('mdy', 'ymd', 'mdy_HM', 'mdy_HMS')))
)


# separate date and time created
station_data <- 
  station_data %>% 
  mutate(
    date_created = as.integer(format(online_date, '%Y%m%d')),
    time_created = format(online_date, '%H:%M:%S')
  )


# import station last update date
station_lastupdate <- 
  read_xlsx(file.path(folder_input, 
                      'station_updatedate.xlsx'))


# join station with last update date
station_data <- 
  station_data %>% 
  left_join(station_lastupdate, by = 'filename') %>% 
  select(-filename, -online_date) %>% 
  mutate(
    CURRUPDATE = ifelse(update_date == 20171231, 'Y', 'N')
  )


# check after join
table(is.na(station_data$update_date))  # should be all FALSE - no NA
table(station_data$update_date, station_data$CURRUPDATE)         # check count


# check if any duplicated id in the last update
table(duplicated((station_data %>% filter(CURRUPDATE == 'Y'))$id))


# check id range by update date
station_data %>% 
  group_by(update_date) %>% 
  summarise(
    minID = min(id),
    maxID = max(id)
  )


# export for manual review
# write.csv(station_data,
#           file.path(folder_ouput, 'station_data.csv'),
#           na = '', row.names = FALSE)



# 7. validate trip data since 2020 -------------------------------------------------

# data type ---
glimpse(trips20_data)


# data range & constraints ---

# ride_id
table(is.na(trips20_data$ride_id))  # all FALSE, not NULL
table(duplicated(trips20_data$ride_id))   # 209 duplicates


# rideable_type
table(is.na(trips20_data$rideable_type))     # all FALSE, not NULL
addmargins(table(trips20_data$rideable_type))
prop.table(table(trips20_data$rideable_type)) * 100


# started_at
table(is.na(trips20_data$started_at))   # all FALSE, not NULL
min(trips20_data$started_at)
max(trips20_data$started_at)


# ended_at
table(is.na(trips20_data$ended_at))   # all FALSE, not NULL
min(trips20_data$ended_at)
max(trips20_data$ended_at)


# station_id
table(is.na(trips20_data$start_station_id))   # 5M rows NULL
table(is.na(trips20_data$end_station_id))     # 6M rows NULL


length(unique(c(trips20_data$start_station_id,   # 1293
                trips20_data$end_station_id)))


min(unique(c(trips20_data$start_station_id,      # 2
             trips20_data$end_station_id)),
    na.rm = TRUE)


max(unique(c(trips20_data$start_station_id,      # 202480
             trips20_data$end_station_id)),
    na.rm = TRUE)


# check if any station id not in station data      # 47 not in station data
table(!unique(c(trips20_data$start_station_id,
              trips20_data$end_station_id))
      %in% c(station_data$id))


# station name
table(is.na(trips20_data$start_station_name))   # 1M rows NULL
table(is.na(trips20_data$end_station_name))     # 1M rows NULL


length(unique(c(trips20_data$start_station_name,   # 1499
                trips20_data$end_station_name)))


# check if any station name not in station data      # 90 not in station data
table(!unique(c(trips20_data$start_station_name,
              trips20_data$end_station_name))
      %in% c(station_data$name))


# long, lat
table(is.na(trips20_data$start_lat))   # all FALSE, not NULL
table(is.na(trips20_data$start_lng))   # all FALSE, not NULL

table(is.na(trips20_data$end_lat))     # 13k NULL
table(is.na(trips20_data$end_lng))     # same with lat


# membership
table(is.na(trips20_data$member_casual))
table(trips20_data$member_casual)
prop.table(table(trips20_data$member_casual)) * 100   # 57.26% members



# find duplicate & check ride length ---
trips20_data <- 
  trips20_data %>% 
  mutate(
    ride_length = difftime(ended_at, started_at),
    .after = 'ended_at',
    Is_duplicate = ifelse(ride_id %in% 
                            trips20_data$ride_id[duplicated(trips20_data$ride_id)],
                          TRUE, FALSE)
  )


# filter duplicated data 
trips20_duplicate <- 
  trips20_data %>% 
  filter(ride_id %in% 
           trips20_data$ride_id[duplicated(trips20_data$ride_id)]) %>% 
  arrange(ride_id)
# reason for duplicate: duplicate with start time > end time


# filter out duplicate 
trips20_data <- 
  trips20_data %>% 
  filter(!(Is_duplicate == TRUE
         & ride_length > -1000000))


# check duplicate again
table(duplicated(trips20_data$ride_id))


# check ride length ---

# check if any trip lsss than 1m included -- should be all FALSE
table(trips20_data$ride_length < 60)     # 227k 

# check if trip greater than 24h included -- should be all FALSE
table(trips20_data$ride_length > 24 * 60 * 60)  # 10k


# formatting date type ---

# add start_date, end_date
trips20_data <- 
  trips20_data %>% 
  mutate(
    start_date = as.integer(format(as.Date(started_at), '%Y%m%d')),
    end_date = as.integer(format(as.Date(ended_at), '%Y%m%d')),
    .before = 'started_at'
  )


# format date
trips20_data <- 
  trips20_data %>% 
  mutate(
    started_at = format(started_at, '%Y-%m-%d %H:%M:%S'),
    ended_at = format(ended_at, '%Y-%m-%d %H:%M:%S'),
    ride_length = format(as_hms(ride_length), '%H:%M:%S')
  )


# select columns to load
glimpse(trips20_data)

trips20_data <- 
  trips20_data %>% 
  select(-filename,
         -Is_duplicate) 



# 8. validate trip data before 2020 ---------------------------------

# data type ---
glimpse(tripb20_data_final)


# data range & constraints ---

# trip_id
table(is.na(tripb20_data_final$trip_id))   # all FALSE not NULL
table(duplicated(tripb20_data_final$trip_id)) # all FALSE not NULL

min(tripb20_data_final$trip_id)
max(tripb20_data_final$trip_id)


# bikeid
table(is.na(tripb20_data_final$bikeid))      # all FALSE not NULL
table(duplicated(tripb20_data_final$bikeid))  # not unique

min(tripb20_data_final$bikeid)
max(tripb20_data_final$bikeid)

length(unique(tripb20_data_final$bikeid))


# start time, end time
table(is.na(tripb20_data_final$start_time))  # all FALSE not NULL
table(is.na(tripb20_data_final$end_time))    # all FALSE not NULL


# trip duration
table(is.na(tripb20_data_final$tripduration))  # all FALSE not NULL
summary(tripb20_data_final$tripduration)

table(tripb20_data_final$tripduration >= 24*60*60)   # 3360


# recalculate trip duration
check_tripduration <- 
  tripb20_data_final %>% 
  mutate(
    trip_length = as.numeric(difftime(end_time, start_time))
  )


table(check_tripduration$tripduration 
      != check_tripduration$trip_length)      # approximately 50% different


# station id
table(is.na(tripb20_data_final$from_station_id))   # all FALSE not NULL
table(is.na(tripb20_data_final$to_station_id))     # all FALSE not NULL


length(unique(c(tripb20_data_final$from_station_id,
              tripb20_data_final$to_station_id)))


min(tripb20_data_final$from_station_id)
min(tripb20_data_final$to_station_id)

max(tripb20_data_final$from_station_id)
max(tripb20_data_final$to_station_id)


# check if any station id not in station data      # 47 not in station data
table(!unique(unique(tripb20_data_final$from_station_id),
             unique(tripb20_data_final$to_station_id))
      %in% c(station_data$id))


# station name
table(is.na(tripb20_data_final$from_station_name))   # all FALSE not NULL
table(is.na(tripb20_data_final$to_station_name))     # all FALSE not NULL


length(unique(c(tripb20_data_final$from_station_name,
              tripb20_data_final$to_station_name)))


# check if any station name not in station data      # 90 not in station data
table(!unique(unique(tripb20_data_final$from_station_name),
              unique(tripb20_data_final$to_station_name))
      %in% c(station_data$name))


# usertype
table(is.na(tripb20_data_final$usertype))           # all FALSE not NULL
table(tripb20_data_final$usertype)
prop.table(table(tripb20_data_final$usertype)) * 100   # 74% subscribers


# gender
table(is.na(tripb20_data_final$gender))
prop.table(table(tripb20_data_final$gender)) * 100     # 74% male


# birth year
table(is.na(tripb20_data_final$birthyear))
summary(tripb20_data_final$birthyear)


table(tripb20_data_final$birthyear <= 1923)    # 6682


# check who lived for 100 or more year
# Maybe because of data entry errors?
abnormal_birthyear <- 
  tripb20_data_final %>% 
  filter(birthyear <= 1923)


# check if any subscribers dont have info abt gender, birthyear
table(tripb20_data_final$usertype == 'Subscriber'
      & is.na(tripb20_data_final$gender))              # 33064


table(tripb20_data_final$usertype == 'Subscriber'
      & is.na(tripb20_data_final$birthyear))         # 10515


# check if anyone have gender and birthyear but not subscribers
table(!is.na(tripb20_data_final$gender)
      & tripb20_data_final$usertype == 'Customer')


table(!is.na(tripb20_data_final$birthyear)
      & tripb20_data_final$usertype == 'Customer')



# add column start_date, end_date
tripb20_data_final <- 
  tripb20_data_final %>% 
  mutate(
    start_date = as.integer(format(as.Date(start_time), '%Y%m%d')),
    end_date = as.integer(format(as.Date(end_time), '%Y%m%d')),
    .before = 'start_time'
  )


# convert datetime
tripb20_data_final <- 
  tripb20_data_final %>% 
  mutate(
    start_time = format(start_time, '%Y-%m-%d %H:%M:%S'),
    end_time = format(end_time, '%Y-%m-%d %H:%M:%S')
  )


# select column to use
glimpse(tripb20_data_final)

tripb20_data_final <- 
  tripb20_data_final %>%
  select(-start_time_year, 
         -end_time_year,
         -filename) %>% 
  relocate(start_date,
           end_date,
           start_time,
           end_time,
           .before = 'tripduration')



# 9. load to PostgreSQL ----------------------------------
# PS: ONLY RUN ONCE

# station data 
# dbWriteTable(con, "d_station", station_data)


# trip data since 2020
# dbWriteTable(con, "f_trips2020", trips20_data)


# trip data before 2020
# dbWriteTable(con, "f_tripb2020", tripb20_data_final)

# Note: go to postgresql to set up data type and constaints after load



# 10. load to SQLite -----------------------------------
# PS: Don't use as it takes too long to query 
# PS: ONLY RUN ONCE


# create table for station data
# PS: ONLY RUN ONCE
# dbExecute(con_sqlite,
#           "CREATE TABLE D_Station (
#               id           INTEGER     NOT NULL,
#               name         TEXT        NOT NULL,
#               latitude     REAL        NOT NULL,
#               longitude    REAL        NOT NULL,
#               dpcapacity   INTEGER,
#               landmark     INTEGER,
#               city         TEXT,
#               date_created INTEGER (8),
#               time_created TEXT,
#               update_date  INTEGER (8) NOT NULL,
#               CURRUPDATE   TEXT(1)        NOT NULL,
#               PRIMARY KEY (id, update_date)
#           )"
# )


# load station data
# ONLY RUN ONCE, if run multiple then append same data to the table
# dbAppendTable(con_sqlite, 'D_Station', station_data)



# create table for trip since 2020
# RUN ONLY ONCE
# dbExecute(con_sqlite,
#           "CREATE TABLE F_TripS2020 (
#     ride_id         TEXT   PRIMARY KEY  NOT NULL,
#     rideable_type   TEXT,
#     start_date      INTEGER (8) NOT NULL,
#     end_date        INTEGER (8) NOT NULL,
#     started_at     TEXT    NOT NULL,
#     ended_at     TEXT      NOT NULL,
#     ride_length   TEXT     NOT NULL,
#     start_station_name     TEXT,
#     start_station_id         INTEGER,
#     end_station_name  TEXT,
#     end_station_id     INTEGER,
#     start_lat  REAL       NOT NULL,
#     start_lng  REAL       NOT NULL,
#     end_lat REAL,
#     end_lng REAL,
#     member_casual TEXT    NOT NULL
# )"
# )


# load trip data since 2020
# ONLY RUN ONCE, if run multiple then append same data to the table
# dbAppendTable(con_sqlite, 'F_TripS2020', trips20_data)



# create table for trip before 2020
# RUN ONLY ONCE
# dbExecute(con_sqlite,
#           "CREATE TABLE F_TripB2020 (
#     trip_id         INTEGER   PRIMARY KEY  NOT NULL,
#     bikeid          INTEGER,
#     start_date      INTEGER (8),
#     end_date        INTEGER (8),
#     start_time          TEXT,
#     end_time            TEXT,
#     tripduration        INTEGER,
#     from_station_id     INTEGER,
#     from_station_name   TEXT,
#     to_station_id     INTEGER,
#     to_station_name  TEXT,
#     usertype  TEXT,
#     gender  TEXT,
#     birthyear INTEGER
# )"
# )


# load trip data before 2020
# ONLY RUN ONCE, if run multiple then append same data to the table
# dbAppendTable(con_sqlite, 'F_TripB2020', tripb20_data_final)


