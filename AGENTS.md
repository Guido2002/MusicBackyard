# MusicBackyard working agreements

The user requests an automatic GitHub release for every new feature or fix.

- Finish implementation and appropriate validation, then commit and push the change to `main` unless the user explicitly asks to keep it local or use a different branch/PR.
- Use `feat(scope): ...` for new functionality and `fix(scope): ...` for corrections. Write a useful, preferably Dutch description; it becomes release notes when no version-specific notes file exists.
- Push changes for one completed feature/fix together. The release workflow publishes one stable release for the app changes in each push, after its checks pass.
- The existing Android releases workflow chooses the version, signs the APK, creates the Git tag/GitHub Release and advances the stable update feed. Do not also create a tag or manually dispatch the same stable release.
- Verify the release workflow result and live update feed after a feature/fix push. Report an incomplete or failed publication clearly.
- Documentation-only changes do not need a new app release. Beta releases remain explicitly tagged/manual.
- Keep signing material private and ignored. Never replace the production signing key. Use emulators for installation tests; do not modify a connected physical phone without explicit instructions.
