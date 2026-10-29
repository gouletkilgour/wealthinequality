using CSV, DataFrames

# Writes output/wealth_inequality.html, an interactive chart comparing the wealth
# shares and Gini coefficient from sfs.jl (SFS), sfs_nbsa.jl (SFS + NBSA),
# sfs_nbsa_forbes.jl (SFS + NBSA + Forbes) and sfs_nbsa_forbes_cb.jl (SFS + NBSA + Forbes
# + Canadian Business), with a button for each measure, including the shares between the 50th
# and 80th and the 80th and 90th percentiles. Run those four scripts first.
# Apart from Plotly, which
# loads from its CDN, the page is self-contained, so it can be published as is.

const OUTDIR = joinpath(@__DIR__, "output")

# One line per source, drawn in this order
const SOURCES = ["SFS" => "sfs_wealth_inequality.csv",
                 "SFS + NBSA" => "sfs_nbsa_wealth_inequality.csv",
                 "SFS + NBSA + Forbes" => "sfs_nbsa_forbes_wealth_inequality.csv",
                 "SFS + NBSA + Forbes + Canadian Business" => "sfs_nbsa_forbes_cb_wealth_inequality.csv"]

json(x::Real) = string(x)
json(::Missing) = "null"
json(s::AbstractString) = "\"" * s * "\""
json(v::AbstractVector) = "[" * join(json.(v), ",") * "]"
json(d::AbstractDict) = "{" * join((json(k) * ":" * json(v) for (k, v) in d), ",") * "}"

# The share held between two percentiles, as the difference of two top shares: the top 50% less
# the top 20% is the share of the families between the 50th and 80th percentiles
const BANDS = ["p50_p80" => ("top_50pct", "top_20pct"), "p80_p90" => ("top_20pct", "top_10pct")]

# measure => (x = years, y = estimates)
function load_source(name, file)
    df = sort(CSV.read(joinpath(OUTDIR, file), DataFrame), :year)
    series = Dict(k.measure => (collect(g.year), collect(g.estimate)) for (k, g) in pairs(groupby(df, :measure)))
    for (band, (upper, lower)) in BANDS
        (years, a), (years_lower, b) = series[upper], series[lower]
        years == years_lower || error("$file: $upper and $lower cover different years")
        series[band] = (years, a .- b)
    end
    measures = Dict(k => Dict("x" => x, "y" => round.(y, digits = 4)) for (k, (x, y)) in series)
    return Dict("name" => name, "measures" => measures)
end

function main()
    data = json([load_source(name, file) for (name, file) in SOURCES])
    write(joinpath(OUTDIR, "wealth_inequality.html"), page(data))
    println("Wrote output/wealth_inequality.html")
end

page(data) = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Wealth Inequality in Canada</title>
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

    h1 { font-size: 1.6rem; margin-bottom: 0.35rem; }

    .subtitle { color: var(--muted); font-size: 0.95rem; margin-bottom: 1.5rem; }

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

    #chart { height: 520px; }

    .source { font-size: 0.75rem; color: var(--muted); }

    @media (max-width: 600px) {
      .page { padding-top: 1.5rem; }
      #chart { height: 440px; }
    }
  </style>
</head>
<body>

<div class="page">
  <h1>Wealth Inequality in Canada</h1>
  <p class="subtitle"></p>

  <section>
    <div class="section-label">Chart</div>
    <div class="chart-controls">
      <span class="chart-ctrl-label" id="measure-label">Measure:</span>
      <div class="measure-tabs" id="measure-tabs" role="group" aria-labelledby="measure-label"></div>
    </div>
    <div id="chart"></div>
  </section>
</div>

