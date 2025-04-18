# iteractive Tumor Immune MicroEnvironment
# 
# iTIME Shiny Application is a tool to visualizeXloc = (XMin + XMax)/2 spatial IF data that is output from HALO. 
# Along with clinical data, brief summary statistics are presented.
#
# Dev team in ui.R
# clinical_data = fread("example_data/deidentified_clinical.csv", check.names = FALSE, data.table = FALSE)
# summary_data = fread("example_data/deidentified_summary.csv", check.names = FALSE, data.table = FALSE)
# summary_data_merged = merge(clinical_data, summary_data, by = "deidentified_id")

shinyServer(function(input, output) {
    
    buttons = reactiveValues(data = NULL)
    observeEvent(input$exampleData, {
        buttons$data = 1
    })
    
    summary_data = reactive({
        if(is.null(buttons$data)){
            infile = input$summaryData
            if(is.null(infile)){
                return()
            }
            
            df = fread(infile$datapath, check.names = FALSE, data.table = FALSE)
        } else {
            df = fread("example_data/deidentified_summary.csv", check.names = FALSE, data.table = FALSE)
        }
        
        colnames(df) <- gsub("\\%", 'Percent', colnames(df))
        df[is.na(df)] = "Missing"
        return(df)
        
    })
    
    clinical_data = reactive({
        if(is.null(buttons$data)){
            infile = input$clinicalData
            if(is.null(infile)){
                return()
            }
            df = fread(infile$datapath, check.names = FALSE, data.table = FALSE)
        } else {
            df = fread("example_data/deidentified_clinical.csv", check.names = FALSE, data.table = FALSE)
        }
        
        df[is.na(df)] = "Missing"
        return(df)
    })
    
    # ---------------------------------------------------------
    # MJ This block was modified to ensure proper processing 
    # of uploaded spatial files. The old code is commented out below.
    # This new version formats spatial data correctly for analysis.
    # ---------------------------------------------------------
    
    # Old code (commented out for reference)
    # spatial_data = reactive({
    #     if(is.null(buttons$data)){
    #         infile = input$spatialData
    #         if(is.null(infile)){
    #             return()
    #         }
    #         df = fread(infile$datapath, check.names = FALSE, data.table = FALSE)
    #     } else {
    #         df = fread("example_data/deidentified_spatial.csv", check.names = FALSE, data.table = FALSE)
    #     }
    #     
    #     df[is.na(df)] = "NA"
    #     return(df)
    # })
    
    # M New code to process spatial file correctly and to support multiple files
    spatial_data = reactive({
      req(input$spatialData)  # Ensure files are uploaded
      
      df_list = lapply(input$spatialData$datapath, function(file) {
        fread(file, check.names = FALSE, data.table = FALSE)
      })
      df = do.call(rbind, df_list)  # Merge multiple files if needed
      
      # Debugging: Print column names and check types
      print("SPATIAL FILE COLUMNS BEFORE PROCESSING:")
      print(colnames(df))
      print("SPATIAL DATA STRUCTURE BEFORE PROCESSING:")
      print(str(df))
      
      # Ensure required columns exist
      required_columns = c("XMin", "XMax", "YMin", "YMax")
      missing_columns = setdiff(required_columns, colnames(df))
      
      if (length(missing_columns) > 0) {
        stop(paste("Spatial file is missing required coordinate columns:", paste(missing_columns, collapse=", ")))
      }
      
      # Convert to numeric and create Xloc, Yloc upfront
      df = df %>%
        mutate(
          XMin = as.numeric(XMin),
          XMax = as.numeric(XMax),
          YMin = as.numeric(YMin),
          YMax = as.numeric(YMax),
          Xloc = (XMin + XMax) / 2,
          Yloc = (YMin + YMax) / 2  # Move this here to ensure it exists before ripley_data() uses it
        )
      
      print("SPATIAL FILE COLUMNS AFTER PROCESSING:")
      print(colnames(df))
      print("SPATIAL DATA STRUCTURE AFTER PROCESSING:")
      print(str(df))
      
      print("Spatial Data Successfully Processed.")
      return(df)
    })
    
    

    output$summary_preview = renderTable({
        head(summary_data(), n = 15L)
    })
    
    output$clinical_preview = renderTable({
        head(clinical_data(), n = 15L)
    })
    
    output$spatial_preview = renderTable({
        head(spatial_data()[,-3], n = 15L)
    })
    
    output$merged_preview = renderTable({
        head(summary_data_merged(), n=15L)
    })
    
    output$choose_summary_merge = renderUI({
        
        summary_column_names = colnames(summary_data())
        
        selectInput("summary_merge", "Choose Summary Merge Variable",
                    choices = summary_column_names,
                    selected = summary_column_names[1])
        
        #print("summary merge variable selected")
    })
    
    output$choose_clinical_merge = renderUI({
        
        clinical_column_names = colnames(clinical_data())
        
        selectInput("clinical_merge", "Choose Clinical Merge Variable",
                    choices = clinical_column_names,
                    selected = clinical_column_names[1])
        
        #print('clinical merge variable selected')
        
    })
    
    summary_data_merged = reactive({
        if(is.null(clinical_data()) | is.null(summary_data())){
            return()
        }
        
        df = merge(clinical_data(), summary_data(), by.x = input$clinical_merge, by.y = input$summary_merge)
      assign("summary_data_merged", df, envir = .GlobalEnv)
        return(df)
    })
    
#univariate
    
    output$choose_marker = renderUI({
        
        summary_marker_names = colnames(summary_data_merged())[grepl("^Percent", colnames(summary_data_merged()))]
        
        selectInput("picked_marker", "Choose Cell Marker to Plot",
                    choices = summary_marker_names,
                    selected = summary_marker_names[3])
        
    })
    
    output$choose_clinical = renderUI({
        validate(need(ncol(clinical_data()) > 0, "Loading Clinical Data....."),
                 need(ncol(summary_data_merged()) > 0, "Waiting on merging clinical and summary data....."))
        summary_clinical_names = sort(colnames(summary_data_merged())[(colnames(summary_data_merged()) %in% colnames(clinical_data()))])
        t = sapply(summary_data_merged() %>% select(all_of(summary_clinical_names)), function(x){return(length(unique(x)))})
        good = t[t > 1 & t < 10]
        
        selectInput("picked_clinical", "Choose Clinical Variable to Plot and Test",
                    choices = summary_clinical_names,
                    selected = names(good)[1]) #select a variable that has a decent amount of levels in order to perform the models
        
    })
    
    output$choose_uni_covariates = renderUI({
      validate(need(ncol(clinical_data()) > 0, "Waiting on Clinical data....."))
      summary_clinical_names = colnames(summary_data_merged())[(colnames(summary_data_merged()) %in% colnames(clinical_data()))]
      t = sapply(summary_data_merged() %>% select(all_of(summary_clinical_names)), function(x){return(length(unique(x)))})
      
      good = summary_clinical_names[t>1]
      good = good[!good %in% input$picked_clinical]
      
      pickerInput(
        inputId = "uni_covariates_selected", 
        label = "Choose Model Covariates", 
        choices = good, 
        options = list(
          `actions-box` = TRUE, 
          size = 10,
          `selected-text-format` = "count > 3"
        ), 
        multiple = TRUE
      )
    })
    
    univar_plots = reactive({
         validate(need(input$picked_marker !="", "Please wait while things finish loading....."),
                 need(input$picked_clinical !="", "Waiting to pick a clinical variable"),
                 need(input$summaryPlotColors !="", "waiting on plot colors"),
                 need(ncol(summary_data_merged()) > 0, "waiting on merging data"),
                 need(input$uni_transformation != "", "have to wait for tranformation options to load"),
                 need(input$summaryPlotType != "", "have to wait for plot type options to load"))
        
        data_table = summary_data_merged()
        cellvar = input$picked_marker
        if(input$uni_transformation == "none"){
            thres = input$choose_cont_thresh
        } else if(input$uni_transformation == "sqrt_transform"){
            data_table[,cellvar] = sqrt(data_table[,cellvar])
            thres = sqrt(as.numeric(input$choose_cont_thresh))
        } else if(input$uni_transformation == "log2_transform"){
            data_table[,cellvar] = log2(data_table[,cellvar]+0.0001)
            thres = log2(as.numeric(input$choose_cont_thresh)+0.0001)
        } else if(input$uni_transformation == "logit_transform"){
            p = (data_table[,cellvar]/100)+0.0001
            data_table[,cellvar] = log10(p/(1-p))
            tmp = (as.numeric(input$choose_cont_thresh)/100) + 0.0001
            thres = log10(tmp/(1-tmp))
        }
        
        
        plots = summary_plots_fn(data_table, clinvar = input$picked_clinical,
                                 cellvar = cellvar, colorscheme <- input$summaryPlotColors, thres)
        
        plots[[as.integer(input$summaryPlotType)]]
    })

    output$boxplot <- renderPlot({
        univar_plots()
    })
    
    cont_table = reactive({
        validate(need(input$picked_clinical !="", "Please wait while things finish loading....."),
                 need(ncol(summary_data_merged()) > 0, ""),
                 need(input$picked_marker != "", ""),
                 need(input$choose_cont_thresh != "", ""))
        
        df = contingency_table(summary_data_merged(), markers = input$picked_marker, clin_vars = input$picked_clinical, percent_threshold = input$choose_cont_thresh)
        
        return(df)
    })
    
    output$contTable = renderTable({
        return(cont_table())
    })
    
    frequency_table = reactive({
        validate(need(input$picked_marker !="", "Please wait while things finish loading....."))
        
        df = freq_table_by_marker(summary_data_merged(), markers = input$picked_marker, clinical = input$picked_clinical)
        return(df)
    })
    
    output$freqTable = renderTable({
        return(frequency_table())
    })
    
    output$selectedModelName = renderText({
        marker = substr(input$picked_marker, 9, nchar(input$picked_marker)-1)
        paste("Statistical Modeling of the", marker, "Counts")
    })
    
    sum_table = reactive({
        validate(need(ncol(summary_data_merged()) > 0, "Please wait while things finish loading....."),
                 need(input$picked_marker !="", "Please wait while things finish loading....."),
                 need(input$clinical_merge !="", "Please wait while things finish loading....."))
        
        return(summary_table(summary_data_merged(), marker = input$picked_marker, clinical = input$picked_clinical, merged = input$clinical_merge))
    })
    
    output$summaryTable = renderTable({
        sum_table()
    })
    
    output$download_boxplot = downloadHandler(
        filename = function() { paste(Sys.Date(), '-summary_plot.pdf', sep='') },
        
        content = function(file) {
            ggsave(file, plot = univar_plots(), device = "pdf",width = 12, height = 10, units = "in")
        }
    )
    
    output$choose_total_cells = renderUI({
        summary_clinical_names = colnames(summary_data_merged())
        
        selectInput("picked_total_cells", "Choose Column Name for Total Number of Cells",
                    choices = summary_clinical_names,
                    selected = summary_clinical_names[grep("Total", summary_clinical_names)])
    })
    output$modeling_reference = renderUI({
        validate(need(ncol(summary_data_merged()) > 0, "Please wait while Summary and Clinical Data are merged....."),
                 need(input$picked_clinical !="", "Please select a clinical variable for comparison....."))
        model_references = unique(summary_data_merged() %>% pull(!!input$picked_clinical)) %>% sort()
        assign("model_references", model_references, envir = .GlobalEnv)
        selectInput("picked_modeling_reference", "Choose Clinical Reference",
                    choices = model_references,
                    selected = model_references[1])
    })
    
    model_list = reactive({
        validate(need(input$picked_clinical !="", "Please select a clinical variable....."),
                 need(ncol(summary_data_merged()) > 0, "Please upload clinical and summary data....."),
                 need(input$picked_marker !="", "Please pick a marker....."),
                 need(input$picked_total_cells !="", "Please select column with total cell count....."),
                 need(input$picked_modeling_reference !="", ""))
        marker = input$picked_marker
        marker = substr(marker, 9, nchar(marker))
        marker = c(marker, gsub("\\ Positive\\ ", "\\ ", marker))
        covars = input$uni_covariates_selected
        #assign("picked_modeling_reference", input$picked_modeling_reference, envir = .GlobalEnv)
        dat = summary_data_merged() %>% mutate_at(.vars = input$picked_clinical,
                                                  .funs = function(x){
                                                    if(input$clinicalClass == "numeric"){
                                                      return(as.numeric(x))
                                                    } else {
                                                      x = as.factor(x)
                                                      x = relevel(x, ref = input$picked_modeling_reference)
                                                      return(x)
                                                    }
                                                  })
        suppressWarnings({
        df = model_checked_repeated(summary_data_merged = dat, markers = marker,
                                    Total = input$picked_total_cells, clin_vars = input$picked_clinical, reference = input$picked_modeling_reference,
                                    choose_clinical_merge = input$clinical_merge, covars = covars) #assuming IDs are merging variable (patientID, subjectID, etc)
        })
        
    return(df)
    })
    
    # output$aic_table = renderTable({
    #     aic_table_react()
    # }, digits = 4)
    
    aic_table_react = reactive({
        models1 = model_list()
        return(data.frame(models$aic))
    })
    
    chosen_model_stats = reactive({
        #validate(need(model_list(), "Please wait while things finish loading....."))
        withProgress(message = "Modeling", value = 0,{
            incProgress(0.33, detail = "Fitting Beta-Binomial")
            models1 = model_list()
            #assign("models1", models1, envir = .GlobalEnv)
            incProgress(0.33, detail = "Extracting Statistics")
            df = models1$models[["Beta Binomial"]]
            if(class(df)=="character"){
              print("simple lm")
                df1 = data.frame(df)
            } else if(class(df)=="MixMod"){
              print("mixmod")
              df1 = summary(df)$coef_table
              #assign("df1", df1, envir = .GlobalEnv)
              df1 = data.frame(Terms = gsub("tmp\\$clin_vars", "", row.names(df1)),
                               df1, check.names = F)
            }else{
                df = df %>% summary() %>% coefficients()#input$selectedModel
                df1 = data.frame(Terms = gsub("tmp\\$clin_vars", "", row.names(df)),
                                 df, check.names = F)
                #df1 = df1[-2,]
            }
            levs = summary_data_merged()[[input$picked_clinical]] %>% unique() %>% length()-1
            incProgress(0.33, detail = "Completed")
            if(input$clinicalClass == "numeric"){
              return(df1)
            } else {
              df = df1[c(1,(nrow(df1)-levs+1):nrow(df1)),]
              #assign("df", df, envir = .GlobalEnv)
              return(df)
            }
            
        })
    })
    
    output$model_stats = renderTable({
        chosen_model_stats()
    }, digits = 4)
    
    cdf_plot_react = reactive({
        validate(need(ncol(summary_data_merged()) > 0, "Please upload Summary and Clinical files....."),
                 need(input$picked_marker !="", "Please select a marker above....."))
        
        marker = input$picked_marker
        marker = substr(marker, 9, nchar(marker))
        marker = c(marker, gsub("\\ Positive\\ ", "\\ ", marker))
        data_table = summary_data_merged()
        assign("summary_data_merged", data_table, envir = .GlobalEnv)
        
        CDF_plots(summary_data_merge = data_table, markers = marker)
    })
    
    output$cdfplot = renderPlot({
        cdf_plot_react()
    })
    
    model_description = reactive({
        validate(need(ncol(chosen_model_stats()) > 0, "Please wait while the model is fit....."))
        model_statistics = chosen_model_stats()
        coefficient_of_interest = model_statistics[2,]
        marker = substr(input$picked_marker, 9, nchar(input$picked_marker)-15)
        
        if(any(table(summary_data_merged()[[input$clinical_merge]])>1)){
            repeated_measure = paste("Merge variable <b>",input$clinical_merge,"</b> has repeated measures.<br>", sep="")
        }else{
            repeated_measure = paste("Merge variable <b>",input$clinical_merge,"</b> does not have repeated measures.<br>", sep="")
        }
        
        if(input$clinicalClass == "factor"){
          interpret = paste0("The predictor of interest, <b>",
                             as.character(input$picked_clinical),
                             "</b>, odds ratio on abundance of the immune marker of interest, <b>", marker, "</b> positive cell counts, is <b>",
                             round(exp(as.numeric(coefficient_of_interest$Estimate)), digits = 4), "</b> [exp(<b>", paste(coefficient_of_interest$Terms)," Estimate</b>)],
                             meaning that a cell from <b>",
                             coefficient_of_interest$Terms, "</b> is <b>", round(exp(as.numeric(coefficient_of_interest$Estimate)), digits = 4), "x</b> as likely to be <b>", 
                             marker, "</b> positive than a cell from <b>", paste0(as.character(input$picked_clinical),input$picked_modeling_reference),
                             "</b>. ")
        } else {
          # interpret = paste0("The predictor of interest, <b>",
          #                    as.character(input$picked_clinical),
          #                    "</b>, odds ratio on abundance of the immune marker of interest, <b>", marker, "</b> positive cell counts, is <b>",
          #                    round(exp(as.numeric(coefficient_of_interest$Estimate)), digits = 4), "</b> [exp(<b>", paste(coefficient_of_interest$Terms)," Estimate</b>)],
          #                    meaning that for a cell from <b>",
          #                    coefficient_of_interest$Terms, "</b> is <b>", round(exp(as.numeric(coefficient_of_interest$Estimate)), digits = 4), "x</b> as likely to be <b>", 
          #                    marker, "</b> positive for every increase of <b> 1 </b> in <b>", as.character(input$picked_clinical),
          #                    "</b>. ")
          interpret = paste0("For every increase in the predictor of interest, <b>",
                             as.character(input$picked_clinical),
                             "</b>, by one unit, <b>", coefficient_of_interest$Terms, "</b> has a change of <b>", 
                             round(as.numeric(coefficient_of_interest$Estimate), digits = 4), "</b>. ")
        }
        paste(repeated_measure, interpret,
              "The p-value for the effect of the predictor of interest <b>", as.character(input$picked_clinical), "</b> on the abundance of <b>", 
              marker, "</b> positive cells is <b>", round(as.numeric(coefficient_of_interest[,ncol(coefficient_of_interest)]), digits = 4),
              "</b>. A small p-value (less than 0.05, for example) indicates the association is unlikely to occur by chance and indicates 
              a significant association of the predictor <b>", as.character(input$picked_clinical) ,"</b> on immune abundance for <b>",
              marker, "</b>.",
              sep="")
    })
    
    output$modelingDescription <- renderText({
        model_description()
    })
    
    output$univariate_report <- downloadHandler(
        filename <-  "univariate_report.pdf",
        content = function(file) {
            tempReport <- file.path(tempdir(), "volanoes_report.Rmd")
            file.copy("report_templates/univariate_report.Rmd", tempReport, overwrite = TRUE)
            params <- list(include_functions = F, #input$printFunctions
                           selected_marker = input$picked_marker,
                           contingency_threshold = input$choose_cont_thresh,
                           picked_clinical = input$picked_clinical,
                           boxplots = univar_plots(),
                           contingency_table = cont_table(),
                           frequency_table = frequency_table(),
                           summary_table = sum_table(),
                           cdf_plot = cdf_plot_react(),
                           total_cell_column = input$picked_total_cells,
                           modeling_reference = input$picked_modeling_reference,
                           chosen_model_stats = chosen_model_stats(),
                           modelDescription = model_description()
                           #selected_univariate_model = input$selectedModel,
                           #model_aic_table = aic_table_react(),
                           )
            rmarkdown::render(tempReport, output_file = file,
                              params = params,
                              envir = new.env(parent = globalenv())
            )
        }
    )

#multivariate
    
    output$choose_heatmap_marker = renderUI({
        heatmap_names = colnames(summary_data())
        
        heatmap_names2 = heatmap_names[grep("^(?=Percent.*)",
                              heatmap_names,perl=TRUE,ignore.case = TRUE)]
        
        awesomeCheckboxGroup("heatmap_selection", "Choose Cell Marker for Heatmap",
                           choices = heatmap_names2, selected = heatmap_names2[grepl("Opal", heatmap_names2)],
                           status = "primary"
        )
    })
    
    output$choose_heatmap_clinical = renderUI({
        validate(need(ncol(clinical_data()) > 0, "Loading Clinical Data....."),
                 need(ncol(summary_data_merged()) > 0, "Waiting on merging clinical and summary data....."))
        
        clinical_heatmap_names = colnames(summary_data_merged())[(colnames(summary_data_merged()) %in% colnames(clinical_data()))]
        t = sapply(summary_data_merged() %>% select(all_of(clinical_heatmap_names)), function(x){return(length(unique(x)))})
        good = t[t > 1 & t < 10]
        
        selectInput("picked_clinical_factor", "Choose Annotation for Heatmap",
                    choices = clinical_heatmap_names, 
                    selected = names(good)[1])
        
    })
    
    heatmap_plot = reactive({
         validate(need(length(input$heatmap_selection) > 1, "Please select 2 or more markers....."),
                  need(ncol(summary_data_merged()) > 1, "wait for magic"))
        
        if(input$heatmap_transform == "none"){
            heatmap_data = summary_data_merged()
        }else if(input$heatmap_transform == "square_root"){
            heatmap_data = summary_data_merged()
            heatmap_data[,input$heatmap_selection] = sqrt(heatmap_data[,input$heatmap_selection])
        }
        
        
        
        pheat_map(summary_clinical_merge = heatmap_data,
                 markers = input$heatmap_selection,
                 clin_vars = input$picked_clinical_factor,
                 anno_clust = input$cluster_heatmap_annotation,
                 mark_clust = input$cluster_heatmap_Marker)
    })
    
    output$heatmap = renderPlot({
       heatmap_plot()
    })
    
    output$download_heatmap = downloadHandler(
        filename = function() { paste(Sys.Date(), '-heatmap.pdf', sep='') },
        
        content = function(file) {
            ggsave(file, plot = heatmap_plot(), device = "pdf",
                   width = 10, height = 7, units = 'in')
        }
    )
    
    pca_plot = reactive({
        validate(need(ncol(summary_data_merged()) > 0, "Please upload Summary and Clinical files....."),
                 need(length(input$heatmap_selection) > 1, "Please select 2 or more markers....."),
                 need(input$picked_clinical_factor !="", "Please select a clinical variable....."))
        
        if(is.null(summary_data_merged())){
            return()
        }
        
        if(input$heatmap_transform == "none"){
            pca_data = summary_data_merged()
        }else if(input$heatmap_transform == "square_root"){
            pca_data = summary_data_merged()
            pca_data[,input$heatmap_selection] = sqrt(pca_data[,input$heatmap_selection])
        }
        
        return(pca_plot_function(summary_clinical_merged = pca_data, markers = input$heatmap_selection, clin_vars = input$picked_clinical_factor))
        
        
    })
    
    output$pca = renderPlot({
        pca_plot()
    })
    
    output$download_pca = downloadHandler(
        filename = function () {paste(Sys.Date(), '-pca.pdf', sep='')},
        
        content = function(file){
            ggsave(file, plot = pca_plot(), device = "pdf",
                   width = 7, height = 7, units = "in")
        }
    )
    
#spatial
    output$choosePlotlyMarkers = renderUI({
        validate(need(ncol(spatial_data()) > 0, "Please wait while spatial data is loaded....."))
        if(is.null(spatial_data())){
            return()
        }
        
        ripleys_spatial_names = colnames(Filter(is.numeric, spatial_data()))
        
        whichcols = grep("^(?!.*(nucle|max|min|cytoplasm|area|path|image|Analysis|Object))",
                         ripleys_spatial_names,perl=TRUE,ignore.case = TRUE)
        tmp = ripleys_spatial_names[whichcols]
        acceptable_ripleys_names =  tmp[sapply(spatial_data()[,tmp],sum)>0]
        
        awesomeCheckboxGroup("plotly_selection", "Choose Markers for Spatial Plot",
                    choices = rev(acceptable_ripleys_names),
                    selected = acceptable_ripleys_names[grep("^(?=.*Opal)",
                                                             acceptable_ripleys_names, 
                                                             perl=TRUE)],
                    status = "info"
                    )
    })
    
    spatial_plot = reactive({
        validate(need(nrow(spatial_data()) > 0, "Please wait while things finish loading....."))
        
        spatial_plotly(data = spatial_data(), markers = input$plotly_selection) #
    })
    
    output$spatial_plotly = renderPlotly({
        spatial_plot()
    })
    
    # output$download_spatialPlotly = downloadHandler(
    #     filename = function() { paste(Sys.Date(), '-spatial_plot.pdf', sep='') },
    #     #https://github.com/plotly/orca#installation
    #     #conda install -c plotly plotly-orca
    #     content = function(file) {
    #         orca(file, plot = spatial_plot(), format = "pdf",width = 12*96, height = 10*96)
    #     }
    # )
    
    # MJ commented old code
    #output$choose_ripley = renderUI({
    #    
    #    ripleys_spatial_names = colnames(Filter(is.numeric, spatial_data()))
    #    
    #    whichcols = grep("^(?!.*(nucle|max|min|cytoplasm|area|path|image|Analysis|Object))",
    #                     ripleys_spatial_names,perl=TRUE,ignore.case = TRUE)
    #    tmp = ripleys_spatial_names[whichcols]
    #    acceptable_ripleys_names =  tmp[sapply(spatial_data()[,tmp],sum)>0]
    #    
    #    selectInput("ripleys_selection", "Choose Marker for Ripleys",
    #                choices = acceptable_ripleys_names,
    #                selected = acceptable_ripleys_names[1])
    #    
    #})
    
    # MJ New code to filter non-marker columns
    
    
    output$choose_ripley = renderUI({
      req(spatial_data())  # Ensure spatial data is uploaded
      
      # Extract only numeric columns that are potential markers
      ripleys_spatial_names = colnames(Filter(is.numeric, spatial_data()))
      
      # Remove non-marker columns (coordinates, IDs, etc.)
      exclude_columns = c("XMin", "XMax", "YMin", "YMax", "Xloc", "Yloc", "Object.Id")
      marker_choices = setdiff(ripleys_spatial_names, exclude_columns)
      
      # Ensure there are markers available
      if (length(marker_choices) == 0) {
        return("No valid marker columns found in the uploaded spatial file.")
      }
      
      # ✅ Wrap both inputs in a tagList to return them together
      tagList(
        selectInput("ripleys_selection", "Choose Marker for Ripley’s K",
                    choices = marker_choices,
                    #selected = marker_choices[1]),
                    selected = NULL),
        checkboxInput("permute_marker", "Permute marker labels (for control)", value = FALSE)
      )
    })
    
    
    # MJ commented the old code
    #ripley_data = reactive({
    #    validate(need(input$ripleys_selection !="", "Please wait while calculations are running....."),
    #             need(sum(spatial_data()[[input$ripleys_selection]]) > 5, "Please select a marker with more than 5 positive cells....."))
    #    #print(input$ripleysEstimator %in% c("M", "K", "L"))
    #    withProgress(message = "Calculating", value = 0,{
    #        incProgress(0.25, detail = "Ripley's K.....")
    #        ripley = Ripley(spatial_data(), input$ripleys_selection)
    #        incProgress(0.25 , detail = "Permuting CSR for Ripley's K.....")
    #        ripley2 = Permute_positives_r(data = spatial_data(), ripleys_list = ripley, cell_type = input$ripleys_selection)
    #        incProgress(0.25, detail = "Nearest Neighbor.....")
    #        g = NN_G(spatial_data(), input$ripleys_selection)
    #        incProgress(0.25 , detail = "Permuting CSR for Nearest Neighbor G.....")
    #        g2 = Permute_positives_g(data = spatial_data(), g_list = g, cell_type = input$ripleys_selection)
    #        incProgress(0.25, detail = "Completed!")
    #        #assign("data_list", list(ripley, g), envir = .GlobalEnv)
    #        return(list(ripley2, g2))
    #    })
    #})
    
    # MJ Added the new code to enforce data validation before calling Ripley's K
    ripley_data = reactive({
      req(spatial_data())  # Ensure spatial data is available
      
      print("Checking spatial data structure before filtering:")
      print(str(spatial_data()))
      
      validate(
        need(input$ripleys_selection %in% colnames(spatial_data()), "Selected marker not found in uploaded spatial data."),
        need(any(spatial_data()[[input$ripleys_selection]] == 1, na.rm = TRUE), "Selected marker has no positive cells. Please choose a different marker."),
        need(nrow(spatial_data()) > 5, "Not enough spatial points detected. Ensure your data has sufficient cells.")
      )
      
      withProgress(message = "Calculating", value = 0, {
        incProgress(0.25, detail = "Formatting spatial data...")
        
        # Use only Xloc and Yloc
        formatted_data = spatial_data() %>%
          filter(.[[input$ripleys_selection]] == 1) %>%  # Keep only positive marker cells
          select(Xloc, Yloc, input$ripleys_selection)  # Only keep necessary columns
        
        print("Checking formatted data before running Ripley's K:")
        print(str(formatted_data))
        
        # Stop if no points are left after filtering
        if (nrow(formatted_data) < 5) {
          showNotification("Not enough positive cells for the selected marker to run spatial analysis.", type = "error")
          return(NULL)
        }
        

        incProgress(0.25, detail = "Running Ripley's K...")
        ripley = Ripley(formatted_data, input$ripleys_selection)
        
        incProgress(0.25 , detail = "Permuting CSR for Ripley's K...")
        #ripley2 = Permute_positives_r(data = formatted_data, ripleys_list = ripley, cell_type = input$ripleys_selection)
        
        if (input$permute_marker) {
          message("Permutation mode activated: shuffling marker ", input$ripleys_selection)
          
          # ✅ Use correct argument name: marker_col instead of cell_type
          permuted_data <- Permute_positives_K(spatial_data(), marker_col = input$ripleys_selection)
          
          # ✅ Use permuted data to construct ppp object for Ripley’s K
          formatted_permuted_data = permuted_data %>%
            filter(.[[input$ripleys_selection]] == 1) %>%
            select(Xloc, Yloc, all_of(input$ripleys_selection))
          
          ppp_obj <- ppp(
            x = formatted_permuted_data$Xloc,
            y = formatted_permuted_data$Yloc,
            window = owin(
              xrange = range(formatted_permuted_data$Xloc, na.rm = TRUE),
              yrange = range(formatted_permuted_data$Yloc, na.rm = TRUE)
            )
          )
          
          ripley2 = list(
            as.data.frame(Kest(ppp_obj)),                       # observed K
            as.data.frame(envelope(ppp_obj, fun = Kest, nsim=100)), # CSR envelope
            NULL                                                # placeholder for perm data if needed
          )
          
        } else {
          ppp_obj <- ppp(
            x = formatted_data$Xloc,
            y = formatted_data$Yloc,
            window = owin(
              xrange = range(formatted_data$Xloc, na.rm = TRUE),
              yrange = range(formatted_data$Yloc, na.rm = TRUE)
            )
          )
          ripley2 = list(
            as.data.frame(Kest(ppp_obj)),
            as.data.frame(envelope(ppp_obj, fun = Kest, nsim = 100)),
            NULL
          )
        }
        
        
        
        incProgress(0.25, detail = "Nearest Neighbor Analysis...")
        g = NN_G(formatted_data, input$ripleys_selection)
        
        incProgress(0.25 , detail = "Permuting CSR for Nearest Neighbor G...")
        g2 = Permute_positives_g(data = formatted_data, g_list = g, cell_type = input$ripleys_selection)
        
        incProgress(0.25, detail = "Completed!")
        
        return(list(ripley2, g2))
      })
    })
    
    
    spatialStatsPlot = reactive({
        validate(need(input$ripleys_selection !="", "Please wait while calculations are running....."))
        if(input$ripleysEstimator %in% c("M", "K", "L")){
          Ripley_plot(ripley_data = ripley_data()[[1]], estimator = input$ripleysEstimator)
         # plot(ripley_data()[[1]])  # Uses default plotting for `envelope` object
        } else if(input$ripleysEstimator == "G"){
            G_plot(G_data = ripley_data()[[2]])
        }
    })
    
    output$ripleysPlot = renderPlot({
        spatialStatsPlot()
    })
    
    output$download_ripley = downloadHandler(
        filename = function() { paste(Sys.Date(), '-spatialStats_plot.pdf', sep='') },
        
        content = function(file) {
          ggsave(file, plot = spatialStatsPlot(), device = "pdf",width = 12, height = 10, units = "in")
          #pdf(file, width = 12, height = 10)
          #plot(ripley_data()[[1]])  # Direct base R plot
          #dev.off()
        }
    )
    
    
    output$download_ripley_data <- downloadHandler(
      filename = function() {
        paste0("ripley_data_", input$ripleys_selection, "_", Sys.Date(), ".csv")
      },
      content = function(file) {
        ripley_obj <- ripley_data()
        df <- NULL
        
        try({
          # ✅ Go one level deeper
          if (inherits(ripley_obj[[1]][[1]], "fv")) {
            df <- as.data.frame(ripley_obj[[1]][[1]])
          } else if (is.data.frame(ripley_obj[[1]][[1]])) {
            df <- ripley_obj[[1]][[1]]
          } else {
            print("Export failed: Unrecognized format in ripley_obj[[1]][[1]]")
          }
        }, silent = TRUE)
        
        if (is.null(df) || !nrow(df)) {
          shinyjs::alert("⚠️ Ripley K export data is empty.")
          return(NULL)
        }
        
        write.csv(df, file, row.names = FALSE)
      },
      contentType = "text/csv"
    )
    

    
    
    
    
    
#Getting started RMD rendering
    
    output$aboutitime <- renderUI({
        withMathJax({
            k = knitr::knit(input = "AboutiTIME.Rmd", quiet = T)
            HTML(markdown::markdownToHTML(k, fragment.only = T))
        })
    })
    
    output$getting_started <- renderUI({
        withMathJax({
            k = knitr::knit(input = "GettingStarted.Rmd", quiet = T)
            HTML(markdown::markdownToHTML(k, fragment.only = T))
        })
    })

})