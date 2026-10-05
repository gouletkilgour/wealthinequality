using CSV, DataFrames

# Writes output/wealth_inequality.html, an interactive chart comparing the wealth
# shares and Gini coefficient from sfs.jl (SFS), sfs_nbsa.jl (SFS + NBSA),
# sfs_nbsa_forbes.jl (SFS + NBSA + Forbes) and sfs_nbsa_forbes_cb.jl (SFS + NBSA + Forbes
# + Canadian Business), with a button for each measure. Run those four scripts first.
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

# measure => (x = years, y = estimates)
function load_source(name, file)
    df = sort(CSV.read(joinpath(OUTDIR, file), DataFrame), :year)
    measures = Dict(k.measure => Dict("x" => g.year, "y" => round.(g.estimate, digits = 4))
                    for (k, g) in pairs(groupby(df, :measure)))
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
      align-items: center;
      gap: 0.5rem;
      flex-wrap: wrap;
    }

    .chart-ctrl-label { font-size: 0.75rem; font-weight: 500; color: var(--muted); }

    .measure-tabs { display: flex; flex-wrap: wrap; gap: 0.3rem; }

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


    details { padding: 0.75rem 1.25rem; border-top: 1px solid var(--border); }

    summary { cursor: pointer; font-size: 0.85rem; color: var(--accent); }

    table {
      width: 100%;
      max-width: 32rem;
      border-collapse: collapse;
      margin-top: 0.75rem;
      font-size: 0.85rem;
      font-variant-numeric: tabular-nums;
    }

    caption { text-align: left; font-size: 0.8rem; color: var(--muted); padding-bottom: 0.4rem; }

    th, td { padding: 0.3rem 0 0.3rem 1.5rem; text-align: right; border-bottom: 1px solid var(--border); }

    th:first-child { padding-left: 0; text-align: left; }

    tbody th { font-weight: 400; }

    .prose { padding: 1.5rem 1.75rem; line-height: 1.7; font-size: 0.93rem; }

    .prose h2 { font-size: 1rem; font-weight: 600; margin-bottom: 0.5rem; }

    .prose p { margin-bottom: 1rem; }

    .source { font-size: 0.75rem; color: var(--muted); }

    @media (max-width: 600px) {
      .page { padding-top: 1.5rem; }
      #chart { height: 440px; }
      .prose { padding: 1.25rem 1rem; }
    }
  </style>
</head>
<body>

