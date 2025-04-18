# @datatable a data frame with clinical and summary data merged by "Image tag"
# @clinvar the name of the column for the clinical variable.
# @cellvar the name of the column for the cell type (marker)
# @return summ_plots a list with three ggplot object containing a boxplot, a violin plot, a scatter plot, and a histogram with the clinical variable as a factor.

summary_plots_fn <- function(datatable, clinvar, cellvar, colorscheme, threshold){
  box_p <- ggplot(datatable, aes(x=as.factor(get(clinvar)), y=get(cellvar), fill=as.factor(get(clinvar)))) + 
    geom_boxplot() +
    xlab(str_to_title(clinvar)) + ylab(gsub("_", " ", str_to_title(cellvar))) +
    labs(fill=str_to_title(clinvar)) + theme_classic(base_size = 20) +
    viridis::scale_fill_viridis(option = colorscheme, discrete = TRUE) + 
    geom_hline(yintercept = as.numeric(threshold), size = 1.25, 
               linetype = "twodash", color = 'red') + 
    theme(legend.position = 'none')
  
  violin_p <- ggplot(datatable, aes(x=as.factor(get(clinvar)), y=get(cellvar), fill=as.factor(get(clinvar)))) + 
    geom_violin() +
    xlab(str_to_title(clinvar)) + ylab(gsub("_", " ", str_to_title(cellvar))) +
    labs(fill=str_to_title(clinvar)) + theme_classic(base_size = 20) +
    viridis::scale_fill_viridis(option = colorscheme, discrete = TRUE) + 
    geom_hline(yintercept = as.numeric(threshold), size = 1.25, 
               linetype = "twodash", color = 'red') + 
    theme(legend.position = 'none')
  
  hist_p <- ggplot(datatable, aes(x=get(cellvar), fill=as.factor(get(clinvar)))) + 
    geom_histogram(position='stack', color="white") + facet_wrap(get(clinvar)~., nrow = 1) +   
    xlab(str_to_title(gsub("_", " ", cellvar))) + ylab("Count") +
    labs(fill=str_to_title(clinvar)) + theme_classic(base_size = 20) +
    viridis::scale_fill_viridis(option = colorscheme, discrete = TRUE) + 
    theme(legend.position = 'none') + 
    geom_vline(xintercept = as.numeric(threshold), size = 1.25, linetype = "twodash", color = 'red')
  
  stacked_data = freq_table_by_marker(summary_clinical_merge = datatable,
                                      clinical = clinvar,
                                      markers = cellvar) %>%
    melt(id=clinvar)
  
  stacked_bar = stacked_data %>% ggplot(aes(fill=variable, y=value, x=as.factor(get(clinvar)))) + 
    geom_bar(position="fill", stat="identity", color="white") + ylab(gsub("_", " ", str_to_title(cellvar))) + 
    labs(fill='Threshold')  + theme_classic(base_size = 20) + xlab(clinvar) +
    viridis::scale_fill_viridis(option = colorscheme, discrete = TRUE) 
  
  if(is.character(datatable[[clinvar]])){
    scatter_p <- ggplot(datatable, aes(x=get(clinvar), y=get(cellvar), color=get(clinvar))) +
      geom_point() +
      xlab(str_to_title(clinvar)) + ylab(gsub("_", " ", str_to_title(cellvar))) +
      labs(color=str_to_title(clinvar)) + theme_classic(base_size = 20) + 
      viridis::scale_color_viridis(option = colorscheme, discrete=TRUE)
  } else{
    scatter_p <- ggplot(datatable, aes(x=get(clinvar), y=get(cellvar), color=get(clinvar))) +
      geom_point() +
      xlab(str_to_title(clinvar)) + ylab(gsub("_", " ", str_to_title(cellvar))) +
      labs(color=str_to_title(clinvar)) + theme_classic(base_size = 20) + 
      viridis::scale_color_viridis(option = colorscheme, discrete=FALSE)    
  }
  
  summ_plots <- list(box_p, violin_p, hist_p, scatter_p, stacked_bar)
  
  return(summ_plots)
}


# # Load tidyverse for data frame manipulation.
# library('tidyverse')
# 
# # Load data from .Rdata file.
# load("data/example_data.RData")
# 
# # Clean column names for the image summary data and the clinical data.
# summary_clean <- janitor::clean_names(summary)
# clinical_clean <- janitor::clean_names(clinical)
# 
# #Join the image summary data and the clinical data by the filename of the image ("Image tag").
# datatable <- left_join(clinical_clean, summary_clean, by="image_tag")
# 
# # Show columns available for selection.
# cat("CLINICAL VARIABLES:\n")
# names(clinical_clean)
# cat("\n")
# cat("CELL TYPES:\n")
# names(summary_clean)
# 
# # Specify user-selected clinical column.
# # Specify user-selected cell type column.
# clinvar <- 'age'
# cellvar <- 'cd3_opal_570_positive_cells'
# 
# # Select color scheme
# colorscheme <- 'viridis'
# 
# # Get plots
# plots <- summary_plots_fn(datatable, clinvar, cellvar, colorscheme)
