# Windsurf Prompts for DSGE.jl

> This file contains ready-to-use prompts for [Windsurf](https://windsurf.com), Cognition's AI-powered IDE. Open this repo in Windsurf, pick a prompt below, and paste it into Cascade. Each prompt includes context on what problem it solves and what Windsurf will do.
>
> Prompts are ordered from simple → complex so you can start easy and build confidence.

---

## Prompt 1 — Understand the DSGE Model Architecture (Beginner)
**What this solves:** DSGE.jl is the New York Fed's official DSGE modeling package, but the codebase is complex — it spans macroeconomic theory, Bayesian estimation, and Julia metaprogramming. Even experienced developers need help navigating it.

**What Windsurf will do:** Map the codebase for you, explain the economic concepts in plain language, and show how the Julia code implements the math.

**Paste this into Cascade:**
```
I'm an engineer (not an economist) who needs to understand this codebase. Give me a layered walkthrough:

1. **What's a DSGE model?** Explain in 3 sentences what this software does, in plain language — no jargon
2. **Project structure**: Walk me through the src/ directory. What are the main modules and what does each one do?
3. **Type hierarchy**: This repo uses Julia's type system heavily. Show me the AbstractDSGEModel type tree — what types exist and how do they relate?
4. **The pipeline**: Trace the full workflow from "I have economic data" to "I have a forecast":
   - Data loading → model construction → parameter estimation → model solution → forecasting
   - Which functions handle each step? Which files are they in?
5. **The Smets-Wouters model**: This is the main built-in model. Where is it defined? What economic variables does it track?
6. **Key dependencies**: What are StateSpaceRoutines.jl and SMC.jl, and how does this package use them?

I want to be able to navigate this codebase confidently after reading your explanation.
```

---

## Prompt 2 — Add Docstrings to Core Functions (Intermediate)
**What this solves:** The core estimation and solution functions have minimal or no docstrings. Economists and developers calling these functions have to read the implementation to understand what arguments to pass and what comes back.

**What Windsurf will do:** Read each function's implementation, understand what it does mathematically and programmatically, and write clear docstrings with parameter descriptions, return types, and usage examples.

**Paste this into Cascade:**
```
The core public functions in this package need proper Julia docstrings. For each function below:

1. Read the implementation carefully
2. Write a docstring that includes:
   - A one-line summary
   - A longer description explaining what the function does (both the math and the code)
   - All parameters with types and descriptions
   - Return type and description
   - A brief usage example
   - Any important notes (e.g., "this modifies the model in-place" or "this is computationally expensive")

Add docstrings to these key functions (find them in the codebase):
- `estimate()` — the main Bayesian estimation entry point
- `solve()` — solves the model for given parameters
- `forecast()` or `forecast_one()` — produces forecasts
- `impulse_responses()` — computes impulse response functions
- `compute_system()` — constructs the state-space representation
- The main model constructor (e.g., `SmetsWouters()` or equivalent)

Use the @doc macro or triple-quoted docstrings — follow whichever convention the codebase already uses.
```

---

## Prompt 3 — Create a Getting Started Tutorial Script (Advanced)
**What this solves:** New users (researchers, economists, grad students) struggle to run their first model. There's no end-to-end example that goes from zero to a working forecast. The README covers installation but not actual usage.

**What Windsurf will do:** Create a complete, runnable Julia script that walks a new user through the entire workflow with extensive comments explaining each step.

**Paste this into Cascade:**
```
Create a file examples/getting_started.jl — a fully commented tutorial script that a new user can run to understand the package. The script should:

1. **Setup** (with comments explaining each step):
   - Import DSGE and dependencies
   - Set up a working directory for output

2. **Model Construction**:
   - Instantiate the default Smets-Wouters model (or whatever the primary built-in model is)
   - Print a summary of the model: how many parameters, how many states, how many observables
   - Show how to inspect and modify a parameter (e.g., change the prior for a specific parameter)

3. **Data Loading**:
   - Load the sample/test data included in the package (find where it is)
   - Show what the data looks like (dimensions, date range, variable names)
   - If no sample data exists, show how to construct synthetic data

4. **Model Solution**:
   - Solve the model at the prior mean parameter values
   - Explain what "solving" means (finding the rational expectations equilibrium)
   - Show the solution matrices and what they represent

5. **Impulse Response Functions**:
   - Compute IRFs for a monetary policy shock
   - Print or describe the results (how GDP, inflation, and interest rates respond)

6. **Estimation** (optional — note it takes a long time):
   - Show the command to estimate the model (but comment it out since it's slow)
   - Explain what estimation does (Bayesian posterior via SMC or MCMC)
   - Show how to load pre-computed estimation results if available

Add extensive comments throughout — this should read like a textbook chapter, not just code. A PhD student in economics with basic Julia knowledge should be able to follow it.
```

---

## Prompt 4 — Diagnose and Fix the Julia 1.11 Compatibility Issue (Expert)
**What this solves:** Issue #245 — DSGE.jl fails to install on Julia 1.11.4+. This is a real, active bug that prevents new users from using the package on the latest Julia version.

**What Windsurf will do:** Reproduce the error, trace it through the dependency chain, identify the root cause, and implement a fix — all while explaining the Julia package ecosystem concepts involved.

**Paste this into Cascade:**
```
This package has a reported issue (#245): it fails to install or precompile on Julia 1.11.4+. I need you to diagnose and fix it.

1. **Reproduce the error**: Look at the Project.toml and figure out what would break on Julia 1.11. Check:
   - Julia version compatibility bounds in Project.toml ([compat] section)
   - Dependencies that might not support Julia 1.11 yet
   - Any use of Julia APIs that were deprecated/removed in 1.11 (check the Julia 1.11 release notes for breaking changes)

2. **Trace the dependency chain**: 
   - List all direct dependencies and their version constraints
   - Identify which dependencies have Julia 1.11 compatibility
   - Check StateSpaceRoutines.jl and SMC.jl (same org, likely same issue)

3. **Fix the issue**:
   - Update version bounds in Project.toml
   - Fix any deprecated Julia syntax (e.g., changes to abstract type declarations, method signatures)
   - If a dependency is the blocker, document which one and what version is needed

4. **Verify**: Show me what commands a user would run to verify the fix works:
   - `julia -e 'using Pkg; Pkg.add("DSGE"); using DSGE'`
   - Running the test suite

Explain each change and why it's needed — I want to understand the Julia package compatibility model.
```

---
