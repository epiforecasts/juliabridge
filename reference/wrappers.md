# Backend-agnostic wrappers around Julia eval / call / import

These thin wrappers exist so consumer packages can call into Julia
without directly depending on JuliaConnectoR. If `juliaready` ever
switches backend, consumer code keeps working.
