# Task Completion Checklist

When a task is complete, do the following before considering it done:

1. **Track new files**: `jj file track <path>` for any new `.nix` files created
2. **Format**: `just fmt` — alejandra formatting is enforced in CI
3. **Lint** (optional but recommended): `just lint` — checks statix + deadnix
4. **Build**: `just build` or `just build <host>` — verify no evaluation errors
5. **Test** (on target host): `just test` — activates without setting boot default
6. **Switch** (when ready): `just switch` — activates and sets boot default

For secrets changes:
- After adding a recipient to `secrets/secrets.nix`: run `just rekey`
- Encrypt new secret: `agenix -e secrets/<name>.age`

Reference docs:
- Secrets workflow: `docs/references/secrets-sop.md`
- CI/GitHub Actions: `docs/references/ci-github-actions-sop.md`
