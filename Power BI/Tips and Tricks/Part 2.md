# When AI Gets DAX Wrong: A Case Study in SUMX

**Power BI Tips & Tricks Series | Part 2 of 2**

---

## Introduction

AI coding assistants like GitHub Copilot, ChatGPT, and Microsoft Copilot have revolutionized how we write code—including DAX. But there's a catch: **AI doesn't understand performance implications the way a seasoned developer does**.

In Part 1, we explored the mechanics of iterator functions. In this article, we'll examine why AI tools frequently suggest `SUMX` when `SUM` would suffice, and how to critically evaluate AI-generated DAX before deploying it to production.

---

## The Problem: AI is Deterministic, Not Optimal

Here's the uncomfortable truth about AI-generated code:

> **AI optimizes for correctness, not performance.**

When you ask an AI to "calculate total sales," it will give you a solution that *works*. But "working" and "optimal" are two very different things.

### Why AI Loves Iterator Functions

AI models are trained on vast amounts of code. Iterator functions like `SUMX` appear frequently because they're **flexible**—they can handle almost any scenario. This makes them a "safe" choice for AI to suggest.

| What AI Sees | What AI Suggests | The Problem |
|--------------|------------------|-------------|
| "Calculate total sales" | `SUMX(Sales, Sales[Quantity] * Sales[UnitPrice])` | Might work, but is it necessary? |
| "Sum the Amount column" | `SUMX(Sales, Sales[Amount])` | `SUM(Sales[Amount])` is faster |
| "Add up all values" | `SUMX(Table, Table[Value])` | Overkill for simple aggregation |

---

## Real-World Examples: AI Suggestions vs. Optimal DAX

### Example 1: Simple Column Aggregation

**Prompt to AI:** "Create a measure to calculate total revenue"

**AI Suggestion:**
```dax
Total Revenue = SUMX(Sales, Sales[Revenue])
```

**Optimal Solution:**
```dax
Total Revenue = SUM(Sales[Revenue])
```

**Why it matters:** On a table with 10 million rows, the `SUMX` version forces row-by-row iteration. The `SUM` version leverages the storage engine's optimized aggregation. The difference can be **10x or more** in query time.

---

### Example 2: Calculated Expression (AI Gets It Right)

**Prompt to AI:** "Create a measure to calculate total sales from quantity times price"

**AI Suggestion:**
```dax
Total Sales = SUMX(Sales, Sales[Quantity] * Sales[UnitPrice])
```

**Assessment:** ✅ **This is correct!** You genuinely need `SUMX` here because you're calculating an expression per row.

---

### Example 3: Conditional Sum

**Prompt to AI:** "Calculate total sales for premium customers only"

**AI Suggestion:**
```dax
Premium Sales = 
SUMX(
    FILTER(Sales, Sales[CustomerType] = "Premium"),
    Sales[Amount]
)
```

**Optimal Solution:**
```dax
Premium Sales = 
CALCULATE(
    SUM(Sales[Amount]),
    Sales[CustomerType] = "Premium"
)
```

**Why it matters:** `CALCULATE` with `SUM` allows the engine to apply the filter context efficiently. The `SUMX` with `FILTER` approach first materializes a filtered table in memory, then iterates through it—unnecessary overhead.

---

### Example 4: Sum with Related Table

**Prompt to AI:** "Calculate weighted total using product weight from related table"

**AI Suggestion:**
```dax
Weighted Total = 
SUMX(
    Sales,
    Sales[Quantity] * RELATED(Products[Weight])
)
```

**Assessment:** ✅ **This is correct!** The `RELATED` function requires row context, which only `SUMX` can provide within a measure.

---

## The AI Evaluation Framework

Before accepting AI-generated DAX, run it through this checklist:

### Step 1: Identify the Function Type

```
Is the AI using an iterator function (SUMX, AVERAGEX, COUNTX, etc.)?
├── YES → Continue to Step 2
└── NO → Probably fine, but verify logic
```

### Step 2: Check for Necessity

Ask yourself:
- Is there a **calculation** happening that requires row context?
- Am I combining **multiple columns**?
- Am I using **RELATED** or other row-context functions?

```
Is row-by-row calculation actually needed?
├── YES → Iterator is appropriate ✅
└── NO → Simplify to SUM/AVERAGE/COUNT ⚠️
```

### Step 3: Test Performance

| Test Method | How to Do It |
|-------------|--------------|
| **DAX Studio** | Use Server Timings to compare query duration |
| **Performance Analyzer** | In Power BI Desktop, capture query times |
| **Visual Comparison** | Create both versions and compare refresh times |

---

## Common AI Pitfalls to Watch For

