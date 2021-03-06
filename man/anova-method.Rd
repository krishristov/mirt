% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/SingleGroup-methods.R
\docType{methods}
\name{anova-method}
\alias{anova,DiscreteClass-method}
\alias{anova,MixedClass-method}
\alias{anova,MultipleGroupClass-method}
\alias{anova,SingleGroupClass-method}
\alias{anova-method}
\title{Compare nested models}
\usage{
\S4method{anova}{SingleGroupClass}(object, object2, verbose = TRUE)
}
\arguments{
\item{object}{an object of class \code{SingleGroupClass},
\code{MultipleGroupClass}, or \code{MixedClass}}

\item{object2}{a second model estimated from any of the mirt package estimation methods}

\item{verbose}{logical; print additional information to console?}
}
\description{
Compare nested models using likelihood ratio, AIC, BIC, etc.
}
\examples{
\dontrun{
x <- mirt(Science, 1)
x2 <- mirt(Science, 2)
anova(x, x2)
}
}

