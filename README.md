
<!-- README.md is generated from README.Rmd. Please edit that file -->

# Bagged OutlierTrees

<!-- badges: start -->

[![R-CMD-check](https://github.com/RafaJPSantos/bagged.outliertrees/workflows/R-CMD-check/badge.svg)](https://github.com/RafaJPSantos/bagged.outliertrees/actions)
[![CRAN
status](https://www.r-pkg.org/badges/version/bagged.outliertrees)](https://CRAN.R-project.org/package=bagged.outliertrees)
<!-- badges: end -->

Bagged OutlierTrees is an explainable unsupervised outlier detection
method based on an ensemble implementation of the existing OutlierTree
procedure (Cortes, 2020). This implementation takes advantage of
bootstrap aggregating (bagging) to improve robustness by reducing the
possible masking effect and subsequent high variance (similarly to
Isolation Forest), hence the name “Bagged OutlierTrees”.

To learn more about the base procedure OutlierTree (Cortes, 2020),
please refer to
[&lt;arXiv:2001.00636&gt;](https://arxiv.org/abs/2001.00636) (the
corresponding GitHub repository can be found
[here](https://github.com/david-cortes/outliertree)). This repository
and its documentation are heavily based on the latter to ensure
consistency and ease-of-use between the packages.

## Important Note

Bagged OutlierTrees does not support missing values: if not taken care
of, rows with missing values are automatically removed while fitting the
model or predicting on new data.

## Installation

You can install the released version of `bagged.outliertrees` from
[CRAN](https://CRAN.R-project.org) with:

``` r
install.packages("bagged.outliertrees")
```

Or, install the development version of `bagged.outliertrees` from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("RafaJPSantos/bagged.outliertrees")
```

## Example

This is a basic example which shows you how to find outliers in the
[hypothyroid
dataset](http://archive.ics.uci.edu/ml/datasets/thyroid+disease):

``` r
library(bagged.outliertrees)

### example dataset with interesting outliers
data(hypothyroid)

### fit a Bagged OutlierTrees model
model <- bagged.outliertrees(hypothyroid,
  ntrees = 100,
  subsampling_rate = 0.75,
  z_outlier = 5,
  nthreads = 1
)

### use the fitted model to find outliers in the training dataset
outliers <- predict(model,
  newdata = hypothyroid,
  min_outlier_score = 0.5,
  nthreads = 1
)
```

``` r
### print the top-5 outliers in human-readable format
print(outliers, outliers_print = 5)
#> Reporting top 5 outliers [out of 28 found]
#> 
#> row [1438] - suspicious column: [FTI] - suspicious value: [394.495412844037]
#>  distribution: 99.93% <= [292.4685] - [mean: 109.7603] - [sd: 30.5332] - [norm. obs: 956]
#> 
#> 
#> row [623] - suspicious column: [age] - suspicious value: [455]
#>  distribution: 99.92% <= [91.8] - [mean: 53.2439] - [sd: 18.9342] - [norm. obs: 956]
#> 
#> 
#> row [1157] - suspicious column: [T3] - suspicious value: [7]
#>  distribution: 99.79% <= [5.4] - [mean: 2.0285] - [sd: 0.7776] - [norm. obs: 955]
#> 
#> 
#> row [745] - suspicious column: [T4U] - suspicious value: [2.12]
#>  distribution: 99.91% <= [1.7176] - [mean: 0.9977] - [sd: 0.1511] - [norm. obs: 698]
#>      [age] > [37.5789] (value: 87)
#> 
#> 
#> row [1425] - suspicious column: [FTI] - suspicious value: [161.290322580645]
#>  distribution: 98.99% <= [103.4513] - [mean: 62.781] - [sd: 18.0421] - [norm. obs: 85]
#>      [TT4] <= [98.6733] (value: 50)
```

# References

-   [outliertree](https://github.com/david-cortes/outliertree)
-   Cortes, David. “Explainable outlier detection through decision tree
    conditioning.” arXiv preprint
    [arXiv:2001.00636](https://arxiv.org/abs/2001.00636) (2020).
-   [GritBot software](https://www.rulequest.com/gritbot-info.html)
