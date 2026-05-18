# Step E8b — Experiment lock (Time-in-loss failure exit)



**Status:** **DISCARD** — WR collapse worse than E8a; OOS net/PF destroyed vs D7  

**Date locked:** 2026-05-16  

**Date tested:** 2026-05-16  

**Habitat:** `vem5m_d7_session_bb_rsi.set` (entries unchanged)  

**Test:** `vem5m_e8b_d7_time_loss.set` (D7 + E8b only)  

**Prior:** E8a **discarded** (WR ~47%) — E8b removed outside-BB rule but still exits too early



---



## Prerequisites



- D7 locked @ **0.01** lots

- **Not** combined with E8a, E7, E9, or partial midline

- E8a reference: 293 IS / 122 OOS tr, WR ~47%, OOS −$4.65



---



## References



| Item | Path / value |

|------|----------------|

| **Control** | `vem5m_d7_session_bb_rsi.set` |

| **Test** | `vem5m_e8b_d7_time_loss.set` |

| Step E | Losers median MFE 0.15R — slow bleeds |

| D7 OOS | 119 tr · **+$6.00** · PF **1.17** · WR **~69%** |



---



## E8b — single hypothesis



**Name:** Close trade still in loss after N bars (slow bleed / no snapback)



**Hypothesis:** E8a failed because **outside BB + low MFE** is normal for good fades. E8b only asks: after **N** bars, is the position **still red**? If yes, exit early.



**Rule v1:**



| Condition | Action |

|-----------|--------|

| `bars_in_trade >= 4` | Start checking |

| `POSITION_PROFIT < 0` | **Close** (market) |



| Parameter | Value |

|-----------|--------|

| `inp_fail_exit_mode` | **2** (`VEM_FAIL_EXIT_E8B`) |

| `inp_fail_exit_bars` | **4** |

| E8a fields | **ignored** (outside BB off, mode ≠ E8a) |



**Code:** `VEM_Execution_CheckFailureExits()` — E8b branch



**Optional E8b2:** `inp_fail_exit_bars = 6` — **not recommended** after v1 (WR already ~35%).



---



## Evaluation windows



| Window | From | To |

|--------|------|-----|

| **IS** | 2024.01.01 | 2026.05.15 |

| **OOS** | 2025.01.01 | 2026.05.15 |



**Tester:** EURUSD M5 · every tick · **$200** · **0.01** lots (same as D7).



---



## Pass / fail (E8b)



**Keep E8b** if vs D7 on **OOS**:



- [ ] Net **≥ +$6.00** (or clearly better)

- [ ] PF **≥ 1.17**

- [ ] WR **≥ ~65%** (must not repeat E8a ~47% collapse)

- [ ] Avg loss **<** D7 (−$0.97) with similar trade count (±20%)



**Verdict (2026-05-16):** **DISCARD** — rule fires (≈E8a trade count) but **WR ~35%** (worse than E8a ~47%). Many D7 winners are still red at bar 4 before midline snapback. **Production:** `vem5m_d7_session_bb_rsi.set` @ **0.01**, **failure exit OFF** (mode 0). Phase 2b exit queue on D7 habitat **complete** unless you trial E8c/E8b2.



---



## E8b results (tester screenshots 2026-05-16)



`vem5m_e8b_d7_time_loss.set` · mode **2** · bars **4** · 0.01 lots



### OOS (2025.01.01 → 2026.05.15)



| Metric | D7 | E8b | Δ |

|--------|-----|-----|---|

| Trades | 119 | **122** | +3 |

| Net profit | **+$6.00** | **−$4.48** | **−$10.48** |

| Profit factor | **1.17** | **0.86** | −0.31 |

| Win rate | **~69%** | **34.4%** | **−35 pp** |

| Avg win / avg loss | — | **$0.67** / **−$0.41** | smaller loss, useless without WR |

| Max DD (equity) | **3.2%** | **~4.5%** | worse |



### IS (2024.01.01 → 2026.05.15)



| Metric | D7 | E8b | Δ |

|--------|-----|-----|---|

| Trades | 270 | **293** | +23 |

| Net profit | **−$0.38** | **−$4.73** | **−$4.35** |

| Profit factor | **0.99** | **0.92** | −0.07 |

| Win rate | **~69%** | **35.2%** | **−34 pp** |

| Avg win / avg loss | — | **$0.56** / **−$0.33** | avg loss smaller; edge gone |

| Max DD (equity) | **7.8%** | **~4.5%** | lower DD irrelevant |



**Interpretation:** At bar 4, **still in loss** is the **normal state** for mean-reversion before midline (~80% of D7 wins). E8b cuts those trades for small losses instead of waiting for midline — same failure mode as E8a, **more aggressive** (no MFE/outside-BB gate). **Do not enable** `inp_fail_exit_mode` on production.



---



## Deliverables



- [x] E8b D0 — this file

- [x] `inp_fail_exit_mode` + E8b branch in code

- [x] `vem5m_e8b_d7_time_loss.set`

- [x] F7 + IS/OOS

- [x] **DISCARD**



---



## Tester checklist



1. **F7** compile

2. Load **`vem5m_e8b_d7_time_loss.set`**

3. Confirm: **Failure exit mode = 2 (E8b)**, bars **4**, outside BB **off**

4. OOS then IS vs D7

5. Journal: `E8b time-loss exit` lines


