library(rvest)

get_def_season <- function(s) {

  cli::cli_process_start("Load DEF {.val {s}}")

  raw_url <- glue::glue("https://widgets.sports-reference.com/wg.fcgi?css=1&site",
                        "=pfr&url=%2Fyears%2F{s}%2Fdefense_advanced.htm&div=div_advanced_defense")

  raw_html <- read_html(raw_url)
  tbl_html <- html_element(raw_html, xpath = '//*[@id="advanced_defense"]')

  # The "data-append-csv" attribut of the dt tags inherits the pfr player ids
  ids <- tbl_html |>
    html_elements("td") |>
    html_attr("data-append-csv") |>
    na.omit()

  df <- html_table(tbl_html)
  names(df) <- as.character(df[1, ])

  suppressWarnings({
    out <- df |>
      janitor::clean_names() |>
      dplyr::filter(rk != "Rk") |>
      dplyr::mutate(
        pfr_id = ids,
        tm = nflreadr::clean_team_abbrs(tm),
        season = s,
        loaded = lubridate::today()
      ) |>
      dplyr::na_if("") |>
      dplyr::select(season, player, pfr_id, dplyr::everything(), -rk) |>
      dplyr::mutate(
        dplyr::across(
          .cols = tidyselect::contains("percent"),
          .fns = function(x) as.numeric(sub("%","",x)) / 100
        ),
        dplyr::across(
          .cols = !tidyselect::any_of(c("player", "pfr_id", "tm", "pos", "loaded")),
          .fns = as.numeric
        ),
        player = stringr::str_remove_all(player, "\\+|\\*"),
        pos = toupper(pos)
      )
  })

  cli::cli_process_done()

  out
}

df_advstats <- purrr::map_df(2018:nflreadr:::most_recent_season(), get_def_season)

nflversedata::nflverse_save(
  data_frame = df_advstats,
  file_name = "advstats_season_def",
  nflverse_type = "advanced defense season stats via PFR",
  release_tag = "pfr_advstats"
)
