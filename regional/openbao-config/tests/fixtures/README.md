# OpenBao configuration test fixture

Symlinks exercise the deployed configuration without its import blocks: OpenTofu's mocked providers do not support imports. Run `tofu test` from `regional/openbao-config`.

The lifecycle runs share this fixture's applied state: populate team policies, groups, and aliases; remove group declarations while retaining Logos team keys and an unchanged apply ACL; then remove those keys after cleanup. Fixture-only outputs carry the prior applied policy and resource keys between runs. These are mocked-provider state transitions, not a live OpenBao authorization test.
