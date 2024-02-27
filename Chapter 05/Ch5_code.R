# Load and summarize data -------------------------------------------------
library(tidyverse)

# Neuron spike counts during learning phase
chosen_neuron_data <- read_csv("data/chosen_neuron_data.csv")

# One observation (spike count) per trial, for 100 trials
nrow(chosen_neuron_data)
# [1] 100
length(unique(chosen_neuron_data$trial_number))
# [1] 100

# Even split of image categories among trials
table(chosen_neuron_data$image_categ)
# Animal    Fruit     Kids Military    Space 
#     20       20       20       20       20 


# Fit generalized linear model --------------------------------------------

# Poisson GLM with the default log link function
poisson_fit <- glm(n_spikes ~ image_categ, data = chosen_neuron_data, 
                   family = poisson())

# Tabulate the coefficient estimates and confidence intervals
poisson_neuron_table <- cbind(summary(poisson_fit)$coefficients, 
                              confint(poisson_fit))

# View the GLM model summary
summary(poisson_fit)

# Test for visual selectivity
anova(poisson_fit, update(poisson_fit, n_spikes ~ 1), test = "Chisq")


# Fit Bayesian GLM --------------------------------------------------------
library(brms)

bglm_fit <- brm(n_spikes ~ image_categ, data = chosen_neuron_data,
                family = poisson, iter = 2500, warmup = 500, chains = 4)

# Tabulate posterior summary and MCMC diagnostics for regression coefficients
bglm_poisson_table <- summary(bglm_fit)$fixed[, c("Estimate", "Est.Error", 
                                                  "l-95% CI", "u-95% CI", 
                                                  "Bulk_ESS", "Rhat")]


# Plots -------------------------------------------------------------------
library(tidyverse)
library(gridExtra)
library(grid)
image_category_colors <- c("#D55E00", "#009E73", "#E69F00", "#56B4E9", "#CC79A7")

# Spike counts per trial
neuron_trial_plot <- chosen_neuron_data %>% 
  mutate(ordered_trial_num = as.numeric(
    factor(trial_number, levels = unique(trial_number[order(image_categ)]))
    )) %>% 
  ggplot(aes(ordered_trial_num + 0.5, n_spikes,
             fill = image_categ)) +
  geom_col() +
  labs(y = "Total Spikes Detected\n(0.2 to 1.2 seconds after stimulus onset)", 
       x = "Trial (sorted by image category)", 
       fill = "Image Category") +
  scale_fill_manual(values = image_category_colors) +
  scale_y_continuous(breaks = seq(0, 10, by = 1), minor_breaks = NULL) +
  scale_x_continuous(breaks = seq(0, 100, by = 20), minor_breaks = seq(0, 100)) +
  coord_cartesian(expand = FALSE) +
  theme_bw() +
  theme(text = element_text(size = 14),
        legend.position = "bottom")
neuron_trial_plot

# Comparison of spike count distribution with Poisson fit
poisson_dist_params <- chosen_neuron_data %>% 
  mutate(image_categ_number = as.numeric(factor(image_categ)) - 3) %>% 
  group_by(image_categ) %>% 
  summarise(predicted_trial_counts = c(sapply(mean(n_spikes), 
                                              function(x) {dpois(0:9, x)}) * 20),
            spike_count = c(0:9) + unique(image_categ_number) * 0.1) %>% 
  ungroup()

# Spike counts per image category (vs Poisson fits)
poisson_obs_fit_plt <- chosen_neuron_data %>% 
  ggplot(aes(n_spikes, fill = image_categ)) +
  geom_histogram(binwidth = 0.5, position = "dodge") +
  geom_point(aes(spike_count, predicted_trial_counts, 
                 color = "Poisson Distribution Fit"),
             data = poisson_dist_params) +
  labs(x = "Total Spikes Detected (0.2 to 1.2 seconds after stimulus onset)", 
       y = "Number of Trials", fill = "Image Category", color = "") +
  scale_fill_manual(values = image_category_colors, 
                    guide = guide_legend(override.aes = list(shape = NA))) +
  scale_color_manual(values = "black") +
  scale_x_continuous(breaks = seq(0, 10), minor_breaks = NULL) +
  scale_y_continuous(breaks = seq(0, 20, by = 4)) +
  coord_cartesian(xlim = c(-0.5, NA), ylim = c(0, 20), expand = FALSE) +
  theme_bw() +
  theme(text = element_text(size = 14),
        legend.position = "bottom")