<div class="page">
  <h1>Wealth Inequality in Canada</h1>
  <p class="subtitle">Survey of Financial Security, alone, aligned with the National Balance Sheet Accounts, and with the Forbes and Canadian Business rich lists added, 2012&ndash;2023</p>

  <section>
    <div class="section-label">Chart</div>
    <div class="chart-controls">
      <span class="chart-ctrl-label" id="measure-label">Measure:</span>
      <div class="measure-tabs" id="measure-tabs" role="group" aria-labelledby="measure-label"></div>
    </div>
    <div id="chart"></div>
    <details>
      <summary>Data table</summary>
      <table id="data-table"></table>
    </details>
  </section>

  <section>
    <div class="section-label">About this data</div>
    <div class="prose">
      <h2>Measures</h2>
      <p>
        A wealth share is the percentage of all family net worth held by the wealthiest families. For example, if the top 1% share is 14%, the richest 1% of families together hold 14% of total net worth. The Gini coefficient summarizes inequality across the whole distribution: 0 means every family has the same net worth, and higher values mean wealth is more concentrated.
      </p>

      <h2>SFS</h2>
      <p>
        The Survey of Financial Security (SFS) is Statistics Canada's household survey of wealth and income. These estimates use its Public Use Microdata Files for 2012, 2016, 2019 and 2023, weighted by the survey weights. Net worth includes employer pension plans valued on a termination basis.
      </p>

      <h2>SFS + NBSA</h2>
      <p>
        Following Appendix A.1 of PBO (2020), <em>Estimating the Top Tail of the Family Wealth Distribution in Canada</em>, each family's financial assets, non-financial assets and debts are scaled so that the SFS totals match the household sector of the National Balance Sheet Accounts (NBSA), at market value. Each category is scaled by one adjustment factor per year: the NBSA total divided by the SFS weighted total.
      </p>

      <h2>SFS + NBSA + Forbes</h2>
      <p>
        Following Appendices A.2 to A.4 of PBO (2020), Canadians on the Forbes billionaires list are added to the NBSA-aligned SFS as one family each. A Pareto distribution is fitted to the SFS families with net worth above a threshold (\$3 million in 2016 dollars) together with the Forbes entries, using the modified regression of Vermeulen (2018). The SFS families above the threshold are replaced by synthetic families drawn from that distribution up to the lowest Forbes entry, with the Forbes entries themselves above it. The adjustment factors are then revised until financial assets, non-financial assets and debts again match the NBSA. Unlike PBO, Canadians living abroad are kept, and relatives listed separately by Forbes are combined into one family, which fattens the top of the distribution somewhat.
      </p>

      <h2>SFS + NBSA + Forbes + Canadian Business</h2>
      <p>
        The same procedure as SFS + NBSA + Forbes, but for 2012 and 2016 the Forbes list is replaced by the Canadian Business Rich 100 merged with it: families on both lists are combined, at the average of their two net worths, and families on only one list are kept at that list's value. The Rich 100 reaches below the Forbes billionaires, to about \$650 million in 2012 and \$875 million in 2016, so the synthetic families stop at its lowest entry, as in PBO (2020). Canadian Business stopped publishing the list after 2017, so 2019 and 2023 use the Forbes list alone and match SFS + NBSA + Forbes. The Rich 100 lists used were published in November 2012 and December 2016.
      </p>

      <h2>Caveats</h2>
      <p>
        In the SFS and SFS + NBSA series, shares for the top 0.1% and above rest on very few survey records and should be read with caution. In 2023, families reported much higher values for home contents and collectibles than in earlier cycles, most plausibly because the survey was self-completed rather than interviewer-administered. This probably raises measured 2023 inequality slightly, by an amount not yet quantified.
      </p>

      <p class="source">
        Data source: Statistics Canada, Survey of Financial Security Public Use Microdata Files, and Table 36-10-0580-01 (National Balance Sheet Accounts); Forbes, The World's Billionaires; Canadian Business, Rich 100
      </p>
    </div>
  </section>
</div>

<script>
  const DATA = $(data);

  const MEASURES = [
    { key: "top_0_01pct", label: "Top 0.01%", digits: 1 },
    { key: "top_0_1pct",  label: "Top 0.1%",  digits: 1 },
    { key: "top_1pct",    label: "Top 1%",    digits: 1 },
    { key: "top_5pct",    label: "Top 5%",    digits: 1 },
    { key: "top_10pct",   label: "Top 10%",   digits: 1 },
    { key: "top_20pct",   label: "Top 20%",   digits: 1 },
    { key: "top_50pct",   label: "Top 50%",   digits: 1 },
    { key: "gini",        label: "Gini",      digits: 3 },
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

  // The chart's values as a table, for reading exact figures without hovering
  function renderTable() {
    const table = document.getElementById("data-table");
    table.textContent = "";
    table.createCaption().textContent =
      isShare(current) ? current.label + " share of total net worth (%)" : "Gini coefficient of net worth";
    const head = table.createTHead().insertRow();
    ["Year", ...DATA.map(src => src.name)].forEach(name => {
      const th = document.createElement("th");
      th.scope = "col";
      th.textContent = name;
      head.appendChild(th);
    });
    const body = table.createTBody();
    series(DATA[0]).x.forEach(year => {
      const row = body.insertRow();
      const th = document.createElement("th");
      th.scope = "row";
      th.textContent = year;
      row.appendChild(th);
      DATA.forEach(src => {
        const s = series(src), k = s.x.indexOf(year);
        row.insertCell().textContent = k < 0 ? "" : fmt(s.y[k]);
      });
    });
  }

  function update() {
    drawChart();
    renderTable();
  }

  const tabs = document.getElementById("measure-tabs");
  MEASURES.forEach(m => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "measure-tab";
    btn.textContent = m.label;
    btn.setAttribute("aria-pressed", String(m === current));
    btn.addEventListener("click", () => {
      current = m;
      tabs.querySelectorAll(".measure-tab").forEach(b => b.setAttribute("aria-pressed", String(b === btn)));
      update();
    });
    tabs.appendChild(btn);
  });

  update();
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
