# very-git
Fine grained authentication of changes to a git repository, based on GPG signatures. Inspired by GUIX channel authentication.

Disclaimer: This is a research project, the software may effectively increase attack surface when run without proper sandboxing.
# usage
The checkCommitRange.sh skript expects to be given multiple commit references and a path to a .git directory. It does not make use of the worktree and should therefore also work with bare repos.
The commits it expects are:
- new commit: The one that is supposed to be verified
- current commit: can be given to avoid re-checking and downgrade attacks
- introduction commit: This is the root of trust, every commit that is to be included must be a decendant of this
The authentication is based on GPG-key-fingerprints, every directory may specify a .auth file that lists the fingerprints of the primary keys, that are allowed to change the contents of the directory. Permission to change a directory includes all subdirectories and files, to rename a directory the user must have the rights to alter its parent directory.
Merge commits will be reduced to their diff (we always follow the first parent path), this allows mergeing unsigned changes.