poisson_obs_fit_plt





# Load and summarize data -------------------------------------------------
library(tidyverse)

# Load log patient response times for each trial (last 50 recognition trials)
resp_time_data <- read_csv("data/resp_time_data.csv") %>% 
  mutate(image_type = factor(image_type, levels = c("Old", "New")),
         resp_conf = factor(resp_conf, levels = c("guess", "probably", 
                                                  "confident"))) 

# Number of sessions per subject
resp_time_data %>% 
  group_by(subject_id) %>% 
  summarise(n_sessions = length(unique(session_id))) %>% 
  select(n_sessions) %>% 
  table()
# n_sessions
#  1  2  3 
# 35 18  4 

# Total number of subjects
length(unique(resp_time_data$subject_id))
# [1] 57

# The data has 50 trials per session and 83 sessions
resp_time_data %>% 
  group_by(session_id) %>% 
  summarise(n_trials = length(unique(recog_trial_number))) %>% 
  select(n_trials) %>% 
  table()
# n_trials
# 50 
# 83

# Total observations: 50 * 83 = 4150
nrow(resp_time_data)
# [1] 4150

# Fit linear mixed-effects model ------------------------------------------
library(lme4)

# Note: here session ids and subject ids are character strings. For numerical ids,
#       be sure to convert to factors before using lmer
lme_fit <- lmer(log_resp_time ~ sex + age + image_type * resp_conf + 
                  (1 | subject_id/session_id), data = resp_time_data)

# Tabulate the fixed effect estimates and confidence intervals
lme_logresp_table <- cbind(summary(lme_fit)$coefficients, 
                           confint(lme_fit, method = "Wald", level = 0.95, 
                                   parm = c("(Intercept)", "sexM", "age", 
                                            "image_typeNew", "resp_confprobably", 
                                            "resp_confconfident", 
                                            "image_typeNew:resp_confprobably",
                                            "image_typeNew:resp_confconfident")))

# View the model summary for both fixed effects and random effects
summary(lme_fit)

# Test significance of image type
anova(lme_fit, update(lme_fit, log_resp_time ~ sex + age + resp_conf + 
                        (1 | subject_id/session_id)))


# Fit generalized estimating equation -------------------------------------
library(geepack)

# Note: always convert cluster ids to factors (even character ids).

# Use independence and exchangeable working correlation structures
gee_fit_ind <- geeglm(log_resp_time ~ sex + age + image_type * resp_conf,
                      id = as.factor(resp_time_data$subject_id), 
                      corstr = "independence", data = resp_time_data)

gee_fit_exch <- geeglm(log_resp_time ~ sex + age + image_type * resp_conf,
                       id = as.factor(resp_time_data$subject_id), 
                       corstr = "exchangeable", data = resp_time_data)

# Tabulate model estimates for both GEE fits
gee_logresp_table <- cbind(summary(gee_fit_ind)$coefficients[, -3],
                           summary(gee_fit_exch)$coefficients[, -3])

# View the model summary for exchangeable working corr. structure
summary(gee_fit_exch)

# Test significance of image type
anova(gee_fit_exch, update(gee_fit_exch, log_resp_time ~ sex + age + resp_conf))

# Compare linear model fit, i.e. all trials independent / no random effects
lm_fit <- lm(log_resp_time ~ sex + age + image_type * resp_conf, 
             data = resp_time_data)

# The standard errors are smaller than the LMM and GEE estimates, suggesting
# that failure to account for the dependence across trials would lead to 
# anti-conservative inference, i.e. more likely to find statistical significance
# when there is none. 
lm_logresp_table <- cbind(summary(lm_fit)$coefficients, 
                          confint(lm_fit, level = 0.95, 
                                  parm = c("(Intercept)", "sexM", "age", 
                                           "image_typeNew", "resp_confprobably", 
                                           "resp_confconfident", 
                                           "image_typeNew:resp_confprobably",
                                           "image_typeNew:resp_confconfident")))


# Fit Bayesian LMM --------------------------------------------------------
library(brms)

blme_fit <- brm(log_resp_time ~ sex + age + image_type * resp_conf + 
                  (1 | subject_id) + (1 | session_id), data = resp_time_data,
                iter = 2500, warmup = 500, chains = 4)

# Tabulate posterior summary and MCMC diagnostics for fixed effects
blme_logresp_table <- summary(blme_fit)$fixed[, c("Estimate", "Est.Error", 
                                                  "l-95% CI", "u-95% CI", 
                                                  "Bulk_ESS", "Rhat")]


