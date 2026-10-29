using CSV, DataFrames

# Writes output/wealth_inequality_quarterly.html and its published copy docs/quarterly.html: the
# quarterly series from sfs_nbsa_quarterly.jl, with the annual series from sfs_nbsa.jl at the
# survey quarters, and a button for each measure of the annual chart (chart.jl). Run those two
# scripts first. Apart from Plotly, which loads from its CDN, the page is self-contained.

const OUTDIR = joinpath(@__DIR__, "output")
const DOCSDIR = joinpath(@__DIR__, "docs")
const SURVEY_QUARTERS = Dict(2012 => "2012Q4", 2016 => "2016Q4", 2019 => "2019Q4", 2023 => "2023Q2")

json(x::Real) = string(x)
json(::Missing) = "null"
json(s::AbstractString) = "\"" * s * "\""
json(v::AbstractVector) = "[" * join(json.(v), ",") * "]"
json(d::AbstractDict) = "{" * join((json(k) * ":" * json(v) for (k, v) in d), ",") * "}"

# The share held between two percentiles, as the difference of two top shares, as in chart.jl
const BANDS = ["p50_p80" => ("top_50pct", "top_20pct"), "p80_p90" => ("top_20pct", "top_10pct")]

function main()
    q = CSV.read(joinpath(OUTDIR, "sfs_nbsa_quarterly_wealth_inequality.csv"), DataFrame)
    quarters = unique(q.quarter)
    quarterly = Dict(k.measure => collect(g.estimate) for (k, g) in pairs(groupby(q, :measure)))
    a = sort(CSV.read(joinpath(OUTDIR, "sfs_nbsa_wealth_inequality.csv"), DataFrame), :year)
    annual = Dict(k.measure => (collect(g.year), collect(g.estimate)) for (k, g) in pairs(groupby(a, :measure)))
    for (band, (upper, lower)) in BANDS
        quarterly[band] = quarterly[upper] .- quarterly[lower]
        (years, u), (years_lower, l) = annual[upper], annual[lower]
        years == years_lower || error("sfs_nbsa_wealth_inequality.csv: $upper and $lower cover different years")
        annual[band] = (years, u .- l)
    end

    data = json(Dict("quarters" => quarters, "surveys" => [SURVEY_QUARTERS[y] for y in sort(collect(keys(SURVEY_QUARTERS)))],
                     "quarterly" => Dict(k => round.(y, digits = 4) for (k, y) in quarterly),
                     "annual" => Dict(k => Dict("x" => [SURVEY_QUARTERS[y] for y in x], "y" => round.(y, digits = 4))
                                      for (k, (x, y)) in annual)))
    html = page(data)
    write(joinpath(OUTDIR, "wealth_inequality_quarterly.html"), html)
    write(joinpath(DOCSDIR, "quarterly.html"), html)
    println("Wrote output/wealth_inequality_quarterly.html and docs/quarterly.html")
end

page(data) = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Quarterly Wealth Inequality</title>
  <script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
  <style>
    :root {
      --bg: #ffffff;
      --text: #1a1a1a;
      --muted: #666666;
      --border: #e0e0e0;
      --accent: #2a5db0;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --bg: #15161a;
        --text: #ececec;
        --muted: #9a9a9a;
        --border: #33343a;
        --accent: #7aa2f7;
      }
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      background: var(--bg);
      color: var(--text);
      line-height: 1.5;
    }

    .page { max-width: 960px; margin: 0 auto; padding: 2.5rem 1rem 3rem; }

    h1 { font-size: 1.6rem; margin-bottom: 1.5rem; }

    section {
      background: var(--bg);
      border: 1px solid var(--border);
      border-radius: 6px;
      overflow: hidden;
      margin-bottom: 1.5rem;
    }

    .section-label {
      font-size: 0.7rem;
      font-weight: 600;
      letter-spacing: 0.08em;
      text-transform: uppercase;
      color: var(--muted);
      padding: 0.75rem 1.25rem;
      border-bottom: 1px solid var(--border);
    }

    .chart-controls {
      padding: 0.6rem 1rem;
      border-bottom: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      align-items: flex-start;
      gap: 0.5rem;
    }

    .chart-ctrl-label { font-size: 0.75rem; font-weight: 500; color: var(--muted); }

    .measure-tabs { display: flex; flex-direction: column; gap: 0.3rem; }

    .measure-row { display: flex; flex-wrap: wrap; gap: 0.3rem; }

    .measure-tab {
      font-family: inherit;
      font-size: 0.78rem;
      font-weight: 500;
      line-height: 1.5;
      padding: 0.2rem 0.55rem;
      border: 1.5px solid var(--accent);
      border-radius: 3px;
      background: transparent;
      color: var(--accent);
      cursor: pointer;
      transition: background 0.12s, color 0.12s;
    }

    .measure-tab[aria-pressed="true"] { background: var(--accent); color: var(--bg); }

    .measure-tab:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }

    .chart { height: 520px; }

    @media (max-width: 600px) {
      .page { padding-top: 1.5rem; }
      .chart { height: 440px; }
    }
  </style>
