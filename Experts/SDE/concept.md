We are building an MT5 Expert Advisor (EA) centred around the following trading concept and system architecture:
[The Volatility Breakout Stack
Indicators: Bollinger Bands (20,2) + Keltner Channel (20,1.5) + ADX (14)
How it works:
When Bollinger Bands contract inside the Keltner Channel = Squeeze (TTM Squeeze concept)
Squeeze signals low volatility compression — a big move is loading
ADX rising above 20–25 after the squeeze confirms a new directional trend has started
Entry logic: BB inside KC (squeeze on) → BB begins to expand outside KC (squeeze fires) → ADX rises → Enter in the direction of the expansion
Why it works: The squeeze is one of the most statistically robust pre-breakout signals. ADX filters out false fires. Developed and popularised by John Carter (TTM Squeeze).
Best on: 1H–Daily | Any liquid instrument before earnings, macro events, or after long consolidations Weakness: Squeeze can fire and reverse immediately (false breakout); ADX lags the initial move
]
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


Gap Answered
Formal State Machine
Define explicit EA states to prevent execution drift and signal duplication:
STATE_FLAT
No active setup or trade
Waiting for squeeze detection
STATE_SQUEEZE_ON
BB fully inside KC
Compression phase active
STATE_SQUEEZE_FIRED
BB expands outside KC after squeeze
Breakout candidate detected
STATE_ADX_CONFIRM
ADX threshold crossed/rising
Direction validated
STATE_IN_TRADE
Active position exists
Entry complete
STATE_COOLDOWN
Trade exited
Temporary lockout to avoid immediate re-entry
Define strict transitions:
FLAT → SQUEEZE_ON
SQUEEZE_ON → SQUEEZE_FIRED
SQUEEZE_FIRED → ADX_CONFIRM
ADX_CONFIRM → IN_TRADE
IN_TRADE → COOLDOWN
COOLDOWN → FLAT
Add invalidation rules:
Squeeze canceled before fire
ADX fails within X bars
Opposite breakout appears
Track:
breakout candle index
setup timestamp
last trade timestamp
signal direction
setup expiration bars
Exact Indicator Handles & Buffers
Standardize all indicator reads on:
shift = 1 (last closed candle only)
Never use shift 0 for entries
Define handles explicitly:
BB handle
KC handle
ADX handle
Define exact buffers:
BB upper/lower/middle
KC upper/lower/basis
ADX main line
optional +DI / -DI later
Add warmup requirements:
minimum bars before logic starts
recommended:
max(BB period, KC period, ADX period) + safety buffer
example: 100 bars minimum
Mandatory checks:
BarsCalculated(handle)
CopyBuffer() return validation
avoid calculations on incomplete history
Add centralized indicator manager module:
all handles initialized once in OnInit
released in OnDeinit
Keltner Channel Definition
This must be frozen early to avoid inconsistent optimization later.
Recommended definition:
Basis:
EMA(20)
Envelope:
ATR(20) * 1.5
Upper:
EMA + ATR multiplier
Lower:
EMA - ATR multiplier
Clarify:
EMA vs SMA
ATR vs high-low range
ATR smoothing method
Recommended:
Modern TTM-style implementation:
EMA basis
ATR-based bands
MT5 issue:
No native KC indicator
Recommendation:
Build custom KC module internally
Avoid dependency on external indicators
Order Type Edge Cases
v1 should remain:
market execution only
Document behavior for:
market closed
invalid spread
requotes
no liquidity
trade context busy
broker rejection
Handle broker execution specifics:
SYMBOL_TRADE_MODE
SYMBOL_FILLING_MODE
SYMBOL_TRADE_EXECUTION
Define filling fallback:
FOK → IOC if supported
Add retry policy:
max retry attempts
retry delay
Future-proof notes:
partial fills
pending orders
stop/limit entries
Centralize all OrderSend() validation logic in execution module
SL/TP in Points vs Price
Normalize for:
3-digit brokers
5-digit brokers
metals/indices later
Use:
_Point
_Digits
Add conversion utility:
pips ↔ points ↔ price
Before execution:
validate:
SYMBOL_TRADE_STOPS_LEVEL
SYMBOL_TRADE_FREEZE_LEVEL
Ensure:
SL not too close
TP not too close
normalized price precision
Add rejection handling:
invalid stops
freeze-level conflicts
One Position vs Scaling
Define this now to avoid state complexity later.
Recommended for Phase 1:
One signal → One position
Rules:
no pyramiding
no scaling in
no hedging
no averaging down
Entry lock conditions:
ignore new entries while position open
ignore duplicate signals from same squeeze cycle
Benefits:
simpler debugging
cleaner analytics
easier optimization
lower state complexity
Time in Force & Manual Override Policy
Market orders:
immediate execution only
No pending order persistence needed yet
Add configurable permissions:
buy only
sell only
both
disable trading
Clarify:
manual trades ignored unless matching magic number
EA only manages its own positions
Optional future hooks:
news pause
manual override
emergency disable
For now:
keep disabled to avoid scope creep

Recovery After Restart
Critical production requirement.
Recommended behavior:
EA re-syncs existing positions on OnInit
Rebuild runtime state from:
magic number
symbol
open positions
On restart:
scan active positions
restore:
trade direction
entry price
SL/TP
trade state
Prevent:
duplicate entries after restart
orphaned trades
state desynchronization
Add persistent tracking later if needed:
Global Variables
files
lightweight state snapshots
Phase 1 recommendation:
magic-number-based recovery is enough
Additional Hidden Gaps Worth Filling Early
Candle processing model
process only once per new closed bar
avoid intra-bar signal noise
Direction definition
how exactly bullish vs bearish breakout is detected
ADX confirmation logic
rising ADX?
threshold cross?
slope requirement?
Squeeze persistence
minimum squeeze duration before valid fire
Setup expiration
invalidate setup after X candles
Trade ownership model
magic number isolation
Logging levels
INFO / WARNING / ERROR / DEBUG
Error telemetry
capture broker return codes
Parameter namespace consistency
grouped inputs by:
signal
risk
execution
debugging
Deterministic execution
identical inputs should reproduce identical behavior in backtests whenever possible