# Plots -------------------------------------------------------------------
library(tidyverse)
library(gridExtra)
library(grid)
image_type_colors <- c("New" = "#D55E00",
                       "Old" = "#56B4E9")

## LMM residual plots showing adequate fit to the data and approximate normality
lme_data <- resp_time_data %>% 
  mutate(fitted_vals = fitted(lme_fit),
         resids = residuals(lme_fit))

resid_plot <- grid.arrange(
  # vs fitted values
  ggplot(lme_data, aes(fitted_vals, resids)) +
    geom_point(shape = 21, alpha = 0.5) +
    geom_smooth(se = FALSE, method = "loess", color = "#E69F00") +
    labs(x = "Fitted Value", y = "Residual") +
    theme_bw() +
    theme(text = element_text(size = 14)),
  # vs image_type and response confidence
  ggplot(lme_data, aes(resp_conf, resids, fill = image_type)) +
    geom_boxplot(outlier.shape = 21) +
    labs(x = "Response Confidence Level", y = "Residual", fill = "Image Type") +
    scale_fill_manual(values = image_type_colors) +
    theme_bw() +
    theme(text = element_text(size = 14)),
  # vs age
  ggplot(lme_data, aes(age, resids)) +
    geom_point(shape = 21, alpha = 0.5) +
    geom_smooth(se = FALSE, method = "loess", color = "#E69F00") +
    labs(x = "Age", y = "Residual") +
    theme_bw() +
    theme(text = element_text(size = 14)),
  # qq-normal
  ggplot(lme_data, aes(sample = resids)) +
    geom_qq(shape = 21) +
    geom_abline(slope = 1, intercept = 0, linetype = "dotted") +
    labs(x = "Theoretical Quantile", y = "Sample Quantile") +
    theme_bw() +
    theme(text = element_text(size = 14)), 
  nrow = 2)
grid.draw(resid_plot)

## Exploratory covariate plots
resp_time_plt_data <- resp_time_data %>%
  mutate(image_type = factor(image_type, levels = c("New", "Old")))

# Side by side boxplots after log transform
boxplots_log_response_time <- resp_time_plt_data %>% 
  ggplot(aes(y = log_resp_time,
             x = subject_id,
             fill = image_type)) +
  geom_boxplot(outlier.size = 0.5) +
  labs(x = "Subject", 
       y = "Log Patient Response Time", 
       fill = "Image Type") +
  scale_fill_manual(values = image_type_colors) +
  theme_bw() +
  theme(text = element_text(size = 14),
        axis.text.x.bottom = element_text(angle = 35, hjust = 1, size = 6),
        legend.position = "bottom")
boxplots_log_response_time

# Histogram of log response time grouped by image type
log_time_histograms <- resp_time_plt_data %>% 
  ggplot(aes(x = log_resp_time)) +
  # add black outline for histogram and density curves
  geom_histogram(aes(y = ..density.., fill = image_type), bins = 35,
                 color = "black", alpha = 0.5, position = "identity") +
  geom_density(aes(y=..density.., group = image_type),
               color = "black", size = 3) +
  geom_density(aes(y=..density.., color = image_type), size = 2) +
  labs(x = "Log Patient Response Time", 
       y = "Density",
       fill = "Image Type") +
  scale_color_manual(values = image_type_colors, guide = "none") +
  scale_fill_manual(values = image_type_colors, 
                    guide = guide_legend(override.aes = list(alpha = 1, 
                                                             color = NULL))) +
  theme_bw() +
  theme(text = element_text(size = 14),
        legend.position = "bottom")
log_time_histograms

# Smoothed histogram of log response time grouped by image type and confidence
log_response_time_confidence_densities <- resp_time_plt_data %>% 
  ggplot() +
  # vertical lines at group averages
  geom_vline(aes(xintercept = log_resp_time, color = image_type, 
                 linetype = resp_conf), size = 0.75, show.legend = FALSE,
             data = aggregate(log_resp_time ~ image_type + resp_conf,
                              data = resp_time_data, FUN = mean)) +
  geom_density(aes(x = log_resp_time, color = image_type, linetype = resp_conf), 
               size = 1.5, fill = NA, key_glyph = "vline") +
  labs(x = "Log Patient Response Time", 
       y = "Density",
       linetype = "Response Confidence Level",
       color = "Image Type") +
  scale_color_manual(values = image_type_colors) +
  scale_linetype_manual(values = c("guess" = "dotted",
                                   "probably" = "longdash",
                                   "confident" = "solid"),
                        guide = guide_legend(override.aes = list(size = 0.5))) +
  theme_bw() +
  theme(text = element_text(size = 14),
        legend.position = "bottom")
