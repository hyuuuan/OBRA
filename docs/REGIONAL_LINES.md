# Regional-language lines (for checking with a speaker)

The cultural panel asked for local languages (Chapter 5, Table 34), so every level has a line or
two in its region's own language, said in the story and glossed in English by the next line.
Each such line carries a `"lang"` code in its dialogue file, and `run_regional_language_probe`
fails if a level loses its line, if a line is not glossed, or if a tagged line is missing from
this list. **Change a line here and in the dialogue file together.**

**None of these has been checked by a native speaker yet.** "Confidence" is how sure the team
is of the spelling and meaning from published phrasebooks; a speaker overrules it.

| Level | Language (code) | Line, exactly as shown | Who says it | Meaning | Confidence |
|---|---|---|---|---|---|
| Payyo | Tuwali Ifugao (`ifk`) | Maphod an biggatna. | The guardian at Ang Bale (`L1_N3_017`) | Good morning. | **Low.** Phrasebooks disagree on the Tuwali greeting; the SIL Tuwali dictionary could not be reached to confirm it. Check first. |
| Piyesta | Cebuano (`ceb`) | Kaon ta, apo! | Lolo, at the fiesta table (`L2_PL_001`) | Let's eat, apo! (*kaon*, eat; *ta*, we, including you) | High |
| Piyesta | Cebuano (`ceb`) | When it is good, you say lami. Lami kaayo — very good. | Lolo (`L2_PL_005`) | *lami*, delicious; *lami kaayo*, very delicious | High |
| Piyesta | Cebuano (`ceb`) | Lami kaayo! | The apo (`L2_PL_006`) | Very delicious! | High |
| Dagat | Waray (`war`) | Maupay nga aga, apo. | Lolo, on the shore (`L3_B0_001b`) | Good morning, apo. | High |
| Dilim | Tagalog (`tgl`) | Kaya ko 'to. | The apo, alone at the edge of the woods (`L4_IN_006`) | I can do this. | High |
| Dilim | Tagalog (`tgl`) | Tabi-tabi po. Excuse me -- I only need to pass. | The apo, at the nuno's mound, on one route only (`L4_NU_002`, older than this list) | Asking leave of the unseen ones before passing. | High |
| Mayon | Central Bikol (`bcl`) | Dios mabalos, Lolo. | The apo, after the legend (`L5_magayon_7`) | Thank you, Lolo. (also spelled *Diyos mabalos*) | High |

Also in the lines, and worth the same check: *magayon*, Bikol for beautiful, and *Daragang
Magayon*, the beautiful maiden (`L5_magayon_1`); *puso*, *bibingka*, *adobo* and *pancit*
(`L2_PL_004`); *halipan* and *cogon* (`L1_N3_017e`, `L1_N3_017f`).
