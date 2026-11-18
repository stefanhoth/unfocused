# UX Metrics Frameworks Compendium

## HEART Framework Deep Dive

Google's HEART framework organizes user experience metrics into five dimensions. Apply the Goals-Signals-Metrics (GSM) process to each dimension: define what success looks like (Goal), identify observable user behaviors that indicate progress toward the goal (Signals), and translate those signals into quantifiable metrics.

### Happiness

Happiness captures subjective user attitudes — satisfaction, perceived ease of use, and overall sentiment. Measure happiness through survey instruments deployed at contextually appropriate moments.

| Metric | Definition |
|--------|-----------|
| CSAT (Post-task) | Percentage of users rating satisfaction 4 or 5 on a 5-point Likert scale immediately after completing a task |
| Ease-of-use rating | Mean score on a single-item "How easy was it to complete this task?" scale (1-7) |
| NPS (In-product) | Net Promoter Score collected at a natural pause point within the product experience |
| SUS score | System Usability Scale score aggregated from 10-item questionnaire |
| Visual appeal rating | Mean score on a "How visually appealing is this interface?" scale (1-5) |
| Sentiment polarity | Ratio of positive to negative terms in open-ended feedback, app store reviews, or support tickets |
| Emotional response | Self-reported emotional state using the SAM (Self-Assessment Manikin) valence dimension |
| Perceived performance | User rating of application speed and responsiveness (1-5 scale) |

**Signal selection guidance:** Deploy happiness surveys at moments of completion, not interruption. Avoid surveying during onboarding flows or error states. Sample no more than 10-15% of sessions to prevent survey fatigue.

**Common pitfalls:** Relying solely on happiness metrics creates a "feel-good" bias. Users can report high satisfaction with a product they rarely use. Always pair happiness metrics with behavioral dimensions.

### Engagement

Engagement measures the depth and frequency of user interaction. Focus on actions that correlate with value delivery, not vanity metrics.

| Metric | Definition |
|--------|-----------|
| DAU/MAU ratio | Daily active users divided by monthly active users — measures visit frequency (stickiness) |
| Session duration (median) | Median time per session, excluding sessions under 5 seconds |
| Session depth | Average number of meaningful actions per session |
| Feature adoption rate | Percentage of active users who use a specific feature within a defined period |
| Content consumption rate | Percentage of available content viewed, read, or interacted with per session |
| Interaction intensity | Number of high-value actions (saves, shares, creates) per active user per week |
| Return visit interval | Median number of days between consecutive visits |
| Scroll depth | Percentage of page content viewed on long-form pages |

**Signal selection guidance:** Define "active" precisely — a page view is not engagement. Require at least one meaningful action (click, scroll past fold, search, filter) to count a session as engaged.

**Common pitfalls:** Longer session duration is not always better. In productivity tools, shorter task-completion times indicate higher engagement quality. Define engagement relative to the product's value proposition.

### Adoption

Adoption tracks new user acquisition and feature uptake. Distinguish between product-level adoption (new users) and feature-level adoption (existing users discovering new capabilities).

| Metric | Definition |
|--------|-----------|
| New user signups | Count of first-time account creations per period |
| Activation rate | Percentage of new signups who complete the defined activation milestone within 7 days |
| Onboarding completion | Percentage of new users who finish the onboarding sequence |
| Feature discovery rate | Percentage of users who encounter a new feature within 30 days of release |
| First-use conversion | Percentage of users who use a feature a second time after initial exposure |
| Upgrade conversion | Percentage of free users who convert to a paid tier within 90 days |
| Referral rate | Percentage of active users who invite at least one other person |

**Common pitfalls:** High signup numbers without activation indicate a leaky funnel. Track adoption through the full new-user journey, not just the top of the funnel.

### Retention

Retention measures whether users return over time. Retention is the single strongest predictor of long-term product health.

| Metric | Definition |
|--------|-----------|
| Day 1/7/30 retention | Percentage of users who return on day 1, 7, or 30 after first use |
| Rolling retention | Percentage of users active in the current period who were also active in the previous period |
| Churn rate | Percentage of users who stop using the product within a defined window |
| Resurrection rate | Percentage of churned users who return after 30+ days of inactivity |
| Subscription renewal rate | Percentage of subscribers who renew at the end of their billing period |
| Habit formation rate | Percentage of new users who reach a defined usage frequency (e.g., 3 sessions/week for 3 consecutive weeks) |

