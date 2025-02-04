#!/usr/bin/Rscript
# take cutting efficiency for each site, labeled reads on each site, bedGraph for labeled reads
# then calculate labeled reads for each DSB, and total studied DSBs
# Author: Yingjie Zhu yizhu@utmb.edu

Args <- commandArgs()

# load library

script.basename <- dirname(Args[4])
script.dir <- sub("--file=", "",script.basename)
source(paste(script.dir,"R/lib_qDSB-seq.R",sep="/"))

#############################################
###### pass arguments from command line #####
#############################################

library("optparse")

option_list = list(
  make_option(c("-s", "--sample"), type="character", default="unknown", 
              help="sample name [default = %default]", metavar="character"),
  make_option(c("-e", "--enzyme"), type="character", default="unknown", 
              help="enzyme name [default = %default]", metavar="character"),
  make_option(c("-g", "--group"), type="character", default="unknown", 
              help="group name [default = %default]", metavar="character"),
  make_option(c("-m", "--fenzyme"), type="character", default=NULL, 
              help="cutting efficiencies of enzyme 
              [TABLE FILE: 
                  Chr Start End Name Total_reads Uncut_reads Left_reads Right_reads Summit_reads Cutting_efficiency Min Max]", metavar="character"),
  make_option(c("-b", "--fbg"), type="character", default=NULL, 
              help="cutting efficiencies of background 
              [TABLE FILE: 
                  Chr Start End Name Total_reads Uncut_reads Left_reads Right_reads Summit_reads Cutting_efficiency Min Max]", metavar="character"),
  make_option(c("-r", "--renzyme"), type="character", default=NULL, 
              help="labeled reads on enzyme cutting sites 
              [TABLE FILE: 
                  Chr     BED_start       BED_end Name    Start   End     Region_size     Total_reads     Perc_total
                      Plus_reads      Perc_plus       Minus_reads     Perc_minus      Peak_reads      Perc_peak_reads Plus_peak_reads Perc_plus_peak_reads    
                      Minus_peak_reads       Perc_minus_peak_reads   Summit_reads    Perc_summit_reads]", metavar="character"),
  make_option(c("-d", "--rstudied"), type="character", default="empty", 
              help="labeled reads on studied positions [bedGraph FILE: Chr start end coverage, NOTE: no header in bedGraph file, alternative in -d, -y, -z]", metavar="character"),
  make_option(c("-y", "--rstudiedtotal"), type="double", default=-1, 
              help="the total number of labeled reads [optional, alternative in -d, -y, -z]", metavar="character"),
  make_option(c("-z", "--rstudiedlist"), type="character", default="empty", 
              help="A list of the number of labeled reads, one column [optional, alternative in -d, -y, -z]", metavar="character"),
  make_option(c("-t", "--type"), type="integer", default=2, 
              help="type of DSBs, 1 for 1-ended, 2 for 2-ended, [default = %default]", metavar="character"),
  make_option(c("-c", "--coverage"), type="integer", default=100, 
              help="minimum of coverage for gDNA reads on cutting site, [default = %default]", metavar="character"),
  make_option(c("-n", "--fmin"), type="double", default=0, 
              help="minimum of cutting efficiency used for quantification, [default = %default]", metavar="character"),
  make_option(c("-a", "--fmax"), type="double", default=1, 
              help="maximum of cutting efficiency used for quantification, [default = %default]", metavar="character"),
  make_option(c("-p", "--prefix"), type="character", default="output", 
              help="output prefix, [default = %default]", metavar="character"),
  make_option(c("-u", "--summit"), type="integer", default=0, 
              help="use summit of left and right side of cutting site to calculate cutting efficiency, set to 1, [default = %default]", metavar="character"),
  make_option(c("-x", "--mixprop"), type="double", default=1, 
              help="proportion of cut cells, [default = %default]", metavar="character")
)

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$fenzyme)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}
 
print(opt)

sample_name <- opt$sample
enzyme_name <- opt$enzyme
group       <- opt$group
# table of cutting efficiency: 
# Chr Start End Name Total_reads Uncut_reads Left_reads Right_reads Summit_reads Cutting_efficiency Min Max
table_fcut  <- opt$fenzyme
# table of cutting efficiency of genomic background: 
# Chr Start End Name Total_reads Uncut_reads Left_reads Right_reads Summit_reads Cutting_efficiency Min Max
table_fbg   <- opt$fbg
# table of labeled reads on restrictive sites: 
# Chr BED_start BED_end Name Start End Region_size Total_reads Perc_total Plus_reads Perc_plus
#  Minus_reads Perc_minus Peak_reads Perc_peak_reads Plus_peak_reads Perc_plus_peak_reads Minus_peak_reads Perc_minus_peak_reads Summit_reads Perc_summit_reads
table_labeled_reads_on_enz     <- opt$renzyme
# bedGraph contains no. of labeled reads
bedGraph_labeled_reads_studied <- opt$rstudied
# total number of labled reads
total_labeled_reads_studied <- opt$rstudiedtotal
# a list of the number of labled reads
list_labeled_reads_studied <- opt$rstudiedlist
# an index for 1-DSB and 2DSB calculation, if 1-DSB the index is 2, if 2-DSB it is 1
index_12DSB <- opt$type
# minimum of coverage for gDNA reads on cutting site
gcov         <- opt$coverage
# minimum of cutting efficiency used to quantify
fcut_min     <- opt$fmin
# maximum of cutting efficiency used to quantify
fcut_max     <- opt$fmax
# output prefix
prefix   <- opt$prefix
# use summit of left and right side of cutting site to calculate cutting efficiency, set to 1
summit   <- opt$summit
# proportion of cut cells
mixprop  <- opt$mixprop


#############################################

# load data

 # enzyme fcut
data_fcut <- read.table(table_fcut,header=T)
 # background fcut
data_fbg  <- read.table(table_fbg,header=T)
 # Reads on cutting sites
data_labeled_reads_on_enz   <- read.table(table_labeled_reads_on_enz,header=T)

 # Reads on studied DSBs
if( bedGraph_labeled_reads_studied != "empty" ){
  data_labeled_reads_studied <- read.table(bedGraph_labeled_reads_studied)
}else if( total_labeled_reads_studied > -1 ){
  data_labeled_reads_studied <- data.frame(V1="chr",V2="1",V3="1",V4=total_labeled_reads_studied)
}else if( list_labeled_reads_studied != "empty" ){
  data_labeled_reads_studied <- read.table(list_labeled_reads_studied)
  data_labeled_reads_studied <- data.frame(V1="chr",V2="1",V3="1",V4=data_labeled_reads_studied$V1)
}

# remove unnecessary columns from data_fcut

drops <- c("Min","Max","Cutting_efficiency_rmbg")
data_fcut <- data_fcut[, !(names(data_fcut) %in% drops)]

# replace column names

colnames(data_fcut)[6] <- "Uncut_reads"
colnames(data_fcut)[10] <- "Cutting_efficiency"
colnames(data_fbg)[6] <- "Uncut_reads"
colnames(data_fbg)[10] <- "Cutting_efficiency"

# calculate fbg

fbg <- calc_fbg(data_fbg)
fbg_sd <- calc_fbg_sd(data_fbg)

# calculate fcut by site

data_fcut$Cutting_efficiency <- calc_fcut_by_site(data_fcut,summit)
data_fcut[is.na(data_fcut)] <- 0
data_fcut$Cutting_efficiency_rmbg <- data_fcut$Cutting_efficiency - fbg
data_fcut$Cutting_efficiency_rmbg[data_fcut$Cutting_efficiency_rmbg<0] <- 0
data_fcut$Cutting_efficiency_rmbg[data_fcut$Cutting_efficiency==1]     <- 1

# add labeled enzyme reads to fcut

data_fcut$labeled_reads = data_labeled_reads_on_enz$Total_reads

# output data_fcut to *.fcut.txt

 # write.table(data_fcut,paste(prefix,"fcut.txt",sep="."),quote=FALSE,sep="\t",col.names=T,row.names=F)

# remove outliers based on gDNA coverage, cutting efficiency to reduce bias 

 # filter fcut
 #data_fcut <- filter_fcut_outliers_q10_q90(data_fcut)
 # low coverage
data_fcut <- filter_fcut_low_coverage(data_fcut,gcov)
 # fcut = 0
data_fcut <- data_fcut[data_fcut$Cutting_efficiency_rmbg > 0,]
 # fcut thresholds
data_fcut <- data_fcut[data_fcut$Cutting_efficiency_rmbg >= fcut_min & data_fcut$Cutting_efficiency_rmbg <= fcut_max,]
 # labeled reads outliers
 #data_fcut <- filter_fcut_outliers_labeled_reads(data_fcut)
 # write.table(data_fcut,paste(prefix,"fcut.filtered.txt",sep="."),quote=FALSE,sep="\t",col.names=T,row.names=F)

# count no. of cutting sites

nsites <- nrow(data_fcut)

# calculate fcut

fcut <- calc_fcut(data_fcut,summit)
 # remove fbg from fcut
fcut_rmbg <- fcut - fbg

# calculate standard deviaiton of fcut

fcut_sd <- calc_fcut_sd(data_fcut)

if( nsites == 1 ){ # calcuate fcut by Poisson distribution and fbg_sd
    fcut_sd_poisson <- calc_fcut_poisson(data_fcut,summit)
    
    fcut_sd = round(sqrt(fcut_sd_poisson**2+fbg_sd**2),6)
}

# count sum of labeled reads from DSBs
sum_of_labeled_reads_studied <- sum(abs(data_labeled_reads_studied$V4))
print(sum_of_labeled_reads_studied)

# count sum of labeled reads from enzymes

sum_of_labeled_reads_enz <- sum(data_fcut$labeled_reads) 

# calculate DSBs

index_12DSB   <- ifelse(index_12DSB==1,2,1)
total_DSBs    <- round(calc_DSBs(sum_of_labeled_reads_studied,sum_of_labeled_reads_enz,fcut_rmbg,nsites,index_12DSB,mixprop),6)
total_DSBs_sd    <- round(calc_DSBs(sum_of_labeled_reads_studied,sum_of_labeled_reads_enz,fcut_sd,nsites,index_12DSB,mixprop),6)

# calculate DSBs at studied positions

DSBs_perM <- round(calc_DSBs_perM(data_labeled_reads_studied$V4,sum_of_labeled_reads_enz,fcut_rmbg,nsites,index_12DSB,mixprop),6)

df_DSBs_perM <- data.frame(data_labeled_reads_studied$V1,data_labeled_reads_studied$V2,data_labeled_reads_studied$V3,DSBs_perM)

write.table(df_DSBs_perM,paste(prefix,"DSBs_perM.bedGraph",sep="."),quote=FALSE,sep="\t",col.names=F,row.names=F)


# induced DSBs

induced_DSBs <- fcut_rmbg * nsites


############################################################
####### Calculating DSBs by individual cutting sites #######
############################################################


# combine data

#combined_data <- data.frame(
#  sample = sample_name,
#  enzyme = enzyme_name,
#  group = group,
#  sum_of_reads_enz    = sum_of_labeled_reads_enz,
#  sum_of_reads_studied = sum_of_labeled_reads_studied,
#  reads_enz = data_fcut$labeled_reads,
#  fcut      = data_fcut$Cutting_efficiency_rmbg,
#  fcut_sd   = fcut_sd,
#  DSBs = total_DSBs,
#  DSBs_sd = total_DSBs_sd,
#  induced_DSBs=induced_DSBs
#)

# write.table(combined_data,paste(prefix,"combined_data.txt",sep="."),quote=FALSE,sep="\t",col.names=T,row.names=F)

# calculate DSBs

DSBs_by_site <- round((sum_of_labeled_reads_studied * data_fcut$Cutting_efficiency_rmbg * index_12DSB * mixprop ) / data_fcut$labeled_reads,6)

DSBs_by_site[!is.finite(DSBs_by_site)] <- 0


# store results of DSBs by site

results <- data.frame(chr=data_fcut$Chr,start=data_fcut$Start,end=data_fcut$End,fcut=data_fcut$Cutting_efficiency_rmbg,reads_enz=data_fcut$labeled_reads,DSBs_by_site=DSBs_by_site)

# write.table(results,paste(prefix,"DSBs.txt",sep="."),quote=FALSE,sep="\t",col.names=T,row.names=F)

##############################################
################### summary ##################
##############################################

# fcut calculated by average of all individual sites

fcut_by_site_avg <- round(mean(data_fcut$Cutting_efficiency_rmbg),6)

fcut_by_site_sd  <- round(sd(data_fcut$Cutting_efficiency_rmbg),6)

# DSBs averaged by sites

DSBs_avg         <- round(mean(results$DSBs_by_site),6)

DSB_sd           <- round(sd(results$DSBs_by_site),6)

# calculate correlation between cutting efficiency and labeled reads

cor_fcut_labeled_reads <- round(cor(data_fcut$Cutting_efficiency_rmbg,data_fcut$labeled_reads,method="pearson"),3)

summary <- c(
  sample_name,
  group,
  enzyme_name,
  sum_of_labeled_reads_enz,
  sum_of_labeled_reads_studied,
  fcut_rmbg,
  total_DSBs,
  DSB_sd,
  total_DSBs_sd,
  nsites,
  cor_fcut_labeled_reads
)

names(summary) <- c(
  "sample_name",
  "group",
  "enzyme_name",
  "reads_from_enzyme",
  "reads_from_studied_DSBs",
  "fcut_rmbg",
  "DSBs",
  "DSBs_sd_by_site",
  "DSBs_sd_by_fcut",
  "nsites",
  "cor_fcut_labeled_reads"
)

write.table(t(summary),paste(prefix,"DSBs.summary.txt",sep="."),quote=FALSE,sep="\t",col.names=T,row.names=F)
