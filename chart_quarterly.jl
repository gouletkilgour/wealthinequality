using CSV, DataFrames

# Writes output/wealth_inequality_quarterly.html and its published copy docs/quarterly.html: the
# quarterly series from sfs_nbsa_quarterly.jl (SFS + NBSA) and sfs_nbsa_forbes_quarterly.jl (SFS +
# NBSA + Forbes), drawn in the colours of the same series on the annual chart (chart.jl), with a
# button for each of its measures and the same toggle between share and average net worth in 2023
# dollars. Run those two scripts first. Apart from Plotly, which loads
# from its CDN, the page is self-contained.

const OUTDIR = joinpath(@__DIR__, "output")
const DOCSDIR = joinpath(@__DIR__, "docs")

json(x::Real) = string(x)
json(::Missing) = "null"
json(s::AbstractString) = "\"" * s * "\""
json(v::AbstractVector) = "[" * join(json.(v), ",") * "]"
json(d::AbstractDict) = "{" * join((json(k) * ":" * json(v) for (k, v) in d), ",") * "}"

# One line per source, drawn in this order, with the prefix of its _wealth_inequality.csv and
# _summary.csv
const SOURCES = ["SFS + NBSA" => "sfs_nbsa_quarterly",
                 "SFS + NBSA + Forbes" => "sfs_nbsa_forbes_quarterly"]

# The share held between two percentiles, as the difference of two top shares, as in chart.jl
const BANDS = ["p50_p80" => ("top_50pct", "top_20pct"), "p80_p90" => ("top_20pct", "top_10pct")]

# The fraction of families in each group, to turn a share into an average net worth, as in chart.jl
const GROUP_SIZES = Dict("top_0_01pct" => 0.0001, "top_0_1pct" => 0.001, "top_1pct" => 0.01,
                         "top_5pct" => 0.05, "top_10pct" => 0.10, "top_20pct" => 0.20,
                         "top_50pct" => 0.50, "p80_p90" => 0.10, "p50_p80" => 0.30,
                         "bottom_50pct" => 0.50)

# The CPI of each quarter, the average of its three months (Table 18-10-0004-01, all-items,
# 2002 = 100), to express average net worth in dollars of 2023, whose annual CPI is 157.1
const CPI = Dict(
    "2012Q1" => 121.2, "2012Q2" => 121.97, "2012Q3" => 121.77, "2012Q4" => 121.77,
    "2013Q1" => 122.3, "2013Q2" => 122.9, "2013Q3" => 123.17, "2013Q4" => 122.9,
    "2014Q1" => 124.0, "2014Q2" => 125.63, "2014Q3" => 125.73, "2014Q4" => 125.27,
    "2015Q1" => 125.33, "2015Q2" => 126.77, "2015Q3" => 127.23, "2015Q4" => 126.93,
    "2016Q1" => 127.27, "2016Q2" => 128.73, "2016Q3" => 128.8, "2016Q4" => 128.7,
    "2017Q1" => 129.7, "2017Q2" => 130.43, "2017Q3" => 130.57, "2017Q4" => 131.0,
    "2018Q1" => 132.37, "2018Q2" => 133.43, "2018Q3" => 134.07, "2018Q4" => 133.67,
    "2019Q1" => 134.5, "2019Q2" => 136.3, "2019Q3" => 136.67, "2019Q4" => 136.47,
    "2020Q1" => 136.93, "2020Q2" => 136.33, "2020Q3" => 137.03, "2020Q4" => 137.53,
    "2021Q1" => 138.9, "2021Q2" => 140.9, "2021Q3" => 142.6, "2021Q4" => 144.03,
    "2022Q1" => 147.0, "2022Q2" => 151.53, "2022Q3" => 152.8, "2022Q4" => 153.63,
    "2023Q1" => 154.57, "2023Q2" => 156.87, "2023Q3" => 158.43, "2023Q4" => 158.57,
    "2024Q1" => 158.97, "2024Q2" => 161.17, "2024Q3" => 161.67, "2024Q4" => 161.6,
    "2025Q1" => 162.6, "2025Q2" => 164.03, "2025Q3" => 164.87, "2025Q4" => 165.23,
    "2026Q1" => 166.1)