**Common pitfalls:** Averaging retention across all cohorts masks trends. Always visualize retention by cohort (weekly or monthly acquisition groups) to detect improvements or regressions.

### Task Success

Task success quantifies how effectively and efficiently users accomplish their goals. This dimension is the most directly tied to usability.

| Metric | Definition |
|--------|-----------|
| Task completion rate | Percentage of users who successfully complete a defined task |
| Time on task | Time elapsed from task initiation to successful completion |
| Error rate | Number of errors per task attempt |
| Lostness score | Measure of navigational inefficiency (formula below) |
| Abandon rate | Percentage of users who start but do not complete a task |
| Retry rate | Percentage of tasks requiring more than one attempt |
| Optimal path adherence | Percentage of users who follow the shortest path to task completion |
| Assistance rate | Percentage of tasks requiring help documentation, chat, or support contact |

**Common pitfalls:** Measuring task success only in controlled usability tests misses real-world complexity. Instrument key task flows in production analytics to track task success at scale.

### Worked Example: E-Commerce Checkout Redesign

| Dimension | Goal | Signal | Metric | Target |
|-----------|------|--------|--------|--------|
| Happiness | Users find checkout effortless | Post-purchase satisfaction survey responses | Mean ease-of-checkout rating (1-7 scale) | >= 5.5 |
| Engagement | Users interact with upsell recommendations | Clicks on "frequently bought together" items | Click-through rate on cross-sell module | >= 8% |
| Adoption | New users complete their first purchase | First-time buyers completing checkout | First-purchase conversion rate (within 14 days of signup) | >= 12% |
| Retention | Buyers return for repeat purchases | Second purchase within 60 days | 60-day repeat purchase rate | >= 25% |
| Task Success | Users complete checkout without errors | Checkout completions without error recovery | Checkout error-free completion rate | >= 92% |

---

## SUS Detailed Scoring

The System Usability Scale, developed by John Brooke in 1986, is a 10-item Likert-scale questionnaire that produces a single composite score representing perceived usability. SUS is technology-agnostic, quick to administer, and has extensive normative data.

### The 10 SUS Items

1. I think that I would like to use this system frequently.
2. I found the system unnecessarily complex.
3. I thought the system was easy to use.
4. I think that I would need the support of a technical person to be able to use this system.
5. I found the various functions in this system were well integrated.
6. I thought there was too much inconsistency in this system.
7. I would imagine that most people would learn to use this system very quickly.
8. I found the system very cumbersome to use.
9. I felt very confident using the system.
10. I needed to learn a lot of things before I could get going with this system.

Each item uses a 5-point Likert scale: 1 (Strongly disagree) to 5 (Strongly agree).

### Scoring Algorithm

Follow these steps precisely:

1. For odd-numbered items (1, 3, 5, 7, 9): subtract 1 from the user's response. This yields a score contribution of 0-4.
2. For even-numbered items (2, 4, 6, 8, 10): subtract the user's response from 5. This yields a score contribution of 0-4.
3. Sum all 10 item contributions to get a raw score (range: 0-40).
4. Multiply the raw score by 2.5 to produce the final SUS score (range: 0-100).

```
SUS Score = ( SUM(odd_item - 1) + SUM(5 - even_item) ) * 2.5

Example: Responses [4, 2, 5, 1, 4, 2, 5, 1, 4, 2]
Odd items:  (4-1) + (5-1) + (4-1) + (5-1) + (4-1) = 3+4+3+4+3 = 17
Even items: (5-2) + (5-1) + (5-2) + (5-1) + (5-2) = 3+4+3+4+3 = 17
Raw score: 17 + 17 = 34
SUS score: 34 * 2.5 = 85.0
```

### Percentile Benchmark Table

| Percentile | SUS Score | Interpretation |
|-----------|-----------|----------------|
| 25th | 62.7 | Below average — significant usability concerns |
| 50th | 68.0 | Median — acceptable but room for improvement |
| 75th | 77.2 | Above average — good usability |
| 90th | 84.1 | Excellent — strong usability |
| 95th | 90.9 | Exceptional — top-tier usability |

