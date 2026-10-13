# One-line summary for the record view:
# "Submitted by A on 2026-10-13. Edited 3 times by B, C."
history_summary_ui <- function(h) {
  if (is.null(h) || nrow(h) == 0) return(shiny::p(class = "text-muted", "No history recorded."))
  created <- h[h$change_type == "INSERT", , drop = FALSE]
  edits   <- h[h$change_type == "UPDATE", , drop = FALSE]

  parts <- character()
  if (nrow(created)) {
    parts <- c(parts, sprintf("Submitted by %s on %s.",
                              orcid_link(created$changed_by_orcid[1], created$full_name[1]),
                              format(created$changed_at[1], "%Y-%m-%d")))
  }
  if (nrow(edits)) {
    eds <- unique(edits[, c("changed_by_orcid", "full_name")])
    links <- vapply(seq_len(nrow(eds)), function(i) {
      orcid_link(eds$changed_by_orcid[i], eds$full_name[i])
    }, character(1))
    parts <- c(parts, sprintf("Edited %d time%s by %s.", nrow(edits),
                              if (nrow(edits) == 1) "" else "s",
                              paste(links, collapse = ", ")))
  }
  shiny::p(shiny::HTML(paste(parts, collapse = " ")))
}

fmt_val <- function(x) {
  if (is.null(x)) "(empty)" else paste(as.character(unlist(x)), collapse = ", ")
}

# Long table of field-level changes for the "full history" view.
history_diff_table <- function(h) {
  empty <- data.frame(when = character(), who = character(), action = character(),
                      field = character(), old = character(), new = character(),
                      comment = character())
  if (is.null(h) || nrow(h) == 0) return(empty)

  rows <- lapply(seq_len(nrow(h)), function(i) {
    r <- h[i, , drop = FALSE]
    when <- format(r$changed_at, "%Y-%m-%d %H:%M")
    who  <- orcid_link(r$changed_by_orcid, r$full_name)
    comment <- if (is_blank(r$change_comment)) "" else r$change_comment

    if (r$change_type == "UPDATE") {
      old <- jsonlite::fromJSON(r$old_values, simplifyVector = FALSE)
      new <- jsonlite::fromJSON(r$new_values, simplifyVector = FALSE)
      flds <- names(new)
      data.frame(when = when, who = who, action = "Edited", field = flds,
                 old = vapply(flds, function(f) fmt_val(old[[f]]), character(1)),
                 new = vapply(flds, function(f) fmt_val(new[[f]]), character(1)),
                 comment = comment, row.names = NULL)
    } else {
      data.frame(when = when, who = who,
                 action = if (r$change_type == "INSERT") "Created" else "Deleted",
                 field = "", old = "", new = "", comment = comment)
    }
  })
  do.call(rbind, rows)
}
