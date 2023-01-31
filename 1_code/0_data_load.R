# Version 20221019


# set up ---------------------------------------------

# packages
library(tidyverse)
library(lubridate)
library(sqldf)
library(janitor)
library(readxl)
library(data.table)
library(readxl)
library(DBI)
library(RSQLite)
library(hms)


# folder 
folder_data <- '2_data'
folder_input <- '3_input'
folder_ouput <- '4_output'
folder_db <- '5_dbsqlite'


# # create folder extract data
# PS: RUN ONLY ONCE
# dir.create(file.path(folder_data, 'extract_data'))

 
# folder extract data path
folder_extractdata <-
  paste0(folder_data, '/', 'extract_data')


# connect SQLite
# PS: new database will be created if the bike db does not exist
con <- 
  dbConnect(SQLite(), 
            paste0(folder_db, '/bike.sqlite'))



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
# PS: compare with files in folder data
sort(unique(trips20_data$filename))

# check rideable type
addmargins(table(trips20_data$rideable_type))
prop.table(table(trips20_data$rideable_type)) * 100

# check member type
addmargins(table(trips20_data$member_casual))
prop.table(table(trips20_data$member_casual)) * 100


# check if any NA station
addmargins(table(is.na(trips20_data$start_station_id)))   
addmargins(table(is.na(trips20_data$end_station_id)))

addmargins(table(is.na(trips20_data$start_station_name)))
addmargins(table(is.na(trips20_data$end_station_name)))

addmargins(table(is.na(trips20_data$start_lat)))   # no NA
addmargins(table(is.na(trips20_data$start_lng)))   # no NA

addmargins(table(is.na(trips20_data$end_lat)))   
addmargins(table(is.na(trips20_data$end_lng)))   


# PS: check on station will be done later, after rbind with the leftover data



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


# function to read headers
read.header <- function(filename){
  
  data <- 
    colnames(read.csv2(file.path(folder_extractdata, filename))) %>%  # only import the column header in one column
    as.data.frame() %>% 
    rename(header = '.') %>% 
    mutate(filename = basename(filename))
  
  return(data)
  
}


# import data file header
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
table(tripb20_header$num_separator)



# 3. import trip before 2020 ---------------------------------------

# filter headers that have the same num separator (11)
tripb20_same_header <- 
  tripb20_header %>% 
  filter(num_separator == 11)


# check header char length
table(tripb20_same_header$num_char)


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


# check filename
sort(unique(tripb20_data$filename))
table(is.na(tripb20_data$filename))



# data cleansing ---

# check column birthday if it is year only
min(tripb20_data$birthday[!is.na(tripb20_data$birthday)])
max(tripb20_data$birthday[!is.na(tripb20_data$birthday)])

# check if any case has values for both birthday and birthyear
table(!is.na(tripb20_data$birthday), 
      !is.na(tripb20_data$birthyear))


# combine 2 columns birthday, birth year
tripb20_data <- 
  tripb20_data %>% 
  mutate(
    birthyear = case_when(is.na(birthyear) ~ birthday,
                          TRUE ~ birthyear)
  ) %>% 
  select(-birthday)


# check variable distribution
addmargins(table(tripb20_data$usertype))
addmargins(table(is.na(tripb20_data$gender)))
addmargins(table(tripb20_data$gender))
addmargins(table(is.na(tripb20_data$birthyear)))


# check date format
check_startdate <- 
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


# check time adjustment
glimpse(tripb20_data)


# check if any NA
table(is.na(tripb20_data$start_time_adj))
table(is.na(tripb20_data$end_time_adj))


# check distribution by date
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



# 4. import data with different header ---------------------------------------

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
table(Q1_2018$start_time_year)
table(Q1_2018$end_time_year)


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
table(Q2_2019$start_time_year)
table(Q2_2019$end_time_year)


# import Q1_2020 (same data frame as trips20 trip)
Q1_2020 <- 
  read_csv(file.path(folder_extractdata, 'Divvy_Trips_2020_Q1.csv')) %>% 
  clean_names() %>% 
  mutate(
    filename = basename(file.path(folder_extractdata, 'Divvy_Trips_2020_Q1.csv'))
  )


# check if Q1_2020 data already in trips20 trip data
table(Q1_2020$ride_id %in% c(trips20_data$ride_id))

# check dates
min(Q1_2020$started_at)
max(Q1_2020$started_at) 



# 5. rbind data ---------------------------------------

# check minDate, maxDate of data since 2020
min(trips20_data$started_at)
max(trips20_data$ended_at)

# check col name before rbind
glimpse(trips20_data)
glimpse(Q1_2020)


# rbind data since 2020 
trips20_data <- 
  trips20_data %>% 
  rbind(Q1_2020 %>% 
          select(names(trips20_data)))


# check data before 2020 
glimpse(tripb20_data_adj)
glimpse(Q1_2018)
glimpse(Q2_2019)


# rbind data before 2020
tripb20_data_final <- 
  tripb20_data_adj %>% 
  rbind(
    Q1_2018 %>% select(names(tripb20_data_adj)),
    Q2_2019 %>% select(names(tripb20_data_adj))
  )


# remove duplicate if any
tripb20_data_final <- 
  tripb20_data_final %>% 
  distinct()



# 6. import stations ---------------------------------------------

# list station
station_files <- 
  list.files(folder_extractdata, pattern = 'Divvy_Stations_')


# filter only csv files
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


# check unique station filename
sort(unique(station_data$filename))


# check na columns
table(station_data$filename, is.na(station_data$date_created))
table(station_data$filename, is.na(station_data$online_date))
table(station_data$filename, is.na(station_data$city))
table(station_data$filename, is.na(station_data$x8))  # empty 