### Adjective Scale Mapping

| SUS Score Range | Adjective Rating |
|----------------|-----------------|
| 0-24 | Worst Imaginable |
| 25-38 | Awful |
| 39-51 | Poor |
| 52-62 | OK / Marginal |
| 63-72 | Good |
| 73-84 | Excellent |
| 85-100 | Best Imaginable |

### Grade Scale

| SUS Score Range | Grade |
|----------------|-------|
| >= 80.3 | A |
| 68.0-80.2 | B |
| 51.0-67.9 | C |
| 36.7-50.9 | D |
| < 36.7 | F |

### Curved Grading Interpretation

The SUS scale is not linear in its interpretation. A score of 68 is the midpoint (50th percentile), not 50. This means a SUS score of 50 is actually well below average — roughly the 15th percentile. Treat SUS scores on a curved scale where small improvements above 68 represent meaningful percentile jumps, while gains below 50 indicate the product has fundamental usability problems.

### When to Use SUS

**Appropriate:** Post-test questionnaire in usability studies, comparative evaluation of design alternatives, longitudinal benchmarking across releases, cross-industry comparison using normative data.

**Inappropriate:** In-app micro-surveys (too many items), measuring specific UX dimensions (SUS produces a single composite), contexts requiring diagnostic detail about what is broken.

### SUS for Comparative Studies

When comparing two designs, administer SUS to both groups under identical conditions. Use a between-subjects design with at least 20 participants per condition. Apply a two-sample t-test (or Mann-Whitney U for non-normal distributions) to determine whether the score difference is statistically significant. A difference of 10+ points between designs typically indicates a meaningful difference; differences under 5 points are rarely significant with sample sizes under 50.

---

## UEQ Scales and Interpretation

The User Experience Questionnaire (UEQ) measures six UX dimensions using 26 semantic differential items on a 7-point scale ranging from -3 to +3.

### Six Scales

| Scale | Definition | Example Item Pair |
|-------|-----------|-------------------|
| Attractiveness | Overall impression of the product | unpleasant / pleasant |
| Perspicuity | Ease of learning and understanding | not understandable / understandable |
| Efficiency | Speed and effort required to accomplish goals | slow / fast |
| Dependability | Predictability and sense of control | not secure / secure |
| Stimulation | Excitement and motivation to use | boring / exciting |
| Novelty | Creativity and innovation of the design | conventional / inventive |

### Quality Groupings

**Pragmatic Quality** = Perspicuity + Efficiency + Dependability. Measures goal-directed, task-oriented quality. Answers: "Can users accomplish their goals?"

**Hedonic Quality** = Stimulation + Novelty. Measures non-instrumental, experience-oriented quality. Answers: "Does the product feel engaging and innovative?"

**Attractiveness** spans both dimensions as an overall valence measure.

### Benchmark Interpretation

| Category | Mean Score Range | Interpretation |
|----------|-----------------|----------------|
| Excellent | >= 1.75 | Top 10% — among the best products evaluated |
| Good | 1.00 to 1.74 | Above average — clear positive impression |
| Above Average | 0.50 to 0.99 | Slightly positive — minor improvement opportunities |
| Below Average | -0.49 to 0.49 | Neutral — no clear positive or negative impression |
| Bad | -0.99 to -0.50 | Negative impression — needs attention |
| Very Bad | <= -1.00 | Bottom results — fundamental redesign warranted |

### UEQ+ Modular Variant

UEQ+ allows selecting only the scales relevant to a given evaluation context. It adds additional scales (Visual Aesthetics, Content Quality, Clarity, Usefulness, Intuitive Use, Response Time, Customizability) beyond the original six. Use UEQ+ when the full 26-item UEQ is too lengthy or when specific dimensions are irrelevant.

### When UEQ Adds Value Over SUS

Use UEQ instead of SUS when diagnostic detail across multiple experience dimensions is needed, when hedonic quality matters (consumer products, entertainment, creative tools), or when benchmarking against the UEQ dataset of 450+ products. Use SUS when a quick single-score benchmark suffices and broad normative comparison is the priority.

---

## UMUX-Lite

The Usability Metric for User Experience - Lite is a two-item questionnaire designed for contexts where brevity is critical.

