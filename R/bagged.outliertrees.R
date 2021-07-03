#' @importFrom outliertree "outlier.tree"
#' @importFrom dplyr "slice_sample"
NULL

#' @title Bagged OutlierTrees
#' @description Fit Bagged OutlierTrees ensemble model to normal data with perhaps some outliers.
#' @param df Data Frame with normal data that might contain some outliers. See details for allowed column types.
#' @param ntrees Controls the ensemble size (i.e. the number of OutlierTrees or bootstrapped training sets).
#' A large value is always recommended to build a robust and stable ensemble.
#' Should be decreased if training is taking too much time.
#' @param subsampling_rate Sub-sampling rate used for bootstrapping.
#' A small rate results in smaller bootstrapped training sets, which should not suffer from the masking effect.
#' This parameter should be adjusted given the size of the training data (perhaps a smaller value for large training data and conversely).
#' @param max_depth Maximum depth of the trees to grow. Can also pass zero, in which case it will only look
#' for outliers with no conditions (i.e. takes each column as a 1-d distribution and looks for outliers in
#' there independently of the values in other columns).
#' @param min_gain Minimum gain that a split has to produce in order to consider it (both in terms of looking
#' for outliers in each branch, and in considering whether to continue branching from them). Note that default
#' value for GritBot is 1e-6, with `gain_as_pct` = `FALSE`, but it's recommended to pass higher values (e.g. 1e-1) when using
#' `gain_as_pct` = `FALSE`.
#' @param z_norm Maximum Z-value (from standard normal distribution) that can be considered as a normal
#' observation. Note that simply having values above this will not automatically flag observations as outliers,
#' nor does it assume that columns follow normal distributions. Also used for categorical and ordinal columns
#' for building approximate confidence intervals of proportions.
#' @param z_outlier Minimum Z-value that can be considered as an outlier. There must be a large gap in the
#' Z-value of the next observation in sorted order to consider it as outlier, given by (z_outlier - z_norm).
#' Decreasing this parameter is likely to result in more observations being flagged as outliers.
#' Ignored for categorical and ordinal columns.
#' @param pct_outliers Approximate max percentage of outliers to expect in a given branch.
#' @param min_size_numeric Minimum size that branches need to have when splitting a numeric column. In order to look for
#' outliers in a given branch for a numeric column, it must have a minimum of twice this number
#' of observations.
#' @param min_size_categ Minimum size that branches need to have when splitting a categorical or ordinal column. In order to
#' look for outliers in a given branch for a categorical, ordinal, or boolean column, it must have a minimum of twice
#' this number of observations.
#' @param categ_split How to produce categorical-by-categorical splits. Options are:
#' \itemize{
#'   \item `"binarize"` : Will binarize the target variable according to whether it's equal to each present category
#'   within it (greater/less for ordinal), and split each binarized variable separately.
#'   \item `"bruteforce"` : Will evaluate each possible binary split of the categories (that is, it evaluates 2^n potential
#'   splits every time). Note that trying this when there are many categories in a column will result
#'   in exponential computation time that might never finish.
#'   \item `"separate"` : Will create one branch per category of the splitting variable (this is how GritBot handles them).
#' }
#' @param categ_outliers How to look for outliers in categorical variables. Options are:
#' \itemize{
#'   \item `"tail"` : Will try to flag outliers if there is a large gap between proportions in sorted order, and this
#'   gap is unexpected given the prior probabilities. Such criteria tends to sometimes flag too many
#'   uninteresting outliers, but is able to detect more cases and recognize outliers when there is no
#'   single dominant category.
#'   \item `"majority"` : Will calculate an equivalent to z-value according to the number of observations that do not
#'   belong to the non-majority class, according to formula '(n-n_maj)/(n * p_prior) < 1/z_outlier^2'.
#'   Such criteria  tends to miss many interesting outliers and will only be able to flag outliers in
#'   large sample sizes. This is the approach used by GritBot.
#' }
#' @param numeric_split How to determine the split point in numeric variables. Options are:
#' \itemize{
#'   \item `"mid"` : Will calculate the midpoint between the largest observation that goes to the '<=' branch and the
#'   smallest observation that goes to the '>' branch.
#'   \item `"raw"` : Will set the split point as the value of the largest observation that goes to the '<=' branch.
#' }
#' This doesn't affect how outliers are determined in the training data passed in `df`, but it does
#' affect the way in which they are presented and the way in which new outliers are detected when
#' using `predict`. `"mid"` is recommended for continuous-valued variables, while `"raw"` will
#' provide more readable explanations for counts data at the expense of perhaps slightly worse
#' generalizability to unseen data.
#' @param cols_ignore Vector containing columns which will not be split, but will be evaluated for usage
#' in splitting other columns. Can pass either a logical (boolean) vector with the same number of columns
#' as `df`, or a character vector of column names (must match with those of `df`).
#' Pass `NULL` to use all columns.
#' @param follow_all Whether to continue branching from each split that meets the size and gain criteria.
#' This will produce exponentially many more branches, and if depth is large, might take forever to finish.
#' Will also produce a lot more spurious outiers. Not recommended.
#' @param gain_as_pct Whether the minimum gain above should be taken in absolute terms, or as a percentage of
#' the standard deviation (for numerical columns) or shannon entropy (for categorical columns). Taking it in
#' absolute terms will prefer making more splits on columns that have a large variance, while taking it as a
#' percentage might be more restrictive on them and might create deeper trees in some columns. For GritBot
#' this parameter would always be `FALSE`. Recommended to pass higher values for `min_gain` when passing `FALSE`
#' here. Not that when `gain_as_pct` = `FALSE`, the results will be sensitive to the scales of variables.
#' @param nthreads Number of parallel threads to use when fitting the model.
#' @return An object with the fitted model that can be used to detect more outliers in new data.
#' @references \itemize{
#'   \item GritBot software: \url{https://www.rulequest.com/gritbot-info.html}
#'   \item Cortes, David. "Explainable outlier detection through decision tree conditioning." arXiv preprint arXiv:2001.00636 (2020).
#' }
#' @seealso \link{predict.bagged.outliertrees} \link{print.bagged.outlieroutputs} \link{hypothyroid}
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
bagged.outliertrees <- function(df, ntrees = 100L, subsampling_rate = 0.25, max_depth = 4L, min_gain = 1e-2, z_norm = 2.67, z_outlier = 8.0,
                                pct_outliers = 0.01, min_size_numeric = 25L, min_size_categ = 50L,
                                categ_split = "binarize", categ_outliers = "tail", numeric_split = "raw",
                                cols_ignore = NULL, follow_all = FALSE, gain_as_pct = TRUE,
                                nthreads = parallel::detectCores()) {
  cl <- parallel::makeCluster(nthreads)
  doSNOW::registerDoSNOW(cl)
  on.exit(parallel::stopCluster(cl))

  pb <- utils::txtProgressBar(max = ntrees, style = 3)
  progress <- function(n) utils::setTxtProgressBar(pb, n)
  opts <- list(progress = progress)

  df <- stats::na.omit(df)
  cols <- sapply(df, is.logical)
  df[, cols] <- lapply(df[, cols], as.character)

  bagged_model <- foreach::`%dopar%`(
    foreach::foreach(
      i = 1:ntrees,
      .packages = c("outliertree", "dplyr"),
      .inorder = FALSE,
      .options.snow = opts
    ),
    {
      outlier.tree(slice_sample(df, prop = subsampling_rate, replace = TRUE),
        max_depth = max_depth, min_gain = min_gain, z_norm = z_norm, z_outlier = z_outlier,
        pct_outliers = pct_outliers, min_size_numeric = min_size_numeric, min_size_categ = min_size_categ,
        categ_split = categ_split, categ_outliers = categ_outliers,
        cols_ignore = cols_ignore, follow_all = follow_all, gain_as_pct = gain_as_pct,
        outliers_print = FALSE,
        save_outliers = FALSE
      )
    }
  )

  class(bagged_model) <- "bagged.outliertrees"
  return(bagged_model)
}
