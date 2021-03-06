% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/M2.R
\name{M2}
\alias{M2}
\title{Compute M2 statistic}
\usage{
M2(obj, calcNull = TRUE, quadpts = NULL, Theta = NULL, impute = 0,
  CI = 0.9, residmat = FALSE, QMC = FALSE, suppress = 1, ...)
}
\arguments{
\item{obj}{an estimated model object from the mirt package}

\item{calcNull}{logical; calculate statistics for the null model as well?
Allows for statistics such as the limited information TLI and CFI}

\item{quadpts}{number of quadrature points to use during estimation. If \code{NULL},
a suitable value will be chosen based
on the rubric found in \code{\link{fscores}}}

\item{Theta}{a matrix of factor scores for each person used for imputation}

\item{impute}{a number indicating how many imputations to perform
(passed to \code{\link{imputeMissing}}) when there are missing data present. This requires
a precomputed \code{Theta} input. Will return a data.frame object with the mean estimates
of the stats and their imputed standard deviations}

\item{CI}{numeric value from 0 to 1 indicating the range of the confidence interval for
RMSEA. Default returns the 90\% interval}

\item{residmat}{logical; return the residual matrix used to compute the SRMSR statistic?}

\item{QMC}{logical; use quasi-Monte Carlo integration? Useful for higher dimensional models.
If \code{quadpts} not specified, 2000 nodes are used by default}

\item{suppress}{a numeric value indiciating which parameter residual dependency combinations
to flag as being too high. Absolute values for the standardized residuals greater than
this value will be returned, while all values less than this value will be set to NA.
Must be used in conjunction with the arguement \code{residmat = TRUE}}

\item{...}{additional arguments to pass}
}
\value{
Returns a data.frame object with the M2 statistic, along with the degrees of freedom,
  p-value, RMSEA (with 90\% confidence interval), SRMSR if all items were ordinal,
  and optionally the TLI and CFI model fit statistics
}
\description{
Computes the M2 (Maydeu-Olivares & Joe, 2006) statistic for dichotomous data and the
M2* statistic for polytomous data (collapsing over response categories for better stability;
see Cai and Hansen, 2013), as well as associated fit indices that are based on
fitting the null model.
}
\examples{
\dontrun{
dat <- expand.table(LSAT7)
(mod1 <- mirt(dat, 1))
M2(mod1)

#M2 imputed with missing data present (run in parallel)
dat[sample(1:prod(dim(dat)), 250)] <- NA
mod2 <- mirt(dat, 1)
mirtCluster()
Theta <- fscores(mod2, full.scores=TRUE)
M2(mod2, Theta=Theta, impute = 10)

}
}
\author{
Phil Chalmers \email{rphilip.chalmers@gmail.com}
}
\references{
Cai, L. & Hansen, M. (2013). Limited-information goodness-of-fit testing of
hierarchical item factor models. British Journal of Mathematical and Statistical
Psychology, 66, 245-276.

Maydeu-Olivares, A. & Joe, H. (2006). Limited information goodness-of-fit testing in
multidimensional contingency tables Psychometrika, 71, 713-732.
}
\keyword{fit}
\keyword{model}

