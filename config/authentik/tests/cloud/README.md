# Cloud authentication regression

The symlinks load the actual cloud root's resources, discovery, locals, variables, and moves. Only provider encryption/backend, cloud helper discovery, and imports are omitted: mocked state outputs and helper context allow a credential-free full plan/apply without accessing cloud state. The released Arche source pin remains unchanged.

Run `tofu init -backend=false` and `tofu test` here. The shared child module has additional rendering regressions under `../../authentication/tests/`.
