#install.packages('R.matlab')
#install.packages("lubridate")
#install.packages("jsonlite")
#install.packages('dplyr')
#install.packages('microbenchmark')
#install.packages('ggplot2')
#install.packages(stringi)


# Load installed packages
library(R.matlab)
library(lubridate)
library(jsonlite)
library(dplyr)
library(stringi)
library(stringr)
library(microbenchmark)
library(ggplot2)

########################################################################################################################################################################
# Look up help for read.csv
?read.csv()

### Load in a single file

# Initialize all the required paths (working directory should be set to Ch1_data)
data_path = "Ch1_data/"
single_patient_folder = "Patient_1/"
filename = "metadata.csv"

# Concatenate all directories (as strings)
file_path = paste(data_path, single_patient_folder, filename, sep="")

# Read in the csv file for a single patient
metadata_patient1 <- read.csv(file_path, header = TRUE, sep = ",")

### Write a for loop to read all patients

# Initialize a list with all patient's folders
patients_list = c()
patient_size = 20
for (i in 1:patient_size){
  patients_list[i] = paste('Patient_', i, sep="")
  
}

# Initiliaze the vector where the patient's metdata will be stored
df_metadata = data.frame()

# Get the metadata for all patients
for (i in 1:length(patients_list)){
  # Get the filepath for each patient
  file_path = paste(data_path, patients_list[i], '/', filename, sep="")
  
  # Load the patient's metadata
  metadata_current_patient <- read.csv(file_path, header = TRUE, sep = ",")
  
  # Concatenate the dataframes
  df_metadata = rbind(df_metadata, metadata_current_patient)
}  


# Initialize the directory containing the files and provide the filenames within each folder
files <- dir(data_path, recursive = TRUE, full.names = TRUE, pattern = "metadata.csv$")

# Iteratively load all csv files as a list
metadata_list <- lapply(files, read.csv)

# Convert the metadata to a dataframe
metadata <- data.frame(matrix(unlist(metadata_list), nrow=length(metadata_list), byrow=TRUE), stringsAsFactors=FALSE)

# Assign the appropriate column names
names(metadata) <- names(unlist(metadata_list[1]))

# Explore the two datasets and compare
str(metadata)
str(df_metadata)

# Remove one of the indetical dataframes
rm(df_metadata)

# Read in the json files
# Create a function for reading and processing .json files
read_json_files <- function(file_list){
  
  # Load json data
  rdata <- read_json(file_list, simplifyVector = TRUE)
  seizure_data <- fromJSON(rdata)
  
  return(seizure_data)
}

# Read in all json files
files <- dir(data_path, recursive = TRUE, full.names = TRUE, pattern = "sdata.json$")
data <- lapply(files, read_json_files)

# Convert the list of dataframes to a dataframe
seizure_data = bind_rows(data)

# Read in .mat timedata file and convert to time data
files <- dir(data_path, recursive = TRUE, full.names = TRUE, pattern = "timedata.mat$")
timedata <- lapply(files, readMat)

# Check the datatype - list of strings
typeof(timedata)

# Unlist timedata to extract the characters
timedata <- unlist(timedata)

# Convert the strings to time stamps (hourly markers) usung lubridate
timedata <- ymd_hms(timedata, tz="UTC")

# Add the time stamps as a new column
seizure_data$hourly_markers = timedata

# Remove timestamp variable to free up memory
rm(timedata)
rm(data)

# Explore the metadata and seizure_data dataframes
str(metadata)
str(seizure_data)

# Convert patient_id to match format in metadata. Only for pedagogical purposes. Later we show how to convert both
# to integers. 
seizure_data$patient_id <- paste0("Patient_", seizure_data$patient_id)

# Join the metadata into the dataframe
seizure_data <- merge(seizure_data, metadata, by.x = 'patient_id', by.y = 'ID', all.x = TRUE, all.y = FALSE)

# Get characteristics of the data frame - # cols x # rows; date types
# We have a combination of int, dates and characters
str(seizure_data)
dim(seizure_data)

# Convert age and patient_id columns from strings to integers
seizure_data$Age <- as.numeric(seizure_data$Age)

