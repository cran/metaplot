#' Pack Something
#'
#' Pack Something.  Generic, with method for data.frame.
#'
#' @export
#' @param x object
#' @param ... other arguments
#' @seealso \code{\link{unpack}}
#' @family pack
pack <- function(x,...)UseMethod('pack')


#' Capture Scalar Column Metadata as Column Attributes
#'
#' Captures scalar column metadata (row values) as column attributes.  Excises rows with non-missing values of \code{meta}, converting column values to column attributes. Afterward, column classes are re-optimized using default behavior of \code{read.table}. It is an error if \code{meta} is not in \code{names(x)}.
#'
#' @param x data.frame
#' @param meta column in x giving names of attributes
#' @param as.is passed to \code{\link[utils]{read.table}}
#' @param ... ignored arguments
#' @export
#' @importFrom utils write.table read.table
#' @return data.frame
#' @family pack
#' @seealso \code{\link{unpack.data.frame}}
#' @return data.frame
#' @examples
#' foo <- data.frame(head(Theoph))
#' attr(foo$Subject, 'label') <-  'subject identifier'
#' attr(foo$Wt, 'label') <-  'weight'
#' attr(foo$Dose, 'label') <-  'dose'
#' attr(foo$Time, 'label') <-  'time'
#' attr(foo$conc, 'label') <-  'concentration'
#' attr(foo$Subject, 'guide') <-  '////'
#' attr(foo$Wt, 'guide') <-  'kg'
#' attr(foo$Dose, 'guide') <-  'mg/kg'
#' attr(foo$Time, 'guide') <-  'h'
#' attr(foo$conc, 'guide') <-  'mg/L'
#' unpack(foo, pos = 1)
#' unpack(foo, pos = 2)
#' unpack(foo, pos = 3)
#' unpack(foo, pos = 4)
#' bar <- unpack(foo)
#' pack(bar)
#' attributes(pack(bar)$Subject)
pack.data.frame <- function(x, meta = getOption('meta','meta'), as.is = TRUE, ...){
  stopifnot(meta %in% names(x))
  i <- x[[meta]]
  y <- x[!is.na(i),]
  x <- x[is.na(i),]
  x[[meta]] <- NULL
  if(nrow(y) == 0) return(x)
  # have at least one non-missing value of meta
  # now that meta is excised, refigure column classes
  dat <- character(0)
  z <- textConnection('dat','w',local = TRUE)
  write.table(x,  z)
  z <- textConnection(dat,'r')
  x <- read.table(z)
  close(z)
  # distribute metadata
  y$meta <- as.character(y$meta)
  if(any(duplicated(y$meta)))stop('found duplicate metadata names')
  for(attr in y$meta){
    for(col in names(x)){
      attr(x[[col]], attr) <- y[y$meta == attr, col]
    }
  }
  x
}

#' Unpack Something
#'
#' Unpack Something.  Generic, with method for data.frame.
#'
#' @family unpack
#' @export
#' @param x object
#' @param ... other arguments
#' @seealso pack
unpack <- function(x,...)UseMethod('unpack')


#' Express Scalar Column Attributes as Column Metadata
#'
#' Expresses scalar column attributes as column metadata (row values).  Column with name \code{meta} is created to hold names of attributes, if any. A transposed table (sorted by attribute name) of scalar column attribute values (coerced to character) is bound to the existing data.frame (the attributes themselves are removed from columns).  Bind position is controlled by \code{position} such that the intersection of new rows and column occurs in the corresponding corner, numbered clockwise from top-left. Resulting column classes are character. It is an error if \code{meta} is already in \code{names(x)}.
#'
#' @param x data.frame
#' @param meta column in result giving names of attributes
#' @param position 1 (top-left), 2 (top-right), 3 (bottom-right), or 4 (bottom-left)
#' @param ignore character: attributes to ignore
#' @param ... ignored arguments
#' @export
#' @return data.frame
#' @family pack
#' @seealso \code{\link{pack.data.frame}}
#' @importFrom dplyr bind_rows bind_cols
#' @return data.frame with all columns of class character
unpack.data.frame <- function(x, meta = getOption('meta','meta'), position = 1L, ignore = 'class', ...){
  stopifnot(length(position) == 1)
  stopifnot(length(meta) == 1)
  stopifnot(!meta %in% names(x))
  stopifnot(position %in% 1:4)
  stopifnot(is.character(ignore))
  y <- data.frame(x[0,],stringsAsFactors = FALSE)
  y[] <- lapply(y, as.character)
  y <- data.frame(t(y),stringsAsFactors = FALSE) # transpose
  for(col in names(x)){
    attr <- attributes(x[[col]])
    for(name in setdiff(names(attr),ignore)){
      val <- attr[[name]]
      if(length(val) == 1) {
        attr[[name]] <- NULL
        val <- as.character(val)
        y[col,name] <- val
      }
    }
    attributes(x[[col]]) <- attr
  }
  y <- data.frame(t(y), stringsAsFactors = FALSE) # back-transpose
  y[[meta]] <- row.names(y)
  x[] <- lapply(x, as.character)
  if(position %in% 1:2){ # meta rows top
    x <- bind_rows(y,x)
  } else{
    x <- bind_rows(x,y)
  }
  if(position %in% c(1,4)) x <- x[,union(meta, names(y))] #  meta col first
  x
}

#' Normalize a Folded Data Frame
#'
#' Convert folded data.frame to conventional format with column attributes. Scalar metadata is converted to column attributes. Other metadata left unfolded.
#' @export
#' @family pack
#' @return data.frame
#' @seealso \code{\link[fold]{fold.data.frame}}
#' @param x folded
#' @param tolower whether to coerce attribute names to lower case
#' @param ... other arguments
#' @examples
#' library(fold)
#' data(eventsf)
#' head(pack(eventsf))
#' attributes(pack(eventsf)$BLQ)
#'
pack.folded <- function(x, tolower = TRUE, ...){
  y <- unfold(x)
  for (col in names(y)){
    if(grepl('_',col)){
      target <- sub('_.*','',col)
      attrib <- sub('[^_]+_','',col)
      if(tolower) attrib <- tolower(attrib)
      if(target %in% names(y)){
        val <- unique(y[[col]])
        spar <- unique(y[,c(target,col)])
        spar <- spar[order(spar[[target]]),]
        spar[[target]] <- paste(spar[[target]]) # guarranteed nonmissing
        if(length(val) == 1){
          attr(y[[target]], attrib) <- val
        } else {
          if(length(spar[[target]]) == length(unique(spar[[target]]))){
            attr(y[[target]], attrib) <- encode(spar[[target]], labels = spar[[col]])
          }
        }
        y[[col]] <- NULL
      }

    }
  }
  y
}
#' Unpack a Folded Data Frame
#'
#' Convert folded data.frame to unpacked format with scalar metadata as row entries.
#' @export
#' @family unpack
#' @return data.frame
#' @seealso \code{\link[fold]{fold.data.frame}} \code{\link{pack.folded}}
#' @param x folded
#' @param tolower whether to coerce attribute names to lower case
#' @param ... other arguments
#' @examples
#' library(fold)
#' data(eventsf)
#' head(unpack(eventsf))
#'
unpack.folded <- function(x, tolower = TRUE, ...)unpack(pack(x, tolower = tolower, ...), ...)