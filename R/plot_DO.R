#' Create dissolved oxygen plots to display status and trend.
#'
#'
#' @param data Dataframe to determine status from. Must have 'excursion_cen' column generated.
#' @param seaKen Results of Seasonal Kendall Analysis
#' @param station The station to plot
#' @return dataframe of stations with sufficient data
#' @export
#' @examples
#' plot_DO(data = data.frame, seaKen, station)

plot_DO <- function(data, seaKen, station){
  # obtain data range limits for plotting
  result_max <- max(c(data$Result_cen, data$Do_crit_instant), na.rm = TRUE)
  xmin <- min(data$sample_datetime, na.rm = TRUE)
  xmax <- max(data$sample_datetime, na.rm = TRUE)
  ymin <- 0
  ymax <- ifelse(result_max > 25, result_max, 25)
  data$excursion <- if_else(((data$in_spawn == 1) & (data$spwn_exc_inst == 1)) | data$yr_exc_inst == 1, "Excursion", "Result") # change numeric value to descriptor

  # obtain plotting values for trend line if applicable
  if(station %in% seaKen$MLocID){
    slope <- seaKen[seaKen$MLocID == station & seaKen$Char_Name == "Dissolved oxygen (DO)", "slope"]
    x_delta <- as.numeric((xmax-xmin)/2)
    y_median <- median(data$Result_cen, na.rm = TRUE)
    sk_min <- y_median - x_delta*slope/365.25
    sk_max <- y_median + x_delta*slope/365.25
  }

  p <- ggplot(data)

  if(any(data$in_spawn == 1)){
    # Convert spawning dates to datetimes
    data$Start_spawn <- as.POSIXct(data$Start_spawn)
    data$End_spawn <- as.POSIXct(data$End_spawn)

    # create dataframe of spawning start/end dates, and relevant values for Spawning Periods and criteria lines
    spawn_zones <- unique(data[,c("Start_spawn", "End_spawn")])
    spawn_zones$next_start <- spawn_zones$Start_spawn + years(1)
    spawn_zones$ymin <- -Inf
    spawn_zones$ymax <- Inf
    spawn_zones$Do_crit_instant <- unique(data$Do_crit_instant)
    spawn_zones$spawn_crit <- 11
    # adjust plot limits to allow for first and last Spawning Periods to plot
    xmin <- min(xmin, min(spawn_zones$Start_spawn, na.rm = TRUE))
    xmax <- max(xmax, max(spawn_zones$End_spawn, na.rm = TRUE))

    # plot the shaded Spawning Periods
    p <- p + geom_rect(data = spawn_zones, aes(xmin=Start_spawn - lubridate::seconds(1), xmax= End_spawn + lubridate::seconds(1), ymin=ymin, ymax=ymax,
                                               # linetype = 'Spawning Period', shape = 'Spawning Period', color = 'Spawning Period',
                                               fill='Spawning Period'),
                       color = NA, alpha=.15, show.legend = c(fill=TRUE, linetype=FALSE, shape=FALSE, color=FALSE))

    # plot non-spawning criteria lines within non-spawning periods
    p <- p + geom_segment(data = spawn_zones,
                          aes(x=End_spawn - lubridate::seconds(1), xend=next_start + lubridate::seconds(1), y=Do_crit_instant, yend=Do_crit_instant,
                              color="Non-Spawning", linetype="Non-Spawning", shape="Non-Spawning"),
                          size = 1)

    # plot spawning criteria lines within Spawning Periods
    p <- p + geom_segment(data = spawn_zones,
                          aes(x=Start_spawn - lubridate::seconds(1), xend=End_spawn + lubridate::seconds(1), y = 11, yend = 11,
                              color="Spawning", linetype="Spawning", shape="Spawning"),
                          size = 1)

  } else if(any(!is.na(data$Do_crit_instant))){
    # plot non-spawining line across data if no Spawning Periods apply
    p <- p + geom_segment(aes(x=min(sample_datetime) - lubridate::seconds(1), xend=max(sample_datetime) + lubridate::seconds(1),
                              y=Do_crit_instant, yend=Do_crit_instant,
                              color="Non-Spawning", linetype="Non-Spawning", shape="Non-Spawning"))
  }

  # plot data with excursion colors
  p <- p + geom_point(aes(x=sample_datetime, y=Result_cen, color = excursion, linetype = excursion, shape = excursion)) +
    geom_point(aes(x=sample_datetime, y=DO_sat, linetype = excursion), color = "black", shape = 6) +
    ggtitle(paste(station, 'Dissolved Oxygen'), subtitle = paste(unique(data$StationDes))) +
    ylab("Dissolved oxygen (mg/l)") +
    xlab("Datetime")

  # plot the trend line if applicable
  if(station %in% seaKen$MLocID){
    p <- p + geom_segment(aes(x=xmin, xend=xmax, y=sk_min, yend=sk_max, color = "Trend", linetype = "Trend", shape = "Trend"))
  }

  # apply color, shape, line types, and range limits
  p <- p +
    scale_color_manual(name = "Legend",
                       values =    c('Excursion' = 'red', 'Result' = 'black', "Trend" = 'blue', "Spawning" = 'black', "Non-Spawning" = 'black')) +
    scale_linetype_manual(name = "Legend",
                          values = c('Excursion' = 0, 'Result' = 0, "Trend" = 1, "Spawning" = 2, "Non-Spawning" = 1)) +
    scale_shape_manual(name = "Legend",
                       values =    c('Excursion' = 16, 'Result' = 16, "Trend" = 32, "Spawning" = 32, "Non-Spawning" = 32)) +
    scale_fill_manual(name = "", values = c("Spawning Period" = 'black')) +
    ylim(c(ymin, ymax)) +
    xlim(c(xmin - lubridate::seconds(1), xmax + lubridate::seconds(1))) +
    scale_x_datetime(date_labels = "%b-%Y")+
    theme(legend.position="bottom", legend.direction = "horizontal", legend.box = "horizontal")

  return(p)
}
