# Internal mTLS CA

## Purpose

`Fleet mTLS Root CA` is the trust anchor for private machine-to-machine TLS inside the fleet.
It is not a public CA, or a replacement for ACME certificates, or a general purpose CA and must not be added to the operating system trust store.

The root signs one intermediate per service.
Each service intermediate signs only that service's leaf certificates.
This keeps a compromised intermediate from minting certificates for another service.

## Trust hierarchy

```text
Fleet mTLS Root CA (offline, pathlen 1, 10 years)
├── SeaweedFS Intermediate CA (offline, pathlen 0, 5 years)
│   └── master, volume, filer, admin, client, worker leaves (2 years)
└── Alloy Dynamic Capture Intermediate CA (offline, pathlen 0, 5 years)
    ├── per-host capture API server leaves (2 years)
    └── alloy-capture-relay client leaf (2 years)
```

The root and intermediates are CAs.
Leaf certificates are never CAs.

## Consumers

Keep the used domain aligned with `server.proxy.domain`.

| Consumer                       | Intermediate                            | Leaf profile                                                                                                              | Trust store file                      |
| ------------------------------ | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| SeaweedFS gRPC and Caddy proxy | `SeaweedFS Intermediate CA`             | `serverAuth` + `clientAuth`, SANs for `seaweedfs.${server.proxy.domain}` and `<service>.seaweedfs.${server.proxy.domain}` | `hosts/server/nixio/seaweedfs-tls/CA` |
| Alloy dynamic capture API      | `Alloy Dynamic Capture Intermediate CA` | `serverAuth`, SANs for `<host>`, `<host>.localdomain`, `<host>.${server.proxy.domain}`, `127.0.0.1`                       | `hosts/server/<host>/alloy/CA_CERT`   |
| Alloy capture relay client     | `Alloy Dynamic Capture Intermediate CA` | `clientAuth`, CN `alloy-capture-relay`                                                                                    | `hosts/server/nixmon/alloy/CA_CERT`   |

Service-specific leaf details live in:

- [Server Monitoring](../components/server_monitoring.md#alloy-leaf-certificates)
- [SeaweedFS](../modules/nixos/server/storage/seaweedfs.md#tls-trust-chain)

## Key custody

- Root private key: offline only, used only to sign or rotate service intermediates.
- Intermediate private keys: offline only, used only to sign that service's leaves.
- Leaf private keys: stored in SOPS for the consuming service.
- Root and intermediate certificates are public and may be distributed.

If an intermediate key is compromised, rotate that intermediate and reissue its leaves.
The other service and the root remain unaffected.

## Secret layout

TLS material is stored as binary SOPS files, not inline YAML values.
`sops.secrets` declarations point at these files with `format = "binary"`.

| Purpose                | Path                                             |
| ---------------------- | ------------------------------------------------ |
| SeaweedFS trust bundle | `hosts/server/nixio/seaweedfs-tls/CA`            |
| SeaweedFS leaf chain   | `hosts/server/nixio/seaweedfs-tls/<SERVICE>_CRT` |
| SeaweedFS leaf key     | `hosts/server/nixio/seaweedfs-tls/<SERVICE>_KEY` |
| Alloy trust root       | `hosts/server/<host>/alloy/CA_CERT`              |
| Alloy server chain     | `hosts/server/<host>/alloy/SERVER_CERT`          |
| Alloy server key       | `hosts/server/<host>/alloy/SERVER_KEY`           |
| Alloy client chain     | `hosts/server/nixmon/alloy/CLIENT_CERT`          |
| Alloy client key       | `hosts/server/nixmon/alloy/CLIENT_KEY`           |

The service intermediate is not a trust anchor.
Relying parties trust the root and receive the intermediate from the peer's certificate chain.

## Issuing certificates

Create the root once:

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out root.key
openssl req -x509 -new -key root.key -sha256 -days 3650 \
  -subj "/CN=Fleet mTLS Root CA" \
  -addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
  -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -out root.crt
```

Create a service intermediate:

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out <service>-intermediate.key
openssl req -new -key <service>-intermediate.key \
  -subj "/CN=<service> Intermediate CA" -out <service>-intermediate.csr
openssl x509 -req -in <service>-intermediate.csr \
  -CA root.crt -CAkey root.key -CAcreateserial \
  -days 1825 -sha256 -out <service>-intermediate.crt -extensions v3 \
  -extfile <(printf '[v3]\nbasicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\n')
```

Create a leaf with the service intermediate, then build the chain:

```bash
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out <leaf>.key
openssl req -new -key <leaf>.key -subj "/CN=<common-name>" -out <leaf>.csr
openssl x509 -req -in <leaf>.csr \
  -CA <service>-intermediate.crt -CAkey <service>-intermediate.key -CAcreateserial \
  -days 730 -sha256 -out <leaf>.crt -extensions v3 \
  -extfile <(printf '[v3]\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\nextendedKeyUsage=<eku>\nsubjectKeyIdentifier=hash\nauthorityKeyIdentifier=keyid,issuer\nsubjectAltName=<sans>\n')

cat <leaf>.crt <service>-intermediate.crt > <leaf>-chain.crt
```

Write a chain or trust bundle to its target file, then encrypt it in place:

```bash
mkdir -p hosts/server/<host>/alloy
cp <leaf>-chain.crt hosts/server/<host>/alloy/SERVER_CERT
sops encrypt --input-type binary --in-place hosts/server/<host>/alloy/SERVER_CERT
```

`sops` uses the target path to select the `.sops.yaml` recipients.
The encrypted file is a SOPS JSON envelope; `format = "binary"` makes sops-nix decrypt it back to the original PEM.

## Rotation

- **Leaf renewal:** sign with the current service intermediate.
  No trust-store change is needed.
- **Intermediate rotation:** sign a new intermediate with the root, reissue that service's leaves, and deploy the new chains.
  The trust store stays on the root.
- **Root rotation:** add the new root to the trust bundle, reissue all intermediates and leaves, deploy them, then remove the old root.
- **Revocation:** neither the Alloy API nor the SeaweedFS/Caddy path currently checks CRLs or OCSP.
  A leaked leaf certificate stays usable until it expires, or until its issuing intermediate is rotated and the service leaves are reissued.
  Per-leaf revocation would require adding CRL/OCSP support or using short-lived leaves.

## Verification

Verify a leaf against the root and intermediate:

```bash
openssl verify -CAfile root.crt -untrusted <service>-intermediate.crt <leaf>.crt
```

Verify a live mTLS peer:

```bash
openssl s_client -connect <host>:<port> \
  -CAfile root.crt -cert <client-chain>.crt -key <client>.key \
  -verify_hostname <host>
```

## Trust store policy

Do not install this CA with `security.pki` or any other OS-wide trust store.
Adding the CA to the OS trust store would let any process trust certificates signed by this CA for any hostname, which is broader than these services need.
