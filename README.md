# shiny_workout

Build, save and run custom workout routines (bodyweight strength, HIIT, planks, mobility,
yoga, pilates, physiotherapy) in the browser. An R Shiny app compiled to WebAssembly with
[Shinylive](https://posit-dev.github.io/r-shinylive/) and hosted on GitHub Pages: no
server, everything runs locally in your browser.

Status: early development, see [PLAN.md](PLAN.md).

## Development

Requires R 4.6. Package versions are pinned with [renv](https://rstudio.github.io/renv/).

```r
renv::restore()                 # install pinned packages
shiny::runApp("app")            # run the app with regular Shiny
```

Build and preview the static (WebAssembly) site:

```sh
Rscript scripts/build_site.R    # run tests, export to _site/
python3 -m http.server 8008 --directory _site
```

Then open <http://127.0.0.1:8008>. Shinylive needs a browser with service workers.

Pushes to `main` are tested, exported and deployed to GitHub Pages by
`.github/workflows/deploy.yml`.

## License

Code: GPL-3.0. The exercise catalog (added in a later phase) combines public-domain and
CC-BY-SA sources and is published under CC-BY-SA 4.0; see `CREDITS.md` once it exists.
