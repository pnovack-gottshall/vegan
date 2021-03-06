### extract scores from rda, capscale and dbrda results. The two
### latter can have special features which are commented below. cca
### results are handled by scores.cca.
`scores.rda` <-
    function (x, choices = c(1, 2), display = c("sp", "wa", "cn"),
              scaling = "species", const, correlation = FALSE, ...)
{
    ## Check the na.action, and pad the result with NA or WA if class
    ## "exclude"
    if (!is.null(x$na.action) && inherits(x$na.action, "exclude"))
        x <- ordiNApredict(x$na.action, x)
    tabula <- c("species", "sites", "constraints", "biplot", 
                "centroids")
    names(tabula) <- c("sp", "wa", "lc", "bp", "cn")
    if (is.null(x$CCA)) 
        tabula <- tabula[1:2]
    display <- match.arg(display, c("sites", "species", "wa",
                                    "lc", "bp", "cn"),
                         several.ok = TRUE)
    if("sites" %in% display)
      display[display == "sites"] <- "wa"
    if("species" %in% display)
      display[display == "species"] <- "sp"
    take <- tabula[display]
    sumev <- x$tot.chi
    ## dbrda can have negative eigenvalues, but have scores only for
    ## positive
    eigval <- eigenvals(x)
    if (inherits(x, "dbrda") && any(eigval < 0))
        eigval <- eigval[eigval > 0]
    slam <- sqrt(eigval[choices]/sumev)
    nr <- if (is.null(x$CCA))
        nrow(x$CA$u)
    else
        nrow(x$CCA$u)
    ## const multiplier of scores
    if (missing(const))
        const <- sqrt(sqrt((nr-1) * sumev))
    ## canoco 3 compatibility -- canoco 4 is incompatible
    ##else if (pmatch(const, "canoco")) {
    ##    const <- (sqrt(nr-1), sqrt(nr))
    ##}
    ##
    ## const[1] for species, const[2] for sites and friends
    if (length(const) == 1) {
        const <- c(const, const)
    }
    ## in dbrda we only have scores for positive eigenvalues
    if (inherits(x, "dbrda"))
        rnk <- x$CCA$poseig
    else
        rnk <- x$CCA$rank
    sol <- list()
    ## process scaling; numeric scaling will just be returned as is
    scaling <- scalingType(scaling = scaling, correlation = correlation)
    if ("species" %in% take) {
        v <- cbind(x$CCA$v, x$CA$v)[, choices, drop=FALSE]
        if (scaling) {
            scal <- list(1, slam, sqrt(slam))[[abs(scaling)]]
            v <- sweep(v, 2, scal, "*")
            if (scaling < 0) {
                v <- sweep(v, 1, x$colsum, "/")
                v <- v * sqrt(sumev / (nr - 1))
            }
            v <- const[1] * v
        }
        if (nrow(v) > 0)
            sol$species <- v
        else
            sol$species <- NULL
    }
    if ("sites" %in% take) {
        wa <- cbind(x$CCA$wa, x$CA$u)[, choices, drop=FALSE]
        if (scaling) {
            scal <- list(slam, 1, sqrt(slam))[[abs(scaling)]]
            wa <- sweep(wa, 2, scal, "*")
            wa <- const[2] * wa
        }
        sol$sites <- wa
    }
    if ("constraints" %in% take) {
        u <- cbind(x$CCA$u, x$CA$u)[, choices, drop=FALSE]
        if (scaling) {
            scal <- list(slam, 1, sqrt(slam))[[abs(scaling)]]
            u <- sweep(u, 2, scal, "*")
            u <- const[2] * u
        }
        sol$constraints <- u
    }
    if ("biplot" %in% take && !is.null(x$CCA$biplot)) {
        b <- matrix(0, nrow(x$CCA$biplot), length(choices))
        b[, choices <= rnk] <- x$CCA$biplot[, choices[choices <= rnk]]
        colnames(b) <- c(colnames(x$CCA$u), colnames(x$CA$u))[choices]
        rownames(b) <- rownames(x$CCA$biplot)
        if (scaling) {
            scal <- list(slam, 1, sqrt(slam))[[abs(scaling)]]
            scal <- scal/max(scal) # scale proportionally to the "best" dim
            b <- sweep(b, 2, scal, "/")
        }
        sol$biplot <- b
    }
    if ("centroids" %in% take) {
        if (is.null(x$CCA$centroids))
            sol$centroids <- NA
        else {
            cn <- matrix(0, nrow(x$CCA$centroids), length(choices))
            cn[, choices <= rnk] <- x$CCA$centroids[, choices[choices <= rnk]]
            colnames(cn) <- c(colnames(x$CCA$u), colnames(x$CA$u))[choices]
            rownames(cn) <- rownames(x$CCA$centroids)
            if (scaling) {
                scal <- list(slam, 1, sqrt(slam))[[abs(scaling)]]
                cn <- sweep(cn, 2, scal, "*")
                cn <- const[2] * cn
            }
            sol$centroids <- cn
        }
    }
    ## Take care that scores have names
    if (length(sol)) {
        for (i in seq_along(sol)) {
            if (is.matrix(sol[[i]])) 
                rownames(sol[[i]]) <-
                    rownames(sol[[i]], do.NULL = FALSE, 
                             prefix = substr(names(sol)[i], 1, 3))
        }
    }
    ## Only one type of scores: return a matrix instead of a list
    if (length(sol) == 1) 
        sol <- sol[[1]]
    ## collapse const if both items identical
    if (identical(const[1], const[2]))
        const <- const[1]
    attr(sol, "const") <- const
    sol
}
