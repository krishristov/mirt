#' Compute M2 statistic
#'
#' Computes the M2 (Maydeu-Olivares & Joe, 2006) statistic for dichotomous data and the
#' M2* statistic for polytomous data (collapsing over response categories for better stability;
#' see Cai and Hansen, 2013), as well as associated fit indices that are based on
#' fitting the null model.
#'
#' @return Returns a data.frame object with the M2 statistic, along with the degrees of freedom,
#'   p-value, RMSEA (with 90\% confidence interval), SRMSR if all items were ordinal,
#'   and optionally the TLI and CFI model fit statistics
#'
#' @aliases M2
#' @param obj an estimated model object from the mirt package
#' @param quadpts number of quadrature points to use during estimation. If \code{NULL},
#'   a suitable value will be chosen based
#'   on the rubric found in \code{\link{fscores}}
#' @param calcNull logical; calculate statistics for the null model as well?
#'   Allows for statistics such as the limited information TLI and CFI
#' @param Theta a matrix of factor scores for each person used for imputation
#' @param impute a number indicating how many imputations to perform
#'   (passed to \code{\link{imputeMissing}}) when there are missing data present. This requires
#'   a precomputed \code{Theta} input. Will return a data.frame object with the mean estimates
#'   of the stats and their imputed standard deviations
#' @param CI numeric value from 0 to 1 indicating the range of the confidence interval for
#'   RMSEA. Default returns the 90\% interval
#' @param residmat logical; return the residual matrix used to compute the SRMSR statistic?
#' @param QMC logical; use quasi-Monte Carlo integration? Useful for higher dimensional models.
#'   If \code{quadpts} not specified, 2000 nodes are used by default
#' @param suppress a numeric value indiciating which parameter residual dependency combinations
#'   to flag as being too high. Absolute values for the standardized residuals greater than
#'   this value will be returned, while all values less than this value will be set to NA.
#'   Must be used in conjunction with the arguement \code{residmat = TRUE}
#' @param ... additional arguments to pass
#' @author Phil Chalmers \email{rphilip.chalmers@@gmail.com}
#' @references
#' Cai, L. & Hansen, M. (2013). Limited-information goodness-of-fit testing of
#' hierarchical item factor models. British Journal of Mathematical and Statistical
#' Psychology, 66, 245-276.
#'
#' Maydeu-Olivares, A. & Joe, H. (2006). Limited information goodness-of-fit testing in
#' multidimensional contingency tables Psychometrika, 71, 713-732.
#' @keywords model fit
#' @export M2
#' @examples
#' \dontrun{
#' dat <- expand.table(LSAT7)
#' (mod1 <- mirt(dat, 1))
#' M2(mod1)
#'
#' #M2 imputed with missing data present (run in parallel)
#' dat[sample(1:prod(dim(dat)), 250)] <- NA
#' mod2 <- mirt(dat, 1)
#' mirtCluster()
#' Theta <- fscores(mod2, full.scores=TRUE)
#' M2(mod2, Theta=Theta, impute = 10)
#'
#' }
M2 <- function(obj, calcNull = TRUE, quadpts = NULL, Theta = NULL, impute = 0, CI = .9,
               residmat = FALSE, QMC=FALSE, suppress = 1, ...){

    fn <- function(collect, obj, Theta, ...){
        dat <- imputeMissing(obj, Theta)
        tmpobj <- obj
        tmpobj@Data$data <- dat
        if(is(obj, 'MultipleGroupClass')){
            for(g in 1L:length(obj@Data$groupNames))
                tmpobj@pars[[g]]@Data$data <- dat[obj@Data$groupNames[g] == obj@Data$group,
                                                  , drop=FALSE]
        }
        return(M2(tmpobj, ...))
    }

    #if MG loop
    if(is(obj, 'MixedClass'))
        stop('mixedmirt objects not yet supported')
    if(QMC && is.null(quadpts)) quadpts <- 2000L
    discrete <- FALSE
    if(is(obj, 'DiscreteClass')){
        discrete <- TRUE
        class(obj) <- 'MultipleGroupClass'
        calcNull <- FALSE
    }
    if(any(is.na(obj@Data$data))){
        if(impute == 0 || is.null(Theta))
            stop('Fit statistics cannot be computed when there are missing data. Pass suitable
                 Theta and impute arguments to compute statistics following multiple
                 data inputations')
        collect <- vector('list', impute)
        collect <- myLapply(collect, fn, obj=obj, Theta=Theta, calcNull=calcNull,
                            quadpts=quadpts)
        ave <- SD <- collect[[1L]]
        ave[ave!= 0] <- SD[SD!=0] <- 0
        for(i in 1L:impute)
            ave <- ave + collect[[i]]
        ave <- ave/impute
        for(i in 1L:impute)
            SD <- (ave - collect[[i]])^2
        SD <- sqrt(SD/impute)
        ret <- rbind(ave, SD)
        rownames(ret) <- c('stats', 'SD_stats')
        return(ret)
    }
    alpha <- (1 - CI)/2
    if(is(obj, 'MultipleGroupClass')){
        pars <- obj@pars
        ngroups <- length(pars)
        ret <- vector('list', length(pars))
        for(g in 1L:ngroups){
            attr(pars[[g]], 'MG') <- g
            pars[[g]]@bfactor <- obj@bfactor
            if(discrete){
                pars[[g]]@Prior <- list(obj@Prior[[g]])
                pars[[g]]@Theta <- obj@Theta
            }
            pars[[g]]@Data <- list(data=obj@Data$data[obj@Data$group == obj@Data$groupName[g], ],
                                   mins=obj@Data$mins)
            ret[[g]] <- M2(pars[[g]], calcNull=FALSE, quadpts=quadpts, residmat=residmat,
                           discrete=discrete, QMC=QMC)
        }
        if(residmat){
            names(ret) <- obj@Data$groupNames
            return(ret)
        }
        newret <- list()
        newret$M2 <- numeric(ngroups)
        names(newret$M2) <- obj@Data$groupNames
        for(g in 1L:ngroups)
            newret$M2[g] <- ret[[g]]$M2
        newret$Total.M2 <- sum(newret$M2)
        Tsum <- 0
        for(g in 1L:ngroups) Tsum <- Tsum + ret[[g]]$nrowT
        newret$df <- Tsum - obj@nest
        newret$p <- 1 - pchisq(newret$Total.M2, newret$df)
        newret$RMSEA <- rmsea(X2=newret$Total.M2, df=newret$df, N=obj@Data$N)
        RMSEA.90_CI <- RMSEA.CI(newret$Total.M2, newret$df, obj@Data$N,
                                ci.lower=alpha, ci.upper=1-alpha)
        newret[[paste0("RMSEA_", alpha*100)]]  <- RMSEA.90_CI[1L]
        newret[[paste0("RMSEA_", (1-alpha)*100)]] <- RMSEA.90_CI[2L]
        if(!is.null(ret[[1L]]$SRMSR)){
            SRMSR <- numeric(ngroups)
            for(g in 1L:ngroups)
                SRMSR[g] <- ret[[g]]$SRMSR
            names(SRMSR) <- paste0(obj@Data$groupNames, '.SRMSR')
            SRMSR <- as.list(SRMSR)
        } else SRMSR <- numeric(0)
        if(calcNull){
            null.mod <- try(multipleGroup(obj@Data$data, 1, group=obj@Data$group,
                                          TOL=1e-3, technical=list(NULL.MODEL=TRUE),
                                          verbose=FALSE))
            null.fit <- M2(null.mod, calcNull=FALSE)
            newret$TLI <- (null.fit$Total.M2 / null.fit$df - newret$Total.M2/newret$df) /
                (null.fit$Total.M2 / null.fit$df - 1)
            newret$CFI <- 1 - (newret$Total.M2 - newret$df) /
                (null.fit$Total.M2 - null.fit$df)
            if(newret$CFI > 1) newret$CFI <- 1
            if(newret$CFI < 0 ) newret$CFI <- 0
        }
        M2s <- as.numeric(newret$M2)
        names(M2s) <- paste0(obj@Data$groupNames, '.M2')
        newret$M2 <- NULL
        if(length(SRMSR)){
            names(SRMSR) <- paste0(obj@Data$groupNames, '.SRMSR')
            newret <- data.frame(as.list(M2s), newret, SRMSR)
        } else newret <- data.frame(as.list(M2s), newret)
        rownames(newret) <- 'stats'
        return(newret)
    }

    if(!all(sapply(obj@pars, class) %in% c('dich', 'graded', 'gpcm', 'nominal',
                                           'ideal', 'lca', 'GroupPars')))
       stop('M2 currently only supported for \'dich\', \'ideal\', \'graded\',
            \'gpcm\', and \'nominal\' objects')
    dots <- list(...)
    discrete <- FALSE
    if(!is.null(dots$discrete)){
        discrete <- dots$discrete
        calcNull <- ifelse(discrete, FALSE, calcNull)
    }
    ret <- list()
    group <- if(is.null(attr(obj, 'MG'))) 1 else attr(obj, 'MG')
    nitems <- ncol(obj@Data$data)
    if(any(is.na(obj@Data$data)))
        stop('M2 can not be calulated for data with missing values.')
    adj <- obj@Data$mins
    dat <- t(t(obj@Data$data) - adj)
    N <- nrow(dat)
    p  <- colMeans(dat)
    cross <- crossprod(dat, dat)
    p <- c(p, cross[lower.tri(cross)]/N)
    prodlist <- attr(obj@pars, 'prodlist')
    K <- obj@K
    pars <- obj@pars
    if(is.null(quadpts))
        quadpts <- select_quadpts(obj@nfact)
    estpars <- c()
    for(i in 1L:(nitems+1L))
        estpars <- c(estpars, pars[[i]]@est)
    itemloc <- obj@itemloc
    bfactorlist <- obj@bfactor
    if(!discrete){
        theta <- as.matrix(seq(-(.8 * sqrt(quadpts)), .8 * sqrt(quadpts), length.out = quadpts))
#         if(is.null(bfactorlist$Priorbetween[[1L]])){
        if(TRUE){ #TODO bifactor reduction possibilty? Not as effective at computing marginals
            prior <- Priorbetween <- sitems <- specific <- NULL
            Theta <- if(QMC) qnorm(sfsmisc::QUnif(quadpts, min=0, max=1, p=obj@nfact, leap=409), sd=2)
                else thetaComb(theta, obj@nfact)
            gstructgrouppars <- ExtractGroupPars(pars[[nitems+1L]])
            Prior <- mirt_dmvnorm(Theta,gstructgrouppars$gmeans,
                                           gstructgrouppars$gcov)
            Prior <- Prior/sum(Prior)
            if(length(prodlist) > 0L)
                Theta <- prodterms(Theta, prodlist)
        } else {
            Theta <- obj@Theta
            prior <- bfactorlist$prior[[group]]; Priorbetween <- bfactorlist$Priorbetween[[group]]
            sitems <- bfactorlist$sitems; specific <- bfactorlist$specific;
            Prior <- bfactorlist$Prior[[group]]
        }
    } else {
        Theta <- obj@Theta
        Prior <- obj@Prior[[1L]]
    }
    E1 <- E11 <- numeric(nitems)
    E2 <- matrix(NA, nitems, nitems)
    EIs <- EIs2 <- E11s <- matrix(0, nrow(Theta), nitems)
    DP <- matrix(0, nrow(Theta), length(estpars))
    wherepar <- c(1L, numeric(nitems))
    ind <- 1L
    for(i in 1L:nitems){
        x <- extract.item(obj, i)
        EIs[,i] <- expected.item(x, Theta, min=0L)
        tmp <- ProbTrace(x, Theta)
        E11s[,i] <- colSums((1L:ncol(tmp)-1L)^2 * t(tmp))
        for(j in ncol(tmp):2L)
            tmp[,j-1L] <- tmp[,j] + tmp[,j-1L]
        cfs <- c(0,1)
        if(K[i] > 2L) cfs <- c(cfs, 2:(ncol(tmp)-1L) * 2 - 1)
        EIs2[,i] <- t(cfs %*% t(tmp))
        tmp <- length(x@parnum)
        DP[ ,ind:(ind+tmp-1L)] <- dP(x, Theta)
        ind <- ind + tmp
        wherepar[i+1L] <- ind
    }
    ind <- 1L
    for(i in 1L:nitems){
        E1[i] <- sum(EIs[,i] * Prior)
        E11[i] <- sum(E11s[,i] * Prior)
        for(j in 1L:nitems){
            if(i >= j){
                E2[i,j] <- sum(EIs[,i] * EIs[,j] * Prior)
                ind <- ind + 1L
            }
        }
    }
    e <- c(E1, E2[lower.tri(E2)])
    if(all(sapply(obj@pars, class) %in% c('dich', 'graded', 'gpcm', 'GroupPars'))){
        E2[is.na(E2)] <- 0
        E2 <- E2 + t(E2)
        diag(E2) <- E11
        R <- cov2cor(cross/N - outer(colMeans(dat), colMeans(dat)))
        Kr <- cov2cor(E2 - outer(E1, E1))
        SRMSR <- sqrt( sum((R[lower.tri(R)] - Kr[lower.tri(Kr)])^2) / sum(lower.tri(R)))
        if(residmat){
            ret <- matrix(NA, nrow(R), nrow(R))
            ret[lower.tri(ret)] <- R[lower.tri(R)] - Kr[lower.tri(Kr)]
            colnames(ret) <- rownames(ret) <- colnames(obj@Data$dat)
            if(suppress < 1)
                ret[lower.tri(ret)][abs(ret[lower.tri(ret)]) < suppress] <- NA
            return(ret)
        }
    } else SRMSR <- NULL
    delta1 <- matrix(0, nitems, length(estpars))
    delta2 <- matrix(0, length(p) - nitems, length(estpars))
    ind <- 1L
    offset <- pars[[1L]]@parnum[1L] - 1L
    for(i in 1L:nitems){
        dp <- colSums(DP[ , wherepar[i]:(wherepar[i+1L]-1L), drop=FALSE] * Prior)
        delta1[i, pars[[i]]@parnum - offset] <- dp
        for(j in 1L:nitems){
            if(i < j){
                dp <- colSums(DP[ , wherepar[i]:(wherepar[i+1L]-1L), drop=FALSE] * EIs[,j] * Prior)
                delta2[ind, pars[[i]]@parnum - offset] <- dp
                dp <- colSums(DP[ , wherepar[j]:(wherepar[j+1L]-1L), drop=FALSE] * EIs[,i] * Prior)
                delta2[ind, pars[[j]]@parnum - offset] <- dp
                ind <- ind + 1L
            }
        }
    }
    delta <- rbind(delta1, delta2)
    delta <- delta[, estpars, drop=FALSE]
    Xi2els <- .Call('buildXi2els', nrow(delta1), nrow(delta2), nitems, EIs, EIs2, Prior)
    Xi2 <- rbind(cbind(Xi2els$Xi11, Xi2els$Xi12), cbind(t(Xi2els$Xi12), Xi2els$Xi22))
    tmp <- qr.Q(qr(delta), complete=TRUE)
    if((ncol(delta) + 1L) > ncol(tmp))
        stop('M2 cannot be calulated since df is too low')
    deltac <- tmp[,(ncol(delta) + 1L):ncol(tmp), drop=FALSE]
    C2 <- deltac %*% solve(t(deltac) %*% Xi2 %*% deltac) %*% t(deltac)
    M2 <- N * t(p - e) %*% C2 %*% (p - e)
    ret$M2 <- M2
    if(is.null(attr(obj, 'MG'))){
        df <- length(p) - obj@nest
        ret$df <- df
        ret$p <- 1 - pchisq(M2, ret$df)
        ret$RMSEA <- rmsea(X2=M2, df=ret$df, N=N)
        RMSEA.90_CI <- RMSEA.CI(M2, df, N, ci.lower=alpha, ci.upper=1-alpha)
        ret[[paste0("RMSEA_", alpha*100)]]  <- RMSEA.90_CI[1L]
        ret[[paste0("RMSEA_", (1-alpha)*100)]] <- RMSEA.90_CI[2L]
        if(calcNull){
            null.mod <- try(mirt(obj@Data$data, 1, TOL=1e-3, technical=list(NULL.MODEL=TRUE),
                                 verbose=FALSE))
            null.fit <- M2(null.mod, calcNull=FALSE, quadpts=quadpts)
            ret$TLI <- (null.fit$M2 / null.fit$df - ret$M2/ret$df) /
                (null.fit$M2 / null.fit$df - 1)
            ret$CFI <- 1 - (ret$M2 - ret$df) / (null.fit$M2 - null.fit$df)
            if(ret$CFI > 1) ret$CFI <- 1
            if(ret$CFI < 0) ret$CFI <- 0
        }
    } else {
        ret$nrowT <- length(p)
    }
    if(!is.null(SRMSR)) ret$SRMSR <- SRMSR
    ret <- as.data.frame(ret)
    rownames(ret) <- 'stats'
    return(ret)
}
