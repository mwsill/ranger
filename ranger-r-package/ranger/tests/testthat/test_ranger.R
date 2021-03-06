library(ranger)
library(survival)
context("ranger")

## GenABEL
if (!requireNamespace("GenABEL", quietly = TRUE)) {
  stop("Package GenABEL is required for testing ranger completely. Please install it.", call. = FALSE)
} else {
  dat.gwaa <- readRDS("../test_gwaa.Rds")
  rg.gwaa <- ranger(CHD ~ ., data = dat.gwaa, verbose = FALSE, write.forest = TRUE)
}

test_that("classification gwaa rf is of class ranger with 14 elements", {
  expect_that(rg.gwaa, is_a("ranger"))
  expect_that(length(rg.gwaa), equals(14))
})

test_that("Matrix interface works for Probability estimation", {
  rf <- ranger(dependent.variable.name = "Species", data = data.matrix(iris), write.forest = TRUE, probability = TRUE)
  expect_that(rf$treetype, equals("Probability estimation"))
  expect_that(rf$forest$independent.variable.names, equals(colnames(iris)[1:4]))
})

test_that("Matrix interface prediction works for Probability estimation", {
  dat <- data.matrix(iris)
  rf <- ranger(dependent.variable.name = "Species", data = dat, write.forest = TRUE, probability = TRUE)
  expect_that(predict(rf, dat), not(throws_error()))
})

test_that("no warning if data.frame has two classes", {
  dat <- iris
  class(dat) <- c("data.frame", "data.table")
  expect_that(ranger(Species ~ ., data = dat, verbose = FALSE), 
              not(gives_warning()))
})

test_that("Error if sample fraction is 0 or >1", {
  expect_that(ranger(Species ~ ., iris, num.trees = 5, sample.fraction = 0), 
              throws_error())
  expect_that(ranger(Species ~ ., iris, num.trees = 5, sample.fraction = 1.1), 
              throws_error())
})

test_that("as.factor() in formula works", {
  n <- 20
  dt <- data.frame(x = runif(n), y = rbinom(n, 1, 0.5))
  expect_that(ranger(as.factor(y) ~ ., data = dt, num.trees = 5, write.forest = TRUE), 
              not(throws_error()))
})

test_that("If respect.unordered.factors=TRUE, regard characters as unordered", {
  n <- 20
  dt <- data.frame(x = sample(c("A", "B", "C", "D"), n, replace = TRUE), 
                   y = rbinom(n, 1, 0.5), 
                   stringsAsFactors = FALSE)
  
  set.seed(2)
  rf.char <- ranger(y ~ ., data = dt, num.trees = 5, min.node.size = n/2, respect.unordered.factors = TRUE)
  
  dt$x <- factor(dt$x, ordered = FALSE)
  set.seed(2)
  rf.fac <- ranger(y ~ ., data = dt, num.trees = 5, min.node.size = n/2, respect.unordered.factors = TRUE)
  
  expect_that(rf.char$prediction.error, equals(rf.fac$prediction.error))
})

test_that("If respect.unordered.factors=FALSE, regard characters as ordered", {
  n <- 20
  dt <- data.frame(x = sample(c("A", "B", "C", "D"), n, replace = TRUE), 
                   y = rbinom(n, 1, 0.5), 
                   stringsAsFactors = FALSE)
  
  set.seed(2)
  rf.char <- ranger(y ~ ., data = dt, num.trees = 5, min.node.size = n/2, respect.unordered.factors = FALSE)
  
  dt$x <- factor(dt$x, ordered = FALSE)
  set.seed(2)
  rf.fac <- ranger(y ~ ., data = dt, num.trees = 5, min.node.size = n/2, respect.unordered.factors = FALSE)
  
  expect_that(rf.char$prediction.error, equals(rf.fac$prediction.error))
})

test_that("maxstat splitting works for survival", {
  rf <- ranger(Surv(time, status) ~ ., veteran, splitrule = "maxstat")
  expect_that(rf, is_a("ranger"))
})

test_that("maxstat splitting, alpha out of range throws error", {
  expect_that(ranger(Surv(time, status) ~ ., veteran, splitrule = "maxstat", alpha = -1), 
              throws_error())
  expect_that(ranger(Surv(time, status) ~ ., veteran, splitrule = "maxstat", alpha = 2), 
              throws_error())
})

test_that("holdout mode holding out data with 0 weight", {
  weights <- rbinom(nrow(iris), 1, 0.5)
  rf <- ranger(Species ~ ., iris, num.trees = 5, importance = "permutation",  
               case.weights = weights, replace = FALSE, sample.fraction = 0.632*mean(weights), 
               holdout = TRUE, keep.inbag = TRUE)
  inbag <- data.frame(rf$inbag.counts)
  expect_that(all(inbag[weights == 0, ] == 0), is_true())
})

test_that("holdout mode uses holdout OOB data", {
  weights <- rbinom(nrow(iris), 1, 0.5)
  rf <- ranger(Species ~ ., iris, num.trees = 5, importance = "permutation",  
               case.weights = weights, replace = FALSE, sample.fraction = 0.632*mean(weights), 
               holdout = TRUE, keep.inbag = TRUE)
  expect_that(any(is.na(rf$predictions[weights == 0])), is_false())
  expect_that(all(is.na(rf$predictions[weights == 1])), is_true())
})

test_that("holdout mode not working if no weights", {
  expect_that(ranger(Species ~ ., iris, num.trees = 5, importance = "permutation", holdout = TRUE), 
              throws_error())
})

test_that("holdout mode: no OOB prediction if no 0 weights", {
  weights <- runif(nrow(iris))
  rf <- ranger(Species ~ ., iris, num.trees = 5, importance = "permutation",  
               case.weights = weights, replace = FALSE, 
               holdout = TRUE, keep.inbag = TRUE)
  expect_that(all(is.na(rf$predictions)), is_true())
})

test_that("Probability estimation works for empty classes", {
  expect_that(rf <- ranger(Species ~., iris[1:100,],  num.trees = 5, probability = TRUE), 
              not(throws_error()))
})