# Convert all column names to lower case
names(seizure_data) <- tolower(names(seizure_data))

# Gender seems to have "FALSE"; explore the unique values of the gender column; the unique values are "FALSE" and "M". Indeed the csv file had the genders correct as "F" and "M"
unique(seizure_data$gender)

# Compare gsub vs stri_replace_all_fixed
microbenchmark(gsub("FALSE", "F", seizure_data$gender), stri_replace_all_fixed(seizure_data$gender, "FALSE", "F"))

# Convert FALSE to F; replace the string values using the function stri_replace_all_fixed from the stringi package. An alternative to that is to use gsub. However, stri_replace_all_fixed can perform faster especially for larger datasets
seizure_data$gender <- stri_replace_all_fixed(seizure_data$gender, "FALSE", "F")

# Change column names
col_names <- colnames(seizure_data)
colnames(seizure_data)[col_names == "na."] <- 'first_visit_date'

# Explore the data to look for missing values
unique(seizure_data$na..1)

# Drop the column using the subset operator
seizure_data <- seizure_data[, -which(names(seizure_data) == "na..1")]
colnames(seizure_data)

# Define a function for displaying all columns that have NA
display_na <- function(df, threshold){
  # Params:
  # df: data.frame - data frame for which the NA percentage is to be calculated
  # threshold: double - value between 0 and 1 indicating that columns with NA 
  #                     proportion higher than threshold should be returned
  
  # Return:
  # named vector with all columns that have more than threshold proportion of values with NA
  na_percent_per_column <- round(colMeans(is.na(df)),3)  
  return(na_percent_per_column[na_percent_per_column > threshold])
}

# It looks like the dataframe has 3 variables that have 10% missing values. 
display_na(seizure_data, 0.01)

# If NA is present in any row of the entire dataframe drop that row
any_na_drop = na.omit(seizure_data)

# Complete case removal - allows for subseting specific columns when deciding whether to drop if NA is present. 
# In this case we notice that the two dataframes are identical size. This implies that any observation that had NAs in iea_lead1 and iea_lead2 (columns 3 and 4) also has NA in le (column 2)
partial_na_drop = seizure_data[complete.cases(seizure_data[, 2:4]),]

# Fill with median in place instead of dropping. Here we definie two functions that will aid in filling in missing values
# Create a function for filling NAs with median
median_noNA <- function(df){
  # Return the median value of x removing NA
  return(replace(df, is.na(df), median(df, na.rm = TRUE)))
}

# Execute the function on each row in the dataframe
replace_na <- function(df, impute_function){
  
  # Get only the numeric columns 
  is_numeric <- sapply(df, is.numeric)
  
  # Impute NA inplace with the median
  clean_df <- replace(df, is_numeric, lapply(df[is_numeric], impute_function))
  return(clean_df)
}

# Impute with median
seizure_data_median_impute = replace_na(seizure_data, median_noNA)

# Mean imputation function
mean_noNA <- function(df){
  # Return the mean value of x removing NA
  return(replace(df, is.na(df), mean(df, na.rm = TRUE)))
}

# Impute with mean
seizure_data_mean_impute = replace_na(seizure_data, mean_noNA)

# A more succint way of doing it using built in R functions
seizure_data <- seizure_data %>% 
  mutate_at(vars(c(le, iea_lead1, iea_lead2)), ~ifelse(is.na(.), median(., na.rm = TRUE), .))


# Check again to make sure that there are no NA
display_na(seizure_data, 0.01)

# Add the two leads and use the aggregated variable. Drop the individual ones
seizure_data$iea_lead_agg = seizure_data$iea_lead1 + seizure_data$iea_lead2
seizure_data = subset(seizure_data, select = -c(iea_lead1,iea_lead2) )

# Built a histogram to explore the data - it looks like the majority of the seizure counts are near 0. We have a very left skewed histogram with very few observations having >10 seizures. Contributing to this may be the fact that each observation represents the number of seizures within a 1 hour window
pdf("./Documents/temp/github/le_histogram.pdf")
hist(seizure_data$le, main = "", xlab = "Long Episodes", ylab = "Density", freq=FALSE)
dev.off()

