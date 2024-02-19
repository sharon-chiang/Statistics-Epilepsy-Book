# Import libraries (install if not already installed)
library(survival)
library(icenReg)
library(ggplot2)
library(survminer)

# Import data example and process a few columns
Dsurv= read.csv('survivaldata.csv')

colnames(Dsurv)[5] = "Diag"
Dsurv[Dsurv[, 5] == 2, 5] = 1

Dsurv$Group = 1 - Dsurv$Group

# Get survival times
getsurvtime = function(x){
    which(x>0)[1]
    }
    
survtime = apply(Dsurv[, 7:16], 1, getsurvtime)
survtime[is.na(survtime)] = 12

# Define censoring variable
censor = as.numeric(!is.na(survtime))

# Kaplan-Meier estimator
fits =survfit (Surv(survtime, censor) ~  Group,  data=data.frame(Dsurv))
ggsurv <- ggsurvplot(fits , data =Dsurv,conf.int = TRUE,  risk.table =T,  
                     ggtheme = theme_light(), pval =F, conf.int.style = "step", 
                     legend.lab =  c( 'Medical-therapy group', 'Surgery group'), 
                     palette = gray(seq(0.5,0, len=2)), xlab = 'Time (days)')
print(ggsurv)

# Log rank test on the two group difference 
surv_diff <- survdiff(Surv(survtime, censor) ~ Group,  data=data.frame(Dsurv))

# Cox proportional hazards model
newdata = Dsurv[c(1,4),  ]
coxfits =coxph(Surv(survtime, censor) ~ Group,  data=data.frame(Dsurv))
summary(coxfits)

# Cox proportional hazards model with additional covariates
coxcovfits = coxph(Surv(survtime, censor) ~  Group + Age + Gender + Diag + 
                    Family_hist,data = data.frame(Dsurv))
plot(residuals(coxcovfits, method = 'deviance'), ylab = 'Martingale residual')

ggsurv <- ggsurvplot(survfit(coxfits, newdata = newdata), data = Dsurv,
                     conf.int = TRUE,  ggtheme = theme_light(), pval =F, 
                     conf.int.style = "step", 
                     legend.lab = c( 'Medical-therapy group', 'Surgery group'), 
                     palette = gray(seq(0.5, 0, len = 2)), xlab = 'Time (days)')
print(ggsurv)
summary(coxcovfits)

# Test proportional hazards assumption
test.ph <- cox.zph(coxfits)
testcov.ph <- cox.zph(coxcovfits)

# Parametric model
regfits =survreg(Surv(survtime, censor) ~  Group,  data=data.frame(Dsurv), dist = 'lognormal')

# Parametric model with additional covariates
regcovfits =survreg(Surv(survtime, censor) ~  Group +Age + Gender +Diag + Family_hist ,  data=data.frame(Dsurv), dist = 'lognormal')
ggsurvreg <- ggsurvplot(predict(regfits), data =Dsurv,conf.int = TRUE,  ggtheme = theme_light(), pval =F, conf.int.style = "step", legend.lab = c( 'Medical-therapy group', 'Surgery group'), palette = gray(seq(0.5,0, len=2)), xlab = 'Time (days)')
print(ggsurvreg)

summary(regcovfits)
plot(residuals(regcovfits, method = 'deviance'), ylab = 'Deviance')

wregcovfits = survreg(Surv(survtime, censor) ~  Group + Age + Gender + Diag + 
                        Family_hist,  data=data.frame(Dsurv), dist = 'weibull')
plot(residuals(wregcovfits, method = 'deviance'), ylab = 'Deviance')

# Kaplan Meier curve for interval censored data
getintervaltime = function(x){
    a = which(x>0)[1]
    c(a- 1, a)
}

LRsurvtime = t(apply(Dsurv[, 7:16], 1, getintervaltime))
LRsurvtime[is.na(LRsurvtime[, 2]), 1] = 12
LRsurvtime[is.na(LRsurvtime[, 2]), 2] = 14
icfit = ic_np(LRsurvtime ~ Group, data = data.frame(Dsurv))
plot(icfit)

weib = function(t, lambda, alpha){
    hazard = alpha * lambda * t^(alpha -1)
    survival =exp(-lambda * t ^alpha)
    return(rbind(hazard, survival))
    }

expon =  function(t, lambda){
    hazard = lambda
    survival =exp(-lambda * t)
    return(rbind(hazard, survival))
}

lognorm =  function(t, mu, sigma){
    f=dlnorm(t, mu, sigma)
    s = plnorm(t, mu, sigma)
    hazard = f/s
    survival =1-s
    return(rbind(hazard, survival))
}

t = seq(0.1, 10, length.out = 100)

wt1 = weib(t, 1.5, 1.2)
wt2 = weib(t, 1.5, 0.8)
expn = expon(t, 1)
logres = lognorm(t, 0,5)

plot(wt1[1, ]~t, type = 'l', lwd = 3, lty = 1, ylim = c(0, 4), xlab = 'time', ylab = 'Hazard function')

lines(wt2[1, ]~t, type = 'l', lwd = 3, lty = 2)
lines(expn[1, ]~t, type = 'l', lwd = 3, lty = 3)
lines(logres[1, ]~t, type = 'l', lwd = 3, lty = 4)
legend('topleft',c('Increasing Weibull', 'Decreasing Weibull', 'Exponential', 'Log-normal'), lty = 1:4, )

plot(wt1[2, ]~t, type = 'l', lwd = 3, lty = 1, ylim = c(0, 1.2), xlab = 'time', ylab = 'Survival function')

lines(wt2[2, ]~t, type = 'l', lwd = 3, lty = 2)
lines(expn[2, ]~t, type = 'l', lwd = 3, lty = 3)
lines(logres[2, ]~t, type = 'l', lwd = 3, lty = 4)
legend('topleft',c('Increasing Weibull', 'Decreasing Weibull', 'Exponential', 'Log-normal'), lty = 1:4, )

