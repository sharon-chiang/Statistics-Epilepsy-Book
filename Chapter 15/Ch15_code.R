###########################
# Load required libraries
##########################
library(mrgsolve)
library(dplyr)
library(ggplot2)
library(gridExtra)

#############################
#### Simulation ############
#############################

#Compile model with mrgsolve

mod <- '

$PROB
1 cmt model - Simulation with sex on volume, genetics on clearance

$PARAM
KA = 3.17, // First order rate of absorption
SEX = 0, // 0 = Female; 1 = Male
SNP = 0, // 0 = Wild Type; 1 = Mutated
SEX_EFF = 1.45, // Effect of male sex on volume
SNP_EFF = 1.75 // Effect of SNP on clearance

$CMT DEPOT CENT // One compartment model with a depot compartment for oral dosing 

$GLOBAL
#define Cp (CENT/V) // Define central concentration (ug/mL)

$MAIN
F_DEPOT = 0.9; // Oral bioavailability

double TVV = THETA1 * pow(SEX_EFF,SEX); // Typical volume 
double TVCL = THETA2 * pow(SNP_EFF,SNP) ; // Typical clearance

double V = TVV*exp(ETA(1)); // Population volume
double CL = TVCL*exp(ETA(2)); // Population clearance

$THETA  
90 // Volume
2.15 // Clearance

$OMEGA
0.09 // BSV on V
0.09 // BSV on CL

$SIGMA
0.0225

$ODE
dxdt_DEPOT = -KA*DEPOT; // Absorption compartment
dxdt_CENT = KA*DEPOT - CL*Cp; // Central compartment

$CAPTURE
Cp, V, CL,SEX, SNP // Capture variables you want to report

'

modpop2 <- mcode("1cmt_sex_SNP",mod)

#Generate input data file for simulation
# Simulation of 500 individuals, with 40% males and 20% population having the SNP mutation
input_data <- data.frame(ID=c(1:500),
                       SEX = rbinom(500,1,0.4),
                       SNP = rbinom(500,1,0.2))

#Assume a dosing regimen of 500 mg given twice a day at steady state 
dosing <- ev(amt=500,ss=1,ii=12, addl=1)

#Generate simulation
set.seed(12323)
out <- modpop2 %>%
  Req(Cp,V,CL,SEX,SNP)%>% #Request variables in simulation output
  obsonly() %>% 
  idata_set(input_data)%>%
  mrgsim(events=dosing,end=24,delta=1,obsonly=TRUE) %>%
  as.data.frame()

#Add names to the indicator covariate variables
sim.out <- out %>%
  mutate(SEX_Name = if_else(SEX ==0,"FEMALE","MALE"),
         SNP_Name = if_else(SNP ==0,"WILD TYPE","MUTATED"))


##########################
##### Plotting ##########
#########################


#Generate summary data for plotting

sim.summ_sex <- sim.out %>%
  group_by(SEX_Name,time) %>%
  summarise(LOW_CI = quantile(Cp,0.05),
            HI_CI = quantile(Cp,0.95))

sim.summ_snp <- sim.out %>%
  group_by(SNP_Name,time) %>%
  summarise(LOW_CI = quantile(Cp,0.05),
            HI_CI = quantile(Cp,0.95))

# Generate concentration plots

# SNP plot
a <- ggplot()+
  stat_summary(data=sim.out,aes(time,Cp,color=SNP_Name),geom="line",fun.y = "median",size=1.2)+
  geom_ribbon(data=sim.summ_snp,aes(x=time,ymin=LOW_CI,ymax=HI_CI,fill=SNP_Name),alpha=0.3)+
  labs(x = "Time after first dose (hr)",
         y = "Concentration (ug/mL)",
         title = "Median (90% CI) Concentrations by SNP Status")+
  scale_x_continuous(breaks=seq(0,24,4))+
  theme_bw()+
  theme(legend.title = element_blank(),
        axis.title = element_text(size=13),
        axis.text = element_text(size=12),
        title = element_text(size=14),
        legend.text = element_text(size=12),
        legend.position = "bottom")

png("Median SNP.png",width = 8,height = 5,units = "in",res = 300)
a
dev.off()

# Plot for sex
b <- ggplot()+
  stat_summary(data=sim.out,aes(time,Cp,color=SEX_Name),geom="line",fun.y = "median",size=1.2)+
  geom_ribbon(data=sim.summ_sex,aes(x=time,ymin=LOW_CI,ymax=HI_CI,fill=SEX_Name),alpha=0.3)+
  labs(x = "Time after first dose (hr)",
       y = "Concentration (ug/mL)",
       title = "Median (90% CI) Concentrations by Sex")+
  scale_x_continuous(breaks=seq(0,24,4))+
  theme_bw()+
  theme(legend.title = element_blank(),
        axis.title = element_text(size=13),
        axis.text = element_text(size=12),
        title = element_text(size=14),
        legend.text = element_text(size=12),
        legend.position = "bottom")

png("Median SEX.png",width = 8,height = 5,units = "in",res = 300)
b
dev.off()

#################################
# Plot of covariate vs parameter
##################################


# Generate parameter file
sim.param <- sim.out %>%
  distinct(ID,.keep_all = T)

c <- ggplot(sim.param,aes(SEX_Name,V))+
  geom_boxplot()+
  labs(x = "SEX",
       y = "Volume (L)",
       title = "Volume Distribution by Sex")+
  theme_bw()+
  theme(axis.title = element_text(size=13),
        axis.text = element_text(size=12),
        title = element_text(size=14))

d <- ggplot(sim.param,aes(SNP_Name,CL))+
  geom_boxplot()+
  labs(x = "SNP Status",
       y = "Clearance (L/hr)",
       title = "Clearance Distribution by SNP Status")+
  theme_bw()+
  theme(axis.title = element_text(size=13),
        axis.text = element_text(size=12),
        title = element_text(size=14))

# Combine plots

png("Covariate vs Parameter.png",width = 5,height = 8,units = "in",res = 600)
grid.arrange(c,d,ncol=1)
dev.off()