pdf("./Documents/temp/github/iea_lead_agg.pdf")
hist(seizure_data$iea_lead_agg, main = "", xlab = "Interictal Epileptiform Discharges", ylab = "Density", freq=FALSE)
dev.off()


# An alternative way to look at the seizure counts is to use summary - A quick look confirms what we observed via the histogram - most seizures within a 1 hour interval are 0. In fact even the 3rd quartile is 0 indicating that 75% of the observaitons have 0 seziures
summary(seizure_data$iea_lead_agg)

# Extract the dates from the time stamps
seizure_data$seizure_date <- as.Date(seizure_data$hourly_markers)

# Aggregate the seizures and spikes on daily level into a new dataframe
daily_seizures_spikes <- seizure_data %>%
  group_by(patient_id, seizure_date) %>%
  summarise(total_le = sum(le), total_iea_lead_agg = sum(iea_lead_agg))

pdf("./Documents/temp/github/daily_le_histogram.pdf")
hist(daily_seizures_spikes$total_le, main = "", xlab = "Long Episodes", ylab = "Density", freq=FALSE)
dev.off()

pdf("./Documents/temp/github/daily_iea_lead_agg.pdf")
hist(daily_seizures_spikes$total_iea_lead_agg, main = "", xlab = "Interictal Epileptiform Discharges", ylab = "Density", freq=FALSE)
dev.off()

# Look at the unique seizure focus values - there are 5
unique(seizure_data$seizure_foci) 

# Does each patient have each of the seizure foci - it looks like the seizure_focus is unique to each patient. Ask SHARON?
seizure_data %>%
  group_by(patient_id) %>%
  summarise(count = n_distinct(seizure_foci))

# Display all the patients that correspond to each seziure focus
aggregate(patient_id ~ seizure_foci, seizure_data, function(x) paste(unique(x), collapse = ", "))

# Convert the gender and seizure foci columns to factors
factor_cols <- c('gender', 'seizure_foci')
seizure_data[factor_cols] <- lapply(seizure_data[factor_cols], factor)

# Let's explore the time series component of the data
min(seizure_data$hourly_markers)
max(seizure_data$hourly_markers)
length(unique(seizure_data$hourly_markers))

# Do all patients have the same number of datapoints?
seizure_data %>%
  group_by(patient_id) %>%
  summarise(count = n_distinct(hourly_markers))

# Drop duplicate observations
seizure_data <- seizure_data[!duplicated(seizure_data), ]

# Patient 6
seizure_data_2017_patient_6 = seizure_data[seizure_data$patient_id == 'Patient_6', ]

# Let's plot the time series of the spikes; since the data is quite large and we have a lot of zeros we will just explore data between February 1st, 2017 and March 20th, 2017. We pick these time periods as they contain seizures and this can be useful for our later analysis
seizure_data_subset_2017_patient_6 = seizure_data_2017_patient_6[(seizure_data_2017_patient_6$hourly_markers > '2017-02-01 00:00:00 UTC') & (seizure_data_2017_patient_6$hourly_markers <= '2017-03-20 00:00:00 UTC'),]

# Create a plot for the spikes
pdf("./Documents/temp/github/hourly_seizure_spikes.pdf",  height = 8, width = 10)
spikes <- ggplot() +
  geom_line(data=seizure_data_subset_2017_patient_6, aes(x=hourly_markers, y=iea_lead_agg)) + 
  xlab("Date") + 
  ylab("Interictal Epileptiform Discharges") +
  theme(
    axis.text = element_text(size = 14),
    axis.title.x = element_text(size = 14),
    axis.title.y = element_text(size = 14)
  )

# Add the seizures as dots to the plot; it looks like a lot of the seizures are occurring on the upward cycle of a spike
spikes + geom_point(data=seizure_data_subset_2017_patient_6[seizure_data_subset_2017_patient_6$le > 0, ], aes(x=hourly_markers, y=iea_lead_agg), color='red')

dev.off()


