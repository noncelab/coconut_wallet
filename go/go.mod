module coconut_wallet/go

go 1.25.0

require (
	github.com/BitBoxSwiss/bitbox02-api-go v0.0.0
	github.com/btcsuite/btcd/btcutil/psbt v1.1.10
	github.com/flynn/noise v1.1.0
)

require (
	github.com/btcsuite/btcd v0.24.2 // indirect
	github.com/btcsuite/btcd/btcec/v2 v2.3.3 // indirect
	github.com/btcsuite/btcd/btcutil v1.1.6 // indirect
	github.com/btcsuite/btcd/chaincfg/chainhash v1.1.0 // indirect
	github.com/btcsuite/btclog v0.0.0-20170628155309-84c8d2346e9f // indirect
	github.com/decred/dcrd/crypto/blake256 v1.0.1 // indirect
	github.com/decred/dcrd/dcrec/secp256k1/v4 v4.2.0 // indirect
	github.com/pkg/errors v0.8.1 // indirect
	golang.org/x/crypto v0.27.0 // indirect
	golang.org/x/mobile v0.0.0-20260611195102-4dd8f1dbf5d2 // indirect
	golang.org/x/mod v0.37.0 // indirect
	golang.org/x/sync v0.21.0 // indirect
	golang.org/x/sys v0.46.0 // indirect
	golang.org/x/tools v0.46.0 // indirect
	google.golang.org/protobuf v1.33.0 // indirect
)

replace github.com/BitBoxSwiss/bitbox02-api-go => ../../bitbox02-api-go

tool golang.org/x/mobile/cmd/gobind
