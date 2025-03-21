
<!-- README.md is generated from README.Rmd. Please edit that file -->
# iTIME Extended

Extended version of iTIME with support for multiple spatial files, improved Ripley's K analysis, and bug fixes. Built by Manasa.

# iTIME <img src="figures/hex.png" align="right" height="139" />
iTIME (interactive Tumor Immune MicroEnvironment) is a `shiny`
application that creates interactive figures for examining spatial
organization of individual tumors and provide basic spatial and summary
information. This project was initiated as part of the [Moffitt Biodata
Club](https://www.biodataclub.org/) 2020 Hackathon.


#	R File	Code Segment	Description of Change	Purpose / Task
1	global.R	spatial_data() setup	Added logic to merge and validate multiple uploaded spatial CSVs. Added debug prints and formatted checks for consistency.	Enable multiple spatial file uploads and ensure consistent merging.
2	server.R	spatial_data, ripley_data, observeEvent(input$spatial_files)	Modified spatial_data to support dynamic merging and pre-validation (e.g., checking for XMin, YMin). Added robust ripley_data handling with more detailed validation and progress tracking.	Improve spatial stats tab with better error handling, clear visual feedback, and analysis validation.
3	server.R	output$ripleysPlot & related plotting logic	Updated to handle the new structure of formatted spatial data with Xloc and Yloc. Improved progress bars and error handling.	Improve spatial stats tab with better error handling, clear visual feedback, and analysis validation.
4	server.R	uiOutput("choose_ripley") & dropdown logic	Updated to reflect merged column choices from multiple uploaded files.	Enable multiple spatial file uploads and ensure consistent merging.
5	ui.R	fileInput("spatial_files")	Updated fileInput to allow multiple CSV uploads (multiple = TRUE). Added progress messages in UI.	Enable multiple spatial file uploads and ensure consistent merging.
6	ui.R	uiOutput("choose_ripley") UI segment	Added conditional UI to disable UI until file is uploaded and valid marker is selected.	Improve spatial stats tab with better error handling, clear visual feedback, and analysis validation.
7	ripleys_plot.R	Inside Ripley()	Added handling for Xloc, Yloc to ensure valid point pattern creation. Added additional progress messages and debug printing.	Improve spatial stats tab with better error handling, clear visual feedback, and analysis validation.
8	g_plot.R	In Permute_positives_g() and helper map call	Fixed the 'window not of class owin' issue by ensuring correct conversion of data to point pattern using as.ppp().	Fix crash when user uploads 0 or 1-row files / malformed inputs.
9	iTIME_plotly_legend_updated.R	Legend tweak	Minor aesthetic adjustments to preserve legend clarity when multiple spatial datasets are visualized.	Add clarity around available cell types / markers.
![image](https://github.com/user-attachments/assets/a0f07ae7-fb24-4d89-bf14-95a7cb919a5c)