const BASE_CPI = 157.1

# The quarters a file covers, and measure => estimates and measure => average net worth in that order
function load_source(prefix)
    q = CSV.read(joinpath(OUTDIR, prefix * "_wealth_inequality.csv"), DataFrame)
    quarters = unique(q.quarter)
    series = Dict(k.measure => collect(g.estimate) for (k, g) in pairs(groupby(q, :measure)))
    for (band, (upper, lower)) in BANDS
        series[band] = series[upper] .- series[lower]
    end
    series["bottom_50pct"] = 100 .- series["top_50pct"]   # what the top 50% does not hold
    summary = CSV.read(joinpath(OUTDIR, prefix * "_summary.csv"), DataFrame)
    mean = getindex.(Ref(Dict(zip(summary.quarter, summary.mean_networth))), quarters) .* BASE_CPI ./ getindex.(Ref(CPI), quarters)
    averages = Dict(k => round.(Int, y ./ 100 .* mean ./ GROUP_SIZES[k]) for (k, y) in series if haskey(GROUP_SIZES, k))
    return quarters, Dict(k => round.(y, digits = 4) for (k, y) in series), averages
end

function main()
    loaded = [name => load_source(prefix) for (name, prefix) in SOURCES]
    quarters = first(last(loaded[1]))
    all(first(last(l)) == quarters for l in loaded) || error("the quarterly files cover different quarters")
    data = json(Dict("quarters" => quarters,
                     "series" => [Dict("name" => name, "measures" => m, "averages" => a)
                                  for (name, (_, m, a)) in loaded]))
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

    .measure-tab:disabled { opacity: 0.35; cursor: not-allowed; }

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
      <span class="chart-ctrl-label" id="view-label">Measure:</span>
      <div class="measure-row" id="view-tabs" role="group" aria-labelledby="view-label"></div>
      <span class="chart-ctrl-label" id="measure-label">Group:</span>
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
    { key: "bottom_50pct", label: "Bottom 50%", digits: 1, row: 0 },
    { key: "p80_p90",     label: "Upper middle class (P80–P90)", digits: 1, row: 1 },
    { key: "p50_p80",     label: "Middle class (P50–P80)",       digits: 1, row: 1 },
    { key: "gini",        label: "Gini",      digits: 3, row: 2 },
  ];

  // The colours of the same series on the annual page: red for SFS + NBSA, green for SFS + NBSA
  // + Forbes
  const COLORS = ["#ef553b", "#00aa7a"];

  // As on the annual page
  const VIEWS = [
    { key: "share",   label: "Share of total net worth" },
    { key: "average", label: "Average net worth" },
  ];

  const THEMES = {
    light: { paper: "#ffffff", plot: "#E5ECF6", grid: "#ffffff", text: "#444444" },
    dark:  { paper: "#15161a", plot: "#1e1f24", grid: "#33343a", text: "#c8c8c8" },
  };

  const MARGIN_T = 50, MARGIN_B = 70, MARGIN_L = 60, MARGIN_R = 40;   // MARGIN_R fits half of the last "2026 Q1" label
  const darkMode = window.matchMedia("(prefers-color-scheme: dark)");
  const Q = DATA.quarters;
  let measure = MEASURES[2];
  let view = VIEWS[0];

  const isShare = m => m.key !== "gini";
  const isAverage = () => view.key === "average";
  const values = src => (isAverage() ? src.averages : src.measures)[measure.key];

  // Average net worth is drawn in millions of dollars once the largest value reaches a million,
  // and in thousands below that, as on the annual page
  function money() {
    const hi = Math.max(...DATA.series.flatMap(values));
    return hi >= 1e6 ? { scale: 1e6, unit: "M", name: "millions", digits: hi >= 1e7 ? 1 : 2 }
                     : { scale: 1e3, unit: "K", name: "thousands", digits: 0 };
  }
  const theme = () => darkMode.matches ? THEMES.dark : THEMES.light;

  // One line per series, without markers
  function buildTraces(fmt, scale) {
    return DATA.series.map((src, i) => {
      const y = values(src).map(v => v / scale);
      return {
        x: Q, y: y, name: src.name, type: "scatter", mode: "lines",
        line: { color: COLORS[i], width: 2, dash: "solid" },
        text: y.map(v => "<b>" + fmt(v) + "</b>  " + src.name),
        hovertemplate: "%{text}<extra></extra>",
      };
    });
  }

  function range(ys) {
    const lo = Math.min(...ys), hi = Math.max(...ys);
    const pad = 0.1 * (hi - lo || Math.abs(hi) || 1);
    return [lo - pad, hi + pad];
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
        ticktext: years.map(q => q.slice(0, 4) + " " + q.slice(4)),
        range: [-0.5, Q.length - 0.5],
        gridcolor: t.grid,
        spikedash: "solid",
        spikethickness: 1,
        spikecolor: t.text,
      },
      yaxis: { title: { text: ytitle }, range: yrange, gridcolor: t.grid, zeroline: false },
      legend: { x: 0.5, xanchor: "center", y: -(55 / plotH), orientation: "h" },
      margin: { l: MARGIN_L, b: MARGIN_B, r: MARGIN_R, t: marginT },
      hovermode: "x unified",
      hoverlabel: { bgcolor: t.paper, font: { color: t.text } },
      paper_bgcolor: t.paper,
      plot_bgcolor: t.plot,
    };
  }

  function drawTop() {
    const t = theme(), el = document.getElementById("chart-top");
    const m = isAverage() ? money() : null;
    const fmt = m ? v => "\$" + v.toFixed(m.digits) + m.unit
                  : v => v.toFixed(measure.digits) + (isShare(measure) ? "%" : "");
    const traces = buildTraces(fmt, m ? m.scale : 1);
    const title = !isShare(measure) ? "Gini Coefficient of Net Worth"
                : (m ? "Average Net Worth – " : "Share of Total Net Worth – ") + measure.label;
    const ytitle = !isShare(measure) ? "Gini Coefficient"
                 : m ? "Average Net Worth (2023 \$, " + m.name + ")" : "Share of Total Net Worth (%)";
    Plotly.react(el, traces, layout(el, t, title, ytitle, range(traces.flatMap(tr => tr.y))), { responsive: true });
  }

  function button(label, onClick) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "measure-tab";
    btn.textContent = label;
    btn.addEventListener("click", () => { onClick(); syncButtons(); drawTop(); });
    return btn;
  }

  const viewTabs = document.getElementById("view-tabs");
  const tabs = document.getElementById("measure-tabs");
  const viewButtons = VIEWS.map(v => button(v.label, () => {
    view = v;
    if (isAverage() && !isShare(measure)) measure = MEASURES[2];
  }));
  viewButtons.forEach(btn => viewTabs.appendChild(btn));

  const rows = [];
  const measureButtons = MEASURES.map(m => {
    if (!rows[m.row]) {
      rows[m.row] = document.createElement("div");
      rows[m.row].className = "measure-row";
      tabs.appendChild(rows[m.row]);
    }
    const btn = button(m.label, () => { measure = m; });
    rows[m.row].appendChild(btn);
    return btn;
  });

  // The Gini has no average, so its button is disabled in the average view
  function syncButtons() {
    viewButtons.forEach((b, i) => b.setAttribute("aria-pressed", String(VIEWS[i] === view)));
    measureButtons.forEach((b, i) => {
      b.setAttribute("aria-pressed", String(MEASURES[i] === measure));
      b.disabled = isAverage() && !isShare(MEASURES[i]);
    });
  }

  syncButtons();
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
