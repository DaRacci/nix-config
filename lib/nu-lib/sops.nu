# Encrypt a file in place as a binary SOPS file.
export def encrypt-binary [path: path] {
  ^sops encrypt --input-type binary --in-place $path
}
