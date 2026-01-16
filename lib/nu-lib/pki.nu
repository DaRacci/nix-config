# Issue a leaf certificate from a CA.
#
# Returns the work-directory paths for the key, CSR, certificate and chain.
export def issue-leaf [
  --work-dir: path # Directory receiving the key, CSR, extension file and certificate
  --name: string # Base file name for the generated files
  --common-name: string # Subject common name
  --san: list<string> = [] # Subject alternative names, for example ["DNS:host" "IP:127.0.0.1"]
  --key-usage: string = "critical,digitalSignature" # keyUsage extension value
  --extended-key-usage: string = "clientAuth" # extendedKeyUsage extension value
  --ca-cert: path # Issuing CA certificate
  --ca-key: any = null # Issuing CA private key path
  --ca-key-data: any = null # Issuing CA private key PEM passed on standard input
  --serial: path # CA serial file
  --days: int = 730 # Certificate lifetime
  --verify # Verify the issued leaf against the CA
] {
  if $ca_key == null and $ca_key_data == null {
    error make { msg: "issue-leaf needs --ca-key or --ca-key-data" }
  }

  let key = $work_dir | path join $"($name).key"
  let csr = $work_dir | path join $"($name).csr"
  let cert = $work_dir | path join $"($name).crt"
  let chain = $work_dir | path join $"($name)-chain.crt"
  let ext = $work_dir | path join $"($name).ext"

  let san_line = if ($san | is-empty) {
    []
  } else {
    [ $"subjectAltName=($san | str join ',')" ]
  }

  let extensions = [
    "[v3]"
    "basicConstraints=critical,CA:FALSE"
    $"keyUsage=($key_usage)"
    $"extendedKeyUsage=($extended_key_usage)"
    "subjectKeyIdentifier=hash"
    "authorityKeyIdentifier=keyid,issuer"
  ] ++ $san_line

  $extensions | str join "\n" | save --force $ext

  ^openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out $key
  ^openssl req -new -key $key -subj $"/CN=($common_name)" -out $csr
  if $ca_key_data == null {
    ^openssl x509 -req -in $csr -CA $ca_cert -CAkey $ca_key -CAserial $serial -CAcreateserial -days $days -sha256 -out $cert -extensions v3 -extfile $ext
  } else {
    $ca_key_data | ^openssl x509 -req -in $csr -CA $ca_cert -CAkey /dev/stdin -CAserial $serial -CAcreateserial -days $days -sha256 -out $cert -extensions v3 -extfile $ext
  }

  if $verify {
    verify-leaf $cert $ca_cert
  }

  ^cat $cert $ca_cert | save --force $chain

  { key: $key, csr: $csr, cert: $cert, chain: $chain }
}

# Issue an intermediate CA certificate from a signing CA.
#
# Returns the work-directory paths for the key, CSR and certificate.
export def issue-ca [
  --work-dir: path # Directory receiving the key, CSR, extension file and certificate
  --name: string # Base file name for the generated files
  --common-name: string # Subject common name
  --ca-cert: path # Issuing CA certificate
  --ca-key: any = null # Issuing CA private key path
  --ca-key-data: any = null # Issuing CA private key PEM passed on standard input
  --serial: path # Issuing CA serial file
  --days: int = 1825 # Certificate lifetime
  --path-length: int = 0 # Maximum CA depth below this intermediate
  --key-bits: int = 4096 # RSA key size
  --key-usage: string = "critical,keyCertSign,cRLSign" # keyUsage extension value
] {
  if $ca_key == null and $ca_key_data == null {
    error make { msg: "issue-ca needs --ca-key or --ca-key-data" }
  }

  let key = $work_dir | path join $"($name).key"
  let csr = $work_dir | path join $"($name).csr"
  let cert = $work_dir | path join $"($name).crt"
  let ext = $work_dir | path join $"($name).ext"

  let extensions = [
    "[v3]"
    $"basicConstraints=critical,CA:TRUE,pathlen:($path_length)"
    $"keyUsage=($key_usage)"
    "subjectKeyIdentifier=hash"
    "authorityKeyIdentifier=keyid,issuer"
  ]

  $extensions | str join "\n" | save --force $ext

  ^openssl genpkey -algorithm RSA -pkeyopt $"rsa_keygen_bits:($key_bits)" -out $key
  ^openssl req -new -key $key -subj $"/CN=($common_name)" -out $csr
  if $ca_key_data == null {
    ^openssl x509 -req -in $csr -CA $ca_cert -CAkey $ca_key -CAserial $serial -CAcreateserial -days $days -sha256 -out $cert -extensions v3 -extfile $ext
  } else {
    $ca_key_data | ^openssl x509 -req -in $csr -CA $ca_cert -CAkey /dev/stdin -CAserial $serial -CAcreateserial -days $days -sha256 -out $cert -extensions v3 -extfile $ext
  }

  { key: $key, csr: $csr, cert: $cert }
}

# Verify a leaf certificate against its issuing CA.
export def verify-leaf [leaf: path, ca: path] {
  let result = ^openssl verify -CAfile $ca -partial_chain $leaf | complete
  if $result.exit_code != 0 {
    error make { msg: $"Issued leaf does not verify against ($ca): ($result.stderr | str trim)" }
  }
}

# Validate a CA certificate's common name and basic constraints.
export def validate-ca-cert [
  cert: path # CA certificate
  --common-name: any = null # Expected subject common name
  --self-signed # Require the certificate to be self-signed
] {
  let subject = ^openssl x509 -in $cert -noout -subject -nameopt RFC2253 | str trim | str replace "subject=" ""
  let issuer = ^openssl x509 -in $cert -noout -issuer -nameopt RFC2253 | str trim | str replace "issuer=" ""

  if $self_signed {
    if $subject != $issuer {
      error make { msg: $"($cert) is not a self-signed certificate" }
    }
  } else if $subject == $issuer {
    error make { msg: $"($cert) is self-signed; expected a certificate issued by another CA" }
  }

  if $common_name != null and not ($subject | str contains $"CN=($common_name)") {
    error make { msg: $"($cert) is not the ($common_name)" }
  }

  let constraints = ^openssl x509 -in $cert -noout -ext basicConstraints | str trim
  if not ($constraints | str contains "CA:TRUE") {
    error make { msg: $"($cert) is not a CA certificate" }
  }
}

# Validate that a certificate and private key match.
export def validate-key-pair [
  cert: path # Certificate to check
  key?: any # Private key path
  --key-data: any = null # Private key PEM passed on standard input
] {
  if $key == null and $key_data == null {
    error make { msg: "validate-key-pair needs a key path or --key-data" }
  }

  let cert_public_key = ^openssl x509 -in $cert -noout -pubkey | str trim
  let key_label = if $key_data == null { $key } else { "standard input" }
  let key_public_key = if $key_data == null {
    ^openssl pkey -in $key -pubout | str trim
  } else {
    $key_data | ^openssl pkey -in /dev/stdin -pubout | str trim
  }
  if $cert_public_key != $key_public_key {
    error make { msg: $"($cert) and ($key_label) do not match" }
  }
}
