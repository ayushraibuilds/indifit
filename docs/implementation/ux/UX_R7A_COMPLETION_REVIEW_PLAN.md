# UX-R7A Completion Review Plan

1. Validate the exact branch, implementation commit, required ancestry, and
   preserve all pre-existing worktree changes.
2. Review the R7A diff against the integration baseline and trace canonical B03
   food identity, correction, persistence, aggregation, B04 invalidation, and
   backup/restore behavior before changing production code.
3. Reproduce the reported R3/R4 golden failures on both the integration
   baseline and R7A using isolated worktrees, and visually inspect every output.
4. Implement only the smallest safe R7A corrections, including canonical food
   deletion if no accepted retraction authority already exists, with focused
   regression tests.
5. Run focused R1/R2/R3/R4/R6/B03/B04/profile/navigation validation, then the
   required formatter, analyzer, diff, and full serial Flutter test gates.
6. Commit the completed remediation as
   `fix(ux): complete r7a interaction repair` without merging.

Open questions to resolve from repository evidence:

- Whether B03 already exposes an append-only retraction/supersession authority.
- Whether `INDIFIT_API_KEY` authenticates an IndiFit proxy, a provider, or only
  release bootstrap configuration.
- Which of the 11 reported R3/R4 golden mismatches exist on the integration
  baseline and which are R7A changes.
- Whether physical-device automation is available after all code/test gates are
  green.
