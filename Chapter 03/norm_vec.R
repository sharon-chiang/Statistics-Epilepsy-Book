# TO run  this script from the command line, use the following at the
#  linux prompt
#cat norm_vec.R | R --slave --args seed.txt --no-save
#Note:  seed.txt is the name of your seed file.  You must be in the
#  directory where the seed is and then a seed_norm file will be
#  created automatically

seed_name=commandArgs()[4]
data=read.table(seed_name)


mn_dat=mean(data[[1]])
sd_dat=sd(data[[1]])

data_std=(data-mn_dat)/sd_dat

save_name=sprintf('norm_%s', seed_name)


write.table(data_std, save_name, row.names=FALSE,col.names=FALSE, na="NaN")
