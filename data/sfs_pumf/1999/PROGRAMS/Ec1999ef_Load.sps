* The job ec1999efLoad.sps contains the SPSS control card to load the publi use microdata file into SPSS.


* NOTE:  The following variable names have been shortened/modified to comply with SPSS's naming convention (maximum variable name length of eight).
* ECFSZ0004  --> ECF0004
* ECFSZ0517  --> ECF0517
* ECFSZ1824  --> ECF1824
* ECFSZ2544  --> ECF2544
* ECFSZ4564  --> ECF4564
* ECFSZ65pl  --> ECF65PL
* ECFDWELLTP --> ECFDWELL
* DVPHLV2G_M --> DVPHLV2G


set compress=on.
DATA LIST FILE='\\Lhs3\paws\PAWSSFS\adssys\SFS99\PUMF\ec1999ef.sdf' /
  ECFKEY    1 -    5 (A)
  WEIGHT    6 -   10
  PVRES25    11 -   12 (A)
  FMSZ27    13 -   14
  DVFMCOMP    15 -   15 (A)
  ECFSZ0004    16 -   17
  ECFSZ0517    18 -   19
  ECFSZ1824    20 -   21
  ECFSZ2544    22 -   23
  ECFSZ4564    24 -   25
  ECFSZ65PL    26 -   27
  NBEAR27    28 -   29
  TRNOUT    30 -   30 (A)
  TRNIN    31 -   31 (A)
  ATTCRC    32 -   32 (A)
  DVFCRN    33 -   33 (A)
  ATTCRP    34 -   34 (A)
  ATTCRR    35 -   35 (A)
  ATTLAT    36 -   36 (A)
  ATTSEL    37 -   37 (A)
  ATTPAW    38 -   38 (A)
  ATTCOS    39 -   39 (A)
  ATTFAS    40 -   40 (A)
  DVFRSPST    41 -   41 (A)
  ATTRSP    42 -   42 (A)
  ATTRSA    43 -   43 (A)
  ATTRSH    44 -   44 (A)
  ATTRSR    45 -   45 (A)
  ATTBUD    46 -   46 (A)
  ATTBUR    47 -   47 (A)
  DVFATT5H    48 -   48 (A)
  DVFATT5K    49 -   49 (A)
  ATTSPD    50 -   50 (A)
  ATTCMF    51 -   51 (A)
  ATTSIT    52 -   52 (A)
  MJSIF27    53 -   54 (A)
  TTINC27    55 -   62
  INCTX27    63 -   70
  ATINC27    71 -   78
  EARNG27    79 -   86
  INVA27    87 -   94
  GTR27    95 -  102
  PEN27   103 -  110
  OTTXM27   111 -  118
  MTINC27   119 -  126
  ECFEXCHR   127 -  133
  ECFEXHMR   134 -  140
  ECFEXVHR   141 -  147
  DVFTENUR   148 -  148 (A)
  ECFDWELLTP   149 -  149 (A)
  WATOTPT   150 -  158
  WATOTPG   159 -  167
  WASTDEPT   168 -  176
  WAMUTUAL   177 -  185
  WASTBOND   186 -  194
  WASTSTCK   195 -  203
  WASTOINP   204 -  212
  WARRSPL   213 -  221
  WARRIF   222 -  230
  WAPRVAL   231 -  239
  WASTREST   240 -  248
  WASTVHLE   249 -  257
  WASTONOF   258 -  266
  WARPPT   267 -  275
  WARPPG   276 -  284
  WAOTPEN   285 -  293
  BUSIND   294 -  294 (A)
  WBUSEQ   295 -  303
  WDTOTAL   304 -  312
  WDPRMOR   313 -  321
  WDSTOMOR   322 -  330
  WDSTCRED   331 -  339
  WDSLOAN   340 -  348
  WDSTVHLN   349 -  357
  WDSTLOC   358 -  366
  WDSTODBT   367 -  375
  WNETWPT   376 -  384
  WNETWPG   385 -  393
  ECPAGE_M   394 -  396 (A)
  DVPHLV2G_M   397 -  397 (A)  .

EXECUTE.
