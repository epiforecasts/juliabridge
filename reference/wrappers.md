# Backend-agnostic wrappers around Julia eval / call / import

These thin wrappers let consumer packages call into Julia through
juliabridge alone. If `juliabridge` ever switches backend, consumer code
keeps working.