### Items

1. "[Product name]'s capabilities meet my requirements." (1-7 Likert scale: Strongly disagree to Strongly agree)
2. "[Product name] is easy to use." (1-7 Likert scale: Strongly disagree to Strongly agree)

### Scoring

```
UMUX-Lite Score = ((Item1 - 1) + (Item2 - 1)) / 12 * 100
```

The score maps to a 0-100 scale for comparability with SUS. Research demonstrates a correlation of r = 0.83 with SUS scores, making UMUX-Lite a reliable proxy when SUS administration is impractical.

### When to Use

Deploy UMUX-Lite for in-app micro-surveys, high-frequency pulse measurement (weekly or per-feature), mobile contexts where screen real estate prohibits longer instruments, and longitudinal tracking where survey fatigue from repeated SUS administration would degrade response rates.

---

## SUPR-Q

The Standardized User Experience Percentile Rank Questionnaire (SUPR-Q) is an 8-item instrument designed specifically for website evaluation. It measures four factors.

### Four Factors

| Factor | Description | Items |
|--------|-------------|-------|
| Usability | Perceived ease of use and learnability | 2 items |
| Trust/Credibility | Confidence in the website's reliability and trustworthiness | 2 items |
| Appearance | Visual appeal and professional quality of the design | 2 items |
| Loyalty | Likelihood to return and recommend | 2 items (including NPS) |

### Scoring and Benchmarking

Score each factor and the composite on a percentile rank against the MeasuringU benchmark database of 200+ websites. A percentile rank of 50 means the website scores at the median; 75 means it outperforms 75% of the benchmark set. Use SUPR-Q for web-specific benchmarking when comparing against industry peers. Do not use it for native mobile apps, desktop software, or hardware interfaces.

---

## Task Metrics Deep Dive

### Binary vs Partial Success Scoring

**Binary scoring** assigns 1 (success) or 0 (failure) to each task attempt. Use binary scoring when the task has a clear pass/fail criterion.

**Partial success scoring** assigns weighted credit for partially completed tasks:

```
Weighted Score = (w1 * step1) + (w2 * step2) + ... + (wn * stepn)
Where each step has a weight reflecting its contribution to the overall task,
and step values are 1 (completed) or 0 (not completed).
Sum of all weights = 1.0.
```

### Completion Rate and Confidence Intervals

Calculate the task completion rate as a simple proportion. For small samples, compute the adjusted-Wald 95% confidence interval:

```
p_adj = (successes + 2) / (n + 4)
CI = p_adj +/- 1.96 * sqrt(p_adj * (1 - p_adj) / (n + 4))
```

With 8 out of 10 users succeeding: p_adj = 10/14 = 0.714, CI = 0.714 +/- 0.236 = [0.478, 0.950]. Report this range to avoid overconfidence from small samples.

### Time-on-Task Analysis

Use the geometric mean rather than the arithmetic mean for time-on-task data, because task times are positively skewed. Calculate the geometric mean by taking the exponential of the mean of the log-transformed values:

```
Geometric Mean = exp( (1/n) * SUM(ln(time_i)) )
```

**Outlier handling:** Remove task times exceeding 3 standard deviations above the mean of the log-transformed data. Alternatively, cap outliers at the 95th percentile value.

**Comparison:** Use a two-sample t-test on the log-transformed times to compare conditions. Report the ratio of geometric means as the effect size (e.g., "Design B was 1.3x faster than Design A").

### Error Taxonomy

| Error Type | Definition | Example | Severity Weight |
|-----------|-----------|---------|----------------|
| Slip | Correct intention, incorrect execution | Clicking the adjacent button by mistake | Low (1) |
| Mistake | Incorrect intention based on flawed mental model | Searching in the wrong section because the IA is unclear | Medium (2) |
| System error | Software failure preventing task completion | Form submission fails silently due to a validation bug | High (3) |

Classify every observed error and compute a weighted error score per task: `Error Score = SUM(count_per_type * severity_weight)`.

### Lostness Formula

```
Lostness = sqrt( (N/S - 1)^2 + (R/N - 1)^2 )
Where:
  N = number of different pages/screens visited
  S = total number of pages/screens visited (including revisits)
  R = minimum number of pages/screens required for optimal task completion
```

