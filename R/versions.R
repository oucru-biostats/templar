#' Knit different versions of a file
#'
#' @export
versions <- function(pull_solutions = TRUE, to_knit = NULL) {

  if (!isTRUE(getOption('knitr.in.progress'))) return()

  orig_file <- knitr::current_input()

  orig_text <- readLines(orig_file)

  # Drop versions() call
  orig_text <- orig_text %>%
    str_subset("versions\\([^\\)]*\\)", negate = TRUE)

  # Put a warning at the top about editing the sub-files
  top_alert <- c(glue("# Warning:  File created automatically from {orig_file}"),
                 "# Do NOT edit this file directly, as it may be overwritten.")

  end_yaml <- str_which(orig_text, "---")[2] - 1

  orig_text <- c(orig_text[1:end_yaml], top_alert, orig_text[-c(1:end_yaml)])

  orig_opts <- knitr::opts_current$get()


  # Pull out chunk label info pertaining to versions

  v_info <- get_version_info(orig_text)

  always_col_names <- c("chunk_starts", "chunk_ends", "is_versioned")


  # In case we only want to knit a few of the versions

  if (!is.null(to_knit)) {

    v_info <- v_info[, c(always_col_names, to_knit)]

  } else {

    to_knit <- setdiff(names(v_info), always_col_names)

  }

  # Do we want to use version = "solution" to create separate solutions?

  if (pull_solutions) {

    to_knit <- setdiff(to_knit, "solution")

    for (v in to_knit) {

      sol_name <- paste(v, "solution", sep = "-")

      v_info[[sol_name]] <- v_info[[v]] | v_info[["solution"]]

    }

    v_info <- v_info %>%
      select(-solution)

    to_knit <- setdiff(names(v_info), always_col_names)

  }


  for (v in to_knit) {

    temp = orig_text

    delete_me <- v_info$is_versioned & !v_info[,v]

    if (any(delete_me)) {

      lines_to_delete <- v_info[delete_me,c("chunk_starts", "chunk_ends")] %>%
        pmap( ~.x:.y) %>%
        unlist()

      temp = temp[-lines_to_delete]

    }

    # later: remove version options from doc

    new_name <- str_remove(orig_file, ".Rmd") %>% paste0("-", v, ".Rmd")

    options(knitr.duplicate.label = 'allow')

    writeLines(temp, new_name)

    rmarkdown::render(new_name, envir = new.env())

  }


  knitr::opts_current$set(orig_opts)

}


get_version_info <- function(source_text) {


  chunk_info <- data.frame(

    chunk_starts = source_text %>% str_which("```\\{"),
    chunk_ends = source_text %>% str_which("```$"),
    is_versioned = source_text %>%
      str_subset("```\\{") %>%
      str_detect("version\\s*=")

  )

  version_opts <- source_text %>%
    str_subset("```\\{") %>%
    str_subset("version\\s*=")

  version_opts_where <- version_opts %>%
    str_extract_all(",\\s*[:alpha:]+\\s*=\\s*") %>%
    map(~str_which(.x, "version"))

  chunk_versions <- version_opts  %>%
    str_split(",\\s*[:alpha:]+\\s*=\\s*") %>%
    map2_chr(version_opts_where, ~.x[[.y+1]]) %>%
    map(~unlist(str_extract_all(.x, '(?<=\\")[:alnum:]+')))

  all_versions <- chunk_versions %>% unlist() %>% unique()


  for (v in all_versions) {

    chunk_info[!chunk_info$is_versioned, v] <- TRUE
    chunk_info[chunk_info$is_versioned, v] <- chunk_versions %>% map_lgl(~any(str_detect(.x, v)))

  }

  return(chunk_info)

}