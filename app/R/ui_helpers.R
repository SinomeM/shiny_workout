placeholder_card <- function(title, text) {
  card(
    card_header(title),
    p(class = "text-muted mb-0", text)
  )
}

# Seconds as "m:ss", or "h:mm:ss" from one hour up. NA stays NA.
format_duration <- function(seconds) {
  s <- round(seconds)
  out <- ifelse(
    s >= 3600,
    sprintf("%d:%02d:%02d", s %/% 3600, (s %% 3600) %/% 60, s %% 60),
    sprintf("%d:%02d", s %/% 60, s %% 60)
  )
  out[is.na(s)] <- NA_character_
  out
}