### Pitfall 1: Unnecessary Iteration on Single Columns

```dax
-- ❌ AI Suggestion
Total = SUMX(Sales, Sales[Amount])

-- ✅ Your Fix
Total = SUM(Sales[Amount])
```

### Pitfall 2: Using FILTER When CALCULATE Suffices

```dax
-- ❌ AI Suggestion
Filtered Sum = SUMX(FILTER(Sales, Sales[Region] = "North"), Sales[Amount])

-- ✅ Your Fix
Filtered Sum = CALCULATE(SUM(Sales[Amount]), Sales[Region] = "North")
```

### Pitfall 3: Nested Iterators

```dax
-- ❌ AI Suggestion (performance nightmare)
Complex Calc = 
SUMX(
    Sales,
    SUMX(
        FILTER(Products, Products[Category] = Sales[Category]),
        Products[Price]
    )
)

-- ✅ Your Fix (rethink the logic entirely)
-- Consider using RELATED, CALCULATE, or pre-calculated columns
```

### Pitfall 4: COUNTX for Simple Counts

```dax
-- ❌ AI Suggestion
Order Count = COUNTX(Sales, Sales[OrderID])

-- ✅ Your Fix
Order Count = COUNTROWS(Sales)
-- or
Order Count = COUNT(Sales[OrderID])
```

---

## How to Prompt AI for Better DAX

The quality of AI output depends heavily on your prompt. Here are tips:

### Be Specific About Performance

```
❌ "Create a measure for total sales"

✅ "Create a performance-optimized measure for total sales. 
   The Sales table has 50 million rows. Prefer SUM over SUMX 
   where possible."
```

### Ask for Alternatives

```
✅ "Show me both a SUMX approach and a SUM approach for 
   calculating total sales, and explain when each is appropriate."
```

### Request an Explanation

```
✅ "Create a measure for total sales and explain why you chose 
   that function over alternatives."
```

---

## Performance Impact: The Numbers

Here's what unnecessary iterators can cost you:

| Table Size | SUM Query Time | SUMX Query Time | Difference |
|------------|----------------|-----------------|------------|
| 100,000 rows | ~50ms | ~80ms | 1.6x slower |
| 1,000,000 rows | ~100ms | ~300ms | 3x slower |
| 10,000,000 rows | ~200ms | ~2,000ms | 10x slower |
| 50,000,000 rows | ~500ms | ~12,000ms | 24x slower |

*Note: These are representative figures. Actual performance varies based on model complexity, hardware, and query context.*

---

## The Golden Rules

1. **Trust but verify.** AI-generated DAX should always be reviewed before production use.

2. **Simple first.** Start with the simplest function (`SUM`, `AVERAGE`, etc.) and only use iterators when necessary.

3. **Test at scale.** A measure that works fine on 10,000 rows might crawl on 10,000,000.

4. **Understand before deploying.** If you can't explain why the AI chose `SUMX`, you shouldn't deploy it.

5. **Performance is a feature.** A slow report is a bad report, regardless of how correct the numbers are.

---

## Quick Reference: When to Override AI

| AI Suggests | Override If... | Replace With |
|-------------|----------------|--------------|
| `SUMX(Table, Table[Column])` | Single column, no calculation | `SUM(Table[Column])` |
| `SUMX(FILTER(...), ...)` | Simple filter condition | `CALCULATE(SUM(...), Filter)` |
| `COUNTX(Table, Column)` | Just counting rows/values | `COUNTROWS` or `COUNT` |
| `AVERAGEX(Table, Table[Column])` | Single column average | `AVERAGE(Table[Column])` |

---

## Conclusion

AI is an incredibly powerful tool for accelerating DAX development, but it's not a substitute for understanding. The developers who thrive will be those who:

- Use AI as a **starting point**, not a final answer
- Understand the **performance implications** of iterator functions
- Know **when to simplify** and when iterators are genuinely needed

Next time an AI suggests `SUMX`, ask yourself: "Is this necessary, or is this just the AI playing it safe?"

---

## Discussion Questions for Tips & Tricks

1. Have you encountered AI-generated DAX that caused performance issues?
2. What's your process for validating AI suggestions?
3. Are there other DAX patterns where AI tends to suggest suboptimal solutions?

---

## Resources

- [DAX.guide - SUMX](https://dax.guide/sumx/)
- [SQLBI - Optimizing DAX](https://www.sqlbi.com/articles/)
- [Microsoft Learn - Iterator Functions](https://learn.microsoft.com/en-us/dax/)
- [DAX Studio - Performance Testing](https://daxstudio.org/)

---

*Power BI Tips & Tricks is a monthly forum for K-C Power BI Developers to collaborate, share best practices, and learn from each other.*