log_response_time_confidence_densities





# Load and summarize data -------------------------------------------------
library(tidyverse)

# Proportions of visual-selective neurons (determined during learning phase)
aggregate_selectivity <- read_csv("data/aggregate_selectivity.csv")

# One observation (proportion) per session, 83 sessions in total
nrow(aggregate_selectivity)
# [1] 83
length(unique(aggregate_selectivity$session_id))
# [1] 83

# Total number of neurons varies substantially by session
summary(aggregate_selectivity$n_neurons)
# Min. 1st Qu.  Median    Mean 3rd Qu.    Max. 
# 1.00   13.00   18.00   22.17   32.50   64.00 

# Total number of subjects
length(unique(aggregate_selectivity$subject_id))
# [1] 57


# Fit generalized linear mixed-effects model ------------------------------
library(lme4)

# Note: subject ids are character strings. For numerical ids, be sure to convert
#       to factors before using glmer
glme_fit <- glmer(prop_selective_visual ~ age + sex + image_categs + 
                    (1 | subject_id), weights = aggregate_selectivity$n_neurons, 
                  data = aggregate_selectivity, family = "binomial")

# Tabulate the fixed effect estimates and confidence intervals
glme_prop_table <- cbind(summary(glme_fit)$coefficients, 
                         confint(glme_fit, method = "Wald", level = 0.95, parm = c(
              "(Intercept)", "sexM", "age", 
              "image_categsAnimals, Cars, Food, People, Spatial",
              "image_categsHouses, Landscapes, Mobility, Phones, Small animal"
              )))

# View the model summary for both fixed effects and random effects
summary(glme_fit)

# Test joint significance of all covariates
anova(glme_fit, update(glme_fit, prop_selective_visual ~ (1 | subject_id)))


# Fit generalized estimating equation -------------------------------------
library(geepack)

# Note: always convert cluster ids to factors (even character ids).

# Use exchangeable working correlation structures
gee_fit <- geeglm(prop_selective_visual ~ age + sex + image_categs,
                  id = as.factor(aggregate_selectivity$subject_id),
                  weights = aggregate_selectivity$n_neurons, 
                  family = "binomial", corstr = "exchangeable",
                  data = aggregate_selectivity)

# Tabulate model estimates for GEE fit (geeglm output does not work with confint())
gee_prop_table <- summary(gee_fit)$coefficients
gee_prop_table$`Lower 95% CI` <- gee_prop_table$Estimate + 
  qnorm(0.025) * gee_prop_table$Std.err
gee_prop_table$`Upper 95% CI` <- gee_prop_table$Estimate + 
  qnorm(0.975) * gee_prop_table$Std.err

# View the GEE model summary
summary(gee_fit)

# Test joint significance of all covariates
anova(gee_fit, update(gee_fit, prop_selective_visual ~ 1))


# Fit Bayesian GLMM -------------------------------------------------------
library(brms)

bglme_fit <- brm(n_selective_visual | trials(n_neurons) ~ age + sex + 
                   image_categs + (1 | subject_id), 
                 data = aggregate_selectivity, family = binomial, 
                 iter = 2500, warmup = 500, chains = 4)

# Tabulate posterior summary and MCMC diagnostics for fixed effects
bglme_prop_table <- summary(bglme_fit)$fixed[, c("Estimate", "Est.Error", 
                                                 "l-95% CI", "u-95% CI", 
                                                 "Bulk_ESS", "Rhat")]

# Save posterior prediction intervals
aggregate_selectivity[, c("pred_mean", "pred_2.5%", "pred_97.5%")] <- 
  predict(bglme_fit)[, -2]


# Plots -------------------------------------------------------------------
library(tidyverse)
library(gridExtra)
library(grid)
pred_label <- "95% Posterior Predictive CI"
hline_label <- "Proportion of Neurons Visual-Selective out of all Sessions"
overall_proportion <- aggregate_selectivity %>% 
  summarise(mean_prop_selective = sum(n_neurons * prop_selective_visual) / sum(n_neurons))

