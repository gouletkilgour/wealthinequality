INFILE &datafid PAD LRECL = 476;
INPUT
    @         1     PEFAMID                          $     5.  /*      1 -      5 */
    @         6     PWEIGHT                               12.4 /*      6 -     17 */
    @        18     RWEIGHT                          $     2.  /*     18 -     19 */
    @        20     PPVRES                           $     2.  /*     20 -     21 */
    @        22     PREGION                          $     1.  /*     22 -     22 */
    @        23     PFSZ                                   1.  /*     23 -     23 */
    @        24     PFSZ0004                         $     1.  /*     24 -     24 */
    @        25     PFSZ0517                         $     1.  /*     25 -     25 */
    @        26     PFSZ1824                         $     1.  /*     26 -     26 */
    @        27     PFSZ2544                         $     1.  /*     27 -     27 */
    @        28     PFSZ4564                         $     1.  /*     28 -     28 */
    @        29     PFSZ65UP                         $     1.  /*     29 -     29 */
    @        30     PAGEMIE                                3.  /*     30 -     32 */
    @        33     PSEXMIE                                1.  /*     33 -     33 */
    @        34     PDWTYP                           $     1.  /*     34 -     34 */
    @        35     PFRSPST                          $     1.  /*     35 -     35 */
    @        36     PFCRN                            $     1.  /*     36 -     36 */
    @        37     PEDUCMIE                         $     1.  /*     37 -     37 */
    @        38     PFMTYPG                          $     1.  /*     38 -     38 */
    @        39     PATTCRC                                1.  /*     39 -     39 */
    @        40     PATTCRP                                1.  /*     40 -     40 */
    @        41     PATTCRR                                1.  /*     41 -     41 */
    @        42     PATTPAYD                               1.  /*     42 -     42 */
    @        43     PATTRSP                                1.  /*     43 -     43 */
    @        44     PATTRSA                                1.  /*     44 -     44 */
    @        45     PATTRSH                                1.  /*     45 -     45 */
    @        46     PATTRSL                                1.  /*     46 -     46 */
    @        47     PATTRSR                                1.  /*     47 -     47 */
    @        48     PATTBUD                                1.  /*     48 -     48 */
    @        49     PEFMTINC                               8.  /*     49 -     56 */
    @        57     REFMTINC                         $     2.  /*     57 -     58 */
    @        59     PEFATINC                               8.  /*     59 -     66 */
    @        67     REFATINC                         $     2.  /*     67 -     68 */
    @        69     PEFGTR                                 8.  /*     69 -     76 */
    @        77     REFGTR                           $     2.  /*     77 -     78 */
    @        79     PFTENUR                                1.  /*     79 -     79 */
    @        80     PWATOTPT                              12.  /*     80 -     91 */
    @        92     RWATOTPT                         $     2.  /*     92 -     93 */
    @        94     PWATOTPG                              12.  /*     94 -    105 */
    @       106     RWATOTPG                         $     2.  /*    106 -    107 */
    @       108     PWASTDEP                              12.  /*    108 -    119 */
    @       120     RWASTDEP                         $     2.  /*    120 -    121 */
    @       122     PWASTMUI                              12.  /*    122 -    133 */
    @       134     RWASTMUI                         $     2.  /*    134 -    135 */
    @       136     PWASTBND                              12.  /*    136 -    147 */
    @       148     RWASTBND                         $     2.  /*    148 -    149 */
    @       150     PWASTSTK                              12.  /*    150 -    161 */
    @       162     RWASTSTK                         $     2.  /*    162 -    163 */
    @       164     PWASTOIN                              12.  /*    164 -    175 */
    @       176     RWASTOIN                         $     2.  /*    176 -    177 */
    @       178     PWARRSPL                              12.  /*    178 -    189 */
    @       190     RWARRSPL                         $     2.  /*    190 -    191 */
    @       192     PWARRIF                               12.  /*    192 -    203 */
    @       204     RWARRIF                          $     2.  /*    204 -    205 */
    @       206     PWAPRVAL                              12.  /*    206 -    217 */
    @       218     RWAPRVAL                         $     2.  /*    218 -    219 */
    @       220     PWASTRST                              12.  /*    220 -    231 */
    @       232     RWASTRST                         $     2.  /*    232 -    233 */
    @       234     PWASTVHE                              12.  /*    234 -    245 */
    @       246     RWASTVHE                         $     2.  /*    246 -    247 */
    @       248     PWARPPT                               12.  /*    248 -    259 */
    @       260     RWARPPT                          $     2.  /*    260 -    261 */
    @       262     PWASTONF                              12.  /*    262 -    273 */
    @       274     RWASTONF                         $     2.  /*    274 -    275 */
    @       276     PWARPPG                               12.  /*    276 -    287 */
    @       288     RWARPPG                          $     2.  /*    288 -    289 */
    @       290     PWAOTPEN                              12.  /*    290 -    301 */
    @       302     RWAOTPEN                         $     2.  /*    302 -    303 */
    @       304     PBUSIND                                1.  /*    304 -    304 */
    @       305     PWBUSEQ                               12.  /*    305 -    316 */
    @       317     RWBUSEQ                          $     2.  /*    317 -    318 */
    @       319     PWDTOTAL                              12.  /*    319 -    330 */
    @       331     RWDTOTAL                         $     2.  /*    331 -    332 */
    @       333     PWDPRMOR                              12.  /*    333 -    344 */
    @       345     RWDPRMOR                         $     2.  /*    345 -    346 */
    @       347     PWDSTCRD                              12.  /*    347 -    358 */
    @       359     RWDSTCRD                         $     2.  /*    359 -    360 */
    @       361     PWDSLOAN                              12.  /*    361 -    372 */
    @       373     RWDSLOAN                         $     2.  /*    373 -    374 */
    @       375     PWDSTVHN                              12.  /*    375 -    386 */
    @       387     RWDSTVHN                         $     2.  /*    387 -    388 */
    @       389     PWDSTLOC                              12.  /*    389 -    400 */
    @       401     RWDSTLOC                         $     2.  /*    401 -    402 */
    @       403     PWDSTODB                              12.  /*    403 -    414 */
    @       415     RWDSTODB                         $     2.  /*    415 -    416 */
    @       417     PWDSTOMR                              12.  /*    417 -    428 */
    @       429     RWDSTOMR                         $     2.  /*    429 -    430 */
    @       431     PWNETWPT                              12.  /*    431 -    442 */
    @       443     RWNETWPT                         $     2.  /*    443 -    444 */
    @       445     PWNETWPG                              12.  /*    445 -    456 */
    @       457     RWNETWPG                         $     2.  /*    457 -    458 */
    @       459     PWATFS                                12.  /*    459 -    470 */
    @       471     RWATFS                           $     2.  /*    471 -    472 */
    @       473     PEFMJSIF                         $     2.  /*    473 -    474 */
    @       475     PRETIRME                         $     1.  /*    475 -    475 */
    @       476     PNBEARG                                1.  /*    476 -    476 */
              ;
 