# cleansing station data
station_data <- 
  station_data %>% 
  mutate(
    # merge online_date and date_created
    online_date = case_when(is.na(online_date) ~ date_created,
                            TRUE ~ online_date)
  ) %>% 
  select(-x8, -date_created)


# check if any date is na
table(station_data$filename, 
      is.na(station_data$online_date))


# list excel file
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
            Q1Q2_2014_station)


# check date format
check_date_station <- 
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


# # create D_station table
# # PS: ONLY RUN ONCE
# dbExecute(con,
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
# dbAppendTable(con, 'D_Station', station_data)



# 7. load trip data since 2020 -------------------------------------------------

# check duplicate before load
table(duplicated(trips20_data$ride_id))


# reason for duplicate: duplicate with start time > end time
# calculate ride length
trips20_data <- 
  trips20_data %>% 
  mutate(
    ride_length = as_hms(difftime(ended_at, started_at)),
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


# # export duplicated trips20 data
# fwrite(trips20_duplicate,
#        file.path(folder_ouput, 'dup_trips20_data.csv'),
#        na = '', row.names = FALSE)


# filter out duplicate 
trips20_data <- 
  trips20_data %>% 
  filter(!(Is_duplicate == TRUE
         & ride_length > -1000000))


# check duplicate again
table(duplicated(trips20_data$ride_id))


# add dateid
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
    ride_length = format(ride_length, '%H:%M:%S')
  )


# select columns to use
glimpse(trips20_data)

trips20_data <- 
  trips20_data %>% 
  select(-filename,
         -Is_duplicate) 


# # create table in bike db
# # RUN ONLY ONCE
# dbExecute(con,
#           "CREATE TABLE F_TripS2020 (
#     ride_id         TEXT   PRIMARY KEY  NOT NULL,
#     rideable_type   TEXT,
#     start_date      INTEGER (8),
#     end_date        INTEGER (8),
#     started_at     TEXT,
#     ended_at     TEXT,
#     ride_length   TEXT,
#     start_station_name     TEXT,
#     start_station_id         INTEGER,
#     end_station_name  TEXT,
#     end_station_id     INTEGER,
#     start_lat  REAL,
#     start_lng  REAL,
#     end_lat REAL,
#     end_lng REAL,
#     member_casual TEXT
# )"
# )


# # load trip data since 2020
# # ONLY RUN ONCE, if run multiple then append same data to the table
# dbAppendTable(con, 'F_TripS2020', trips20_data)



# 8. load trip data before 2020 ---------------------------------

# check before load
glimpse(tripb20_data_final)

min(tripb20_data_final$trip_id)
max(tripb20_data_final$trip_id)

min(tripb20_data_final$bikeid)
max(tripb20_data_final$bikeid)

min(tripb20_data_final$tripduration)
max(tripb20_data_final$tripduration)


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


# check duplicate
table(duplicated(tripb20_data_final$trip_id))
table(duplicated(tripb20_data_final$bikeid))


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


# # create table for quarter data in bike db
# # RUN ONLY ONCE
# dbExecute(con,
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


# # load tripb20 data
# # ONLY RUN ONCE, if run multiple then append same data to the table
# dbAppendTable(con, 'F_TripB2020', tripb20_data_final)



# 9. check station data from trips20 and tripb20 data ----------------------

# check trips20 data ----
glimpse(trips20_data)

# extract station from trips20 data
trips20_station <- 
  trips20_data %>% 
  select(
    start_station_id,
    start_station_name) %>% 
  rename(
    id = start_station_id,
    name = start_station_name
  ) %>% 
  rbind(
    trips20_data %>% 
      select(
        end_station_id,
        end_station_name) %>% 
      rename(
        id = end_station_id,
        name = end_station_name)
  ) %>% 
  distinct() %>% 
  arrange(id, name)


# check unique id and name
length(unique(trips20_station$id))
length(unique(trips20_station$name))

# chech how many id, name not in station data
addmargins(table(!unique(trips20_station$id) %in% unique(station_data$id)))
addmargins(table(!unique(trips20_station$name) %in% unique(station_data$name)))


# view id and name not in station data
trips20_station <- 
  trips20_station %>% 
  left_join(station_data %>% 
              select(id, name, update_date) %>% 
              filter(update_date == 20171231) %>% 
              mutate(Is_duplicate = TRUE),
            by = c('id', 'name')) %>% 
  left_join(station_data %>% 
              filter(update_date == 20171231) %>% 
              select(id, name) %>% 
              rename(station_id = id),
            by = 'name') %>% 
  left_join(station_data %>% 
              filter(update_date == 20171231) %>% 
              select(id, name) %>% 
              rename(station_name = name),
            by = 'id')


# export trips20_station for manual check
fwrite(trips20_station,
       file.path(folder_ouput, 'trips20_station.csv'),
       na = '', row.names = FALSE)


# extract station from tripb20 data ----
tripb20_station <- 
  tripb20_data_adj %>% 
  select(from_station_id, 
         from_station_name) %>% 
  rename(
    id = from_station_id,
    name = from_station_name
  ) %>% 
  rbind(
    tripb20_data %>% 
      select(to_station_id, 
             to_station_name) %>% 
      rename(
        id = to_station_id,
        name = to_station_name
      )
  ) %>% 
  distinct() %>% 
  arrange(id, name)


# export for manual check
fwrite(tripb20_station,
       file.path(folder_ouput, 'tripb20_station.csv'),
       na = '', row.names = FALSE)


# check na
table(is.na(tripb20_station$id))
table(is.na(tripb20_station$name))


table(tripb20_station$id %in% trips20_station$id)
table(tripb20_station$name %in% trips20_station$name)


