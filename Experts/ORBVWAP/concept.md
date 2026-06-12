We are building an MT5 Expert Advisor (EA) centred around the following trading concept and system architecture:
[Foundational Framework Before Strategies
Before covering individual strategies, these principles apply universally to every system in this report.
Capital constraints shape everything. At $100–$200, you are operating micro lots (0.01). One micro lot on EURUSD is roughly $0.10 per pip. A 10-pip stop costs $1, which is 0.5–1% of your capital. This is actually a strength — you can apply textbook risk management from day one without needing large capital.
Spread is your biggest hidden enemy on 1m. A 1.5-pip average spread on a 5-pip scalp target means spread alone is 30% of your potential gain before commissions. You must use ECN/raw spread brokers (IC Markets, Pepperstone, Blueberry Markets). Standard accounts with 2–3 pip spreads make most 1m strategies mathematically negative expectancy before they even begin.
Session filtering is non-negotiable. The 1-minute chart produces signals 24 hours a day. The majority of those signals outside of active market hours are noise. Every EA in this report must include a hard session gate: London open 07:00–12:00 GMT and NY overlap 13:00–17:00 GMT. Asian session trading on 1m with any of these strategies is not recommended for a starting system.
Multi-timeframe logic should cascade top-down. The EA checks D1 for directional bias, H4 for structural alignment, H1 or 15m for zone confirmation, then drops to 1m only for the trigger. No signal fires without the higher timeframes agreeing. This single rule eliminates a large percentage of false entries.
Risk per trade: 1% hard cap. Use ATR-based stop sizing and back-calculate lot size from the ATR stop distance. Never fix lot size; always derive it from the stop.
Daily loss circuit breaker: 5%. When the account loses 5% in a single day, the EA closes all open trades and stops placing new ones until the next session. This prevents the account from being destroyed by a single bad day or news event.
Consecutive loss pause. After three consecutive losses, the EA halts for two hours. This prevents runaway losses during broken market conditions that temporarily invalidate the strategy's edge.Strategy 3: Opening Range Breakout with VWAP
Overview
The Opening Range Breakout captures the directional momentum established in the first 5 to 15 minutes of a major session. This strategy is built on the observation that institutional order flow at session opens creates a defining price range, and a confirmed break of that range in either direction typically leads to a sustained directional move.
Theoretical Edge
At the start of each major trading session, institutional participants are entering the market with significant order size. The first several minutes of price action represent the price discovery process as these large orders are absorbed. This creates an identifiable range — a high and a low — that reflects the current equilibrium. When price breaks cleanly above or below this range with confirming volume, it signals that the price discovery process has concluded and the market has chosen a direction.
The VWAP filter adds institutional confirmation. VWAP is the price at which the majority of the session's volume has transacted. A breakout above the opening range that is also above VWAP means both the range logic and the volume-weighted mean agree on the direction. This dual confirmation substantially improves the reliability of the breakout signal.
Indicators Used
The opening range is defined by recording the high and the low of the first 5 minutes (or optionally 10 or 15 minutes) of the London or NY session. These levels are stored as horizontal lines. VWAP is calculated from the session open and plotted continuously. A 14-period ATR measures the expected move size. Tick volume (available in MT5 as a proxy for real volume on forex) is compared to its 20-period moving average to confirm volume expansion at the breakout point.
On higher timeframes, the D1 chart bias is assessed using the 50 EMA — is price above or below it? The H4 chart shows the last completed swing to confirm structural alignment.
Entry Conditions
For a long entry: the 1-minute candle closes above the opening range high. Tick volume on the breakout candle is at least 1.5 times the 20-period average tick volume. Price is above VWAP. The D1 close is above the D1 50 EMA. The H4 last swing is bullish.
For a short entry: the 1-minute candle closes below the opening range low. Tick volume confirms the move. Price is below VWAP. D1 is bearish. H4 structure is bearish.
A critical rule: only take the first breakout. Do not trade a second or third attempt at the same range boundary. Each subsequent attempt has a lower probability of success as the breakout energy dissipates.
Stop Loss and Take Profit
The stop loss is placed at the opposite side of the opening range — for a long, the stop sits just below the opening range low. For a short, it sits just above the opening range high. This placement is logical: if price returns to the opposite side of the range, the breakout thesis is invalidated.
The take profit target is calculated as a measured move equal to the size of the opening range projected from the breakout point. For example, if the range was 8 pips wide, the target is 8 pips from the breakout level. A secondary target at 1.5 times the range size can be used for trailing.
Trade Frequency
This strategy fires a maximum of two to four times per day — once at the London open and once at the NY open, with one long and one short setup defined by the range. In practice, with all filters applied, you may get one to three trades per day. This is intentionally low frequency.
Strengths
When this setup works, it typically produces the cleanest and most rapid moves of any strategy in this report. The measured move target is often reached within 10 to 30 minutes of the breakout. The stop placement at the opposite range boundary is logically sound and often results in relatively tight stops with excellent RR of 2:1 or better. The strategy is highly automatable since the range formation time is fixed and known in advance.
Weaknesses
The win rate is lower than mean reversion or momentum strategies, typically 52–60%. False breakouts, where price breaks the range briefly and immediately reverses, are the primary failure mode. These are particularly common when the opening range is very narrow (below 5 pips), meaning the breakout threshold is too close to the current price and institutional algorithms can sweep it without genuine directional intent.
To address this, add a minimum range size filter: only activate the strategy when the opening range is at least 0.8 ATR wide. Very narrow ranges indicate a lack of directional conviction at the open and produce unreliable breakouts.
Recommended Pairs
EURUSD, GBPUSD, and USDJPY for the London open. EURUSD, US30 micro, and USDJPY for the NY overlap. Gold (XAUUSD) can also be considered for the NY open given its tendency to make clean breakout moves at that session.]
Current Development Scope (Phase 1):
The focus right now is strictly on building the automated execution engine based on the selected indicators and signal logic. We are intentionally keeping the system lightweight and modular at this stage.
Important:
Do NOT introduce advanced filtering, AI layers, session filters, portfolio management, adaptive optimisation, or overengineered logic yet.
Do NOT add unnecessary complexity outside the core execution workflow.
The goal is simply to automate trade execution reliably using the selected indicators and trading conditions.
Core Objective:
Build a configurable execution engine capable of:
Reading indicator values and market conditions in real time
Evaluating entry conditions
Executing buy/sell trades automatically
Managing basic trade risk
Providing clean parameter configuration for optimization and future scaling
Execution Engine Requirements:
Configurable indicator inputs
Configurable entry conditions
Buy/sell execution logic
Support for market orders initially
Clean order validation before execution
Low-latency and lightweight processing
Modular architecture for future expansion
Basic Risk Management & Position Sizing:
Include foundational risk and trade management features only, such as the following:
Fixed lot size input
Optional risk-based position sizing (% (risk per trade)
Stop Loss (fixed points/pips or ATR-based if applicable)
Take Profit configuration
Risk-to-reward ratio support
Maximum spread filter
Slippage control
Maximum simultaneous open trades
Basic cooldown between trades
Magic number management
Equity/balance safety checks
Configurable trading permissions (buy only / sell only / both)
One Symbol vs Multi-Symbol
Use:
Single symbol
Single timeframe
Based strictly on the current chart
This is the correct decision for Phase 1.
Benefits:
Simpler execution flow
Easier debugging
Lower CPU usage
Cleaner state management
More reliable order tracking
Avoids synchronization complexity
Architecture assumption:
One EA instance per chart
One symbol context
One timeframe context
Avoid for now:
multi-symbol scanning
centralized portfolio engine
cross-chart communication
symbol routing
correlation logic
Future extensibility:
Your modular structure should still isolate the following:
signal engine
execution engine
risk engine
This makes future multi-symbol expansion possible without rewriting the core.
The EA should:
Be modular and extensible
Use clean separation of concerns
Support future integration of:
filters
session logic
AI optimization
volatility layers
portfolio controls
advanced trade management
multi-strategy routing
Architecture Goals:
Clean and maintainable codebase
Production-style folder structure
Clear module responsibilities
Configurable engine design
Scalable architecture without premature complexity
High execution reliability
Easy debugging and testing
Suggested Focus Areas:
Signal evaluation pipeline
Indicator management system
Trade execution module
Risk management module
Position sizing engine
Configuration/input management
Logging and debugging utilities
State and trade tracking
What I need from you:
Design the execution engine architecture
Define module responsibilities and execution workflow
Recommend an MT5 production-grade folder structure
Suggest industry best practices for EA development
Keep implementation practical, scalable, and efficient
Avoid unnecessary abstraction or feature creep
Prioritize configurability, maintainability, and execution reliability
The current objective is NOT strategy perfection or advanced intelligence.
The objective is building a strong, configurable execution foundation first.

Gap answered 
Gap Categories & Priorities
🔴 Core Signal Logic (must build first)

Opening range state machine — FORMING → LOCKED → TRADED/EXPIRED per session
First-breakout flag — boolean per session, resets on new session open
VWAP — session-anchored (resets at London/NY open, not midnight)
Volume filter — tick vol on breakout candle ≥ 1.5× its 20-bar MA
Minimum range gate — range width must be ≥ 0.8 × ATR(14) before arming

🔴 SL/TP Calculation

Long SL = opening range low (with broker stop level check)
Short SL = opening range high
TP = breakout price ± range width (measured move)
All in price, not pips — validate against SYMBOL_TRADE_STOPS_LEVEL

🔴 Risk & Execution Engine

Fixed lot OR % risk → back-calculate lot from SL distance
Spread filter before entry
Slippage control on market orders
Max simultaneous trades, cooldown timer, magic number
Equity floor check before every send
Order validation: lot step/min/max, margin, freeze level

🟡 Session Handling (lightweight version for Phase 1)

Hardcode London (07:00–12:00 GMT) and NY (13:00–17:00 GMT) open times
Store as inputs, convert broker time → GMT via TimeGMT()
DST: expose a GMTOffset input — don't auto-detect yet
Range formation window starts at session open time, locks after N minutes (configurable: 5/10/15)

🟡 Logging / Debug Journal

Every signal rejection logs reason: RANGE_TOO_NARROW, VOL_INSUFFICIENT, WRONG_SIDE_OF_VWAP, etc.
Every order failure logs error code + context
Write to Print() + optional file via FileWrite() for optimization replay