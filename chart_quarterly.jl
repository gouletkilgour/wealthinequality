using CSV, DataFrames

# Writes output/wealth_inequality_quarterly.html and its published copy docs/quarterly.html: the
# quarterly series from sfs_nbsa_quarterly.jl, with the annual series from sfs_nbsa.jl at the
# survey quarters, and the wealth quintile shares against Statistics Canada's DHEA. Run those two
# scripts first. Apart from Plotly, which loads from its CDN, the page is self-contained.

const OUTDIR = joinpath(@__DIR__, "output")
const DOCSDIR = joinpath(@__DIR__, "docs")
const SURVEY_QUARTERS = Dict(2012 => "2012Q4", 2016 => "2016Q4", 2019 => "2019Q4", 2023 => "2023Q2")

json(x::Real) = string(x)
json(::Missing) = "null"
json(s::AbstractString) = "\"" * s * "\""
json(v::AbstractVector) = "[" * join(json.(v), ",") * "]"
json(d::AbstractDict) = "{" * join((json(k) * ":" * json(v) for (k, v) in d), ",") * "}"

function main()
    q = CSV.read(joinpath(OUTDIR, "sfs_nbsa_quarterly_wealth_inequality.csv"), DataFrame)
    quarters = unique(q.quarter)
    quarterly = Dict(k.measure => round.(g.estimate, digits = 4) for (k, g) in pairs(groupby(q, :measure)))
    a = CSV.read(joinpath(OUTDIR, "sfs_nbsa_wealth_inequality.csv"), DataFrame)
    annual = Dict(k.measure => Dict("x" => [SURVEY_QUARTERS[y] for y in g.year], "y" => round.(g.estimate, digits = 4))
                  for (k, g) in pairs(groupby(a, :measure)))
    qs = CSV.read(joinpath(OUTDIR, "sfs_nbsa_quarterly_dhea_quintiles.csv"), DataFrame)
    ours = Dict(string(k.quintile) => round.(g.sfs_nbsa, digits = 2) for (k, g) in pairs(groupby(qs, :quintile)))
    dhea = Dict(string(k.quintile) => Dict("x" => g.quarter[.!ismissing.(g.dhea)], "y" => collect(skipmissing(g.dhea)))
                for (k, g) in pairs(groupby(qs, :quintile)))

    data = json(Dict("quarters" => quarters, "surveys" => [SURVEY_QUARTERS[y] for y in sort(collect(keys(SURVEY_QUARTERS)))],
                     "quarterly" => quarterly, "annual" => annual, "quintiles" => ours, "dhea" => dhea))
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

    h1 { font-size: 1.6rem; margin-bottom: 0.35rem; }

    .subtitle { color: var(--muted); font-size: 0.95rem; margin-bottom: 1.5rem; }

    .subtitle a, .prose a { color: var(--accent); }

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

    .chart { height: 520px; }

    details { padding: 0.75rem 1.25rem; border-top: 1px solid var(--border); }

    summary { cursor: pointer; font-size: 0.85rem; color: var(--accent); }

    .table-wrap { max-height: 24rem; overflow-y: auto; margin-top: 0.75rem; }

    table {
      width: 100%;
      max-width: 32rem;
      border-collapse: collapse;
      font-size: 0.85rem;
      font-variant-numeric: tabular-nums;
    }

    caption { text-align: left; font-size: 0.8rem; color: var(--muted); padding-bottom: 0.4rem; }

    th, td { padding: 0.3rem 0 0.3rem 1.5rem; text-align: right; border-bottom: 1px solid var(--border); }

    th:first-child { padding-left: 0; text-align: left; }

    thead th { position: sticky; top: 0; background: var(--bg); }

    tbody th { font-weight: 400; }

    .prose { padding: 1.5rem 1.75rem; line-height: 1.7; font-size: 0.93rem; }

    .prose h2 { font-size: 1rem; font-weight: 600; margin-bottom: 0.5rem; }

    .prose p { margin-bottom: 1rem; }

    .prose p:last-child { margin-bottom: 0; }

    @media (max-width: 600px) {
      .page { padding-top: 1.5rem; }
      .chart { height: 440px; }
      .prose { padding: 1.25rem 1rem; }
    }
  </style>