| Lostness Score | Interpretation |
|---------------|----------------|
| 0.0 - 0.4 | Not lost — efficient navigation |
| 0.4 - 0.5 | Mildly lost — minor navigational friction |
| > 0.5 | Lost — significant navigation problems |

### Efficiency: Optimal Path Ratio

```
Optimal Path Ratio = Minimum required actions / Actual actions taken
```

A ratio of 1.0 indicates perfect efficiency. Ratios below 0.5 indicate the user took more than twice the optimal number of actions and signal significant usability problems in the information architecture or interaction flow.

---

## NPS, CES, CSAT in UX Context

### Net Promoter Score (NPS)

**Calculation:** Ask "How likely are you to recommend [product] to a friend or colleague?" on a 0-10 scale. Group responses: Promoters (9-10), Passives (7-8), Detractors (0-6). NPS = %Promoters - %Detractors. Range: -100 to +100.

**UX-specific interpretation:** NPS measures brand loyalty and overall satisfaction, not usability. A product can have a high NPS due to strong brand affinity despite mediocre usability. Do not use NPS as a usability metric. Use it to gauge overall product-market fit and emotional attachment.

**Limitations for UX work:** NPS provides no diagnostic information. A score change from 30 to 20 does not indicate what degraded. Always supplement NPS with follow-up open-ended questions and task-level metrics.

### Customer Effort Score (CES)

**Survey item:** "To what extent do you agree: [Company] made it easy for me to [complete task]." (1-7 Likert scale.)

**When effort matters more than satisfaction:** Use CES for support interactions, onboarding flows, and complex task sequences where reducing friction is the primary goal. CES is a stronger predictor of churn in service contexts than CSAT. CES focuses on the process; CSAT focuses on the outcome.

**CES vs SUS:** CES measures effort for a specific interaction; SUS measures perceived usability of the overall system. Use CES for touchpoint-level measurement and SUS for product-level benchmarking.

### Customer Satisfaction Score (CSAT)

**Survey design:** Ask "How satisfied are you with [specific aspect]?" on a 1-5 scale. Deploy CSAT immediately after the relevant experience (post-purchase, post-support, post-onboarding). Calculate as the percentage of respondents selecting 4 or 5.

**Contextual deployment:** Trigger CSAT surveys based on behavioral events (task completion, feature first-use, subscription renewal) rather than arbitrary time intervals. Rotate survey deployment across user segments to prevent fatigue.

---

## Analytics Metric Design

### Event Taxonomy

Establish a consistent naming convention for analytics events. Use a hierarchical structure:

```
category.action.label

Examples:
  checkout.step_completed.shipping_address
  checkout.step_completed.payment_method
  checkout.error.card_declined
  search.query_submitted.global
  search.result_clicked.position_3
  onboarding.step_completed.profile_setup
  onboarding.step_skipped.tutorial
```

Enforce lowercase with underscores. Avoid camelCase to prevent inconsistencies across teams. Document every event in a shared event dictionary with its trigger condition, properties, and owning team.

### Funnel Construction

Define each funnel with explicit entry and exit criteria:

1. **Entry event:** The first event that begins the funnel (e.g., `checkout.started`).
2. **Step sequence:** Ordered list of events the user must complete. Decide whether steps must occur in strict order or any order.
3. **Exit criteria:** The terminal success event (e.g., `checkout.order_confirmed`) and the maximum time window (e.g., 30 minutes from entry).
4. **Conversion calculation:** `Conversion Rate = Users completing final step / Users triggering entry event`.

Calculate step-to-step drop-off rates to identify the highest-friction points.

### Cohort Definitions

| Cohort Type | Definition | Use Case |
|------------|-----------|----------|
| Acquisition-date | Users grouped by signup week or month | Measuring retention improvements over time |
| Behavior-based | Users grouped by actions taken (e.g., "completed onboarding" vs "skipped onboarding") | Comparing outcomes between behavioral segments |
| Attribute-based | Users grouped by demographics, plan tier, device type, or geography | Identifying segment-specific usability issues |

### Segmentation Strategies

Segment UX analytics by device type (mobile vs desktop), user tenure (new vs returning vs power user), entry point (organic search vs direct vs referral), and plan tier (free vs paid). Compare task success rates, error rates, and time-on-task across segments to surface population-specific problems.

