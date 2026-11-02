placeholder_card <- function(title, text) {
  card(
    card_header(title),
    p(class = "text-muted mb-0", text)
  )
}