<script>
  const DATA = $(data);

  // row is the row of buttons the measure sits in
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

  // One colour and marker per source, in order. The first three colours are the Inequality
  // Dashboard's, and the magenta was chosen to stay distinguishable from them with
  // colour-vision deficiency on both themes. The fourth line is dashed, since it
  // coincides with the third in 2019 and 2023.
  const COLORS  = ["#636efa", "#ef553b", "#00aa7a", "#a840a0"];
  const SYMBOLS = ["circle", "diamond", "square", "triangle-up"];
  const DASHES  = ["solid", "solid", "solid", "dash"];

  const THEMES = {
    light: { paper: "#ffffff", plot: "#E5ECF6", grid: "#ffffff", text: "#444444" },
    dark:  { paper: "#15161a", plot: "#1e1f24", grid: "#33343a", text: "#c8c8c8" },
  };

  const MARGIN_T = 50, MARGIN_B = 70, MARGIN_L = 60;
  const darkMode = window.matchMedia("(prefers-color-scheme: dark)");
  let current = MEASURES[2];

  const isShare = m => m.key !== "gini";
  const series  = src => src.measures[current.key];
  const fmt     = v => v.toFixed(current.digits);

  function yRange() {
    const ys = DATA.flatMap(src => series(src).y);
    const lo = Math.min(...ys), hi = Math.max(...ys);
    const pad = 0.1 * (hi - lo || Math.abs(hi) || 1);
    return [lo - pad, hi + pad];
  }

  function buildTraces(t) {
    return DATA.map((src, i) => {
      const s = series(src);
      return {
        x: s.x,
        y: s.y,
        name: src.name,
        type: "scatter",
        mode: "lines+markers",
        line: { color: COLORS[i], width: 2, dash: DASHES[i] },
        marker: { color: COLORS[i], symbol: SYMBOLS[i], size: 10, line: { color: t.plot, width: 2 } },
        text: s.y.map(y => "<b>" + fmt(y) + (isShare(current) ? "%" : "") + "</b>  " + src.name),
        hovertemplate: "%{text}<extra></extra>",
      };
    });
  }

  // On narrow screens the title wraps onto two lines
  function buildLayout(t) {
    const el      = document.getElementById("chart");
    const narrow  = el.offsetWidth < 560;
    const marginT = narrow ? 75 : MARGIN_T;
    const plotH   = Math.max((el.offsetHeight || 480) - marginT - MARGIN_B, 80);
    const years   = series(DATA[0]).x;
    const range   = yRange();
    const sep     = narrow ? "<br>" : " – ";
    return {
      title: { text: isShare(current) ? "Share of Total Net Worth" + sep + current.label + " – Canada"
                                      : "Gini Coefficient of Net Worth" + sep + "Canada" },
      font: { color: t.text },
      xaxis: {
        title: { text: "Year" },
        tickmode: "array",
        tickvals: years,
        range: [years[0] - 1, years[years.length - 1] + 1],
        gridcolor: t.grid,
        spikedash: "solid",
        spikethickness: 1,
        spikecolor: t.text,
      },
      yaxis: {
        title: { text: isShare(current) ? "Share of Total Net Worth (%)" : "Gini Coefficient" },
        range: range,
        gridcolor: t.grid,
        zeroline: false,
      },
      legend: { x: 0.5, xanchor: "center", y: -(55 / plotH), orientation: "h" },
      margin: { l: MARGIN_L, b: MARGIN_B, r: 20, t: marginT },
      hovermode: "x unified",
      hoverlabel: { bgcolor: t.paper, font: { color: t.text } },
      paper_bgcolor: t.paper,
      plot_bgcolor: t.plot,
    };
  }

  function drawChart() {
    const t = darkMode.matches ? THEMES.dark : THEMES.light;
    Plotly.react("chart", buildTraces(t), buildLayout(t), { responsive: true });
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
    btn.setAttribute("aria-pressed", String(m === current));
    btn.addEventListener("click", () => {
      current = m;
      tabs.querySelectorAll(".measure-tab").forEach(b => b.setAttribute("aria-pressed", String(b === btn)));
      drawChart();
    });
    rows[m.row].appendChild(btn);
  });

  drawChart();
  darkMode.addEventListener("change", drawChart);

  // Recompute the legend position when the chart is resized.
  // Debounced to avoid a relayout -> resize -> relayout loop.
  let resizeTimer;
  new ResizeObserver(() => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(drawChart, 50);
  }).observe(document.getElementById("chart"));
</script>

</body>
</html>
"""

main()
