#manasa



Permute_positives_K = function(data, marker_col, sims = 100) {
  message("Running permutation for marker: ", marker_col)

  data_pos = data[data[[marker_col]] == 1, ]
  data_neg = data[data[[marker_col]] == 0, ]

  if (nrow(data_pos) == 0 | nrow(data_neg) == 0) {
    warning("Insufficient positive or negative cells for permutation.")
    return(data)
  }

  data$perm_marker = 0
  all_idxs = sample(nrow(data), nrow(data_pos))
  data$perm_marker[all_idxs] = 1

  # Replace the original marker column with permuted one
  data[[marker_col]] = data$perm_marker
  data$perm_marker = NULL

  return(data)
}


#alex 
Permute_positives_r = function(data, ripleys_list, cell_type, sims = 10){
  data = data %>%
    #dplyr::mutate(xloc = (XMin + XMax)/2,
     #             yloc = (YMin + YMax)/2)
    dplyr::mutate(xloc = Xloc,
                 yloc = Yloc)   
  win = spatstat.geom::convexhull.xy(x = data$xloc,
                                     y = data$yloc)
  grid = expand.grid(cell_type, 1:sims) %>%
    dplyr::mutate(Var1 = as.character(Var1))
  
  data2 = data %>%
    tidyr::pivot_longer(cols = tidyselect::all_of(cell_type), 
                        names_to = "Marker",
                        values_to = "Positive")
  rs = ripleys_list[[1]]$r
  
  cat("Permuting Ripley's K() CSR.....\n")
  perms = purrr::map_df(.x = 1:nrow(grid), 
                        ~{
                          cat(paste0(.x, ", "))
                          data_new = data2 %>%
                            dplyr::mutate(Positive = sample(Positive, nrow(data2), replace = F))
                          data_pos = data_new %>%
                            dplyr::filter(Positive == 1)
                          K_obs = spatstat.geom::ppp(x = data_pos$xloc,
                                                     y = data_pos$yloc,
                                                     window = win) %>%
                            spatstat.core::Kest(r=rs) %>%
                            data.frame() %>%
                            dplyr::select(-border) %>%
                            dplyr::mutate(iter = .x)
                          return(K_obs)
                        })
  
  ripleys_list$perm = perms %>%
    dplyr::group_by(r) %>%
    summarise(perm_trans = mean(trans), perm_iso = mean(iso))
  return(ripleys_list)
}



#christelle

Ripley <- function(data, cell_type, alpha=0.05, sims = 100)
{
  #location2 <- data %>% mutate(Xloc = (XMin + XMax)/2, Yloc = (YMin + YMax)/2)
  location2 <- data %>% mutate(Xloc = Xloc, Yloc = Yloc)  # Use precomputed values
  loc <- location2 %>% select(c(Xloc, Yloc, cell_type)) %>% filter(.[[cell_type]] == 1)
  n = nrow(loc)
  w <- convexhull.xy(x = loc$Xloc, y = loc$Yloc)
  po_pp <- ppp(x= loc$Xloc, y= loc$Yloc, window = w)
  
  est <- as.data.frame(Kest(po_pp)) %>% select(-border)
  set.seed(333)
  EL = envelope(po_pp[w], Kest, nsim=sims) %>% data.frame() #variability of the point process under the null hypothesis of CSR
  
  return(list(est, EL))
}

Ripley_plot = function(ripley_data = NULL, estimator){
  
  if (!is.list(ripley_data) || !inherits(ripley_data[[1]], "data.frame")) {
    stop("Invalid input: ripley_data must be a list of data.frames or 'fv' object.")
  }
  
  est = ripley_data[[1]]
  EL  = ripley_data[[2]]
  perm = ripley_data[[3]]  # May be NULL
  
  if (estimator == "K") {
    est2 <- est %>% pivot_longer(2:ncol(.), names_to = "type", values_to = "value")
    ylabel = "Ripley's K"
    
    if (!is.null(perm)) {
      perm2 <- perm %>% pivot_longer(2:ncol(.), names_to = "type", values_to = "value")
      plot_data = bind_rows(est2, perm2)
    } else {
      plot_data = est2
    }
    
  } else if (estimator == "L") {
    est2 <- est %>% pivot_longer(2:ncol(.), names_to = "type", values_to = "value") %>%
      mutate(value = sqrt(value / pi) - r)
    EL <- EL %>% mutate(
      lo = sqrt(lo / pi) - r,
      hi = sqrt(hi / pi) - r
    )
    ylabel = expression(paste(H^"*","(r) = L(r) - r"))
    
    if (!is.null(perm)) {
      perm2 <- perm %>%
        pivot_longer(2:ncol(.), names_to = "type", values_to = "value") %>%
        mutate(value = sqrt(value / pi) - r)
      plot_data = bind_rows(est2, perm2)
    } else {
      plot_data = est2
    }
    
  } else {  # "M"
    est2 <- est %>% pivot_longer(2:ncol(.), names_to = "type", values_to = "value") %>%
      mutate(value = value / (pi * r^2))
    EL <- EL %>% mutate(
      lo = lo / (pi * r^2),
      hi = hi / (pi * r^2)
    )
    ylabel = "Marcon's M"
    
    if (!is.null(perm)) {
      perm2 <- perm %>%
        pivot_longer(2:ncol(.), names_to = "type", values_to = "value") %>%
        mutate(value = value / (pi * r^2))
      plot_data = bind_rows(est2, perm2)
    } else {
      plot_data = est2
    }
  }
  
  # Final plot
  p = ggplot() +
    geom_line(aes(x = r, y = value, color = type), data = plot_data) +
    scale_color_manual(
      name = "Estimate",
      labels = c("Theoretical CSR", "Permuted Isotropic CSR",
                 "Permuted Translational CSR", "Observed Isotropic", "Observed Translational"),
      breaks = c("theo", "perm_trans", "perm_iso", "iso", "trans"),
      values = c("theo" = 'black', "perm_trans" = "green", "perm_iso" = "orange",
                 "iso" = 'red', "trans" = 'blue')
    ) +
    geom_ribbon(data = EL, aes(x = r, ymin = lo, ymax = hi), inherit.aes = FALSE, alpha = 0.4, color = NA) +
    ylab(ylabel) +
    theme_classic(base_size = 20)
  
  if (estimator == "M") {
    return(p + ylim(0, max(EL$hi[-(1:10)], 3)))
  } else {
    return(p)
  }
}


#Ripley(data = df, cell_type = "CD3..CD8.")