---

## Experimentation Deep Dive

### Hypothesis Template

Structure every experiment hypothesis using this template:

```
If we [change X],
then [metric Y] will [improve/decrease] by [Z%]
because [reasoning based on research or data].

Example:
If we reduce the checkout form from 3 pages to 1 page,
then the checkout completion rate will increase by 15%
because session recordings show 34% of users abandon between pages 2 and 3.
```

### Sample Size Calculation

Determine the required sample size per variant before launching any experiment. The four inputs:

| Input | Definition | Typical Default |
|-------|-----------|----------------|
| Baseline rate | Current conversion/metric rate | Measured from production data |
| Minimum Detectable Effect (MDE) | Smallest meaningful improvement | 5-10% relative lift |
| Significance level (alpha) | Probability of false positive | 0.05 |
| Power (1 - beta) | Probability of detecting a true effect | 0.80 |

**Rule of thumb:** For a baseline conversion rate of 5% and a 10% relative MDE (absolute change from 5.0% to 5.5%), expect to need approximately 50,000 users per variant at 80% power and 95% significance.

### Statistical Significance

**p-value:** The probability of observing results at least as extreme as the measured difference, assuming no true difference exists. A p-value below 0.05 means there is less than a 5% probability the observed result is due to chance.

**Confidence interval:** Report the 95% confidence interval for the difference between variants. If the interval does not contain zero, the result is statistically significant.

**Practical significance vs statistical significance:** A statistically significant result may be practically meaningless. A 0.1% increase in conversion rate can be statistically significant with millions of users but may not justify the engineering cost of implementation. Define a minimum practical threshold before launching the experiment.

### Duration Estimation

Run every experiment for at least one full business cycle (typically 7 days) to capture day-of-week effects. Calculate the required duration:

```
Duration (days) = Required sample size per variant * Number of variants / Daily traffic to the experiment
```

Never end an experiment early because it "looks significant." Early stopping inflates false positive rates. If early stopping is operationally necessary, use sequential testing methods.

### Multivariate Testing

Use multivariate tests (MVT) when evaluating the combined effect of multiple simultaneous changes. Apply factorial design: if testing 2 headline variants and 2 CTA colors, create 4 cells (2x2). MVT requires substantially more traffic than A/B tests — the sample size requirement multiplies with each additional factor. Reserve MVT for high-traffic pages where interactions between variables are hypothesized.

### Sequential Testing

Sequential testing (also called continuous monitoring) applies statistical methods that control for multiple comparisons over time. Use group sequential designs or always-valid confidence intervals to monitor experiment results without inflating the false positive rate. Tools like Optimizely and Eppo implement sequential testing natively. Prefer sequential testing for experiments on business-critical flows where waiting for full sample accumulation is impractical.

---

## ROI of UX

### ROI Calculation Formula

```
ROI = [(Benefits - Costs) / Costs] x 100%
```

### Benefit Categories

| Benefit Category | How to Measure | Typical Impact |
|-----------------|----------------|----------------|
| Reduced development rework | Track rework tickets before/after UX involvement; multiply hours saved by engineering hourly rate | 33-50% reduction in rework when UX is involved early |
| Reduced support tickets | Count support tickets related to usability issues before/after redesign | 20-40% reduction in usability-related tickets |
| Increased conversion | Measure conversion rate lift from UX improvements; multiply by average revenue per conversion | 10-200% lift depending on baseline and severity of issues |
| Increased retention | Measure retention rate improvement; multiply by customer lifetime value | 5% retention improvement can yield 25-95% profit increase |
| Reduced training costs | Measure training hours required before/after redesign; multiply by training cost per hour | 25-60% reduction in training time for enterprise software |

### Case Study Example

An enterprise SaaS company invested $150,000 in a checkout flow redesign (2 designers, 1 researcher, 12 weeks). The redesign increased checkout conversion from 3.2% to 4.1% (28% relative lift). With 500,000 monthly checkout initiations and $85 average order value, the monthly revenue increase was: 500,000 * (0.041 - 0.032) * $85 = $382,500/month. Annual benefit: $4,590,000. ROI: [($4,590,000 - $150,000) / $150,000] x 100% = 2,960%.

