We are building an MT5 Expert Advisor (EA) centred around the following trading concept and system architecture:
[The RSI + Bollinger Band Reversion Stack
Indicators: Bollinger Bands (20,2) + RSI (14) + Volume
How it works:
Price tags the outer Bollinger Band (upper or lower)
RSI simultaneously shows overbought (>70) or oversold (<30)
Volume spike confirms exhaustion or capitulation at the extreme
Entry logic: Price touches lower BB → RSI < 30 → Volume surge (selling climax) → Long entry targeting BB midline
Why it works: Three independent measures — volatility, momentum oscillation, and volume — all agreeing on an extreme. Strong mean reversion edge.
Best on: 1H–Daily | Forex pairs, indices, liquid stocks in ranges Weakness: In a trend, price can "walk the band" — RSI stays oversold while price keeps falling]
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

Gaps answerd 
Exit Rules (Keep v1 Simple & Deterministic)
Default to hard SL + hard TP as the primary exit mechanism.
Add optional BB Midline Exit as a configurable feature because it is directly aligned with the strategy’s mean-reversion logic.
Recommended v1 exit hierarchy:
Fixed SL or ATR-based SL
TP by:
Fixed R:R (default)
OR BB Midline touch
Optional emergency exit:
Opposite signal appears before TP
Avoid advanced exits initially:
trailing stops
partial closes
scale-outs
adaptive exits
time-based exits
Suggested v1 exit modes:
EXIT_FIXED_RR
EXIT_BB_MIDLINE
EXIT_FIXED_POINTS
Recommended default:
Mean reversion target = Bollinger midline
Protective SL beyond recent swing or ATR multiple
Why this is ideal:
Keeps the execution engine lightweight
Preserves strategy identity
Makes optimization cleaner
Easier debugging and validation
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
Your modular structure should still isolate:
signal engine
execution engine
risk engine
This makes future multi-symbol expansion possible without rewriting the core.
Optimization Story (Very Important)
Separate inputs into:
Safe Optimization Parameters
Structural/System Parameters
Safe to Optimize
These affect signal quality and trade behavior directly.
Bollinger Band settings:
BB period
BB deviation
RSI settings:
RSI period
Overbought threshold
Oversold threshold
Volume logic:
Volume MA period
Volume spike multiplier
Entry thresholds:
Minimum BB penetration
RSI confirmation buffer
Risk management:
SL distance
TP distance
ATR multiplier
Risk:Reward ratio
Trade timing:
Cooldown candles
Max simultaneous trades
Execution tolerance:
Slippage threshold
Max spread threshold (within reason)
Why these are safe:
They tune behavior without changing architecture.
They are statistically testable.
They can be optimized using MT5 Strategy Tester safely.
Structural Parameters (DO NOT Optimize Aggressively)
These define system behavior or infrastructure integrity.
Magic number
Trade direction permissions
buy only
sell only
both
Logging/debug flags
Symbol/timeframe mode
Order comment formats
Retry logic
Broker execution settings
Fill policy
Equity protection enable/disable
Maximum daily loss enforcement
Safety shutdown triggers
Why these are structural:
They are operational controls, not alpha generators.
Optimizing them creates misleading backtests.
Can cause unstable or curve-fit behavior.
Recommended Optimization Philosophy
Optimize:
indicator sensitivity
volatility thresholds
stop placement
TP behavior
confirmation strictness
Do NOT optimize:
architecture
execution infrastructure
safety systems
operational constraints
Recommended v1 Strategy Logic
Long Setup:
Price touches/pierces lower BB
RSI < oversold threshold
Volume spike confirmed
No open long trade
Spread acceptable
Cooldown satisfied
Exit:
BB midline OR fixed TP
Hard SL always active
Short Setup:
Mirror inverse conditions
Best Production Decision for v1
Keep:
deterministic logic
fully explainable signals
minimal moving parts
modular architecture
Avoid:
adaptive AI logic
self-learning parameters
dynamic filters
multi-layer confirmation trees
overfitting through excessive optimization