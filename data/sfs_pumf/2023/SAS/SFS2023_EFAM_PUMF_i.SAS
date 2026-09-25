INFILE &datafid PAD LRECL = 504;
INPUT
    @         1     PEFAMID                          $     5.  /*      1 -      5 */
    @         6     PWEIGHT                               12.4 /*      6 -     17 */
    @        18     PAGEMIEG                         $     2.  /*     18 -     19 */
    @        20     PAS1MRAG                               1.  /*     20 -     20 */
    @        21     PAS1MRG1                               1.  /*     21 -     21 */
    @        22     PAS1MRG2                               1.  /*     22 -     22 */
    @        23     PASR1MFA                               8.  /*     23 -     30 */
    @        31     PASR1MR                                1.  /*     31 -     31 */
    @        32     PASRBUYG                               2.  /*     32 -     33 */
    @        34     PASRCNMG                               1.  /*     34 -     34 */
    @        35     PASRCON                                1.  /*     35 -     35 */
    @        36     PASRCST                                8.  /*     36 -     43 */
    @        44     PASRCURG                               2.  /*     44 -     45 */
    @        46     PASRDPO1                               1.  /*     46 -     46 */
    @        47     PASRDPO2                               1.  /*     47 -     47 */
    @        48     PASRDPO3                               1.  /*     48 -     48 */
    @        49     PASRDPO4                               1.  /*     49 -     49 */
    @        50     PASRDPO5                               1.  /*     50 -     50 */
    @        51     PASRDWNG                               2.  /*     51 -     52 */
    @        53     PASRFNMG                               1.  /*     53 -     53 */
    @        54     PASRINT                                1.  /*     54 -     54 */
    @        55     PASRINTG                         $     2.  /*     55 -     56 */
    @        57     PASRMOAG                               1.  /*     57 -     57 */
    @        58     PASRMPFG                               2.  /*     58 -     59 */
    @        60     PASRMRYG                               4.  /*     60 -     63 */
    @        64     PASRRNTG                               1.  /*     64 -     64 */
    @        65     PASRSKP                                1.  /*     65 -     65 */
    @        66     PATTCRC                                1.  /*     66 -     66 */
    @        67     PATTCRLM                               6.  /*     67 -     72 */
    @        73     PATTCRR                                1.  /*     73 -     73 */
    @        74     PATTCRU                                1.  /*     74 -     74 */
    @        75     PATTDIF                                1.  /*     75 -     75 */
    @        76     PATTLCP                                1.  /*     76 -     76 */
    @        77     PATTLCR                                1.  /*     77 -     77 */
    @        78     PATTLMLC                               8.  /*     78 -     85 */
    @        86     PATTPAYD                               1.  /*     86 -     86 */
    @        87     PATTRSA                                1.  /*     87 -     87 */
    @        88     PATTRSH                                1.  /*     88 -     88 */
    @        89     PATTRSL                                1.  /*     89 -     89 */
    @        90     PATTRSP                                1.  /*     90 -     90 */
    @        91     PATTRSR                                1.  /*     91 -     91 */
    @        92     PATTSITC                               1.  /*     92 -     92 */
    @        93     PATTSKP                                1.  /*     93 -     93 */
    @        94     PATTSTIN                               1.  /*     94 -     94 */
    @        95     PBUSIND                                1.  /*     95 -     95 */
    @        96     PDWTYP                           $     1.  /*     96 -     96 */
    @        97     PEDUCMIE                         $     1.  /*     97 -     97 */
    @        98     PEFATINC                               8.  /*     98 -    105 */
    @       106     PEFGTR                                 8.  /*    106 -    113 */
    @       114     PEFMJSIF                         $     2.  /*    114 -    115 */
    @       116     PEFMTINC                               8.  /*    116 -    123 */
    @       124     PEXMG1A                                5.  /*    124 -    128 */
    @       129     PEXMG1F                                1.  /*    129 -    129 */
    @       130     PFCRN                            $     1.  /*    130 -    130 */
    @       131     PFMTYPG                          $     1.  /*    131 -    131 */
    @       132     PFRSPST                          $     1.  /*    132 -    132 */
    @       133     PFSZ                                   1.  /*    133 -    133 */
    @       134     PFSZ0017                         $     1.  /*    134 -    134 */
    @       135     PFSZ1824                         $     1.  /*    135 -    135 */
    @       136     PFSZ2544                         $     1.  /*    136 -    136 */
    @       137     PFSZ4564                         $     1.  /*    137 -    137 */
    @       138     PFSZ65UP                         $     1.  /*    138 -    138 */
    @       139     PFTENUR                                1.  /*    139 -    139 */
    @       140     PGDRMIE                                1.  /*    140 -    140 */
    @       141     PINHERT                                9.  /*    141 -    149 */
    @       150     PLFCHRME                         $     1.  /*    150 -    150 */
    @       151     PLFFPTME                         $     1.  /*    151 -    151 */
    @       152     PLFPDMEG                         $     1.  /*    152 -    152 */
    @       153     PNBEARG                                1.  /*    153 -    153 */
    @       154     PPVRES                           $     2.  /*    154 -    155 */
    @       156     PREGION                          $     1.  /*    156 -    156 */
    @       157     PRETIRME                         $     1.  /*    157 -    157 */
    @       158     PVMFMIE                                1.  /*    158 -    158 */
    @       159     PWAOTPEN                              12.  /*    159 -    170 */
    @       171     PWAPRVAL                              12.  /*    171 -    182 */
    @       183     PWARPPG                               12.  /*    183 -    194 */
    @       195     PWARPPT                               12.  /*    195 -    206 */
    @       207     PWARRIF                               12.  /*    207 -    218 */
    @       219     PWARRSPL                              12.  /*    219 -    230 */
    @       231     PWASTBND                              12.  /*    231 -    242 */
    @       243     PWASTDEP                              12.  /*    243 -    254 */
    @       255     PWASTMUI                              12.  /*    255 -    266 */
    @       267     PWASTOIN                              12.  /*    267 -    278 */
    @       279     PWASTONF                              12.  /*    279 -    290 */
    @       291     PWASTRST                              12.  /*    291 -    302 */
    @       303     PWASTSTK                              12.  /*    303 -    314 */
    @       315     PWASTVHE                              12.  /*    315 -    326 */
    @       327     PWATFS                                12.  /*    327 -    338 */
    @       339     PWATOTPG                              12.  /*    339 -    350 */
    @       351     PWATOTPT                              12.  /*    351 -    362 */
    @       363     PWBUSEQ                               12.  /*    363 -    374 */
    @       375     PWDPRMOR                              12.  /*    375 -    386 */
    @       387     PWDSLOAN                              12.  /*    387 -    398 */
    @       399     PWDSTCRD                              12.  /*    399 -    410 */
    @       411     PWDSTLOC                              12.  /*    411 -    422 */
    @       423     PWDSTODB                              12.  /*    423 -    434 */
    @       435     PWDSTOMR                              12.  /*    435 -    446 */
    @       447     PWDSTVHN                              12.  /*    447 -    458 */
    @       459     PWDTOTAL                              12.  /*    459 -    470 */
    @       471     PWNETWPG                              12.  /*    471 -    482 */
    @       483     PWNETWPT                              12.  /*    483 -    494 */
    @       495     VERDATE                          $    10.  /*    495 -    504 */
              ;
 