</head>
<body>

<div class="page">
  <h1>Quarterly Wealth Inequality in Canada</h1>
  <p class="subtitle">Survey of Financial Security aligned with the quarterly National Balance Sheet Accounts, 2012&ndash;2026, following Statistics Canada&rsquo;s Distributions of Household Economic Accounts. <a href="index.html">Annual series &rarr;</a></p>

  <section>
    <div class="section-label">Top wealth shares</div>
    <div class="chart-controls">
      <span class="chart-ctrl-label" id="measure-label">Measure:</span>
      <div class="measure-tabs" id="measure-tabs" role="group" aria-labelledby="measure-label"></div>
    </div>
    <div class="chart" id="chart-top"></div>
    <details>
      <summary>Data table</summary>
      <div class="table-wrap"><table id="table-top"></table></div>
    </details>
  </section>

  <section>
    <div class="section-label">Comparison with Statistics Canada</div>
    <div class="chart-controls">
      <span class="chart-ctrl-label" id="quintile-label">Wealth quintile:</span>
      <div class="measure-tabs" id="quintile-tabs" role="group" aria-labelledby="quintile-label"></div>
    </div>
    <div class="chart" id="chart-quintile"></div>
    <details>
      <summary>Data table</summary>
      <div class="table-wrap"><table id="table-quintile"></table></div>
    </details>
  </section>

  <section>
    <div class="section-label">About this data</div>
    <div class="prose">
      <p>Each quarter starts from the Survey of Financial Security (SFS) public use microdata of 2012, 2016, 2019 or 2023. The survey is carried to the quarter in two steps. Each family&rsquo;s weight grows with the population of its region and the age group of its major income earner. Then six categories of assets and debts (pensions, other financial assets, real estate, other non-financial assets, mortgages and other debts) are scaled to the household sector of the National Balance Sheet Accounts for that quarter.</p>
      <p>A quarter between two surveys pools both surveys, each weighted by how close the quarter is to it. Quarters before 2012&nbsp;Q4 use the 2012 survey alone, and quarters after 2023&nbsp;Q2 the 2023 survey alone (shaded). Large markers show the survey quarters.</p>
      <p>The unit is the economic family, whereas Statistics Canada&rsquo;s Distributions of Household Economic Accounts use the household, so the shares are not directly comparable. The annual series uses three categories, following the Parliamentary Budget Officer (2020). No adjustment is made for the very wealthy, who are rarely sampled by the survey, so the top 0.1% and 0.01% shares rest on very few records.</p>
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
  const QUINTILES = [
    { key: "1", label: "Lowest" }, { key: "2", label: "Second" }, { key: "3", label: "Third" },
    { key: "4", label: "Fourth" }, { key: "5", label: "Highest" },
  ];

  // The colours of the annual page: red for SFS + NBSA, blue for the annual series, green for
  // Statistics Canada
  const RED = "#ef553b", BLUE = "#636efa", GREEN = "#00aa7a";
  const NAMES = {
    quarterly: "SFS + NBSA, quarterly (families)",
    annual: "SFS + NBSA, annual (PBO method)",
    dhea: "Statistics Canada DHEA (households)",
  };

  const THEMES = {
    light: { paper: "#ffffff", plot: "#E5ECF6", grid: "#ffffff", text: "#444444", shade: "rgba(0,0,0,0.05)" },
    dark:  { paper: "#15161a", plot: "#1e1f24", grid: "#33343a", text: "#c8c8c8", shade: "rgba(255,255,255,0.05)" },
  };

  const MARGIN_T = 50, MARGIN_B = 70, MARGIN_L = 60;
  const darkMode = window.matchMedia("(prefers-color-scheme: dark)");
  const Q = DATA.quarters;
  let measure = MEASURES[2], quintile = QUINTILES[4];

  const isShare = m => m.key !== "gini";
  const theme = () => darkMode.matches ? THEMES.dark : THEMES.light;
  const quarterText = q => q.slice(0, 4) + " " + q.slice(4);

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

  // Quarters as rows, one column per series
  function renderTable(id, caption, columns, fmt) {
    const table = document.getElementById(id);
    table.textContent = "";
    table.createCaption().textContent = caption;
    const head = table.createTHead().insertRow();
    ["Quarter", ...columns.map(c => c.name)].forEach(name => {
      const th = document.createElement("th");
      th.scope = "col";
      th.textContent = name;
      head.appendChild(th);
    });
    const body = table.createTBody();
    Q.forEach(q => {
      const row = body.insertRow();
      const th = document.createElement("th");
      th.scope = "row";
      th.textContent = quarterText(q);
      row.appendChild(th);
      columns.forEach(c => {
        const k = c.x.indexOf(q);
        row.insertCell().textContent = k < 0 ? "" : fmt(c.y[k]);
      });
    });
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

  function drawQuintile() {
    const t = theme(), el = document.getElementById("chart-quintile");
    const fmt = v => v.toFixed(1) + "%";
    const y = DATA.quintiles[quintile.key], dhea = DATA.dhea[quintile.key];
    Plotly.react(el, [quarterlyTrace(t, y, fmt), pointsTrace(t, dhea, NAMES.dhea, GREEN, "square", "lines+markers", fmt)],
                 layout(el, t, "Share of Total Net Worth – " + quintile.label + " Wealth Quintile",
                        "Share of Total Net Worth (%)", range(y.concat(dhea.y))),
                 { responsive: true });
  }

  function updateTop() {
    drawTop();
    const fmt = v => v.toFixed(measure.digits);
    renderTable("table-top", isShare(measure) ? measure.label + " share of total net worth (%)" : "Gini coefficient of net worth",
                [{ name: "Quarterly", x: Q, y: DATA.quarterly[measure.key] },
                 { name: "Annual (PBO method)", x: DATA.annual[measure.key].x, y: DATA.annual[measure.key].y }], fmt);
  }

  function updateQuintile() {
    drawQuintile();
    renderTable("table-quintile", quintile.label + " wealth quintile, share of total net worth (%)",
                [{ name: "This series (families)", x: Q, y: DATA.quintiles[quintile.key] },
                 { name: "DHEA (households)", x: DATA.dhea[quintile.key].x, y: DATA.dhea[quintile.key].y }],
                v => v.toFixed(1));
  }

  function makeTabs(id, items, isCurrent, select) {
    const tabs = document.getElementById(id);
    items.forEach(item => {
      const btn = document.createElement("button");
      btn.type = "button";
      btn.className = "measure-tab";
      btn.textContent = item.label;
      btn.setAttribute("aria-pressed", String(isCurrent(item)));
      btn.addEventListener("click", () => {
        select(item);
        tabs.querySelectorAll(".measure-tab").forEach(b => b.setAttribute("aria-pressed", String(b === btn)));
      });
      tabs.appendChild(btn);
    });
  }

  makeTabs("measure-tabs", MEASURES, m => m === measure, m => { measure = m; updateTop(); });
  makeTabs("quintile-tabs", QUINTILES, k => k === quintile, k => { quintile = k; updateQuintile(); });
  updateTop();
  updateQuintile();
  darkMode.addEventListener("change", () => { drawTop(); drawQuintile(); });

  // Recompute the legend position when a chart is resized.
  // Debounced to avoid a relayout -> resize -> relayout loop.
  let resizeTimer;
  const observer = new ResizeObserver(() => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => { drawTop(); drawQuintile(); }, 50);
  });
  observer.observe(document.getElementById("chart-top"));
  observer.observe(document.getElementById("chart-quintile"));
</script>

</body>
</html>
"""

main()