### Stakeholder Communication

When presenting UX ROI to executives, follow these principles:

- Lead with business outcomes (revenue, cost savings, retention), not UX jargon.
- Anchor to metrics the executive already tracks (conversion rate, support cost per user, churn).
- Present a range (conservative, moderate, optimistic) rather than a single number.
- Include the cost of inaction: "If we do not address the checkout friction, we will continue to lose an estimated $382,500/month."
- Use before/after comparisons with specific timeframes.

---

## Design System ROI

### Sparkbox Research Formula

```
Design System ROI = [(TE + QE + SE + SCE) - (IC + MC)] / (IC + MC) x 100%

Where:
  TE  = Time Efficiency gains (hours saved in design and development)
  QE  = Quality Efficiency gains (reduced defects, fewer accessibility violations)
  SE  = Scale Efficiency gains (faster onboarding of new team members, faster new product launches)
  SCE = Strategic/Consistency Efficiency gains (brand consistency value, reduced design debt)
  IC  = Initial Cost (building the design system)
  MC  = Maintenance Cost (ongoing governance, updates, support)
```

### Key Data Points

| Metric | Value | Source |
|--------|-------|--------|
| Design efficiency gain | 38% | Sparkbox Industry Survey |
| Development efficiency gain | 31% | Sparkbox Industry Survey |
| ROI with mature DesignOps | 228% higher than without | Sparkbox ROI Report |
| Time to first component use (mature system) | < 1 day | Industry benchmark |
| Defect reduction | 22-47% | Reported across multiple organizations |

### Maturity Correlation

Higher design system maturity correlates directly with higher ROI. Organizations at the "Optimized" maturity level report 3-5x the ROI of organizations at the "Draft" stage. Invest in governance, documentation, and DesignOps practices alongside component development to maximize returns.

---

## UX Maturity Models

### NNG UX Maturity Scale

| Level | Name | Characteristics |
|-------|------|----------------|
| 1 | Absent | No UX work. Decisions are based on assumptions or stakeholder preferences. No dedicated UX roles. |
| 2 | Limited | UX work is ad hoc and reactive. One or two designers operate without process or authority. UX is seen as visual design only. |
| 3 | Emergent | UX processes exist but are inconsistent. Some research is conducted. UX is involved in some projects. Leadership is beginning to recognize UX value. |
| 4 | Structured | Defined UX processes are followed consistently. A UX team exists with clear roles. Research informs decisions regularly. Metrics are tracked. |
| 5 | Integrated | UX is embedded in product development. Cross-functional collaboration is the norm. UX metrics influence roadmap priorities. Design system is mature. |
| 6 | User-Driven | The entire organization prioritizes user experience. Executive leadership champions UX. Continuous research feeds strategy. UX metrics are OKRs. |

### Assessment Criteria Per Level

Evaluate each of these dimensions when assessing maturity: research practice (frequency, methods, integration), design process (tools, collaboration, iteration), metrics and measurement (what is tracked, who sees the data), organizational structure (team size, reporting lines, executive sponsorship), and culture (how decisions are made, who advocates for users).

### Design System Maturity Model

| Stage | Criteria |
|-------|----------|
| Draft | Components exist in code or design files but lack documentation, accessibility audits, and governance. Usage is inconsistent. |
| Beta | Components are documented with basic usage guidelines. Accessibility compliance is in progress. A contribution process exists but is informal. |
| Stable | Full documentation, accessibility compliance, visual regression tests, and a formal contribution and deprecation process. Adoption exceeds 70% across product teams. |
| Optimized | Automated token sync between design and code. Performance monitoring per component. Analytics track component usage. Governance is partially automated. Adoption exceeds 90%. |

### Maturity Assessment Questionnaire Outline

Structure the assessment around five areas, each scored 1-5:

1. **Research integration:** How frequently does research inform design decisions? (1 = never, 5 = every sprint)
2. **Process consistency:** Are design and development processes standardized? (1 = no process, 5 = fully documented and followed)
3. **Metric coverage:** Are UX metrics tracked and reviewed? (1 = no metrics, 5 = real-time dashboards reviewed weekly)
4. **Organizational support:** Does leadership fund and advocate for UX? (1 = no awareness, 5 = executive sponsor with UX OKRs)
5. **Cross-functional collaboration:** Do designers, researchers, engineers, and PMs collaborate regularly? (1 = siloed, 5 = embedded cross-functional teams)