</head>
<body>

<div class="page">
  <h1>Quarterly Wealth Inequality in Canada</h1>

  <section>
    <div class="section-label">Chart</div>
    <div class="chart-controls">
      <span class="chart-ctrl-label" id="measure-label">Measure:</span>
      <div class="measure-tabs" id="measure-tabs" role="group" aria-labelledby="measure-label"></div>
    </div>
    <div class="chart" id="chart-top"></div>
  </section>
</div>

<script>
  const DATA = $(data);

  // The measures of the annual page; row is the row of buttons the measure sits in
  const MEASURES = [
    { key: "top_0_01pct", label: "Top 0.01%", digits: 1, row: 0 },
    { key: "top_0_1pct",  label: "Top 0.1%",  digits: 1, row: 0 },
    { key: "top_1pct",    label: "Top 1%",    digits: 1, row: 0 },
    { key: "top_5pct",    label: "Top 5%",    digits: 1, row: 0 },
    { key: "top_10pct",   label: "Top 10%",   digits: 1, row: 0 },
    { key: "top_20pct",   label: "Top 20%",   digits: 1, row: 0 },
    { key: "top_50pct",   label: "Top 50%",   digits: 1, row: 0 },
    { key: "p80_p90",     label: "Upper middle class (P80–P90)", digits: 1, row: 1 },
    { key: "p50_p80",     label: "Middle class (P50–P80)",       digits: 1, row: 1 },
    { key: "gini",        label: "Gini",      digits: 3, row: 2 },
  ];

  // The colours of the annual page: red for SFS + NBSA, blue for the annual series
  const RED = "#ef553b", BLUE = "#636efa";
  const NAMES = {
    quarterly: "SFS + NBSA, quarterly (families)",
    annual: "SFS + NBSA, annual (PBO method)",
  };

  const THEMES = {
    light: { paper: "#ffffff", plot: "#E5ECF6", grid: "#ffffff", text: "#444444", shade: "rgba(0,0,0,0.05)" },
    dark:  { paper: "#15161a", plot: "#1e1f24", grid: "#33343a", text: "#c8c8c8", shade: "rgba(255,255,255,0.05)" },
  };

  const MARGIN_T = 50, MARGIN_B = 70, MARGIN_L = 60;
  const darkMode = window.matchMedia("(prefers-color-scheme: dark)");
  const Q = DATA.quarters;
  let measure = MEASURES[2];

  const isShare = m => m.key !== "gini";
  const theme = () => darkMode.matches ? THEMES.dark : THEMES.light;

  // The quarterly line, with a large marker at each survey quarter
  function quarterlyTrace(t, y, fmt) {
    return {
      x: Q, y: y, name: NAMES.quarterly, type: "scatter", mode: "lines+markers",
      line: { color: RED, width: 2 },
      marker: { color: RED, symbol: "circle", line: { color: t.plot, width: 2 },
                size: Q.map(q => DATA.surveys.includes(q) ? 10 : 0) },
      text: y.map(v => "<b>" + fmt(v) + "</b>  " + NAMES.quarterly),
      hovertemplate: "%{text}<extra></extra>",
    };
  }

  function pointsTrace(t, s, name, color, symbol, mode, fmt) {
    return {
      x: s.x, y: s.y, name: name, type: "scatter", mode: mode,
      line: { color: color, width: 2 },
      marker: { color: color, symbol: symbol, size: 9, line: { color: t.plot, width: 2 } },
      text: s.y.map(v => "<b>" + fmt(v) + "</b>  " + name),
      hovertemplate: "%{text}<extra></extra>",
    };
  }

  function range(ys) {
    const lo = Math.min(...ys), hi = Math.max(...ys);
    const pad = 0.1 * (hi - lo || Math.abs(hi) || 1);
    return [lo - pad, hi + pad];
  }

  // Quarters resting on a single survey, before the first and after the last survey quarter
  function shading(t) {
    const first = Q.indexOf(DATA.surveys[0]), last = Q.indexOf(DATA.surveys[DATA.surveys.length - 1]);
    return [[-0.5, first], [last, Q.length - 0.5]].map(([x0, x1]) => ({
      type: "rect", xref: "x", yref: "paper", x0: x0, x1: x1, y0: 0, y1: 1,
      fillcolor: t.shade, line: { width: 0 }, layer: "below",
    }));
  }

  function layout(el, t, title, ytitle, yrange) {
    const narrow  = el.offsetWidth < 560;
    const marginT = narrow ? 75 : MARGIN_T;
    const plotH   = Math.max((el.offsetHeight || 480) - marginT - MARGIN_B, 80);
    const years   = Q.filter(q => q.endsWith("Q1") && (narrow ? +q.slice(0, 4) % 2 === 0 : true));
    return {
      title: { text: narrow ? title.replace(" – ", "<br>") : title },
      font: { color: t.text },
      xaxis: {
        type: "category",
        tickmode: "array",
        tickvals: years,
        ticktext: years.map(q => q.slice(0, 4)),
        range: [-0.5, Q.length - 0.5],
        gridcolor: t.grid,
        spikedash: "solid",
        spikethickness: 1,
        spikecolor: t.text,
      },
      yaxis: { title: { text: ytitle }, range: yrange, gridcolor: t.grid, zeroline: false },
      shapes: shading(t),
      legend: { x: 0.5, xanchor: "center", y: -(55 / plotH), orientation: "h" },
      margin: { l: MARGIN_L, b: MARGIN_B, r: 20, t: marginT },
      hovermode: "x unified",
      hoverlabel: { bgcolor: t.paper, font: { color: t.text } },
      paper_bgcolor: t.paper,
      plot_bgcolor: t.plot,
    };
  }

  function drawTop() {
    const t = theme(), el = document.getElementById("chart-top");
    const fmt = v => v.toFixed(measure.digits) + (isShare(measure) ? "%" : "");
    const y = DATA.quarterly[measure.key], annual = DATA.annual[measure.key];
    const title = isShare(measure) ? "Share of Total Net Worth – " + measure.label : "Gini Coefficient of Net Worth";
    Plotly.react(el, [quarterlyTrace(t, y, fmt), pointsTrace(t, annual, NAMES.annual, BLUE, "diamond", "markers", fmt)],
                 layout(el, t, title, isShare(measure) ? "Share of Total Net Worth (%)" : "Gini Coefficient",
                        range(y.concat(annual.y))),
                 { responsive: true });
  }

  const tabs = document.getElementById("measure-tabs");
  const rows = [];
  MEASURES.forEach(m => {
    if (!rows[m.row]) {
      rows[m.row] = document.createElement("div");
      rows[m.row].className = "measure-row";
      tabs.appendChild(rows[m.row]);
    }
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "measure-tab";
    btn.textContent = m.label;
    btn.setAttribute("aria-pressed", String(m === measure));
    btn.addEventListener("click", () => {
      measure = m;
      tabs.querySelectorAll(".measure-tab").forEach(b => b.setAttribute("aria-pressed", String(b === btn)));
      drawTop();
    });
    rows[m.row].appendChild(btn);
  });

  drawTop();
  darkMode.addEventListener("change", drawTop);

  // Recompute the legend position when the chart is resized.
  // Debounced to avoid a relayout -> resize -> relayout loop.
  let resizeTimer;
  new ResizeObserver(() => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(drawTop, 50);
  }).observe(document.getElementById("chart-top"));
</script>

</body>
</html>
"""

main()
