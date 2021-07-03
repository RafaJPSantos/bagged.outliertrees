#' @importFrom dplyr "%>%"
#' @importFrom stats "predict"
#' @importFrom rlist "list.filter"
#' @importFrom data.table "data.table"
#' @importFrom data.table "rbindlist"
#' @importFrom data.table "setnames"
NULL

#' @title Predict method for Bagged OutlierTrees
#' @param object A Bagged OutlierTrees object as returned by `bagged.outliertrees`.
#' @param newdata A Data Frame in which to look for outliers according to the fitted model.
#' @param min_outlier_score Minimum outlier score to use when finding outliers.
#' @param nthreads Number of threads to use when predicting.
#' @param ... No use.
#' @return Will return a list of lists with the outliers and their
#' information (each row is an entry in the first list, with the same names as the rows in the input data
#' frame), which can be printed into a human-readable format after-the-fact through functions
#' `print`.
#' @seealso \link{bagged.outliertrees} \link{print.bagged.outlieroutputs}
#' @examples
#' library(bagged.outliertrees)
#'
#' ### example dataset with interesting outliers
#' data(hypothyroid)
#'
#' ### fit a Bagged OutlierTrees model
#' model <- bagged.outliertrees(hypothyroid,
#'   ntrees = 10,
#'   subsampling_rate = 0.5,
#'   z_outlier = 6,
#'   nthreads = 1
#' )
#'
#' ### use the fitted model to find outliers in the training dataset
#' outliers <- predict(model,
#'   newdata = hypothyroid,
#'   min_outlier_score = 0.5,
#'   nthreads = 1
#' )
#'
#' ### print the top-10 outliers in human-readable format
#' print(outliers, outliers_print = 10)
#' @export
predict.bagged.outliertrees <- function(object, newdata, min_outlier_score = 0.95, nthreads = parallel::detectCores(), ...) {
  suppressWarnings({
    i <- outlier_score <- row_name <- outliertree_id <- condition.column <- condition.value_this <- condition.comparison <- suspicious.column <- suspicious.value <- n <- suspicious.column_agg <- statistics.thr <- statistics.pct <- statistics.mean <- statistics.sd <- statistics.n_obs <- condition.value_comp <- NULL

    cl <- parallel::makeCluster(nthreads)
    doSNOW::registerDoSNOW(cl)
    on.exit(parallel::stopCluster(cl))

    pb <- utils::txtProgressBar(max = length(object), style = 3)
    progress <- function(n) utils::setTxtProgressBar(pb, n)
    opts <- list(progress = progress)


    newdata <- stats::na.omit(newdata)
    cols <- sapply(newdata, is.logical)
    newdata[, cols] <- lapply(newdata[, cols], as.character)

    bagged_predictions <- foreach::`%dopar%`(
      foreach::foreach(
        i = 1:length(object),
        .inorder = FALSE,
        .packages = c("outliertree", "rlist", "data.table"),
        .combine = "rbind",
        .options.snow = opts
      ),
      {
        predictions <- list.filter(
          predict(object[[i]], newdata, return_outliers = TRUE, outliers_print = FALSE),
          !is.na(outlier_score)
        )

        predictions_df <- c()
        for (j in names(predictions)) {
          ifelse(length(predictions[[j]]$conditions) > 0,
                 conditions <- rbindlist(predictions[[j]]$conditions, fill = TRUE),
                 conditions <- data.table("column" = NA, "value_this" = NA, "comparison" = NA, "value_comp" = NA)
          )
          setnames(
            conditions, c("column", "value_this", "comparison", "value_comp"),
            c("condition.column", "condition.value_this", "condition.comparison", "condition.value_comp"),
            skip_absent = TRUE
          )

          suspicous_value <- rbindlist(list(predictions[[j]]$suspicous_value))
          setnames(suspicous_value, c("column", "value"), c("suspicious.column", "suspicious.value"), skip_absent = TRUE)

          group_statistics <- rbindlist(list(predictions[[j]]$group_statistics))
          setnames(group_statistics, c("categs_common"), c("statistics.thr"), skip_absent = TRUE)
          setnames(group_statistics, c("categ_maj"), c("statistics.thr"), skip_absent = TRUE)
          setnames(group_statistics, c("pct_common", "pct_next_most_comm", "prior_prob", "n_obs"),
                   c("statistics.pct", "statistics.mean", "statistics.sd", "statistics.n_obs"),
                   skip_absent = TRUE
          )
          setnames(group_statistics, c("mean", "sd", "n_obs"), c("statistics.mean", "statistics.sd", "statistics.n_obs"),
                   skip_absent = TRUE
          )
          setnames(group_statistics, c("upper_thr", "pct_below"), c("statistics.thr", "statistics.pct"), skip_absent = TRUE)
          setnames(group_statistics, c("lower_thr", "pct_above"), c("statistics.thr", "statistics.pct"), skip_absent = TRUE)


          predictions_df <- rbindlist(
            list(
              predictions_df,
              cbind(
                data.table(outliertree_id = i, row_name = j),
                conditions,
                suspicous_value,
                group_statistics
              )
            ),
            fill = TRUE
          )
        }

        return(predictions_df)
      }
    )

    bagged_predictions <- bagged_predictions[, -c("decimals")]

    bagged_predictions <- bagged_predictions %>%

      # Calculate outlier score
      dplyr::group_by(row_name) %>%
      dplyr::mutate(outlier_score = round(dplyr::n_distinct(outliertree_id) / length(object), 2)) %>%

      # Filter minimum outlier score
      dplyr::filter(outlier_score >= min_outlier_score) %>%

      # Only relevant conditions (majority)
      dplyr::add_count(row_name, condition.column, condition.value_this, condition.comparison, suspicious.column, suspicious.value, outlier_score) %>%
      dplyr::filter(n >= (outlier_score * length(object)) / 2 | is.na(condition.column)) %>%

      # Only the most relevant suspicious column
      dplyr::group_by(row_name) %>%
      dplyr::mutate(suspicious.column_agg = paste(suspicious.column, collapse = ", ")) %>%
      dplyr::mutate(suspicious.column_agg = names(sort(table(unlist(strsplit(suspicious.column_agg, ", "))), decreasing = TRUE))[1]) %>%
      dplyr::filter(suspicious.column == suspicious.column_agg) %>%
      dplyr::group_by(row_name) %>%
      dplyr::mutate(statistics.thr = ifelse(!is.na(as.numeric(statistics.thr)),
                                            as.character(round(mean(as.numeric(statistics.thr)), 4)),
                                            paste(sort(unique(statistics.thr)), collapse = ", ")
      )) %>%
      dplyr::mutate(statistics.pct = as.character(round(mean(as.numeric(statistics.pct)), 4))) %>%
      dplyr::mutate(statistics.mean = as.character(round(mean(as.numeric(statistics.mean)), 4))) %>%
      dplyr::mutate(statistics.sd = as.character(round(mean(as.numeric(statistics.sd)), 4))) %>%
      dplyr::mutate(statistics.n_obs = as.character(round(mean(as.numeric(statistics.n_obs)), 0))) %>%

      # Mean statistics
      dplyr::group_by(
        row_name, condition.column, condition.value_this, condition.comparison, suspicious.column, suspicious.value,
        statistics.thr, statistics.pct, statistics.mean, statistics.sd, statistics.n_obs, outlier_score
      ) %>%
      dplyr::summarize(condition.value_comp = paste(condition.value_comp, collapse = ", ")) %>%
      dplyr::rowwise() %>%
      dplyr::mutate(condition.value_comp = ifelse(!is.na(as.numeric(unlist(strsplit(condition.value_comp, ", "))[1])),
                                                  as.character(round(mean(as.numeric(unlist(strsplit(condition.value_comp, ", ")))), 4)),
                                                  paste(sort(unique(unlist(strsplit(condition.value_comp, ", ")))), collapse = ", ")
      ))

    bagged_predictions[bagged_predictions == "NA"] <- NA

    bagged_predictions <- lapply(
      split(bagged_predictions[, -1], bagged_predictions$row_name),
      function(x) {
        list(
          suspicious_value = list(value = unique(x$suspicious.value), column = unique(x$suspicious.column)),
          group_statistics = list(
            thr = unique(x$statistics.thr), pct = unique(x$statistics.pct), mean = unique(x$statistics.mean),
            sd = unique(x$statistics.sd), n_obs = unique(x$statistics.n_obs)
          ),
          conditions = list(
            column = x$condition.column, value_this = x$condition.value_this,
            comparison = x$condition.comparison, value_comp = x$condition.value_comp
          ),
          outlier_score = unique(x$outlier_score)
        )
      }
    )

    bagged_predictions <- bagged_predictions[rlist::list.order(bagged_predictions, -outlier_score)]

    class(bagged_predictions) <- "bagged.outlieroutputs"
    return(bagged_predictions)
  })
}