Compute the average score. Map it to the NNG maturity scale: 1.0-1.5 = Absent, 1.6-2.5 = Limited, 2.6-3.5 = Emergent, 3.6-4.0 = Structured, 4.1-4.5 = Integrated, 4.6-5.0 = User-Driven.

---

## Metric Dashboards

### Dashboard Design Principles

Build UX metric dashboards with four essential elements:

1. **Trend lines:** Display every key metric as a time series. Show at least 12 weeks of history to surface seasonal patterns and distinguish signal from noise.
2. **Targets:** Overlay target lines on every trend chart. Color-code the current value: green (on target), amber (within 10% of target), red (more than 10% below target).
3. **Alerts:** Configure automated alerts when a metric crosses a threshold. Send alerts to the responsible team's Slack channel or email. Define alert severity levels (warning, critical).
4. **Drill-down:** Enable clicking on any aggregate metric to reveal underlying segments (device type, user cohort, geography, feature area). Drill-down prevents dashboards from hiding problems within averages.

### Stakeholder-Specific Views

| Audience | View | Content | Update Cadence |
|----------|------|---------|---------------|
| Executive leadership | Summary scorecard | 5-7 top-level metrics (NPS, task success rate, conversion rate, retention, SUS score) with trend arrows and RAG status | Monthly or quarterly |
| Product management | Feature-level dashboard | Adoption rate, feature-level task success, funnel conversion per feature, error rates by feature area | Weekly |
| Design team | Usability detail view | SUS/UEQ scores per release, task completion rates per flow, heuristic audit scores, accessibility compliance | Per sprint or release |
| Engineering team | Performance and error dashboard | Page load times, error rates, API latency, crash rates overlaid with deployment markers | Daily or real-time |

### Update Cadence Recommendations

| Metric Type | Cadence | Rationale |
|------------|---------|-----------|
| Real-time operational metrics (errors, latency, crashes) | Real-time streaming | Immediate incident detection |
| Behavioral analytics (conversion, engagement, funnel) | Daily aggregation | Captures daily patterns without noise |
| Survey metrics (SUS, NPS, CSAT, UEQ) | Weekly or per-study | Survey data arrives in batches after studies or survey deployment windows |
| Strategic metrics (retention, UX maturity, design system ROI) | Quarterly | These metrics move slowly and require longer observation windows |

### Dashboard Anti-Patterns

Avoid these common dashboard failures:

- **Vanity metrics only:** Showing page views and total users without actionable metrics like task success or error rates.
- **No context:** Displaying numbers without targets, trends, or comparisons. A conversion rate of 4.2% is meaningless without knowing whether it is up, down, or on target.
- **Too many metrics:** Dashboards with more than 12-15 metrics per view cause cognitive overload. Curate ruthlessly.
- **Stale data:** A dashboard nobody updates or reviews is worse than no dashboard. Assign an owner and a review cadence for every dashboard.
- **No segmentation:** Aggregate metrics hide segment-specific problems. A global task success rate of 88% may mask a 60% rate on mobile devices.

---

## Quick Reference: Choosing the Right Instrument

| Need | Instrument | Items | Best For |
|------|-----------|-------|----------|
| Quick usability benchmark | SUS | 10 | Post-test, comparative studies, longitudinal tracking |
| Ultra-short usability pulse | UMUX-Lite | 2 | In-app surveys, high-frequency measurement |
| Multi-dimensional UX assessment | UEQ | 26 | When hedonic and pragmatic quality both matter |
| Modular UX assessment | UEQ+ | Variable | When only specific UX dimensions are relevant |
| Website-specific benchmark | SUPR-Q | 8 | Comparing against web benchmark database |
| Loyalty and advocacy | NPS | 1 | Executive reporting, product-market fit tracking |
| Interaction effort | CES | 1 | Post-support, post-onboarding, high-friction flows |
| Touchpoint satisfaction | CSAT | 1 | Contextual deployment at specific experience moments |
| Holistic product health | HEART + GSM | Custom | Structuring a complete measurement strategy across all UX dimensions |