# Sort subjects by number of sessions and transform predictions to proportions
selectivity_plt_data <- aggregate_selectivity %>% 
  group_by(subject_id) %>% 
  mutate(n_sessions = length(unique(session_id))) %>% 
  ungroup() %>% 
  mutate(session_id = factor(session_id, levels = session_id[order(n_sessions, 
                                                                   subject_id, 
                                                                   image_categs)]),
         pred_mean = pred_mean / n_neurons, 
         `pred_2.5%` = `pred_2.5%` / n_neurons,
         `pred_97.5%` = `pred_97.5%` / n_neurons)

# Barchart for proportion of selective neurons
prop_selective_plt <- selectivity_plt_data %>% 
  ggplot(aes(subject_id, prop_selective_visual, group = session_id)) +
  geom_col(position = position_dodge2(preserve = "single"), 
           width = 1, color = "white", fill = "darkgray") + 
  # horizontal line at overall proportion
  geom_hline(aes(yintercept = mean_prop_selective, linetype = hline_label), 
             data = overall_proportion, size = 1, color = "#D55E00") +
  facet_grid(~ n_sessions + subject_id, scales = "free_x", space = "free_x") +
  labs(x = "Subject (1-3 sessions each)", 
       y = "Proportion of Neurons Visual-Selective", linetype = "") +
  coord_cartesian(expand = FALSE) +
  scale_y_continuous(minor_breaks = seq(0, 1, by = 0.25)) +
  theme_bw() +
  theme(text = element_text(size = 14),
        axis.text.x.bottom = element_text(angle = 90, size = 7,
                                          hjust = 1, vjust = 0.5),
        legend.position = "bottom", 
        panel.spacing = unit(1.5, "pt"), 
        panel.grid.major.x = element_blank(),
        panel.border = element_rect(color = "lightgray"),
        axis.line = element_line(color = "black"),
        strip.background = element_blank(), 
        strip.text = element_blank())
prop_selective_plt

# Proportion of selective neurons vs age and sex
prop_selective_covariates <- gridExtra::grid.arrange(
  aggregate_selectivity %>% 
    ggplot(aes(age, prop_selective_visual)) +
    geom_point(size = 2) +
    labs(x = "Age", y = "Proportion of Neurons Visual-Selective") +
    scale_y_continuous(minor_breaks = seq(0, 1, by = 0.25)) +
    theme_bw() +
    theme(text = element_text(size = 14)),
  aggregate_selectivity %>% 
    ggplot(aes(sex, prop_selective_visual, fill = sex)) +
    geom_boxplot(outlier.size = 2, show.legend = FALSE) +
    labs(x = "Sex", y = "Proportion of Neurons Visual-Selective") +
    scale_y_continuous(minor_breaks = seq(0, 1, by = 0.25)) +
    scale_fill_manual(values = c("F" = "#D55E00", "M" = "#56B4E9")) +
    theme_bw() +
    theme(text = element_text(size = 14)),
  nrow = 1
)
grid.draw(prop_selective_covariates)

# Bayesian prediction intervals for proportion of selective neurons
prop_selective_fits <- selectivity_plt_data %>% 
  ggplot(aes(subject_id, pred_mean, group = session_id)) +
  geom_crossbar(aes(ymin = `pred_2.5%`, ymax = `pred_97.5%`, fill = pred_label), 
                color = "white", fatten = 5,
                position = position_dodge2(preserve = "single")) +
  geom_point(aes(y = prop_selective_visual, shape = "Data"), size = 2,
             position = position_dodge2(preserve = "single", width = 1)) + 
  # horizontal line at overall proportion
  geom_hline(aes(yintercept = mean_prop_selective, linetype = hline_label), 
             data = overall_proportion,
             size = 1, color = "#D55E00") +
  facet_grid(~ n_sessions + subject_id, scales = "free_x", space = "free_x") +
  labs(x = "Subject (1-3 sessions each)", fill = "",
       y = "Proportion of Neurons Visual-Selective", linetype = "", shape = "") +
  coord_cartesian(expand = FALSE) +
  scale_y_continuous(minor_breaks = seq(0, 1, by = 0.25)) +
  scale_fill_manual(values = "slategray2") +
  theme_bw() +
  theme(text = element_text(size = 14),
        axis.text.x.bottom = element_text(angle = 90, size = 7, 
                                          hjust = 1, vjust = 0.5),
        legend.position = "bottom", 
        panel.spacing = unit(1.5, "pt"), 
        panel.grid.major.x = element_blank(),
        panel.border = element_rect(color = "lightgray"),
        axis.line = element_line(color = "black"),
        strip.background = element_blank(), 
        strip.text = element_blank())
prop_selective_fits