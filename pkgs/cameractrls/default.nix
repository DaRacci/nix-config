{ lib
, stdenv
, fetchFromGitHub
}:

stdenv.mkDerivation rec {
  pname = "cameractrls";
  version = "0.5.5";

  src = fetchFromGitHub {
    owner = "soyersoyer";
    repo = "cameractrls";
    rev = "v${version}";
    hash = "sha256-0afI1SGRR9ioZ27fqcwE1gifp7KnDlqmYQyuKWGQcZk=";
  };

  meta = with lib; {
    description = "Camera controls for Linux";
    homepage = "https://github.com/soyersoyer/cameractrls";
    changelog = "https://github.com/soyersoyer/cameractrls/blob/${src.rev}/CHANGELOG.md";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
